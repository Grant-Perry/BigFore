import CoreLocation
import Foundation
import MapKit
import Observation
import SwiftData
import SwiftUI

struct CourseMapShotMarker: Identifiable {
    let id: UUID
    let shotNumber: Int
    var startCoordinate: CLLocationCoordinate2D
    var ballCoordinate: CLLocationCoordinate2D
    var source: ShotRecordSource
    var clubID: UUID?
    var clubName: String?

    init(
        id: UUID = UUID(),
        shotNumber: Int,
        startCoordinate: CLLocationCoordinate2D,
        ballCoordinate: CLLocationCoordinate2D,
        source: ShotRecordSource = .manualMap,
        clubID: UUID? = nil,
        clubName: String? = nil
    ) {
        self.id = id
        self.shotNumber = shotNumber
        self.startCoordinate = startCoordinate
        self.ballCoordinate = ballCoordinate
        self.source = source
        self.clubID = clubID
        self.clubName = clubName
    }
}

struct CourseMapShotSummary: Identifiable, Equatable {
    let id: UUID
    let shotNumber: Int
    let clubName: String?
    let distanceFromPreviousText: String
    let distanceToPinText: String?
    let isSelected: Bool
}

struct CourseMapInfoSelection: Identifiable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
    let cardPlacement: CourseMapInfoCardPlacement
}

enum CourseMapInfoCardPlacement {
    case above
    case trailing
}

struct CourseMapInfoSummary: Equatable {
    let title: String
    let referenceDistanceLabel: String
    let referenceDistanceText: String?
    let pinDistanceText: String?
}

struct CourseMapClubRecommendation: Equatable {
    let title: String
    let detail: String
    let distanceText: String
    let confidenceText: String
    let weatherText: String?
}

struct CourseMapClubLandingTarget: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let coordinate: CLLocationCoordinate2D
    let lineCoordinates: [CLLocationCoordinate2D]

    static func == (lhs: CourseMapClubLandingTarget, rhs: CourseMapClubLandingTarget) -> Bool {
        lhs.title == rhs.title
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
            && lhs.lineCoordinates.count == rhs.lineCoordinates.count
    }
}

private struct CourseMapHoleSession {
    var measuredCoordinate: CLLocationCoordinate2D?
    var teeBoxCoordinate: CLLocationCoordinate2D?
    var holePinCoordinate: CLLocationCoordinate2D?
    var shotStartCoordinate: CLLocationCoordinate2D?
    var shotEndCoordinate: CLLocationCoordinate2D?
    var shotMarkers: [CourseMapShotMarker]
    var selectedShotMarkerID: UUID?
    var currentShotMarkerID: UUID?

    var isEmpty: Bool {
        measuredCoordinate == nil
            && teeBoxCoordinate == nil
            && holePinCoordinate == nil
            && shotStartCoordinate == nil
            && shotEndCoordinate == nil
            && shotMarkers.isEmpty
            && selectedShotMarkerID == nil
            && currentShotMarkerID == nil
    }
}

private struct CourseMapStickyAnchorUndo {
    let kind: CourseMapFeatureKind
    let userMappedCoordinate: CLLocationCoordinate2D?
}

private struct CourseMapPlacementUndo {
    let previousSession: CourseMapHoleSession
    let stickyAnchor: CourseMapStickyAnchorUndo?
    let syncsShotScore: Bool
}

@MainActor
@Observable
final class CourseMapViewModel {
    let course: CourseMapPoint
    private var standaloneHoleNumber: Int
    var round: GolfRound?
    var locationService: LocationService
    var position: MapCameraPosition
    var selectionMode = CourseMapSelectionMode.inactive
    var measuredCoordinate: CLLocationCoordinate2D?
    var teeBoxCoordinate: CLLocationCoordinate2D?
    var holePinCoordinate: CLLocationCoordinate2D?
    var shotStartCoordinate: CLLocationCoordinate2D?
    var shotEndCoordinate: CLLocationCoordinate2D?
    var shotMarkers: [CourseMapShotMarker] = []
    var selectedShotMarkerID: UUID?
    var selectedMapInfo: CourseMapInfoSelection?
    var selectedScoringPlayerID: UUID?
    var selectedClubID: UUID?
    var selectedFeatureKind = CourseMapFeatureKind.target
    var featureLabel = ""
    var statusMessage: String?
    var errorMessage: String?
    var isGPSCentered = false
    private(set) var cameraCenter: CLLocationCoordinate2D
    private(set) var cameraDistance: CLLocationDistance
    private(set) var cameraHeading: CLLocationDirection
    private(set) var cameraPitch: CGFloat
    var isRefreshingGeometry = false
    private let distanceCalculator: DistanceCalculator
    private let geometryEditor: CourseGeometryEditor
    @ObservationIgnored private let geometryProvider: any OpenStreetMapGolfGeometryProviding
    private var currentShotMarkerID: UUID?
    private var holeSessions: [Int: CourseMapHoleSession] = [:]
    private var placementUndoActions: [Int: [CourseMapPlacementUndo]] = [:]
    private static let defaultCameraDistance: CLLocationDistance = 1_200
    private static let minimumCameraDistance: CLLocationDistance = 75
    private static let maximumCameraDistance: CLLocationDistance = 25_000
    private static let holeFlyoverDistanceScale: CLLocationDistance = 0.5
    private static let holeFlyoverPitch: CGFloat = 55
    private static let rotationStep: CLLocationDirection = 15
    private static let minimumTrustedClubShotCount = 3
    private static let acceptableShortMissYards = 7

    init(
        course: CourseMapPoint,
        currentHoleNumber: Int? = nil,
        round: GolfRound? = nil,
        focusedPlayerID: UUID? = nil,
        locationService: LocationService? = nil,
        distanceCalculator: DistanceCalculator? = nil,
        geometryEditor: CourseGeometryEditor = CourseGeometryEditor(),
        geometryProvider: any OpenStreetMapGolfGeometryProviding = OpenStreetMapGolfGeometryClient()
    ) {
        self.course = course
        self.standaloneHoleNumber = round?.currentHole ?? currentHoleNumber ?? 1
        self.round = round
        self.locationService = locationService ?? LocationService()
        self.distanceCalculator = distanceCalculator ?? DistanceCalculator()
        self.geometryEditor = geometryEditor
        self.geometryProvider = geometryProvider
        let sortedPlayers = Self.sortedPlayers(for: round)
        selectedScoringPlayerID = sortedPlayers.first { $0.id == focusedPlayerID }?.id ?? sortedPlayers.first?.id
        cameraCenter = course.coordinate
        cameraDistance = Self.defaultCameraDistance
        cameraHeading = 0
        cameraPitch = 0
        position = .camera(Self.camera(center: course.coordinate, distance: Self.defaultCameraDistance))
    }

    var mapSubtitle: String {
        "\(course.clubName) · Hole \(targetHoleNumber)"
    }

    var measuredPointDistanceFromCourseText: String? {
        guard let measuredCoordinate else {
            return nil
        }

        return distanceCalculator.formattedYards(from: course.coordinate, to: measuredCoordinate)
    }

    var measuredPointDistanceFromUserText: String? {
        guard let measuredCoordinate, let currentLocation = locationService.currentLocation else {
            return nil
        }

        return distanceCalculator.formattedYards(from: currentLocation.coordinate, to: measuredCoordinate)
    }

    var teeToHolePinDistanceText: String? {
        guard let teeBoxCoordinate, let holePinCoordinate else {
            return nil
        }

        return distanceCalculator.formattedYards(from: teeBoxCoordinate, to: holePinCoordinate)
    }

    var shotLocationToHolePinDistanceText: String? {
        guard let holePinCoordinate, let shotLocationCoordinate else {
            return nil
        }

        return distanceCalculator.formattedYards(from: shotLocationCoordinate, to: holePinCoordinate)
    }

    var shotLocationToHolePinLabel: String {
        if shotEndCoordinate != nil {
            return "Ball to pin"
        }

        if locationService.currentLocation != nil {
            return "Me to pin"
        }

        if shotStartCoordinate != nil {
            return "Shot start to pin"
        }

        return "Tee to pin"
    }

    var selectedShotMarker: CourseMapShotMarker? {
        guard let selectedShotMarkerID else {
            return nil
        }

        return shotMarkers.first { $0.id == selectedShotMarkerID }
    }

    var selectedShotMarkerDistanceToPinText: String? {
        guard let selectedShotMarker, let holePinCoordinate else {
            return nil
        }

        return distanceCalculator.formattedYards(from: selectedShotMarker.ballCoordinate, to: holePinCoordinate)
    }

    var selectedShotMarkerPreviousDistanceLabel: String? {
        guard let selectedShotMarker else {
            return nil
        }

        if selectedShotMarker.shotNumber == 1 {
            return "From tee"
        }

        if selectedShotMarker.shotNumber == 2 {
            return "From drive"
        }

        return "From shot \(selectedShotMarker.shotNumber - 1)"
    }

    var selectedShotMarkerPreviousDistanceText: String? {
        guard let selectedShotMarker else {
            return nil
        }

        return distanceCalculator.formattedYards(
            from: previousShotCoordinate(for: selectedShotMarker),
            to: selectedShotMarker.ballCoordinate
        )
    }

    var selectedShotMarkerTitle: String? {
        guard let selectedShotMarker else {
            return nil
        }

        return "Shot \(selectedShotMarker.shotNumber) ball"
    }

    var selectedMapInfoSummary: CourseMapInfoSummary? {
        guard let selectedMapInfo else {
            return nil
        }

        if selectedMapInfoIsSelectedShotMarkerBall(selectedMapInfo) {
            return CourseMapInfoSummary(
                title: selectedMapInfo.title,
                referenceDistanceLabel: selectedShotMarkerPreviousDistanceLabel ?? "From previous",
                referenceDistanceText: selectedShotMarkerPreviousDistanceText,
                pinDistanceText: selectedShotMarkerDistanceToPinText
            )
        }

        return CourseMapInfoSummary(
            title: selectedMapInfo.title,
            referenceDistanceLabel: selectedMapReference?.label ?? "Reference to this",
            referenceDistanceText: selectedMapReference.map {
                distanceCalculator.formattedYards(from: $0.coordinate, to: selectedMapInfo.coordinate)
            },
            pinDistanceText: holePinCoordinate.map {
                distanceCalculator.formattedYards(from: selectedMapInfo.coordinate, to: $0)
            }
        )
    }

