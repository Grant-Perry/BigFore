import CoreLocation
import Foundation

struct CourseGeometryImport {
    let courseExternalID: Int
    let source: CourseGeometrySource
    let sourceName: String
    let attribution: String?
    let holes: [HoleGeometryImport]
}

struct HoleGeometryImport {
    let number: Int
    let greenFrontCoordinate: CLLocationCoordinate2D?
    let greenCenterCoordinate: CLLocationCoordinate2D?
    let greenBackCoordinate: CLLocationCoordinate2D?
    let featurePoints: [CourseGeometryFeatureImport]
    let areaFeatures: [CourseGeometryAreaImport]

    init(
        number: Int,
        greenFrontCoordinate: CLLocationCoordinate2D? = nil,
        greenCenterCoordinate: CLLocationCoordinate2D? = nil,
        greenBackCoordinate: CLLocationCoordinate2D? = nil,
        featurePoints: [CourseGeometryFeatureImport] = [],
        areaFeatures: [CourseGeometryAreaImport] = []
    ) {
        self.number = number
        self.greenFrontCoordinate = greenFrontCoordinate
        self.greenCenterCoordinate = greenCenterCoordinate
        self.greenBackCoordinate = greenBackCoordinate
        self.featurePoints = featurePoints
        self.areaFeatures = areaFeatures
    }
}

struct CourseGeometryFeatureImport {
    let kind: CourseMapFeatureKind
    let label: String
    let coordinate: CLLocationCoordinate2D
    let sortOrder: Int
}

struct CourseGeometryAreaImport {
    let kind: CourseMapAreaKind
    let label: String
    let coordinates: [CLLocationCoordinate2D]
    let sortOrder: Int
}
