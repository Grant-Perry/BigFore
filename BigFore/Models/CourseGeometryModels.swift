import Foundation
import CoreLocation
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

enum CourseMapAreaKind: String, CaseIterable, Codable, Identifiable {
    case fairway
    case rough
    case green
    case bunker
    case water
    case woods

    var id: String { rawValue }

    var isPenaltyArea: Bool {
        switch self {
        case .bunker, .water, .woods:
            true
        case .fairway, .rough, .green:
            false
        }
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
    @Relationship(deleteRule: .cascade, inverse: \CourseMapAreaFeature.holeGeometry) var areaFeatures: [CourseMapAreaFeature]

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
        featurePoints: [CourseMapFeaturePoint] = [],
        areaFeatures: [CourseMapAreaFeature] = []
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
        self.areaFeatures = areaFeatures
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

@Model
final class CourseMapAreaFeature {
    var holeGeometry: HoleGeometry?
    var kindRawValue: String
    var sourceRawValue: String
    var label: String
    var encodedCoordinates: String
    var sortOrder: Int

    init(
        kind: CourseMapAreaKind,
        label: String,
        coordinates: [CourseMapAreaCoordinate],
        source: CourseGeometrySource = .openStreetMap,
        sortOrder: Int = 0
    ) {
        kindRawValue = kind.rawValue
        sourceRawValue = source.rawValue
        self.label = label
        encodedCoordinates = coordinates.encodedString
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

extension CourseMapAreaFeature {
    var kind: CourseMapAreaKind {
        CourseMapAreaKind(rawValue: kindRawValue) ?? .rough
    }

    var source: CourseGeometrySource {
        CourseGeometrySource(rawValue: sourceRawValue) ?? .openStreetMap
    }

    var coordinates: [CourseMapAreaCoordinate] {
        CourseMapAreaCoordinate.decode(encodedCoordinates)
    }
}

extension CourseMapAreaFeature {
    var clLocationCoordinates: [CLLocationCoordinate2D] {
        coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
}

struct CourseMapAreaCoordinate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
}

extension Array where Element == CourseMapAreaCoordinate {
    nonisolated var encodedString: String {
        guard let data = try? JSONEncoder().encode(self) else {
            return "[]"
        }

        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

extension CourseMapAreaCoordinate {
    nonisolated static func decode(_ encodedString: String) -> [CourseMapAreaCoordinate] {
        guard let data = encodedString.data(using: .utf8),
              let coordinates = try? JSONDecoder().decode([CourseMapAreaCoordinate].self, from: data) else {
            return []
        }

        return coordinates
    }
}
