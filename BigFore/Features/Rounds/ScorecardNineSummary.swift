import Foundation

struct ScorecardNineSummary: Equatable {
    let strokes: Int?
    let par: Int
    let yards: Int?
    let relativeToPar: Int?
    /// Sum of Stableford points for scored holes in this nine (stroke play ignores).
    let stablefordPointsTotal: Int?

    var scoreText: String {
        strokes.map(String.init) ?? "—"
    }

    var parText: String {
        par > 0 ? "\(par)" : "—"
    }

    var yardsText: String {
        yards.map(String.init) ?? "—"
    }
}
