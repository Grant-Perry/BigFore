import CoreLocation
import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class CourseSearchViewModel {
    var apiKey: String
    var query = ""
    var results: [GolfCourseAPICourse] = []
    var selectedCourse: GolfCourseAPICourse?
    var selectedTeeID: String?
    var isSearching = false
    var isLoadingCourse = false
    var errorMessage: String?
    var statusMessage: String?
    var recents: [CourseRecent]
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
}
