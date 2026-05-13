import CoreLocation

struct DistanceCalculator {
    func yards(from start: CLLocation, to end: CLLocation) -> Int {
        yards(fromMeters: start.distance(from: end))
    }

    func yards(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Int {
        yards(
            from: CLLocation(latitude: start.latitude, longitude: start.longitude),
            to: CLLocation(latitude: end.latitude, longitude: end.longitude)
        )
    }

    func formattedYards(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> String {
        "\(yards(from: start, to: end)) yds"
    }

    private func yards(fromMeters meters: CLLocationDistance) -> Int {
        Int((meters * 1.09361).rounded())
    }
}