    var shotSummaries: [CourseMapShotSummary] {
        displayedShotMarkers.map { marker in
            CourseMapShotSummary(
                id: marker.id,
                shotNumber: marker.shotNumber,
                clubName: marker.clubName,
                distanceFromPreviousText: distanceCalculator.formattedYards(
                    from: previousShotCoordinate(for: marker),
                    to: marker.ballCoordinate
                ),
                distanceToPinText: holePinCoordinate.map {
                    distanceCalculator.formattedYards(from: marker.ballCoordinate, to: $0)
                },
                isSelected: marker.id == selectedShotMarkerID
            )
        }
    }

    var savedShotLineSegments: [[CLLocationCoordinate2D]] {
        displayedShotMarkers
            .sorted { $0.shotNumber < $1.shotNumber }
            .map { [$0.startCoordinate, $0.ballCoordinate] }
    }

    var hasAnyShotForCurrentHole: Bool {
        displayedShotMarkers.isEmpty == false
    }

    var canStartNextShotFromBall: Bool {
        shotEndCoordinate != nil
    }

    var canMarkBall: Bool {
        shotStartCoordinate != nil || (shotMarkers.isEmpty && teeBoxCoordinate != nil)
    }

    var canUndoLastPin: Bool {
        placementUndoActions[targetHoleNumber]?.isEmpty == false
    }

    var manualShotHelpText: String {
        "Set Tee and Pin once. Then Start, Ball, Next Shot, repeat."
    }

    func selectedClubName(from clubs: [GolfClub]) -> String {
        selectedClub(from: clubs)?.name ?? "No club selected"
    }

    func selectedClubShortName(from clubs: [GolfClub]) -> String {
        guard let club = selectedClub(from: clubs) else {
            return "Club"
        }

        switch club.kind {
        case .driver:
            return "Dr"
        case .fairwayWood, .hybrid, .iron, .wedge:
            return club.name.replacingOccurrences(of: " ", with: "")
        case .putter:
            return "Putt"
        case .other:
            return club.name
        }
    }

    func selectedClubAverageText(from clubs: [GolfClub]) -> String? {
        guard let club = selectedClub(from: clubs) else {
            return "Pick a club so Woody can learn your distances."
        }

        let matchingShots = trustedShots(for: club)
        guard matchingShots.count >= Self.minimumTrustedClubShotCount else {
            return "Woody will use \(club.name)'s \(club.carryYards)-yard default until you have shot history."
        }

        let average = matchingShots.map(\.distanceYards).reduce(0, +) / matchingShots.count
        return "\(club.name) average: \(average) yds from \(matchingShots.count) saved \(matchingShots.count == 1 ? "shot" : "shots")."
    }

    func selectDefaultClubIfNeeded(from clubs: [GolfClub]) {
        let activeClubs = clubs.filter(\.isActive).sorted { $0.displayOrder < $1.displayOrder }
        guard selectedClubID == nil || activeClubs.contains(where: { $0.id == selectedClubID }) == false else {
            return
        }

        selectedClubID = activeClubs.first?.id
    }

    func selectWoodyClub(from clubs: [GolfClub]) {
        selectWoodyClub(from: clubs, geometries: [])
    }

    func selectWoodyClub(from clubs: [GolfClub], geometries: [CourseGeometry]) {
        let activeClubs = clubs.filter(\.isActive).sorted { $0.displayOrder < $1.displayOrder }
        guard activeClubs.isEmpty == false else {
            selectedClubID = nil
            return
        }

        guard let holePinCoordinate, let shotPlanningCoordinate else {
            selectedClubID = activeClubs.first?.id
            return
        }

        let targetYards = distanceCalculator.yards(from: shotPlanningCoordinate, to: holePinCoordinate)
        selectedClubID = bestClub(
            forTargetYards: targetYards,
            from: activeClubs,
            origin: shotPlanningCoordinate,
            target: holePinCoordinate,
            geometries: geometries
        ).id
    }

    func clubRecommendation(from clubs: [GolfClub], geometries: [CourseGeometry] = []) -> CourseMapClubRecommendation? {
        let activeClubs = clubs.filter(\.isActive).sorted { $0.displayOrder < $1.displayOrder }
        guard activeClubs.isEmpty == false else {
            return CourseMapClubRecommendation(
                title: "Woody needs a club",
                detail: "Pick a club from your bag before Woody can make a call.",
                distanceText: "No club selected",
                confidenceText: "No recommendation yet",
                weatherText: latestWeatherText
            )
        }

        guard let holePinCoordinate, let shotPlanningCoordinate else {
            let selectedClub = selectedClub(from: activeClubs) ?? activeClubs.first
            return CourseMapClubRecommendation(
                title: "Woody needs a pin",
                detail: "Set the tee, pin, or ball position so Woody can see the shot.",
                distanceText: selectedClub.map { "\($0.name): \($0.carryYards) yd default" } ?? "No target distance",
                confidenceText: "Waiting for target distance",
                weatherText: latestWeatherText
            )
        }

        let targetYards = distanceCalculator.yards(from: shotPlanningCoordinate, to: holePinCoordinate)
        let bestClub = bestClub(forTargetYards: targetYards, from: activeClubs, origin: shotPlanningCoordinate, target: holePinCoordinate, geometries: geometries)
        let selectedClub = selectedClub(from: activeClubs)
        let history = trustedShots(for: bestClub)
        let expectedYards = expectedDistance(for: bestClub)
        let sourceText = history.count < Self.minimumTrustedClubShotCount ? "default" : "\(history.count)-shot average"
        let gap = targetYards - expectedYards
        let detail: String

        if abs(gap) <= 7 {
            detail = "\(bestClub.name) fits: \(expectedYards) yds \(sourceText) for a \(targetYards)-yd shot."
        } else if gap > 0 {
            detail = "\(bestClub.name) is closest but may be short: \(expectedYards) yds \(sourceText), \(targetYards) to the pin."
        } else {
            detail = "\(bestClub.name) is closest but may be long: \(expectedYards) yds \(sourceText), \(targetYards) to the pin."
        }

        return CourseMapClubRecommendation(
            title: "Woody says \(bestClub.name)",
            detail: selectedClub?.id == bestClub.id ? detail : "\(detail) Selected shot club: \(selectedClub?.name ?? "none").",
            distanceText: "\(targetYards) yds to pin",
            confidenceText: history.count < Self.minimumTrustedClubShotCount ? "Best fit from starter bag" : "Best fit from your saved shots",
            weatherText: latestWeatherText
        )
    }

    func clubLandingTarget(from clubs: [GolfClub], geometries: [CourseGeometry] = []) -> CourseMapClubLandingTarget? {
        guard !hasAnyShotForCurrentHole else {
            return nil
        }

        let activeClubs = clubs.filter(\.isActive).sorted { $0.displayOrder < $1.displayOrder }
        guard activeClubs.isEmpty == false,
              let origin = shotPlanningCoordinate,
              let holePinCoordinate else {
            return nil
        }

        let targetYards = distanceCalculator.yards(from: origin, to: holePinCoordinate)
        let club = bestClub(forTargetYards: targetYards, from: activeClubs, origin: origin, target: holePinCoordinate, geometries: geometries)
        let expectedYards = expectedDistance(for: club)
        guard expectedYards > 0 else {
            return nil
        }

        let bearing = Self.bearing(from: origin, to: holePinCoordinate)
        let targetCoordinate = Self.coordinate(from: origin, bearing: bearing, distanceYards: expectedYards)
        return CourseMapClubLandingTarget(
            title: "\(club.name) target \(expectedYards) yds",
            coordinate: targetCoordinate,
            lineCoordinates: [origin, targetCoordinate]
        )
    }

    var courseToMeasuredCoordinates: [CLLocationCoordinate2D]? {
        guard let measuredCoordinate else {
            return nil
        }

        return [course.coordinate, measuredCoordinate]
    }

    var userToMeasuredCoordinates: [CLLocationCoordinate2D]? {
        guard let measuredCoordinate, let currentLocation = locationService.currentLocation else {
            return nil
        }

        return [currentLocation.coordinate, measuredCoordinate]
    }

    var shotDistanceText: String? {
        guard let shotStartCoordinate, let shotEndCoordinate = shotMeasurementEndCoordinate else {
            return nil
        }

        return distanceCalculator.formattedYards(from: shotStartCoordinate, to: shotEndCoordinate)
    }

    var shotMeasurementEndCoordinate: CLLocationCoordinate2D? {
        shotEndCoordinate ?? locationService.currentLocation?.coordinate
    }

    var isTrackingShot: Bool {
        shotStartCoordinate != nil && shotEndCoordinate == nil
    }

    var shotMeasurementCoordinates: [CLLocationCoordinate2D]? {
        guard let shotStartCoordinate, let shotEndCoordinate = shotMeasurementEndCoordinate else {
            return nil
        }

        return [shotStartCoordinate, shotEndCoordinate]
    }

    var teeToHolePinCoordinates: [CLLocationCoordinate2D]? {
        guard !hasAnyShotForCurrentHole else {
            return nil
        }

        guard let teeBoxCoordinate, let holePinCoordinate else {
            return nil
        }

        return [teeBoxCoordinate, holePinCoordinate]
    }

    var shotLocationToHolePinCoordinates: [CLLocationCoordinate2D]? {
        guard let holePinCoordinate,
              let shotLocationCoordinate = shotEndCoordinate ?? shotStartCoordinate else {
            return nil
        }

        return [shotLocationCoordinate, holePinCoordinate]
    }

