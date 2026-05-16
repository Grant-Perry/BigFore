import SwiftData
import SwiftUI

struct StatisticsView: View {
    @Query(sort: \GolfRound.startedAt, order: .reverse) private var rounds: [GolfRound]
    private let scoring = RoundScoring()

    var body: some View {
        List {
            Section {
                StatisticRow(title: "Rounds Played", value: "\(completedRounds.count)")
                StatisticRow(title: "Scoring Average", value: scoringAverageText)
                StatisticRow(title: "Putts / Round", value: puttsAverageText)
                StatisticRow(title: "Fairways", value: fairwayText)
                StatisticRow(title: "GIR", value: girText)
            } footer: {
                Text("Stats use completed rounds and scorecard fields. Shot tracking will make this sharper over time.")
            }
        }
        .navigationTitle("Statistics")
    }

    private var completedRounds: [GolfRound] {
        rounds.filter(\.isComplete)
    }

    private var scoringAverageText: String {
        let totals = completedRounds.compactMap { round -> Int? in
            guard let player = scoring.sortedPlayers(for: round).first else {
                return nil
            }

            return scoring.totalStrokes(for: player)
        }

        guard !totals.isEmpty else {
            return "--"
        }

        let average = Double(totals.reduce(0, +)) / Double(totals.count)
        return average.formatted(.number.precision(.fractionLength(1)))
    }

    private var puttsAverageText: String {
        let totals = completedRounds.compactMap { round -> Int? in
            guard let player = scoring.sortedPlayers(for: round).first else {
                return nil
            }

            let putts = player.scores.compactMap(\.putts)
            return putts.isEmpty ? nil : putts.reduce(0, +)
        }

        guard !totals.isEmpty else {
            return "--"
        }

        let average = Double(totals.reduce(0, +)) / Double(totals.count)
        return average.formatted(.number.precision(.fractionLength(1)))
    }

    private var fairwayText: String {
        let trackedScores = completedRounds
            .compactMap { scoring.sortedPlayers(for: $0).first }
            .flatMap(\.scores)
            .filter { $0.isFairwayTrackingAvailable }
            .compactMap(\.teeShotAccuracy)
            .filter { $0 != .notApplicable }

        guard !trackedScores.isEmpty else {
            return "--"
        }

        let fairways = trackedScores.filter { $0 == .fairway }.count
        return "\(fairways)/\(trackedScores.count)"
    }

    private var girText: String {
        let girValues = completedRounds
            .compactMap { scoring.sortedPlayers(for: $0).first }
            .flatMap(\.scores)
            .compactMap(\.girEstimate)

        guard !girValues.isEmpty else {
            return "--"
        }

        let hits = girValues.filter { $0 }.count
        return "\(hits)/\(girValues.count)"
    }
}

private struct StatisticRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value)
            .font(.headline)
    }
}
