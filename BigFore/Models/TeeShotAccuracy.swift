import Foundation

enum TeeShotAccuracy: String, CaseIterable, Identifiable, Codable {
    case fairway
    case left
    case right
    case bunker
    case short
    case long
    case missed
    case notApplicable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fairway:
            "Fairway"
        case .left:
            "Left"
        case .right:
            "Right"
        case .bunker:
            "Bunker"
        case .short:
            "Short"
        case .long:
            "Long"
        case .missed:
            "Miss"
        case .notApplicable:
            "N/A"
        }
    }

    var shortTitle: String {
        switch self {
        case .fairway:
            "F"
        case .left:
            "L"
        case .right:
            "R"
        case .bunker:
            "B"
        case .short:
            "S"
        case .long:
            "Lg"
        case .missed:
            "M"
        case .notApplicable:
            "--"
        }
    }

    var systemImage: String {
        switch self {
        case .fairway:
            "target"
        case .left:
            "arrow.left"
        case .right:
            "arrow.right"
        case .bunker:
            "beach.umbrella"
        case .short:
            "arrow.down"
        case .long:
            "arrow.up"
        case .missed:
            "xmark"
        case .notApplicable:
            "minus"
        }
    }
}
