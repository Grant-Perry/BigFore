import Foundation
import SwiftData

enum CourseGeometrySource: String, CaseIterable, Codable, Identifiable {
    case licensedProvider
    case manualImport
    case openStreetMap
    case userMapped

    var id: String { rawValue }

    var title: String {
        switch self {
        case .licensedProvider:
            "Licensed Provider"
        case .manualImport:
            "Manual Import"
        case .openStreetMap:
            "OpenStreetMap"
        case .userMapped:
            "User Mapped"
        }
    }
}

enum CourseMapFeatureKind: String, CaseIterable, Codable, Identifiable {
    case teeBox
    case greenPin
    case dogleg
    case hazard
    case layup
    case target

    var id: String { rawValue }

    static var saveableTargetKinds: [CourseMapFeatureKind] {
        [.dogleg, .hazard, .layup, .target]
    }

    var title: String {
        switch self {
        case .teeBox:
            "Tee"
        case .greenPin:
            "Pin"
        case .dogleg:
            "Dogleg"
        case .hazard:
            "Hazard"
        case .layup:
            "Layup"
        case .target:
            "Target"
        }
    }

    var isStickyHoleAnchor: Bool {
        self == .teeBox || self == .greenPin
    }
}

@Model
final class CourseGeometry {
    @Attribute(.unique) var courseExternalID: Int
    var sourceRawValue: String
    var sourceName: String
    var attribution: String?
    var updatedAt: Date
    @Relationship(deleteRule: .cascade, inverse: \HoleGeometry.courseGeometry) var holes: [HoleGeometry]

    init(
        courseExternalID: Int,
        source: CourseGeometrySource,
        sourceName: String,
        attribution: String? = nil,
        updatedAt: Date = .now,
        holes: [HoleGeometry] = []
    ) {
        self.courseExternalID = courseExternalID
        sourceRawValue = source.rawValue
        self.sourceName = sourceName
        self.attribution = attribution
        self.updatedAt = updatedAt
        self.holes = holes
    }
}

@Model
final class HoleGeometry {
    var courseGeometry: CourseGeometry?
    var number: Int
    var greenFrontLatitude: Double?
    var greenFrontLongitude: Double?
    var greenCenterLatitude: Double?
    var greenCenterLongitude: Double?
    var greenBackLatitude: Double?
    var greenBackLongitude: Double?
    var greenContourAssetIdentifier: String?
    var flyoverAssetIdentifier: String?
    @Relationship(deleteRule: .cascade, inverse: \CourseMapFeaturePoint.holeGeometry) var featurePoints: [CourseMapFeaturePoint]

    init(
        number: Int,
        greenFrontLatitude: Double? = nil,
        greenFrontLongitude: Double? = nil,
        greenCenterLatitude: Double? = nil,
        greenCenterLongitude: Double? = nil,
        greenBackLatitude: Double? = nil,
        greenBackLongitude: Double? = nil,
        greenContourAssetIdentifier: String? = nil,
        flyoverAssetIdentifier: String? = nil,
        featurePoints: [CourseMapFeaturePoint] = []
    ) {
        self.number = number
        self.greenFrontLatitude = greenFrontLatitude
        self.greenFrontLongitude = greenFrontLongitude
        self.greenCenterLatitude = greenCenterLatitude
        self.greenCenterLongitude = greenCenterLongitude
        self.greenBackLatitude = greenBackLatitude
        self.greenBackLongitude = greenBackLongitude
        self.greenContourAssetIdentifier = greenContourAssetIdentifier
        self.flyoverAssetIdentifier = flyoverAssetIdentifier
        self.featurePoints = featurePoints
    }
}

@Model
final class CourseMapFeaturePoint {
    var holeGeometry: HoleGeometry?
    var kindRawValue: String
    var sourceRawValue: String
    var label: String
    var latitude: Double
    var longitude: Double
    var sortOrder: Int

    init(
        kind: CourseMapFeatureKind,
        label: String,
        latitude: Double,
        longitude: Double,
        source: CourseGeometrySource = .userMapped,
        sortOrder: Int = 0
    ) {
        kindRawValue = kind.rawValue
        sourceRawValue = source.rawValue
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.sortOrder = sortOrder
    }
}

extension CourseMapFeaturePoint {
    var kind: CourseMapFeatureKind {
        CourseMapFeatureKind(rawValue: kindRawValue) ?? .target
    }

    var source: CourseGeometrySource {
        CourseGeometrySource(rawValue: sourceRawValue) ?? .userMapped
    }
}
