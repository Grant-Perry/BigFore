import SwiftUI

enum ScorecardQuickScoreOption: CaseIterable, Identifiable {
    case tripleBogey
    case doubleBogey
    case bogey
    case par
    case birdie
    case eagle
    case albatross

    var id: String { title }

    var title: String {
        switch self {
        case .tripleBogey:
            "Triple"
        case .doubleBogey:
            "Double"
        case .bogey:
            "Bogey"
        case .par:
            "Par"
        case .birdie:
            "Birdie"
        case .eagle:
            "Eagle"
        case .albatross:
            "Albatross"
        }
    }

    var relativeToPar: Int {
        switch self {
        case .tripleBogey:
            3
        case .doubleBogey:
            2
        case .bogey:
            1
        case .par:
            0
        case .birdie:
            -1
        case .eagle:
            -2
        case .albatross:
            -3
        }
    }

    var color: Color {
        ScorecardScoreResult(relativeToPar: relativeToPar)?.tint ?? .secondary
    }

    /// Fills quick-score orbs; matches score-result legend gradients.
    var fillGradient: LinearGradient {
        guard let result = ScorecardScoreResult(relativeToPar: relativeToPar) else {
            return BigForeDesign.Gradients.strongFill(for: color)
        }
        return result.fill
    }

    var systemImage: String {
        ScorecardScoreResult(relativeToPar: relativeToPar)?.systemImage ?? "minus.circle"
    }

    /// Clockwise from 12 o'clock: Par → Bogey → Double → Triple → Albatross → Eagle → Birdie.
    static let clockwiseClockOrder: [ScorecardQuickScoreOption] = [
        .par,
        .bogey,
        .doubleBogey,
        .tripleBogey,
        .albatross,
        .eagle,
        .birdie,
    ]
}