    func nextHoleTransitionCoordinates(from geometries: [CourseGeometry]) -> [CLLocationCoordinate2D]? {
        let currentHolePin = holePinCoordinate ?? Self.preferredHoleSetup(from: geometries, holeNumber: targetHoleNumber).holePinCoordinate
        guard let currentHolePin,
              let nextHoleNumber,
              let nextHoleCoordinate = Self.preferredNextHoleTransitionCoordinate(from: geometries, holeNumber: nextHoleNumber) else {
            return nil
        }

        return [currentHolePin, nextHoleCoordinate]
    }

    var targetHoleNumber: Int {
        round?.currentHole ?? standaloneHoleNumber
    }

    var availableHoles: [Int] {
        guard let selectedScoringPlayer else {
            return Array(1...18)
        }

        let holes = selectedScoringPlayer.scores.map(\.holeNumber).sorted()
        return holes.isEmpty ? Array(1...18) : holes
    }

    var previousHoleNumber: Int? {
        adjacentHole(from: targetHoleNumber, offset: -1)
    }

    var nextHoleNumber: Int? {
        adjacentHole(from: targetHoleNumber, offset: 1)
    }

    var canMoveToPreviousHole: Bool {
        previousHoleNumber != nil
    }

    var canMoveToNextHole: Bool {
        nextHoleNumber != nil
    }

    var defaultFeatureLabel: String {
        "\(selectedFeatureKind.title) \(targetHoleNumber)"
    }

    var scoringPlayers: [RoundPlayer] {
        Self.sortedPlayers(for: round)
    }

    var selectedScoringPlayer: RoundPlayer? {
        if selectedScoringPlayerID == nil {
            selectedScoringPlayerID = scoringPlayers.first?.id
        }

        guard let selectedScoringPlayerID else {
            return scoringPlayers.first
        }

        return scoringPlayers.first { $0.id == selectedScoringPlayerID } ?? scoringPlayers.first
    }

    var selectedHoleScore: HoleScore? {
        selectedScoringPlayer?.scores.first { $0.holeNumber == targetHoleNumber }
    }

    var selectedScoringPlayerName: String? {
        selectedScoringPlayer?.name
    }

    var scoringPlayerDetailText: String? {
        guard let selectedScoringPlayer else {
            return nil
        }

        return "Ball: \(selectedScoringPlayer.name)"
    }

    func holeParText(for holeNumber: Int) -> String? {
        let holeScore = selectedScoringPlayer?.scores.first { $0.holeNumber == holeNumber }
            ?? round?.players
                .flatMap(\.scores)
                .first { $0.holeNumber == holeNumber }

        guard let par = holeScore?.par else {
            return nil
        }

        return "Par \(par)"
    }

    func teeBoxTitle(for holeNumber: Int) -> String {
        title("Tee Box \(holeNumber)", holeNumber: holeNumber)
    }

    func greenTitle(for holeNumber: Int) -> String {
        title("Green \(holeNumber)", holeNumber: holeNumber)
    }

    func selectTapMode(_ mode: CourseMapSelectionMode, geometries: [CourseGeometry]) {
        switch mode {
        case .measurementPin:
            setMeasurementPinTapMode()
        case .teeBox:
            setTeeBoxTapMode(geometries: geometries)
        case .holePin:
            setHolePinTapMode(geometries: geometries)
        case .shotStart:
            setShotStartTapMode()
        case .shotBall:
            setShotBallTapMode()
        default:
            selectionMode = mode
        }
    }

    var manualShotScoreText: String? {
        guard let selectedScoringPlayer else {
            return nil
        }

        let scoreText = selectedHoleScore.map { $0.strokes > 0 ? "\($0.strokes)" : "-" } ?? "-"
        return "Scoring \(selectedScoringPlayer.name): \(scoreText) strokes for Hole \(targetHoleNumber)."
    }

    var compactHoleScoreText: String {
        "S\(selectedHoleScoreValueText)"
    }

    var selectedHoleScoreValueText: String {
        guard let strokes = selectedHoleScore?.strokes, strokes > 0 else {
            return "-"
        }

        return "\(strokes)"
    }

    var selectedHoleScoreResult: ScorecardScoreResult? {
        scoreResult(for: selectedScoringPlayer)
    }

    var selectedHoleScoreResultText: String? {
        selectedHoleScoreResult?.title
    }

    var canDecreaseSelectedHoleScore: Bool {
        (selectedHoleScore?.strokes ?? 0) > 0
    }

    var canIncreaseSelectedHoleScore: Bool {
        guard let selectedHoleScore else {
            return false
        }

        return selectedHoleScore.strokes < 12
    }

    var canSaveHole: Bool {
        round != nil && (!shotMarkers.isEmpty || currentHoleHasScore)
    }

    var saveHoleButtonTitle: String {
        guard let selectedScoringPlayerName else {
            return "Save Hole"
        }

        return "Save \(selectedScoringPlayerName)"
    }

    var saveHoleActionAccessibilityLabel: String {
        guard round != nil else {
            return "Save hole"
        }

        let playerText = selectedScoringPlayerName.map { " for \($0)" } ?? ""

        if nextHoleNumber == nil {
            return "Save final hole\(playerText) and finish round"
        }

        return "Save hole\(playerText) and go to next hole"
    }

    var saveHoleHelpText: String? {
        guard round != nil else {
            return nil
        }

        if !canSaveHole {
            if let selectedScoringPlayerName {
                return "Track a shot or enter \(selectedScoringPlayerName)'s score to enable Save Hole."
            }

            return "Track a shot or enter a score to enable Save Hole."
        }

        let playerText = selectedScoringPlayerName.map { " for \($0)" } ?? ""

        if let nextHoleNumber {
            return "Saves Hole \(targetHoleNumber)\(playerText) and moves to Hole \(nextHoleNumber)."
        }

        return "Saves Hole \(targetHoleNumber)\(playerText) and finishes the round."
    }

    func applyStoredHoleSetup(from geometries: [CourseGeometry]) {
        let setup = Self.preferredHoleSetup(from: geometries, holeNumber: targetHoleNumber)
        let session = holeSessions[targetHoleNumber]
        teeBoxCoordinate = setup.teeBoxCoordinate ?? session?.teeBoxCoordinate
        holePinCoordinate = setup.holePinCoordinate ?? session?.holePinCoordinate
    }

    func requestLocationAccess() {
        locationService.requestLocationAccess()
    }

    func toggleGPS() {
        isGPSCentered.toggle()
        if isGPSCentered {
            requestLocationAccess()
            showUser()
            statusMessage = "Centered on GPS."
        } else {
            showTeeBox()
            statusMessage = "Centered on tee."
        }
    }

    func selectMapInfo(
        title: String,
        coordinate: CLLocationCoordinate2D,
        cardPlacement: CourseMapInfoCardPlacement = .above
    ) {
        selectedMapInfo = CourseMapInfoSelection(
            title: title,
            coordinate: coordinate,
            cardPlacement: cardPlacement
        )
    }

    func clearSelectedMapInfo() {
        selectedMapInfo = nil
    }

    func refreshOpenStreetMapGeometry(modelContext: ModelContext) async {
        guard !isRefreshingGeometry else {
            return
        }

        isRefreshingGeometry = true
        errorMessage = nil
        statusMessage = "Finding OpenStreetMap geometry..."

        do {
            let geometryImport = try await geometryProvider.geometry(for: OpenStreetMapGolfGeometryRequest(
                courseExternalID: course.id,
                centerCoordinate: course.coordinate
            ))
            let importedGeometry = try geometryEditor.importGeometry(geometryImport, modelContext: modelContext)
            let holeCount = importedGeometry.holes.count
            applyStoredHoleSetup(from: [importedGeometry])
            focusSelectedHole(from: [importedGeometry])
            statusMessage = "Imported OpenStreetMap geometry for \(holeCount) \(holeCount == 1 ? "hole" : "holes")."
        } catch {
            errorMessage = error.localizedDescription
            statusMessage = nil
        }

        isRefreshingGeometry = false
    }

    func updateCameraState(_ camera: MapCamera) {
        cameraCenter = camera.centerCoordinate
        cameraDistance = Self.clampedDistance(camera.distance)
        cameraHeading = Self.normalizedHeading(camera.heading)
        cameraPitch = camera.pitch
    }

    func showCourse() {
        focusCamera(on: course.coordinate)
    }

    func showUser() {
        guard let currentLocation = locationService.currentLocation else {
            focusCamera(on: course.coordinate)
            return
        }

        focusCamera(on: currentLocation.coordinate)
    }

    func showMeasuredPin() {
        guard let measuredCoordinate else {
            return
        }

        focusCamera(on: measuredCoordinate)
    }

    func showTeeBox() {
        guard let teeBoxCoordinate else {
            return
        }

        focusCamera(on: teeBoxCoordinate)
    }

    func showHolePin() {
        guard let holePinCoordinate else {
            return
        }

        focusCamera(on: holePinCoordinate)
    }

    func showShotMeasurement() {
        guard let shotMeasurementCoordinates else {
            return
        }

        focusCamera(containing: shotMeasurementCoordinates)
    }

    func focusSelectedHole(from geometries: [CourseGeometry]) {
        let anchors = Self.preferredHoleSetup(from: geometries, holeNumber: targetHoleNumber)

        if let lastShotBallCoordinate, let holePinCoordinate = anchors.holePinCoordinate ?? holePinCoordinate {
            focusCamera(containing: [lastShotBallCoordinate, holePinCoordinate])
            return
        }

        if let teeBoxCoordinate = anchors.teeBoxCoordinate, let holePinCoordinate = anchors.holePinCoordinate {
            focusHoleLine(from: teeBoxCoordinate, to: holePinCoordinate)
            return
        }

        if let holePinCoordinate = anchors.holePinCoordinate {
            focusCamera(on: holePinCoordinate)
            return
        }

        if let teeBoxCoordinate = anchors.teeBoxCoordinate {
            focusCamera(on: teeBoxCoordinate)
            return
        }

        if let shotMeasurementCoordinates {
            focusCamera(containing: shotMeasurementCoordinates)
            return
        }

        if let previousHoleAnchor = Self.previousHoleFallbackAnchor(from: geometries, before: targetHoleNumber) {
            focusCamera(on: previousHoleAnchor)
            return
        }

        focusCamera(on: course.coordinate)
    }

