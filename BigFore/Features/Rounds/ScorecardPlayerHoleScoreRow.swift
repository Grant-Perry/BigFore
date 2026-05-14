import SwiftUI

struct ScorecardPlayerHoleScoreRow: View {
    let playerName: String
    @Bindable var score: HoleScore
    let scoringMode: ScoringMode
    let result: ScorecardScoreResult?
    let saveScore: () -> Void
    private let scoring = RoundScoring()

    var body: some View {
        HStack(alignment: .center, spacing: BigForeDesign.Spacing.medium) {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                Text(playerName)
                    .font(.headline)
                    .lineLimit(1)

                ScorecardScoreResultPill(
                    result: result,
                    fallbackText: score.strokes == 0 ? "Not scored" : secondaryScoreText
                )

                if score.strokes > 0 {
                    Text(secondaryScoreText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: BigForeDesign.Spacing.medium)

            Stepper(value: $score.strokes, in: 0...12) {
                Text(score.strokes == 0 ? "—" : "\(score.strokes)")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .frame(minWidth: 34, alignment: .trailing)
                    .accessibilityLabel("Strokes")
                    .accessibilityValue(score.strokes == 0 ? "Not scored" : "\(score.strokes)")
            }
            .frame(maxWidth: 176)
            .onChange(of: score.strokes) { _, _ in
                saveScore()
            }
        }
        .frame(minHeight: 60)
    }

    private var secondaryScoreText: String {
        if scoringMode == .stableford {
            return "\(scoring.stablefordPoints(for: score)) points"
        }

        guard let relative = scoring.scoreRelativeToPar(for: score) else {
            return "Not scored"
        }

        return scoring.relativeText(relative)
    }
}
