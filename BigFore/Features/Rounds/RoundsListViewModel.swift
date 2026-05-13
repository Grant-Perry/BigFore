import Foundation
import Observation

@MainActor
@Observable
final class RoundsListViewModel {
    private let scoring = RoundScoring()

    func activeRounds(from rounds: [GolfRound]) -> [GolfRound] {
        rounds.filter { !$0.isComplete }
    }

    func completedRounds(from rounds: [GolfRound]) -> [GolfRound] {
        rounds.filter(\.isComplete)
    }

    func leader(for round: GolfRound) -> RoundPlayer? {
        scoring.sortedPlayers(for: round).first
    }

    func playerCount(for round: GolfRound) -> Int {
        scoring.sortedPlayers(for: round).count
    }

    func summary(for player: RoundPlayer, in round: GolfRound) -> String {
        scoring.summary(for: player, scoringMode: round.scoringMode)
    }

    func resumeText(for round: GolfRound) -> String {
        if round.isComplete {
            return "Completed"
        }

        return "Resume Hole \(round.currentHole)"
    }

    func gpsStatusText(for round: GolfRound) -> String {
        if round.courseLatitude != nil && round.courseLongitude != nil {
            return "GPS ready"
        }

        return "No course pin"
    }
}
