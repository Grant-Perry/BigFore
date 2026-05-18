import SwiftData
import SwiftUI

enum ScorecardScoreResult: Equatable, Hashable {
    case albatross
    case eagle
    case birdie
    case par
    case bogey
    case doubleBogey
    case triple

    /// Single source of truth for strokes − par → scorecard bucket (fills, legend, quick score).
    static func bucket(relativeToPar d: Int) -> ScorecardScoreResult? {
        if d <= -3 { return .albatross }
        if d == -2 { return .eagle }
        if d == -1 { return .birdie }
        if d == 0 { return .par }
        if d == 1 { return .bogey }
        if d == 2 { return .doubleBogey }
        if d == 3 { return .triple }
        return nil
    }

    /// Returns `nil` when `relativeToPar` is worse than triple bogey (greater than 3 over par).
    init?(relativeToPar: Int) {
        guard let bucket = Self.bucket(relativeToPar: relativeToPar) else { return nil }
        self = bucket
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

    /// Solid fill used on printed / shared scorecard cells and legend swatches.
    var solidColor: Color { tint }

    var fill: LinearGradient {
        BigForeDesign.Gradients.strongFill(for: tint)
    }

    /// Display order for legend rows (best → worst among standard buckets).
    private static let legendDisplayOrder: [ScorecardScoreResult] = [
        .albatross, .eagle, .birdie, .par, .bogey, .doubleBogey, .triple
    ]

    /// Per-result counts for scored holes among the visible players (`showsAllPlayers == false` → first player only).
    private static func resultCounts(for round: GolfRound, showsAllPlayers: Bool) -> [ScorecardScoreResult: Int] {
        let scoring = RoundScoring()
        let players = scoring.sortedPlayers(for: round)
        let visible = showsAllPlayers ? players : Array(players.prefix(1))
        var counts: [ScorecardScoreResult: Int] = [:]
        for player in visible {
            for score in scoring.sortedScores(for: player) {
                guard score.strokes > 0 else { continue }
                guard let result = ScorecardScoreResult.bucket(relativeToPar: score.strokes - score.par) else { continue }
                counts[result, default: 0] += 1
            }
        }
        return counts
    }

    private static func hasAnyScoredHole(for round: GolfRound, showsAllPlayers: Bool) -> Bool {
        let scoring = RoundScoring()
        let players = scoring.sortedPlayers(for: round)
        let visible = showsAllPlayers ? players : Array(players.prefix(1))
        for player in visible {
            for score in scoring.sortedScores(for: player) {
                if score.strokes > 0 { return true }
            }
        }
        return false
    }

    /// Legend rows with counts, ordered best → worst; omits categories with zero holes.
    /// When `includeAlbatrossWhenAbsent` is true and the round has any scored holes for the visible players, **Albatross** is included even at 0 so the key always defines the top bucket (e.g. 3 on a par 5 is still an eagle, not an albatross).
    static func legendRows(for round: GolfRound, showsAllPlayers: Bool, includeAlbatrossWhenAbsent: Bool = true) -> [(result: ScorecardScoreResult, count: Int)] {
        let counts = resultCounts(for: round, showsAllPlayers: showsAllPlayers)
        let padAlbatross = includeAlbatrossWhenAbsent && hasAnyScoredHole(for: round, showsAllPlayers: showsAllPlayers) && (counts[.albatross] ?? 0) == 0
        return Self.legendDisplayOrder.compactMap { result in
            if let count = counts[result], count > 0 {
                return (result, count)
            }
            if result == .albatross, padAlbatross {
                return (result, 0)
            }
            return nil
        }
    }

    /// Legend entries for score colors that actually appear for the visible players’ scored holes.
    static func legendResults(for round: GolfRound, showsAllPlayers: Bool) -> [ScorecardScoreResult] {
        legendRows(for: round, showsAllPlayers: showsAllPlayers).map(\.result)
    }
}
