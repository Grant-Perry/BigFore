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
                Text(footerCopy)
            }

            if scoring.mappedShotRecords(in: completedRounds).isEmpty == false {
                Section {
                    StatisticRow(title: "Mapped Shots (total)", value: "\(scoring.mappedShotRecords(in: completedRounds).count)")
                    StatisticRow(title: "Mapped Shots / Round", value: mappedShotsPerRoundText)
                    StatisticRow(title: "Avg Shot Distance", value: averageShotDistanceText)
                } header: {
                    Text("From GPS shots")
                } footer: {
                    Text("Distances use saved map shot segments. Rounds without tracked shots are excluded from averages where noted.")
                }
            }
        }
        .navigationTitle("Statistics")
    }

    private var footerCopy: String {
        if scoring.mappedShotRecords(in: completedRounds).isEmpty {
            return "Stats use completed rounds and scorecard fields. Track shots on the course map to unlock shot-based averages here."
        }
        return "Scorecard stats use completed rounds. Shot rows refine mapped-shot averages."
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

    private var mappedShotsPerRoundText: String {
        let shots = scoring.mappedShotRecords(in: completedRounds)
        guard !shots.isEmpty, !completedRounds.isEmpty else {
            return "--"
        }

        let withShots = completedRounds.filter { !$0.shotRecords.isEmpty }
        guard !withShots.isEmpty else {
            return "--"
        }

        let average = Double(shots.count) / Double(withShots.count)
        return average.formatted(.number.precision(.fractionLength(1)))
    }

    private var averageShotDistanceText: String {
        guard let avg = scoring.averageMappedShotDistanceYards(in: completedRounds) else {
            return "--"
        }

        return "\(avg.rounded().formatted(.number.precision(.fractionLength(0)))) yd"
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
