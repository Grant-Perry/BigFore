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
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
