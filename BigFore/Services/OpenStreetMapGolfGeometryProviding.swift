import CoreLocation
import Foundation

struct OpenStreetMapGolfGeometryRequest {
    let courseExternalID: Int
    let centerCoordinate: CLLocationCoordinate2D
    let searchRadiusMeters: Int

    init(courseExternalID: Int, centerCoordinate: CLLocationCoordinate2D, searchRadiusMeters: Int = 2_500) {
        self.courseExternalID = courseExternalID
        self.centerCoordinate = centerCoordinate
        self.searchRadiusMeters = searchRadiusMeters
    }
}

@MainActor
protocol OpenStreetMapGolfGeometryProviding {
    func geometry(for request: OpenStreetMapGolfGeometryRequest) async throws -> CourseGeometryImport
}
