import Foundation

struct RoundScoring {
    func sortedPlayers(for round: GolfRound) -> [RoundPlayer] {
        round.players.sorted { $0.displayOrder < $1.displayOrder }
    }

    func sortedScores(for player: RoundPlayer) -> [HoleScore] {
        player.scores.sorted { $0.holeNumber < $1.holeNumber }
    }

    func completedHoles(for player: RoundPlayer) -> Int {
        player.scores.filter { $0.strokes > 0 }.count
    }

    func totalStrokes(for player: RoundPlayer) -> Int {
        player.scores.reduce(0) { $0 + max($1.strokes, 0) }
    }

    func scoreRelativeToPar(for player: RoundPlayer) -> Int {
        player.scores.reduce(0) { total, score in
            guard score.strokes > 0 else { return total }
            return total + score.strokes - score.par
        }
    }

    func scoreRelativeToPar(for score: HoleScore) -> Int? {
        guard score.strokes > 0 else { return nil }
        return score.strokes - score.par
    }

    func stablefordPoints(for player: RoundPlayer) -> Int {
        player.scores.reduce(0) { $0 + stablefordPoints(for: $1) }
    }

    func stablefordPoints(for score: HoleScore) -> Int {
        guard score.strokes > 0 else { return 0 }

        switch score.strokes - score.par {
        case ...(-2):
            return 4
        case -1:
            return 3
        case 0:
            return 2
        case 1:
            return 1
        default:
            return 0
        }
    }

    func relativeText(_ value: Int) -> String {
        if value == 0 { return "E" }
        return value > 0 ? "+\(value)" : "\(value)"
    }

    func summary(for player: RoundPlayer, scoringMode: ScoringMode) -> String {
        if scoringMode == .stableford {
            return "\(stablefordPoints(for: player)) pts"
        }

        return relativeText(scoreRelativeToPar(for: player))
    }
}
