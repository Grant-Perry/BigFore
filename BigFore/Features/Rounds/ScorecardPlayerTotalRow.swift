import SwiftUI

struct ScorecardPlayerTotalRow: View {
    let player: RoundPlayer
    let scoringMode: ScoringMode
    private let scoring = RoundScoring()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
                Text(player.name)
                    .font(.subheadline)
                Text("\(scoring.completedHoles(for: player)) holes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if scoringMode == .stableford {
                Text("\(scoring.stablefordPoints(for: player)) pts")
                    .font(.headline)
                    .monospacedDigit()
            } else {
                VStack(alignment: .trailing, spacing: BigForeDesign.Spacing.xSmall) {
                    Text("\(scoring.totalStrokes(for: player))")
                        .font(.headline)
                        .monospacedDigit()
                    Text(scoring.relativeText(scoring.scoreRelativeToPar(for: player)))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(detailText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var detailText: String {
        var parts: [String] = []
        if let putts = scoring.totalPutts(for: player) {
            parts.append("\(putts) putts")
        }

        let fairways = scoring.fairwaySummary(for: player)
        if fairways.tracked > 0 {
            parts.append("\(fairways.hits)/\(fairways.tracked) fairways")
        }

        let gir = scoring.girSummary(for: player)
        if gir.tracked > 0 {
            parts.append("\(gir.hits)/\(gir.tracked) GIR")
        }

        return parts.isEmpty ? "Stats pending" : parts.joined(separator: " · ")
    }
}