    func focusHoleOverview(from geometries: [CourseGeometry]) {
        let anchors = Self.preferredHoleSetup(from: geometries, holeNumber: targetHoleNumber)
        let tee = teeBoxCoordinate ?? anchors.teeBoxCoordinate
        let pin = holePinCoordinate ?? anchors.holePinCoordinate

        guard let tee, let pin else {
            focusSelectedHole(from: geometries)
            return
        }

        focusHoleLine(from: tee, to: pin)
    }

    func zoomIn() {
        setCamera(distance: cameraDistance * 0.5)
    }

    func zoomOut() {
        setCamera(distance: cameraDistance * 2)
    }

    func rotateLeft() {
        setCamera(heading: cameraHeading - Self.rotationStep)
    }

    func rotateRight() {
        setCamera(heading: cameraHeading + Self.rotationStep)
    }

    func resetNorth() {
        setCamera(heading: 0)
    }

    func handleMapTap(at coordinate: CLLocationCoordinate2D, modelContext: ModelContext? = nil) {
        selectMapLocation(at: coordinate, modelContext: modelContext)
    }

    func selectMapLocation(at coordinate: CLLocationCoordinate2D, modelContext: ModelContext? = nil) {
        statusMessage = nil
        errorMessage = nil
        selectedMapInfo = nil

        switch selectionMode {
        case .inactive:
            statusMessage = "Choose a map action before tapping."
        case .measurementPin:
            registerPlacementUndo()
            measurePoint(at: coordinate)
            statusMessage = "Measurement pin set."
            selectionMode = .inactive
        case .teeBox:
            registerPlacementUndo(stickyAnchorKind: .teeBox, modelContext: modelContext)
            teeBoxCoordinate = coordinate
            saveStickyHoleAnchor(kind: .teeBox, coordinate: coordinate, modelContext: modelContext)
            selectionMode = .inactive
        case .holePin:
            registerPlacementUndo(stickyAnchorKind: .greenPin, modelContext: modelContext)
            holePinCoordinate = coordinate
            saveStickyHoleAnchor(kind: .greenPin, coordinate: coordinate, modelContext: modelContext)
            selectionMode = .inactive
        case .shotStart:
            registerPlacementUndo()
            startShot(at: coordinate)
            statusMessage = "Shot start set."
            selectionMode = .inactive
        case .shotBall:
            registerPlacementUndo(syncsShotScore: canMarkBall)
            markShotEnd(at: coordinate, modelContext: modelContext)
            statusMessage = shotStartCoordinate == nil ? "Ball set. Add a shot start to measure distance." : "Ball set. Use Next Shot to continue from here."
            selectionMode = .inactive
        case .moveShotBall:
            registerPlacementUndo()
            updateSelectedShotMarkerBall(to: coordinate, modelContext: modelContext)
            selectionMode = .inactive
        }
    }

    func applyPersistedShotRecords() {
        guard let round, let selectedScoringPlayer, shotMarkers.isEmpty else {
            return
        }

        let records = round.shotRecords
            .filter { $0.player?.id == selectedScoringPlayer.id && $0.holeNumber == targetHoleNumber }
            .sorted { $0.shotNumber < $1.shotNumber }

        guard records.isEmpty == false else {
            return
        }

        shotMarkers = records.enumerated().map { index, record in
            CourseMapShotMarker(
                id: record.id,
                shotNumber: index + 1,
                startCoordinate: record.startCoordinate,
                ballCoordinate: record.endCoordinate,
                source: record.source,
                clubID: record.club?.id,
                clubName: record.clubNameSnapshot
            )
        }
        selectedShotMarkerID = nil
        currentShotMarkerID = nil
    }

    func setShotStartTapMode() {
        selectionMode = .shotStart
        statusMessage = "Tap the map to set shot start for Hole \(targetHoleNumber)."
        errorMessage = nil
    }

    func setShotBallTapMode() {
        selectionMode = .shotBall
        statusMessage = "Tap the map to set ball location for Hole \(targetHoleNumber)."
        errorMessage = nil
    }

    func setMeasurementPinTapMode() {
        selectionMode = .measurementPin
        statusMessage = "Tap the map to drop a measurement pin."
        errorMessage = nil
    }

    func setTeeBoxTapMode(geometries: [CourseGeometry] = [], focusesHoleLine: Bool = true) {
        selectionMode = .teeBox
        statusMessage = "Tap the map to save Tee \(targetHoleNumber)."
        errorMessage = nil
        if focusesHoleLine {
            focusCurrentHoleLineIfAvailable(from: geometries)
        }
    }

    func setHolePinTapMode(geometries: [CourseGeometry] = [], focusesHoleLine: Bool = true) {
        selectionMode = .holePin
        statusMessage = "Tap the map to save Pin \(targetHoleNumber)."
        errorMessage = nil
        if focusesHoleLine {
            focusCurrentHoleLineIfAvailable(from: geometries)
        }
    }

    func measurePoint(at coordinate: CLLocationCoordinate2D) {
        measuredCoordinate = coordinate
        statusMessage = nil
        errorMessage = nil
    }

    func clearMeasuredPoint() {
        deleteMeasuredPoint()
    }

    func deleteMeasuredPoint() {
        measuredCoordinate = nil
        selectedMapInfo = nil
        selectionMode = .inactive
        statusMessage = "Measured point deleted. Choose a map action before tapping."
        errorMessage = nil
    }

    func undoLastPin(modelContext: ModelContext? = nil) {
        guard var undoActions = placementUndoActions[targetHoleNumber],
              let undoAction = undoActions.popLast() else {
            statusMessage = "Nothing to undo."
            errorMessage = nil
            return
        }

        placementUndoActions[targetHoleNumber] = undoActions.isEmpty ? nil : undoActions
        restoreStickyAnchor(from: undoAction.stickyAnchor, modelContext: modelContext)
        restoreSession(undoAction.previousSession)

        if undoAction.syncsShotScore, let selectedHoleScore {
            selectedHoleScore.strokes = shotMarkers.count
            persistCurrentShotRecords(modelContext: modelContext)
            saveScoreContext(modelContext)
        }

        selectedMapInfo = nil
        selectionMode = .inactive
        statusMessage = "Undid last map pin."
    }

    func clearHoleSetup(modelContext: ModelContext? = nil) {
        teeBoxCoordinate = nil
        holePinCoordinate = nil

        guard let modelContext else {
            statusMessage = "Tee and pin cleared for this session."
            return
        }

        do {
            try geometryEditor.clearStickyHoleAnchors(
                courseExternalID: course.id,
                holeNumber: targetHoleNumber,
                modelContext: modelContext
            )
            statusMessage = "Saved tee and pin cleared for Hole \(targetHoleNumber)."
        } catch {
            errorMessage = "Could not clear tee/pin: \(error.localizedDescription)"
        }
    }

    func deleteStickyHoleAnchor(kind: CourseMapFeatureKind, modelContext: ModelContext, geometries: [CourseGeometry]) {
        guard kind.isStickyHoleAnchor else {
            return
        }

        do {
            try geometryEditor.clearStickyHoleAnchor(
                courseExternalID: course.id,
                holeNumber: targetHoleNumber,
                kind: kind,
                modelContext: modelContext
            )
            let setup = Self.preferredHoleSetup(from: geometries, holeNumber: targetHoleNumber)
            if kind == .teeBox {
                teeBoxCoordinate = setup.teeBoxCoordinate
            } else {
                holePinCoordinate = setup.holePinCoordinate
            }
            statusMessage = kind == .teeBox ? "Deleted saved tee for Hole \(targetHoleNumber)." : "Deleted saved pin for Hole \(targetHoleNumber)."
        } catch {
            errorMessage = "Could not delete \(kind.title.lowercased()): \(error.localizedDescription)"
        }
    }

    func deleteUserMappedFeaturePoint(_ featurePoint: CourseMapFeaturePoint, modelContext: ModelContext) {
        do {
            try geometryEditor.deleteUserMappedFeaturePoint(featurePoint, modelContext: modelContext)
            statusMessage = "Deleted \(featurePoint.kind.title.lowercased()) from Hole \(targetHoleNumber)."
        } catch {
            errorMessage = "Could not delete target: \(error.localizedDescription)"
        }
    }

    func startShotFromCurrentLocation() {
        guard let currentLocation = locationService.currentLocation else {
            return
        }

        startShot(at: currentLocation.coordinate)
    }

    func startShotFromMeasuredPoint() {
        guard let measuredCoordinate else {
            return
        }

        startShot(at: measuredCoordinate)
    }

    func markShotEndAtCurrentLocation(modelContext: ModelContext? = nil) {
        guard canMarkBall, let currentLocation = locationService.currentLocation else {
            return
        }

        markShotEnd(at: currentLocation.coordinate, source: .gps, modelContext: modelContext)
    }

    func markShotEndAtMeasuredPoint(modelContext: ModelContext? = nil) {
        guard canMarkBall, let measuredCoordinate else {
            return
        }

        markShotEnd(at: measuredCoordinate, source: .manualMap, modelContext: modelContext)
    }

    func clearShotMeasurement() {
        shotStartCoordinate = nil
        shotEndCoordinate = nil
        selectedMapInfo = nil
        selectedShotMarkerID = nil
        currentShotMarkerID = nil
    }

    func deleteSelectedShotMarker(modelContext: ModelContext? = nil) {
        guard let selectedShotMarkerID,
              let index = shotMarkers.firstIndex(where: { $0.id == selectedShotMarkerID }) else {
            errorMessage = "Select a shot before deleting it."
            return
        }

        shotMarkers.remove(at: index)
        shotMarkers = shotMarkers.enumerated().map { index, marker in
            CourseMapShotMarker(
                id: marker.id,
                shotNumber: index + 1,
                startCoordinate: marker.startCoordinate,
                ballCoordinate: marker.ballCoordinate,
                source: marker.source,
                clubID: marker.clubID,
                clubName: marker.clubName
            )
        }
        self.selectedShotMarkerID = nil
        selectedMapInfo = nil
        currentShotMarkerID = nil
        shotStartCoordinate = nil
        shotEndCoordinate = nil
        if let selectedHoleScore {
            selectedHoleScore.strokes = shotMarkers.count
            persistCurrentShotRecords(modelContext: modelContext)
            saveScoreContext(modelContext)
        } else {
            syncManualShotCountToScore(modelContext: modelContext)
        }
        statusMessage = "Deleted shot."
        errorMessage = nil
    }

