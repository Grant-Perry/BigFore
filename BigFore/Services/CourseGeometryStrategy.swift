import Foundation

struct CourseGeometryStrategy {
    nonisolated init() {}

    nonisolated var selectedSource: CourseGeometrySource {
        .openStreetMap
    }

    nonisolated var currentLimitationsNotice: String {
        "Scorecard data includes tee details. OpenStreetMap can add hole geometry where courses are mapped, while contours and flyovers still need a licensed source."
    }

    nonisolated var selectedSourceRationale: String {
        "Use MapKit for display and GPS, GolfCourseAPI for scorecard metadata, and OpenStreetMap as the proof-of-concept hole geometry source."
    }

    @MainActor
    func report(for geometry: CourseGeometry?) -> CourseGeometryReport {
        guard let geometry else {
            return CourseGeometryReport(
                sourceName: nil,
                source: selectedSource,
                greenYardages: .missingGeometry,
                hazards: .missingGeometry,
                targets: .missingGeometry,
                greenContours: .missingGeometry,
                flyovers: .missingGeometry
            )
        }

        let holes = geometry.holes
        let featurePoints = holes.flatMap(\.featurePoints)

        return CourseGeometryReport(
            sourceName: geometry.sourceName,
            source: CourseGeometrySource(rawValue: geometry.sourceRawValue) ?? selectedSource,
            greenYardages: holes.contains(where: hasGreenYardageAnchors) ? .available : .missingGeometry,
            hazards: featurePoints.contains { $0.kindRawValue == CourseMapFeatureKind.hazard.rawValue } ? .available : .missingGeometry,
            targets: featurePoints.contains { $0.kindRawValue == CourseMapFeatureKind.target.rawValue } ? .available : .missingGeometry,
            greenContours: holes.contains { $0.greenContourAssetIdentifier != nil } ? .available : .missingGeometry,
            flyovers: holes.contains { $0.flyoverAssetIdentifier != nil } ? .available : .missingGeometry
        )
    }

    @MainActor
    private func hasGreenYardageAnchors(for hole: HoleGeometry) -> Bool {
        hole.greenFrontLatitude != nil &&
            hole.greenFrontLongitude != nil &&
            hole.greenCenterLatitude != nil &&
            hole.greenCenterLongitude != nil &&
            hole.greenBackLatitude != nil &&
            hole.greenBackLongitude != nil
    }
}

struct CourseGeometryReport: Equatable {
    let sourceName: String?
    let source: CourseGeometrySource
    let greenYardages: CourseGeometryFeatureStatus
    let hazards: CourseGeometryFeatureStatus
    let targets: CourseGeometryFeatureStatus
    let greenContours: CourseGeometryFeatureStatus
    let flyovers: CourseGeometryFeatureStatus

    var hasOnCourseGeometry: Bool {
        greenYardages == .available || hazards == .available || targets == .available
    }
}

enum CourseGeometryFeatureStatus: Equatable {
    case available
    case missingGeometry
}
