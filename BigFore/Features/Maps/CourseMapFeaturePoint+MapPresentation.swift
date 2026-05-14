import CoreLocation

extension CourseMapFeaturePoint {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var markerTitle: String {
        if label.hasPrefix("OSM ") {
            return String(label.dropFirst(4))
        }

        if let holeNumber = holeGeometry?.number {
            return "Hole \(holeNumber) \(label)"
        }

        return label
    }
}