    func startNextShotFromBall() {
        guard let shotEndCoordinate else {
            return
        }

        startShot(at: shotEndCoordinate)
        selectionMode = .shotBall
        statusMessage = "Next shot starts from the last ball."
    }

    func selectShotMarker(id: UUID) {
        guard let marker = shotMarkers.first(where: { $0.id == id }) else {
            return
        }

        selectedShotMarkerID = id
        currentShotMarkerID = id
        shotStartCoordinate = marker.startCoordinate
        shotEndCoordinate = marker.ballCoordinate
        selectMapInfo(title: "Shot \(marker.shotNumber) ball", coordinate: marker.ballCoordinate)
        selectionMode = .moveShotBall
        statusMessage = "Shot \(marker.shotNumber) selected. Tap the corrected ball spot or delete it."
    }

    func updateSelectedShotMarkerBall(to coordinate: CLLocationCoordinate2D, modelContext: ModelContext? = nil) {
        guard let selectedShotMarkerID,
              let index = shotMarkers.firstIndex(where: { $0.id == selectedShotMarkerID }) else {
            errorMessage = "Select a ball marker before moving it."
            return
        }

        shotMarkers[index].ballCoordinate = coordinate
        shotStartCoordinate = shotMarkers[index].startCoordinate
        shotEndCoordinate = coordinate
        currentShotMarkerID = selectedShotMarkerID
        persistCurrentShotRecords(modelContext: modelContext)
        saveScoreContext(modelContext)
        statusMessage = "Shot \(shotMarkers[index].shotNumber) ball moved."
        errorMessage = nil
    }

    func applySelectedClubToCurrentShot(from clubs: [GolfClub], modelContext: ModelContext? = nil) {
        guard let selectedShotMarkerID,
              let index = shotMarkers.firstIndex(where: { $0.id == selectedShotMarkerID }),
              let club = selectedClub(from: clubs) else {
            return
        }

        shotMarkers[index].clubID = club.id
        shotMarkers[index].clubName = club.name
        persistCurrentShotRecords(modelContext: modelContext)
        saveScoreContext(modelContext)
        statusMessage = "Shot \(shotMarkers[index].shotNumber) set to \(club.name)."
    }

    func saveMeasuredPointAsFeature(modelContext: ModelContext) {
        errorMessage = nil
        statusMessage = nil

        guard let measuredCoordinate else {
            errorMessage = "Drop a map pin before saving a target."
            return
        }

        let label = featureLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        let labelToSave = label.isEmpty ? defaultFeatureLabel : label

        do {
            let featurePoint = try geometryEditor.addFeaturePoint(
                courseExternalID: course.id,
                holeNumber: targetHoleNumber,
                kind: selectedFeatureKind,
                label: labelToSave,
                coordinate: measuredCoordinate,
                modelContext: modelContext
            )
            featureLabel = ""
            statusMessage = "Saved \(featurePoint.kind.title.lowercased()) to Hole \(targetHoleNumber)."
        } catch {
            errorMessage = "Could not save target: \(error.localizedDescription)"
        }
    }

    func incrementSelectedHoleScore(modelContext: ModelContext? = nil) {
        adjustSelectedHoleScore(by: 1, modelContext: modelContext)
    }

    func decrementSelectedHoleScore(modelContext: ModelContext? = nil) {
        adjustSelectedHoleScore(by: -1, modelContext: modelContext)
    }

    func scoreValueText(for player: RoundPlayer) -> String {
        guard let strokes = score(for: player)?.strokes, strokes > 0 else {
            return "-"
        }

        return "\(strokes)"
    }

    func scoreResult(for player: RoundPlayer?) -> ScorecardScoreResult? {
        guard let player,
              let score = score(for: player),
              score.strokes > 0 else {
            return nil
        }

        return ScorecardScoreResult(relativeToPar: score.strokes - score.par)
    }

    func canDecreaseScore(for player: RoundPlayer) -> Bool {
        (score(for: player)?.strokes ?? 0) > 0
    }

    func canIncreaseScore(for player: RoundPlayer) -> Bool {
        guard let score = score(for: player) else {
            return false
        }

        return score.strokes < 12
    }

    func incrementScore(for player: RoundPlayer, modelContext: ModelContext? = nil) {
        adjustScore(for: player, by: 1, modelContext: modelContext)
    }

    func decrementScore(for player: RoundPlayer, modelContext: ModelContext? = nil) {
        adjustScore(for: player, by: -1, modelContext: modelContext)
    }

    func syncManualShotCountToScore(modelContext: ModelContext? = nil) {
        guard shotMarkers.isEmpty == false else {
            persistCurrentShotRecords(modelContext: modelContext)
            saveScoreContext(modelContext)
            return
        }

        guard let selectedHoleScore else {
            statusMessage = "Manual shots are tracked here. Open from a scorecard to sync strokes."
            return
        }

        selectedHoleScore.strokes = shotMarkers.count
        persistCurrentShotRecords(modelContext: modelContext)
        saveScoreContext(modelContext)
        statusMessage = "Synced \(shotMarkers.count) shots to Hole \(targetHoleNumber)."
    }

    func moveToPreviousHole(modelContext: ModelContext? = nil) {
        guard let previousHoleNumber else {
            return
        }

        moveToHole(previousHoleNumber, modelContext: modelContext)
    }

    func selectPreviousHole(geometries: [CourseGeometry], modelContext: ModelContext? = nil) {
        guard let previousHoleNumber else {
            return
        }

        selectHole(previousHoleNumber, geometries: geometries, modelContext: modelContext)
    }

    func moveToNextHole(modelContext: ModelContext? = nil) {
        guard let nextHoleNumber else {
            return
        }

        moveToHole(nextHoleNumber, modelContext: modelContext)
    }

    func selectNextHole(geometries: [CourseGeometry], modelContext: ModelContext? = nil) {
        guard let nextHoleNumber else {
            return
        }

        selectHole(nextHoleNumber, geometries: geometries, modelContext: modelContext)
    }

    func moveToHole(_ holeNumber: Int, modelContext: ModelContext? = nil) {
        guard availableHoles.contains(holeNumber), holeNumber != targetHoleNumber else {
            return
        }

        syncManualShotCountToScore(modelContext: nil)
        saveCurrentHoleSession()

        if let round {
            round.currentHole = holeNumber
            round.completedAt = nil
        } else {
            standaloneHoleNumber = holeNumber
        }

        restoreSession(for: holeNumber)
        saveScoreContext(modelContext)
        statusMessage = "Moved to Hole \(holeNumber)."
    }

    func selectHole(_ holeNumber: Int, geometries: [CourseGeometry], modelContext: ModelContext? = nil) {
        guard availableHoles.contains(holeNumber) else {
            return
        }

        if holeNumber != targetHoleNumber {
            moveToHole(holeNumber, modelContext: modelContext)
        }

        applyStoredHoleSetup(from: geometries)
        focusHoleOverview(from: geometries)
    }

    func selectTeeBoxMarker(holeNumber: Int, geometries: [CourseGeometry], modelContext: ModelContext? = nil) {
        selectHole(holeNumber, geometries: geometries, modelContext: modelContext)
        setTeeBoxTapMode(geometries: geometries)
        if let teeBoxCoordinate {
            selectMapInfo(
                title: teeBoxTitle(for: holeNumber),
                coordinate: teeBoxCoordinate,
                cardPlacement: .trailing
            )
        }
    }

    func selectPinMarker(holeNumber: Int, geometries: [CourseGeometry], modelContext: ModelContext? = nil) {
        selectHole(holeNumber, geometries: geometries, modelContext: modelContext)
        setHolePinTapMode(geometries: geometries)
        if let holePinCoordinate {
            selectMapInfo(title: greenTitle(for: holeNumber), coordinate: holePinCoordinate)
        }
    }

    func saveCurrentHole(modelContext: ModelContext? = nil) {
        guard let round else {
            statusMessage = "Open from a scorecard round to save this hole."
            return
        }

        guard canSaveHole else {
            statusMessage = "Track a shot or enter a score before saving this hole."
            return
        }

        syncManualShotCountToScore(modelContext: nil)
        saveCurrentHoleSession()

        let finishedHole = round.currentHole
        let holes = availableHoles
        if let index = holes.firstIndex(of: finishedHole), index < holes.index(before: holes.endIndex) {
            round.currentHole = holes[holes.index(after: index)]
            restoreSession(for: round.currentHole)
            statusMessage = "Hole \(finishedHole) saved. Moved to Hole \(round.currentHole)."
        } else {
            round.completedAt = .now
            statusMessage = "Round finished."
        }

        saveScoreContext(modelContext)
    }

    private func saveStickyHoleAnchor(kind: CourseMapFeatureKind, coordinate: CLLocationCoordinate2D, modelContext: ModelContext?) {
        guard let modelContext else {
            statusMessage = kind == .teeBox ? "Tee set for this session." : "Pin set for this session."
            return
        }

        do {
            _ = try geometryEditor.setStickyHoleAnchor(
                courseExternalID: course.id,
                holeNumber: targetHoleNumber,
                kind: kind,
                coordinate: coordinate,
                modelContext: modelContext
            )
            statusMessage = kind == .teeBox ? "Tee saved for Hole \(targetHoleNumber)." : "Pin saved for Hole \(targetHoleNumber)."
        } catch {
            errorMessage = "Could not save \(kind.title.lowercased()): \(error.localizedDescription)"
        }
    }

    private func startShot(at coordinate: CLLocationCoordinate2D) {
        shotStartCoordinate = coordinate
        shotEndCoordinate = nil
        currentShotMarkerID = nil
        selectedShotMarkerID = nil
        statusMessage = nil
        errorMessage = nil
    }

