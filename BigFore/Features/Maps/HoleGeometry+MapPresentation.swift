import CoreLocation

extension HoleGeometry {
    var greenCenterCoordinate: CLLocationCoordinate2D? {
        guard let greenCenterLatitude, let greenCenterLongitude else {
            return nil
        }

        return CLLocationCoordinate2D(latitude: greenCenterLatitude, longitude: greenCenterLongitude)
    }
}
