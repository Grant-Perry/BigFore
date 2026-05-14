import SwiftUI

struct ScorecardHoleScoreColumn: View {
    let holeNumber: Int
    let score: HoleScore?
    let result: ScorecardScoreResult?
    let relativeText: String?
    let isSelected: Bool
    let accessibilityText: String
    let selectHole: () -> Void

    var body: some View {
        Button(action: selectHole) {
            VStack(spacing: ScorecardGridMetrics.rowSpacing) {
                Text("\(holeNumber)")
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? BigForeDesign.Palette.primaryAction : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(height: ScorecardGridMetrics.holeHeaderHeight)

                ScorecardScoreSquare(
                    text: scoreText,
                    result: result,
                    isSelected: isSelected
                )

                ScorecardGridMetricText(text: parText)
                ScorecardGridMetricText(text: yardsText)
                ScorecardGridMetricText(text: handicapText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, BigForeDesign.Spacing.xSmall)
            .background(selectionFill, in: RoundedRectangle(cornerRadius: BigForeDesign.Spacing.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BigForeDesign.Spacing.medium, style: .continuous)
                    .stroke(selectionStroke, lineWidth: isSelected ? 1.5 : 0)
            }
            .contentShape(RoundedRectangle(cornerRadius: BigForeDesign.Spacing.medium, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(relativeText ?? "Not scored")
        .accessibilityHint("Selects hole \(holeNumber).")
        .accessibilityInputLabels(["Hole \(holeNumber)"])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var scoreText: String {
        guard let score, score.strokes > 0 else {
            return "—"
        }

        return "\(score.strokes)"
    }

    private var parText: String {
        score.map { "\($0.par)" } ?? "—"
    }

    private var yardsText: String {
        score?.yardage.map(String.init) ?? "—"
    }

    private var handicapText: String {
        score?.handicap.map(String.init) ?? "—"
    }

    private var selectionFill: LinearGradient {
        isSelected ? BigForeDesign.Gradients.softFill(for: BigForeDesign.Palette.primaryAction) : BigForeDesign.Gradients.softFill(for: .clear)
    }

    private var selectionStroke: Color {
        isSelected ? BigForeDesign.Palette.primaryAction.opacity(0.6) : .clear
    }

}