    private func markShotEnd(at coordinate: CLLocationCoordinate2D, source: ShotRecordSource = .manualMap, modelContext: ModelContext?) {
        shotEndCoordinate = coordinate
        let club = selectedClub(modelContext: modelContext)

        if shotStartCoordinate == nil, shotMarkers.isEmpty, let teeBoxCoordinate {
            shotStartCoordinate = teeBoxCoordinate
        }

        if shotStartCoordinate == nil, shotMarkers.isEmpty == false {
            let fallbackID = selectedShotMarkerID ?? currentShotMarkerID
            if let fallbackID,
               let index = shotMarkers.firstIndex(where: { $0.id == fallbackID }) {
                updateShotMarker(at: index, ballCoordinate: coordinate, source: source, club: club)
                syncManualShotCountToScore(modelContext: modelContext)
                return
            }

            if let lastBall = shotMarkers.sorted(by: { $0.shotNumber < $1.shotNumber }).last?.ballCoordinate {
                shotStartCoordinate = lastBall
            }
        }

        guard let shotStartCoordinate else {
            errorMessage = "Set a shot start or tee box before marking the ball."
            return
        }

        if let currentShotMarkerID,
           let index = shotMarkers.firstIndex(where: { $0.id == currentShotMarkerID }) {
            shotMarkers[index].startCoordinate = shotStartCoordinate
            updateShotMarker(at: index, ballCoordinate: coordinate, source: source, club: club)
            syncManualShotCountToScore(modelContext: modelContext)
            return
        }

        if let index = shotMarkers.firstIndex(where: { Self.coordinatesMatch($0.startCoordinate, shotStartCoordinate) }) {
            updateShotMarker(at: index, ballCoordinate: coordinate, source: source, club: club)
            syncManualShotCountToScore(modelContext: modelContext)
            return
        }

        let marker = CourseMapShotMarker(
            shotNumber: shotMarkers.count + 1,
            startCoordinate: shotStartCoordinate,
            ballCoordinate: coordinate,
            source: source,
            clubID: club?.id,
            clubName: club?.name
        )
        shotMarkers.append(marker)
        currentShotMarkerID = marker.id
        selectedShotMarkerID = marker.id
        syncManualShotCountToScore(modelContext: modelContext)
    }

    private func updateShotMarker(at index: Int, ballCoordinate: CLLocationCoordinate2D, source: ShotRecordSource, club: GolfClub?) {
        shotMarkers[index].ballCoordinate = ballCoordinate
        shotMarkers[index].source = source
        if let club {
            shotMarkers[index].clubID = club.id
            shotMarkers[index].clubName = club.name
        }
        currentShotMarkerID = shotMarkers[index].id
        selectedShotMarkerID = shotMarkers[index].id
        shotStartCoordinate = shotMarkers[index].startCoordinate
        shotEndCoordinate = ballCoordinate
        statusMessage = "Shot \(shotMarkers[index].shotNumber) ball moved."
    }

    private var shotLocationCoordinate: CLLocationCoordinate2D? {
        shotEndCoordinate
            ?? lastShotBallCoordinate
            ?? locationService.currentLocation?.coordinate
            ?? shotStartCoordinate
            ?? teeBoxCoordinate
    }

    private var shotPlanningCoordinate: CLLocationCoordinate2D? {
        shotEndCoordinate
            ?? lastShotBallCoordinate
            ?? shotStartCoordinate
            ?? teeBoxCoordinate
            ?? locationService.currentLocation?.coordinate
    }

    private var lastShotBallCoordinate: CLLocationCoordinate2D? {
        shotMarkers
            .sorted { $0.shotNumber < $1.shotNumber }
            .last?
            .ballCoordinate
    }

    private var selectedMapReference: (label: String, coordinate: CLLocationCoordinate2D)? {
        if let shotEndCoordinate {
            return ("Ball to this", shotEndCoordinate)
        }

        if let currentLocation = locationService.currentLocation {
            return ("GPS to this", currentLocation.coordinate)
        }

        if let shotStartCoordinate {
            return ("Start to this", shotStartCoordinate)
        }

        if let teeBoxCoordinate {
            return ("Tee to this", teeBoxCoordinate)
        }

        return nil
    }

    private func selectedMapInfoIsSelectedShotMarkerBall(_ selectedMapInfo: CourseMapInfoSelection) -> Bool {
        guard let selectedShotMarker else {
            return false
        }

        return Self.coordinatesMatch(selectedMapInfo.coordinate, selectedShotMarker.ballCoordinate)
    }

    private static func coordinatesMatch(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D) -> Bool {
        abs(lhs.latitude - rhs.latitude) < 0.0000001
            && abs(lhs.longitude - rhs.longitude) < 0.0000001
    }

    private func title(_ baseTitle: String, holeNumber: Int) -> String {
        guard let parText = holeParText(for: holeNumber) else {
            return baseTitle
        }

        return "\(baseTitle) - \(parText)"
    }

    private var currentHoleHasScore: Bool {
        scoringPlayers.contains { player in
            player.scores.contains { $0.holeNumber == targetHoleNumber && $0.strokes > 0 }
        }
    }

    private func adjacentHole(from holeNumber: Int, offset: Int) -> Int? {
        guard let index = availableHoles.firstIndex(of: holeNumber) else {
            return nil
        }

        let adjacentIndex = availableHoles.index(index, offsetBy: offset, limitedBy: offset < 0 ? availableHoles.startIndex : availableHoles.index(before: availableHoles.endIndex))
        guard let adjacentIndex, adjacentIndex != index else {
            return nil
        }

        return availableHoles[adjacentIndex]
    }

    private func previousShotCoordinate(for marker: CourseMapShotMarker) -> CLLocationCoordinate2D {
        if marker.shotNumber == 1 {
            return teeBoxCoordinate ?? marker.startCoordinate
        }

        let previousShotNumber = marker.shotNumber - 1
        return shotMarkers.first { $0.shotNumber == previousShotNumber }?.ballCoordinate ?? marker.startCoordinate
    }

    private func focusCurrentHoleLineIfAvailable(from geometries: [CourseGeometry]) {
        if !geometries.isEmpty {
            applyStoredHoleSetup(from: geometries)
        }

        guard let teeBoxCoordinate, let holePinCoordinate else {
            return
        }

        focusCamera(
            containing: [teeBoxCoordinate, holePinCoordinate],
            heading: Self.bearing(from: teeBoxCoordinate, to: holePinCoordinate),
            pitch: Self.holeFlyoverPitch
        )
    }

    private func registerPlacementUndo(
        stickyAnchorKind: CourseMapFeatureKind? = nil,
        modelContext: ModelContext? = nil,
        syncsShotScore: Bool = false
    ) {
        let stickyAnchor = stickyAnchorKind.map {
            CourseMapStickyAnchorUndo(
                kind: $0,
                userMappedCoordinate: userMappedStickyAnchorCoordinate(kind: $0, modelContext: modelContext)
            )
        }
        let undoAction = CourseMapPlacementUndo(
            previousSession: currentHoleSessionSnapshot(),
            stickyAnchor: stickyAnchor,
            syncsShotScore: syncsShotScore
        )

        placementUndoActions[targetHoleNumber, default: []].append(undoAction)
    }

    private func currentHoleSessionSnapshot() -> CourseMapHoleSession {
        CourseMapHoleSession(
            measuredCoordinate: measuredCoordinate,
            teeBoxCoordinate: teeBoxCoordinate,
            holePinCoordinate: holePinCoordinate,
            shotStartCoordinate: shotStartCoordinate,
            shotEndCoordinate: shotEndCoordinate,
            shotMarkers: shotMarkers,
            selectedShotMarkerID: selectedShotMarkerID,
            currentShotMarkerID: currentShotMarkerID
        )
    }

    private func saveCurrentHoleSession() {
        let session = currentHoleSessionSnapshot()

        if session.isEmpty {
            holeSessions[targetHoleNumber] = nil
        } else {
            holeSessions[targetHoleNumber] = session
        }
    }

    private func restoreSession(for holeNumber: Int) {
        guard let session = holeSessions[holeNumber] else {
            measuredCoordinate = nil
            teeBoxCoordinate = nil
            holePinCoordinate = nil
            shotStartCoordinate = nil
            shotEndCoordinate = nil
            shotMarkers = []
            selectedShotMarkerID = nil
            currentShotMarkerID = nil
            return
        }

        measuredCoordinate = session.measuredCoordinate
        teeBoxCoordinate = session.teeBoxCoordinate
        holePinCoordinate = session.holePinCoordinate
        shotStartCoordinate = session.shotStartCoordinate
        shotEndCoordinate = session.shotEndCoordinate
        shotMarkers = session.shotMarkers
        selectedShotMarkerID = session.selectedShotMarkerID
        currentShotMarkerID = session.currentShotMarkerID
    }

    private func restoreSession(_ session: CourseMapHoleSession) {
        measuredCoordinate = session.measuredCoordinate
        teeBoxCoordinate = session.teeBoxCoordinate
        holePinCoordinate = session.holePinCoordinate
        shotStartCoordinate = session.shotStartCoordinate
        shotEndCoordinate = session.shotEndCoordinate
        shotMarkers = session.shotMarkers
        selectedShotMarkerID = session.selectedShotMarkerID
        currentShotMarkerID = session.currentShotMarkerID
    }

