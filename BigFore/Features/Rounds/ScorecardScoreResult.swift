import SwiftUI

enum ScorecardScoreResult: Equatable {
    case albatross
    case eagle
    case birdie
    case par
    case bogey
    case doubleBogeyOrWorse

    init(relativeToPar: Int) {
        switch relativeToPar {
        case ...(-3):
            self = .albatross
        case -2:
            self = .eagle
        case -1:
            self = .birdie
        case 0:
            self = .par
        case 1:
            self = .bogey
        default:
            self = .doubleBogeyOrWorse
        }
    }

    var title: String {
        switch self {
        case .albatross:
            "Albatross"
        case .eagle:
            "Eagle"
        case .birdie:
            "Birdie"
        case .par:
            "Par"
        case .bogey:
            "Bogey"
        case .doubleBogeyOrWorse:
            "Double bogey+"
        }
    }

    var abbreviation: String {
        switch self {
        case .albatross:
            "A"
        case .eagle:
            "E"
        case .birdie:
            "B"
        case .par:
            "P"
        case .bogey:
            "BO"
        case .doubleBogeyOrWorse:
            "DB+"
        }
    }

    var systemImage: String {
        switch self {
        case .albatross:
            "sparkles"
        case .eagle:
            "star.fill"
        case .birdie:
            "arrow.down.circle.fill"
        case .par:
            "checkmark.circle.fill"
        case .bogey:
            "plus.circle.fill"
        case .doubleBogeyOrWorse:
            "exclamationmark.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .albatross:
            .purple
        case .eagle:
            .blue
        case .birdie:
            .teal
        case .par:
            .green
        case .bogey:
            .orange
        case .doubleBogeyOrWorse:
            .red
        }
    }

    var fill: LinearGradient {
        BigForeDesign.Gradients.strongFill(for: tint)
    }
}
