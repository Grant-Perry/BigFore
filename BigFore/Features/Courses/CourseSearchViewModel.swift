import CoreLocation
import Foundation
import MapKit
import Observation
import SwiftData

@MainActor
@Observable
final class CourseSearchViewModel {
    var apiKey: String
    var query = ""
    var results: [GolfCourseAPICourse] = []
    /// MapKit golf POIs near the search anchor (GPS or city/ZIP), sorted by distance (GolfCourseAPI has no lat/lon search).
    var nearbyMapKitRows: [CourseSearchNearbyMapRow] = []
    var selectedCourse: GolfCourseAPICourse?
    var selectedTeeID: String?
    var isSearching = false
    var isFindingClosest = false
    var isLoadingCourse = false
    var errorMessage: String?
    var statusMessage: String?
    var recents: [CourseRecent]
    var locationService = LocationService()
    /// City or US ZIP to anchor “Find closest” instead of GPS. Whitespace-trimmed empty → use GPS.
    var nearbyCityOrZIP = ""
    /// Miles from anchor: slider 10…150 in 10 mi steps; re-queries MapKit golf POIs when the slider is released.
    var nearbyRadiusMiles: Double = 10
    /// `true` after a successful Find closest run until you start a text search or run Find closest again.
    private(set) var isNearbySessionActive = false
    var isRefreshingNearbyForRadius = false

    @ObservationIgnored private var lastNearbyUserLocation: CLLocation?

    nonisolated static let nearbyRadiusSliderClosedRange: ClosedRange<Double> = 10.0...150.0
    nonisolated static let nearbyRadiusSliderStep: Double = 10

    @ObservationIgnored private let apiClientProvider: @MainActor (String) -> any GolfCourseAPIProviding
    @ObservationIgnored private let recentsStore: any CourseRecentsStoring
    @ObservationIgnored private let geometryStrategy: CourseGeometryStrategy
    @ObservationIgnored private let geometryProvider: any OpenStreetMapGolfGeometryProviding
    @ObservationIgnored private let geometryEditor: CourseGeometryEditor

    var hasSearchQuery: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(
        apiKey: String,
        geometryStrategy: CourseGeometryStrategy = CourseGeometryStrategy(),
        apiClientProvider: @escaping @MainActor (String) -> any GolfCourseAPIProviding = { GolfCourseAPIClient(apiKey: $0) },
        recentsStore: any CourseRecentsStoring = UserDefaultsCourseRecentsStore(),
        geometryProvider: any OpenStreetMapGolfGeometryProviding = OpenStreetMapGolfGeometryClient(),
        geometryEditor: CourseGeometryEditor = CourseGeometryEditor()
    ) {
        self.apiKey = apiKey
        self.geometryStrategy = geometryStrategy
        self.apiClientProvider = apiClientProvider
        self.recentsStore = recentsStore
        self.recents = recentsStore.load()
        self.geometryProvider = geometryProvider
        self.geometryEditor = geometryEditor
    }

    func search() async {
        errorMessage = nil
        statusMessage = nil
        results = []
        nearbyMapKitRows = []
        lastNearbyUserLocation = nil
        isNearbySessionActive = false
        selectedCourse = nil
        selectedTeeID = nil

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return
        }

        isSearching = true
        defer { isSearching = false }

