import Foundation

enum ScorecardNine: String, CaseIterable, Identifiable, Hashable {
    case front
    case back

    var id: Self { self }

    var title: String {
        switch self {
        case .front:
            "Front 9"
        case .back:
            "Back 9"
        }
    }

    var totalTitle: String {
        switch self {
        case .front:
            "OUT"
        case .back:
            "IN"
        }
    }

    var holeNumbers: [Int] {
        switch self {
        case .front:
            Array(1...9)
        case .back:
            Array(10...18)
        }
    }

    func contains(_ holeNumber: Int) -> Bool {
        holeNumbers.contains(holeNumber)
    }

    static func containing(_ holeNumber: Int) -> ScorecardNine {
        holeNumber <= 9 ? .front : .back
    }
}
