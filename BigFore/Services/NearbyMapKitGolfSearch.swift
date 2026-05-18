import CoreLocation
import Foundation
import MapKit

/// MapKit golf POIs by coordinate + radius (GolfCourseAPI has no geographic search endpoint).
enum NearbyMapKitGolfSearch {
    /// Returns golf POIs within `radiusMiles` of `userLocation`, sorted nearest-first (straight-line).
    static func mapItemsSortedByDistance(
        userLocation: CLLocation,
        radiusMiles: Double,
        maxResults: Int = 45
    ) async throws -> [(mapItem: MKMapItem, distanceMeters: CLLocationDistance)] {
        let coordinate = userLocation.coordinate
        let radiusMeters = radiusMiles * 1_609.34

        let request = MKLocalSearch.Request()
        let diameter = min(radiusMeters * 2, 400_000)
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: diameter,
            longitudinalMeters: diameter
        )
        request.resultTypes = .pointOfInterest
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.golf])

        let response = try await MKLocalSearch(request: request).start()
        let rows: [(MKMapItem, CLLocationDistance)] = response.mapItems.compactMap { item in
            let itemLocation = item.location
            let distance = userLocation.distance(from: itemLocation)
            guard distance <= radiusMeters + 250 else {
                return nil
            }
            return (item, distance)
        }
        .sorted { $0.1 < $1.1 }

        return dedupePreservingOrder(rows).prefix(maxResults).map { $0 }
    }

    private static func dedupePreservingOrder(_ rows: [(MKMapItem, CLLocationDistance)]) -> [(MKMapItem, CLLocationDistance)] {
        var seen = Set<String>()
        var out: [(MKMapItem, CLLocationDistance)] = []
        for (item, distance) in rows {
            let key = dedupeKey(for: item)
            if seen.insert(key).inserted {
                out.append((item, distance))
            }
        }
        return out
    }

    private static func dedupeKey(for item: MKMapItem) -> String {
        let name = (item.name ?? "").lowercased()
        let c = item.location.coordinate
        let lat = (c.latitude * 10_000).rounded() / 10_000
        let lon = (c.longitude * 10_000).rounded() / 10_000
        return "\(name)|\(lat)|\(lon)"
    }
}