    private func restoreStickyAnchor(from undoAnchor: CourseMapStickyAnchorUndo?, modelContext: ModelContext?) {
        guard let undoAnchor, let modelContext else {
            errorMessage = nil
            return
        }

        do {
            if let userMappedCoordinate = undoAnchor.userMappedCoordinate {
                _ = try geometryEditor.setStickyHoleAnchor(
                    courseExternalID: course.id,
                    holeNumber: targetHoleNumber,
                    kind: undoAnchor.kind,
                    coordinate: userMappedCoordinate,
                    modelContext: modelContext
                )
            } else {
                try geometryEditor.clearStickyHoleAnchor(
                    courseExternalID: course.id,
                    holeNumber: targetHoleNumber,
                    kind: undoAnchor.kind,
                    modelContext: modelContext
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = "Could not undo \(undoAnchor.kind.title.lowercased()): \(error.localizedDescription)"
        }
    }

    private func userMappedStickyAnchorCoordinate(kind: CourseMapFeatureKind, modelContext: ModelContext?) -> CLLocationCoordinate2D? {
        guard let modelContext else {
            return nil
        }

        do {
            let courseExternalID = course.id
            var descriptor = FetchDescriptor<CourseGeometry>(
                predicate: #Predicate { geometry in
                    geometry.courseExternalID == courseExternalID
                }
            )
            descriptor.fetchLimit = 1
            let geometry = try modelContext.fetch(descriptor).first
            return geometry?
                .holes
                .first { $0.number == targetHoleNumber }?
                .featurePoints
                .first { $0.kind == kind && $0.source == .userMapped }?
                .coordinate
        } catch {
            errorMessage = "Could not prepare undo: \(error.localizedDescription)"
            return nil
        }
    }

    private func adjustSelectedHoleScore(by delta: Int, modelContext: ModelContext?) {
        guard let selectedHoleScore else {
            statusMessage = "Open from a scorecard to update strokes."
            errorMessage = nil
            return
        }

        selectedHoleScore.strokes = min(max(selectedHoleScore.strokes + delta, 0), 12)
        saveScoreContext(modelContext)
        statusMessage = "Updated Hole \(targetHoleNumber) score to \(selectedHoleScoreValueText)."
        errorMessage = nil
    }

    private func adjustScore(for player: RoundPlayer, by delta: Int, modelContext: ModelContext?) {
        guard let score = score(for: player) else {
            statusMessage = "No score slot for \(player.name) on Hole \(targetHoleNumber)."
            errorMessage = nil
            return
        }

        score.strokes = min(max(score.strokes + delta, 0), 12)
        saveScoreContext(modelContext)
        statusMessage = "Updated \(player.name) on Hole \(targetHoleNumber) to \(scoreValueText(for: player))."
        errorMessage = nil
    }

    private func score(for player: RoundPlayer) -> HoleScore? {
        player.scores.first { $0.holeNumber == targetHoleNumber }
    }

    private func saveScoreContext(_ modelContext: ModelContext?) {
        guard let modelContext else {
            return
        }

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Could not save score: \(error.localizedDescription)"
        }
    }

    private func persistCurrentShotRecords(modelContext: ModelContext?) {
        guard let modelContext, let round, let selectedScoringPlayer else {
            return
        }

        let markerIDs = Set(shotMarkers.map(\.id))
        let staleRecords = round.shotRecords.filter { record in
            record.player?.id == selectedScoringPlayer.id
                && record.holeNumber == targetHoleNumber
                && !markerIDs.contains(record.id)
        }

        for record in staleRecords {
            modelContext.delete(record)
        }

        for marker in shotMarkers {
            let distanceYards = distanceCalculator.yards(from: marker.startCoordinate, to: marker.ballCoordinate)
            let markerClub = club(id: marker.clubID, modelContext: modelContext)
            let record = round.shotRecords.first { $0.id == marker.id } ?? ShotRecord(
                id: marker.id,
                round: round,
                player: selectedScoringPlayer,
                club: markerClub,
                weatherSnapshot: latestWeatherSnapshot(for: round),
                holeNumber: targetHoleNumber,
                shotNumber: marker.shotNumber,
                startCoordinate: marker.startCoordinate,
                endCoordinate: marker.ballCoordinate,
                distanceYards: distanceYards,
                source: marker.source
            )

            record.round = round
            record.player = selectedScoringPlayer
            record.club = markerClub
            record.weatherSnapshot = record.weatherSnapshot ?? latestWeatherSnapshot(for: round)
            record.holeNumber = targetHoleNumber
            record.shotNumber = marker.shotNumber
            record.startLatitude = marker.startCoordinate.latitude
            record.startLongitude = marker.startCoordinate.longitude
            record.endLatitude = marker.ballCoordinate.latitude
            record.endLongitude = marker.ballCoordinate.longitude
            record.distanceYards = distanceYards
            record.clubNameSnapshot = marker.clubName ?? markerClub?.name
            record.source = marker.source

            if record.modelContext == nil {
                modelContext.insert(record)
            }
        }
    }

    private func latestWeatherSnapshot(for round: GolfRound) -> RoundWeatherSnapshot? {
        round.weatherSnapshots.max { $0.observedAt < $1.observedAt }
    }

    private var latestWeatherText: String? {
        guard let snapshot = round.flatMap(latestWeatherSnapshot(for:)) else {
            return nil
        }

        var parts: [String] = []
        if let temperatureText = snapshot.temperatureText {
            parts.append(temperatureText)
        }
        if let windSpeed = snapshot.windSpeedMilesPerHour {
            let windText = windSpeed.rounded().formatted(.number.precision(.fractionLength(0)))
            parts.append("wind \(windText) mph")
        }

        return parts.isEmpty ? snapshot.conditionText : parts.joined(separator: " · ")
    }

    private var displayedShotMarkers: [CourseMapShotMarker] {
        if shotMarkers.isEmpty == false {
            return shotMarkers
        }

        guard let round, let selectedScoringPlayer else {
            return []
        }

        return round.shotRecords
            .filter { $0.player?.id == selectedScoringPlayer.id && $0.holeNumber == targetHoleNumber }
            .sorted { $0.shotNumber < $1.shotNumber }
            .map { record in
                CourseMapShotMarker(
                    id: record.id,
                    shotNumber: record.shotNumber,
                    startCoordinate: record.startCoordinate,
                    ballCoordinate: record.endCoordinate,
                    source: record.source,
                    clubID: record.club?.id,
                    clubName: record.clubNameSnapshot
                )
            }
    }

    private func selectedClub(from clubs: [GolfClub]) -> GolfClub? {
        guard let selectedClubID else {
            return nil
        }

        return clubs.first { $0.id == selectedClubID }
    }

    private func bestClub(
        forTargetYards targetYards: Int,
        from clubs: [GolfClub],
        origin: CLLocationCoordinate2D? = nil,
        target: CLLocationCoordinate2D? = nil,
        geometries: [CourseGeometry] = []
    ) -> GolfClub {
        let reachableClubs = clubs.filter { expectedDistance(for: $0) >= targetYards - Self.acceptableShortMissYards }
        let candidates = reachableClubs.isEmpty ? clubs : reachableClubs

        return candidates.min { lhs, rhs in
            strategyScore(for: lhs, targetYards: targetYards, origin: origin, target: target, geometries: geometries)
                < strategyScore(for: rhs, targetYards: targetYards, origin: origin, target: target, geometries: geometries)
        } ?? candidates[0]
    }

    private func strategyScore(
        for club: GolfClub,
        targetYards: Int,
        origin: CLLocationCoordinate2D?,
        target: CLLocationCoordinate2D?,
        geometries: [CourseGeometry]
    ) -> Int {
        let delta = expectedDistance(for: club) - targetYards
        var score = delta >= 0 ? delta : abs(delta) * 2
        guard let origin, let target else {
            return score
        }

        let landing = Self.coordinate(from: origin, bearing: Self.bearing(from: origin, to: target), distanceYards: expectedDistance(for: club))
        let penaltyAreas = areaFeatures(from: geometries).filter { $0.kind.isPenaltyArea }
        for area in penaltyAreas {
            let coordinates = area.clLocationCoordinates
            if Self.point(landing, isInside: coordinates) {
                score += 1_000
            } else if Self.segment(from: origin, to: landing, intersects: coordinates) {
                score += 500
            }
        }

        return score
    }

    private func expectedDistance(for club: GolfClub) -> Int {
        let history = trustedShots(for: club)
        guard history.count >= Self.minimumTrustedClubShotCount else {
            return club.carryYards
        }

        return history.map(\.distanceYards).reduce(0, +) / history.count
    }

    private func areaFeatures(from geometries: [CourseGeometry]) -> [CourseMapAreaFeature] {
        geometries
            .flatMap(\.holes)
            .filter { $0.number == targetHoleNumber }
            .flatMap(\.areaFeatures)
    }

    private func selectedClub(modelContext: ModelContext?) -> GolfClub? {
        guard let selectedClubID else {
            return nil
        }

        return club(id: selectedClubID, modelContext: modelContext)
    }

