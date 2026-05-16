import SwiftUI

enum ScorecardScoreResult: Equatable {
    case albatross
    case eagle
    case birdie
    case par
    case bogey
    case doubleBogey
    case triple

    /// Returns `nil` when `relativeToPar` is worse than triple bogey (greater than 3 over par).
    init?(relativeToPar: Int) {
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
        case 2:
            self = .doubleBogey
        case 3:
            self = .triple
        default:
            return nil
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
        case .doubleBogey:
            "Double"
        case .triple:
            "Triple"
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
        case .doubleBogey:
            "DB"
        case .triple:
            "TB"
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
        case .doubleBogey:
            "exclamationmark.circle.fill"
        case .triple:
            "exclamationmark.triangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .albatross:
				 .gpAlbatross
        case .eagle:
				 .gpEagle
        case .birdie:
				 .gpBirdie
        case .par:
				 .gpPar
        case .bogey:
				 .gpBogey
        case .doubleBogey:
				 .gpDoubleBogey
		   case .triple:
				 .gpTripleBogey

        }
    }

    var fill: LinearGradient {
        BigForeDesign.Gradients.strongFill(for: tint)
    }
}
