import CoreLocation
import Observation

@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    var authorizationStatus: CLAuthorizationStatus
    var currentLocation: CLLocation? {
        didSet {
            currentLocationUpdatedAt = currentLocation?.timestamp
        }
    }
    var currentLocationUpdatedAt: Date?
    var errorMessage: String?

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
    }

    func requestLocationAccess() {
        errorMessage = nil

        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            errorMessage = "Location access is off. Enable it in Settings to show your position on the course."
        @unknown default:
            errorMessage = "Location authorization is unavailable."
        }
    }

    var currentAccuracyText: String? {
        guard let horizontalAccuracy = currentLocation?.horizontalAccuracy, horizontalAccuracy >= 0 else {
            return nil
        }

        return "+/- \(Int((horizontalAccuracy * 1.09361).rounded())) yds"
    }

    var locationStatusText: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Location permission is needed for live yardages."
        case .restricted, .denied:
            return "Location access is off. Enable it in Settings to show your position on the course."
        case .authorizedAlways, .authorizedWhenInUse:
            guard let currentLocation else {
                return "Waiting for a GPS fix."
            }

            if currentLocation.horizontalAccuracy < 0 {
                return "GPS accuracy is unavailable."
            }

            let accuracyYards = Int((currentLocation.horizontalAccuracy * 1.09361).rounded())
            if abs(currentLocation.timestamp.timeIntervalSinceNow) > 60 {
                return "GPS fix may be stale. Accuracy was +/- \(accuracyYards) yds."
            }

            if accuracyYards > 50 {
                return "Low GPS accuracy: +/- \(accuracyYards) yds."
            }

            return "GPS accuracy: +/- \(accuracyYards) yds."
        @unknown default:
            return "Location authorization is unavailable."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            errorMessage = "Location access is off. Enable it in Settings to show your position on the course."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        errorMessage = nil
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        errorMessage = error.localizedDescription
    }
}
