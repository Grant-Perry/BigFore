import Foundation

enum GolfClubKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case driver
    case fairwayWood
    case hybrid
    case iron
    case wedge
    case putter
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .driver:
            "Driver"
        case .fairwayWood:
            "Fairway Wood"
        case .hybrid:
            "Hybrid"
        case .iron:
            "Iron"
        case .wedge:
            "Wedge"
        case .putter:
            "Putter"
        case .other:
            "Other"
        }
    }
}
