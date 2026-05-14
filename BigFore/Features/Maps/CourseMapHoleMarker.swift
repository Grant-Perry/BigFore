import CoreLocation

struct CourseMapHoleMarker: Identifiable {
    enum Kind: Equatable {
        case tee
        case pin
    }

    let id: String
    let holeNumber: Int
    let coordinate: CLLocationCoordinate2D
    let kind: Kind
}