    private func club(id: UUID?, modelContext: ModelContext?) -> GolfClub? {
        guard let id, let modelContext else {
            return nil
        }

        do {
            var descriptor = FetchDescriptor<GolfClub>(
                predicate: #Predicate { club in
                    club.id == id
                }
            )
            descriptor.fetchLimit = 1
            return try modelContext.fetch(descriptor).first
        } catch {
            errorMessage = "Could not load selected club: \(error.localizedDescription)"
            return nil
        }
    }

    private func persistedShots(for club: GolfClub) -> [ShotRecord] {
        round?
            .shotRecords
            .filter { $0.club?.id == club.id && $0.distanceYards > 0 }
            ?? []
    }

    private func trustedShots(for club: GolfClub) -> [ShotRecord] {
        persistedShots(for: club).filter { shot in
            plausibleDistance(shot.distanceYards, for: club)
        }
    }

    private func plausibleDistance(_ distanceYards: Int, for club: GolfClub) -> Bool {
        guard distanceYards > 0 else {
            return false
        }

        switch club.kind {
        case .driver:
            return distanceYards >= 180
        case .fairwayWood:
            return distanceYards >= 140
        case .hybrid, .iron:
            return distanceYards >= 60
        case .wedge:
            return distanceYards <= 150
        case .putter:
            return distanceYards <= 80
        case .other:
            return true
        }
    }

    private static func sortedPlayers(for round: GolfRound?) -> [RoundPlayer] {
        round?.players.sorted { $0.displayOrder < $1.displayOrder } ?? []
    }

    private static func preferredHoleSetup(
        from geometries: [CourseGeometry],
        holeNumber: Int
    ) -> (teeBoxCoordinate: CLLocationCoordinate2D?, holePinCoordinate: CLLocationCoordinate2D?) {
        let holes = geometries
            .flatMap(\.holes)
            .filter { $0.number == holeNumber }
        let featurePoints = holes.flatMap(\.featurePoints)
        let userTee = featurePoints.first { $0.kind == .teeBox && $0.source == .userMapped }
        let userPin = featurePoints.first { $0.kind == .greenPin && $0.source == .userMapped }
        let importedTee = Self.preferredImportedFeaturePoint(kind: .teeBox, in: featurePoints)
        let providerPin = holes.compactMap(greenCenterCoordinate(for:)).first

        return (
            teeBoxCoordinate: userTee.map(coordinate(for:)) ?? importedTee.map(coordinate(for:)),
            holePinCoordinate: userPin.map(coordinate(for:)) ?? providerPin
        )
    }

    private static func userMappedHoleAnchors(
        from geometries: [CourseGeometry],
        holeNumber: Int
    ) -> (teeBoxCoordinate: CLLocationCoordinate2D?, holePinCoordinate: CLLocationCoordinate2D?) {
        let featurePoints = geometries
            .flatMap(\.holes)
            .filter { $0.number == holeNumber }
            .flatMap(\.featurePoints)
        let userTee = featurePoints.first { $0.kind == .teeBox && $0.source == .userMapped }
        let userPin = featurePoints.first { $0.kind == .greenPin && $0.source == .userMapped }

        return (
            teeBoxCoordinate: userTee.map(coordinate(for:)),
            holePinCoordinate: userPin.map(coordinate(for:))
        )
    }

    private static func previousHoleFallbackAnchor(
        from geometries: [CourseGeometry],
        before holeNumber: Int
    ) -> CLLocationCoordinate2D? {
        guard holeNumber > 1 else {
            return nil
        }

        let previousHoleNumbers = (1..<holeNumber).reversed()
        for previousHoleNumber in previousHoleNumbers {
            let anchors = preferredHoleSetup(from: geometries, holeNumber: previousHoleNumber)
            if let holePinCoordinate = anchors.holePinCoordinate {
                return holePinCoordinate
            }
        }

        for previousHoleNumber in previousHoleNumbers {
            let anchors = preferredHoleSetup(from: geometries, holeNumber: previousHoleNumber)
            if let teeBoxCoordinate = anchors.teeBoxCoordinate {
                return teeBoxCoordinate
            }
        }

        return nil
    }

    private static func preferredNextHoleTransitionCoordinate(
        from geometries: [CourseGeometry],
        holeNumber: Int
    ) -> CLLocationCoordinate2D? {
        let anchors = preferredHoleSetup(from: geometries, holeNumber: holeNumber)
        return anchors.teeBoxCoordinate ?? anchors.holePinCoordinate
    }

    private static func coordinate(for featurePoint: CourseMapFeaturePoint) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: featurePoint.latitude, longitude: featurePoint.longitude)
    }

    private static func preferredImportedFeaturePoint(
        kind: CourseMapFeatureKind,
        in featurePoints: [CourseMapFeaturePoint]
    ) -> CourseMapFeaturePoint? {
        let sourcePriority: [CourseGeometrySource] = [.licensedProvider, .openStreetMap, .manualImport]

        for source in sourcePriority {
            if let featurePoint = featurePoints.first(where: { $0.kind == kind && $0.source == source }) {
                return featurePoint
            }
        }

        return nil
    }

    private static func greenCenterCoordinate(for hole: HoleGeometry) -> CLLocationCoordinate2D? {
        guard let latitude = hole.greenCenterLatitude, let longitude = hole.greenCenterLongitude else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func region(containing coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard let firstCoordinate = coordinates.first else {
            return MKCoordinateRegion()
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minimumLatitude = latitudes.min() ?? firstCoordinate.latitude
        let maximumLatitude = latitudes.max() ?? firstCoordinate.latitude
        let minimumLongitude = longitudes.min() ?? firstCoordinate.longitude
        let maximumLongitude = longitudes.max() ?? firstCoordinate.longitude
        let center = CLLocationCoordinate2D(
            latitude: (minimumLatitude + maximumLatitude) / 2,
            longitude: (minimumLongitude + maximumLongitude) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maximumLatitude - minimumLatitude) * 1.4, 0.003),
            longitudeDelta: max((maximumLongitude - minimumLongitude) * 1.4, 0.003)
        )

        return MKCoordinateRegion(center: center, span: span)
    }

    private func focusCamera(on coordinate: CLLocationCoordinate2D) {
        setCamera(center: coordinate, distance: Self.defaultCameraDistance)
    }

    private func focusCamera(
        containing coordinates: [CLLocationCoordinate2D],
        heading: CLLocationDirection? = nil,
        pitch: CGFloat? = nil,
        distanceScale: CLLocationDistance = 1
    ) {
        let region = Self.region(containing: coordinates)
        setCamera(center: region.center, distance: Self.distance(for: region) * distanceScale, heading: heading, pitch: pitch)
    }

    private func focusHoleLine(from teeCoordinate: CLLocationCoordinate2D, to pinCoordinate: CLLocationCoordinate2D) {
        focusCamera(
            containing: [teeCoordinate, pinCoordinate],
            heading: Self.bearing(from: teeCoordinate, to: pinCoordinate),
            pitch: Self.holeFlyoverPitch,
            distanceScale: Self.holeFlyoverDistanceScale
        )
    }

    private func setCamera(
        center: CLLocationCoordinate2D? = nil,
        distance: CLLocationDistance? = nil,
        heading: CLLocationDirection? = nil,
        pitch: CGFloat? = nil
    ) {
        cameraCenter = center ?? cameraCenter
        cameraDistance = Self.clampedDistance(distance ?? cameraDistance)
        cameraHeading = Self.normalizedHeading(heading ?? cameraHeading)
        cameraPitch = pitch ?? cameraPitch
        position = .camera(Self.camera(
            center: cameraCenter,
            distance: cameraDistance,
            heading: cameraHeading,
            pitch: cameraPitch
        ))
    }

    private static func camera(
        center: CLLocationCoordinate2D,
        distance: CLLocationDistance,
        heading: CLLocationDirection = 0,
        pitch: CGFloat = 0
    ) -> MapCamera {
        MapCamera(centerCoordinate: center, distance: distance, heading: heading, pitch: pitch)
    }

    private static func clampedDistance(_ distance: CLLocationDistance) -> CLLocationDistance {
        min(max(distance, minimumCameraDistance), maximumCameraDistance)
    }

    private static func normalizedHeading(_ heading: CLLocationDirection) -> CLLocationDirection {
        let normalized = heading.truncatingRemainder(dividingBy: 360)
        return normalized < 0 ? normalized + 360 : normalized
    }

    private static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> CLLocationDirection {
        let startLatitude = start.latitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let deltaLongitude = (end.longitude - start.longitude) * .pi / 180
        let y = sin(deltaLongitude) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) - sin(startLatitude) * cos(endLatitude) * cos(deltaLongitude)
        let bearing = atan2(y, x) * 180 / .pi
        return normalizedHeading(bearing)
    }

    private static func coordinate(
        from start: CLLocationCoordinate2D,
        bearing: CLLocationDirection,
        distanceYards: Int
    ) -> CLLocationCoordinate2D {
        let earthRadiusMeters = 6_371_000.0
        let distanceMeters = Double(distanceYards) / 1.09361
        let angularDistance = distanceMeters / earthRadiusMeters
        let bearingRadians = bearing * .pi / 180
        let startLatitude = start.latitude * .pi / 180
        let startLongitude = start.longitude * .pi / 180
        let targetLatitude = asin(
            sin(startLatitude) * cos(angularDistance)
                + cos(startLatitude) * sin(angularDistance) * cos(bearingRadians)
        )
        let targetLongitude = startLongitude + atan2(
            sin(bearingRadians) * sin(angularDistance) * cos(startLatitude),
            cos(angularDistance) - sin(startLatitude) * sin(targetLatitude)
        )

        return CLLocationCoordinate2D(
            latitude: targetLatitude * 180 / .pi,
            longitude: targetLongitude * 180 / .pi
        )
    }

    private static func point(_ point: CLLocationCoordinate2D, isInside polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else {
            return false
        }

        var isInside = false
        var previousIndex = polygon.count - 1
        for index in polygon.indices {
            let current = polygon[index]
            let previous = polygon[previousIndex]
            let intersects = ((current.latitude > point.latitude) != (previous.latitude > point.latitude)) &&
                (point.longitude < (previous.longitude - current.longitude) * (point.latitude - current.latitude) / (previous.latitude - current.latitude) + current.longitude)
            if intersects {
                isInside.toggle()
            }
            previousIndex = index
        }
        return isInside
    }

    private static func segment(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D, intersects polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 2 else {
            return false
        }

        for (first, second) in zip(polygon, polygon.dropFirst() + [polygon[0]]) {
            if segmentsIntersect(start, end, first, second) {
                return true
            }
        }

        return false
    }

    private static func segmentsIntersect(
        _ firstStart: CLLocationCoordinate2D,
        _ firstEnd: CLLocationCoordinate2D,
        _ secondStart: CLLocationCoordinate2D,
        _ secondEnd: CLLocationCoordinate2D
    ) -> Bool {
        func orientation(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, _ c: CLLocationCoordinate2D) -> Double {
            (b.longitude - a.longitude) * (c.latitude - a.latitude) - (b.latitude - a.latitude) * (c.longitude - a.longitude)
        }

        let first = orientation(firstStart, firstEnd, secondStart)
        let second = orientation(firstStart, firstEnd, secondEnd)
        let third = orientation(secondStart, secondEnd, firstStart)
        let fourth = orientation(secondStart, secondEnd, firstEnd)
        return first * second < 0 && third * fourth < 0
    }

    private static func distance(for region: MKCoordinateRegion) -> CLLocationDistance {
        let latitudeMeters = region.span.latitudeDelta * 111_000
        let longitudeMeters = region.span.longitudeDelta * 111_000 * cos(region.center.latitude * .pi / 180)
        return clampedDistance(max(latitudeMeters, longitudeMeters, defaultCameraDistance))
    }
}