        do {
            results = try await apiClientProvider(apiKey).search(query: trimmedQuery)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func findClosestCourses() async {
        errorMessage = nil
        statusMessage = nil
        results = []
        nearbyMapKitRows = []
        lastNearbyUserLocation = nil
        isNearbySessionActive = false
        selectedCourse = nil
        selectedTeeID = nil

        let trimmedAnchor = nearbyCityOrZIP.trimmingCharacters(in: .whitespacesAndNewlines)

        isFindingClosest = true
        defer {
            isFindingClosest = false
            locationService.stopLocationUpdates()
        }

        let anchorLocation: CLLocation
        if !trimmedAnchor.isEmpty {
            do {
                anchorLocation = try await Self.forwardGeocodeCityOrZIP(trimmedAnchor)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        } else {
            switch locationService.authorizationStatus {
            case .denied, .restricted:
                errorMessage = "Location access is off. Enable it in Settings to find nearby courses, or enter a city or ZIP above."
                return
            default:
                break
            }

            guard let userLocation = await locationService.waitForLocationFix() else {
                if locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted {
                    errorMessage = "Location access is off. Enable it in Settings to find nearby courses, or enter a city or ZIP above."
                } else if let message = locationService.errorMessage {
                    errorMessage = message
                } else {
                    errorMessage = "Could not get a GPS fix. Try again outdoors, enter a city or ZIP above, or open Maps briefly to wake location services."
                }
                return
            }
            anchorLocation = userLocation
        }

        lastNearbyUserLocation = anchorLocation

        do {
            try await refreshNearbyMapKitRows(userLocation: anchorLocation)
            isNearbySessionActive = true
            errorMessage = nil
            if nearbyMapKitRows.isEmpty {
                statusMessage = "No golf courses on Apple Maps within \(Int(nearbyRadiusMiles)) mi. Slide the radius toward \(Int(Self.nearbyRadiusSliderClosedRange.upperBound)) mi or try again after moving."
            } else {
                statusMessage = "\(nearbyMapKitRows.count) map pins within \(Int(nearbyRadiusMiles)) mi. Tap one to match it to the course database."
            }
        } catch {
            errorMessage = error.localizedDescription
            nearbyMapKitRows = []
            isNearbySessionActive = false
            lastNearbyUserLocation = nil
        }
    }

    /// Called when the radius slider is released (`onEditingChanged(false)`).
    func refreshNearbyRadiusAfterSliderReleased() async {
        guard isNearbySessionActive, lastNearbyUserLocation != nil else {
            return
        }
        guard !isFindingClosest else {
            return
        }
        await performNearbyRadiusSearchRefresh()
    }

    private func performNearbyRadiusSearchRefresh() async {
        guard let userLocation = lastNearbyUserLocation, isNearbySessionActive else {
            return
        }
        guard !isFindingClosest else {
            return
        }

        isRefreshingNearbyForRadius = true
        defer { isRefreshingNearbyForRadius = false }

        errorMessage = nil
        statusMessage = "Searching map for \(Int(nearbyRadiusMiles)) mi…"

        do {
            try await refreshNearbyMapKitRows(userLocation: userLocation)
            if nearbyMapKitRows.isEmpty {
                statusMessage = "No golf courses on Apple Maps within \(Int(nearbyRadiusMiles)) mi."
            } else {
                statusMessage = "\(nearbyMapKitRows.count) map pins within \(Int(nearbyRadiusMiles)) mi."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshNearbyMapKitRows(userLocation: CLLocation) async throws {
        let pairs = try await NearbyMapKitGolfSearch.mapItemsSortedByDistance(
            userLocation: userLocation,
            radiusMiles: nearbyRadiusMiles,
            maxResults: 45
        )
        nearbyMapKitRows = pairs.map { CourseSearchNearbyMapRow(mapItem: $0.mapItem, distanceMeters: $0.distanceMeters) }
    }

    /// Resolves a MapKit golf POI to a GolfCourseAPI course (text search + coordinate pick).
    func selectNearbyMapRow(_ row: CourseSearchNearbyMapRow) async {
        errorMessage = nil
        let mapLocation = row.mapItem.location

        let representations = row.mapItem.addressRepresentations
        let queryParts: [String] = [
            row.mapItem.name,
            representations?.cityName,
            representations?.regionName
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

        var seen = Set<String>()
        var uniqueParts: [String] = []
        for part in queryParts {
            let key = part.lowercased()
            if seen.insert(key).inserted {
                uniqueParts.append(part)
            }
        }
        let query = uniqueParts.joined(separator: " ")
        guard !query.isEmpty else {
            errorMessage = "Could not build a database search from this place."
            return
        }

        do {
            let api = apiClientProvider(apiKey)
            let hits = try await api.search(query: query)
            guard let best = Self.bestCourseMatch(from: hits, near: mapLocation) else {
                errorMessage = "No matching course in the database for “\(row.title)”. Try manual search."
                return
            }
            await loadCourse(id: best.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func bestCourseMatch(from hits: [GolfCourseAPICourse], near location: CLLocation) -> GolfCourseAPICourse? {
        let withDistance: [(GolfCourseAPICourse, CLLocationDistance)] = hits.compactMap { course in
            guard let lat = course.location.latitude, let lon = course.location.longitude else {
                return nil
            }
            let loc = CLLocation(latitude: lat, longitude: lon)
            return (course, location.distance(from: loc))
        }
        if let best = withDistance.min(by: { $0.1 < $1.1 }) {
            return best.0
        }
        return hits.first
    }

    /// Search hits often omit lat/long; detail responses usually include them.
    internal func enrichSearchHitsWithCoordinates(
        _ searchHits: [GolfCourseAPICourse],
        api: any GolfCourseAPIProviding,
        maxSearchHitsConsidered: Int = 45,
        maxDetailFetches: Int = 35
    ) async throws -> [GolfCourseAPICourse] {
        let window = Array(searchHits.prefix(maxSearchHitsConsidered))
        guard !window.isEmpty else {
            return []
        }

        var enriched = window
        let missingIndices = window.enumerated().compactMap { index, course -> Int? in
            (course.location.latitude == nil || course.location.longitude == nil) ? index : nil
        }
        let indicesToFetch = Array(missingIndices.prefix(maxDetailFetches))

        for index in indicesToFetch {
            enriched[index] = try await api.course(id: enriched[index].id)
        }

        return enriched
    }

    func loadCourse(id: Int) async {
        errorMessage = nil
        statusMessage = nil
        selectedCourse = nil
        selectedTeeID = nil
        isLoadingCourse = true
        defer { isLoadingCourse = false }

        do {
            let course = try await apiClientProvider(apiKey).course(id: id)
            selectedCourse = course
            selectedTeeID = defaultTeeID(for: course.allTees)
            recordRecent(course: course)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func ensureOpenStreetMapGeometryIfNeeded(modelContext: ModelContext) async {
        guard let selectedCourse else {
            return
        }

        guard let latitude = selectedCourse.location.latitude,
              let longitude = selectedCourse.location.longitude else {
            statusMessage = "Course loaded. No course coordinates were available for OSM geometry."
            return
        }

        do {
            if try hasCachedOpenStreetMapGeometry(courseExternalID: selectedCourse.id, modelContext: modelContext) {
                return
            }

            statusMessage = "Loading OpenStreetMap geometry..."
            let geometryImport = try await geometryProvider.geometry(for: OpenStreetMapGolfGeometryRequest(
                courseExternalID: selectedCourse.id,
                centerCoordinate: .init(latitude: latitude, longitude: longitude)
            ))
            let geometry = try geometryEditor.importGeometry(geometryImport, modelContext: modelContext)
            let holeCount = geometry.holes.count
            statusMessage = "Loaded OpenStreetMap geometry for \(holeCount) \(holeCount == 1 ? "hole" : "holes")."
        } catch OpenStreetMapGolfGeometryError.emptyGeometry {
            statusMessage = "Course loaded. No OpenStreetMap hole geometry was found."
        } catch {
            statusMessage = "Course loaded. OpenStreetMap geometry could not be loaded."
        }
    }

    func recordRecent(course: GolfCourseAPICourse) {
        let recent = CourseRecent(course: course)
        recents.removeAll { $0.id == recent.id }
        recents.insert(recent, at: 0)
        recents = Array(recents.prefix(UserDefaultsCourseRecentsStore.limit))
        recentsStore.save(recents)
    }

    func deleteRecent(id: Int) {
        recents.removeAll { $0.id == id }
        recentsStore.save(recents)
    }

    func clearRecents() {
        recents = []
        recentsStore.save(recents)
    }

    func selectTee(id: String) {
        selectedTeeID = id
    }

    var courseGeometryNotice: String {
        geometryStrategy.currentLimitationsNotice
    }

    func save(course: GolfCourseAPICourse, modelContext: ModelContext) {
        errorMessage = nil
        statusMessage = nil

        modelContext.insert(GolfCourse(apiCourse: course))

        do {
            try modelContext.save()
            statusMessage = "Saved \(course.displayName)."
        } catch {
            modelContext.rollback()
            errorMessage = "Could not save course: \(error.localizedDescription)"
        }
    }

    private func defaultTeeID(for tees: [GolfCourseAPITeeBox]) -> String? {
        tees.first?.id
    }

    private func hasCachedOpenStreetMapGeometry(courseExternalID: Int, modelContext: ModelContext) throws -> Bool {
        var descriptor = FetchDescriptor<CourseGeometry>(
            predicate: #Predicate { geometry in
                geometry.courseExternalID == courseExternalID
            }
        )
        descriptor.fetchLimit = 1

        guard let geometry = try modelContext.fetch(descriptor).first else {
            return false
        }

        let source = CourseGeometrySource(rawValue: geometry.sourceRawValue)
        return source == .openStreetMap && !geometry.holes.isEmpty
    }

    private static func forwardGeocodeCityOrZIP(_ query: String) async throws -> CLLocation {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first else {
            throw CourseSearchAnchorGeocodeError.noResults
        }
        return item.location
    }
}

struct CourseSearchNearbyMapRow: Identifiable {
    let mapItem: MKMapItem
    let distanceMeters: CLLocationDistance

    var title: String {
        if let name = mapItem.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }
        if let city = mapItem.addressRepresentations?.cityName?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
            return city
        }
        return "Golf course"
    }

    var id: String {
        let coordinate = mapItem.location.coordinate
        let lat = (coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (coordinate.longitude * 10_000).rounded() / 10_000
        return "\(title.lowercased())|\(lat)|\(lon)"
    }

    var distanceCaption: String {
        CourseSearchDistanceFormatting.caption(forMeters: distanceMeters)
    }

    var subtitle: String? {
        guard let representations = mapItem.addressRepresentations else {
            return nil
        }
        var parts: [String] = []
        if let city = representations.cityName?.trimmingCharacters(in: .whitespacesAndNewlines), !city.isEmpty {
            parts.append(city)
        }
        if let region = representations.regionName?.trimmingCharacters(in: .whitespacesAndNewlines), !region.isEmpty {
            parts.append(region)
        }
        guard !parts.isEmpty else {
            return nil
        }
        return parts.joined(separator: ", ")
    }
}

private enum CourseSearchAnchorGeocodeError: LocalizedError {
    case noResults

    var errorDescription: String? {
        switch self {
        case .noResults:
            "Could not find that city or ZIP on the map. Try another spelling or include the state (for example, \"Denver, CO\")."
        }
    }
}
