import SwiftUI

struct ScorecardHoleScoreColumn: View {
    let holeNumber: Int
    let score: HoleScore?
    let squareText: String
    let result: ScorecardScoreResult?
    let relativeText: String?
    let isSelected: Bool
    let isStackSelected: Bool
    let accessibilityText: String
    let showQuickScore: () -> Void
    let selectHole: () -> Void

    var body: some View {
        VStack(spacing: ScorecardGridMetrics.rowSpacing) {
            Text("\(holeNumber)")
                .font(.caption.weight(isSelected ? .bold : .semibold))
                .monospacedDigit()
                .foregroundStyle(isSelected ? Color.white : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(height: ScorecardGridMetrics.holeHeaderHeight)

            ScorecardScoreSquare(
                text: squareText,
                result: result,
                isSelected: isSelected
            )
            .contentShape(Rectangle())
            .onTapGesture {
                showQuickScore()
            }

            ScorecardGridMetricText(text: parText)
            ScorecardGridMetricText(text: yardsText)
            ScorecardGridMetricText(text: handicapText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, BigForeDesign.Spacing.xSmall)
        .background(selectionFill, in: RoundedRectangle(cornerRadius: BigForeDesign.Spacing.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BigForeDesign.Spacing.medium, style: .continuous)
                .stroke(selectionStroke, lineWidth: (isSelected || isStackSelected) ? 1.5 : 0)
        }
        .contentShape(RoundedRectangle(cornerRadius: BigForeDesign.Spacing.medium, style: .continuous))
        .onTapGesture(perform: selectHole)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(accessibilityScoreValue)
        .accessibilityHint("Selects hole \(holeNumber).")
        .accessibilityInputLabels(["Hole \(holeNumber)"])
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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

    private var accessibilityScoreValue: String {
        if let relativeText {
            return "\(squareText). \(relativeText) to par."
        }
        return squareText
    }

    private var selectionFill: LinearGradient {
        (isSelected || isStackSelected) ? BigForeDesign.Gradients.softFill(for: .white) : BigForeDesign.Gradients.softFill(for: .clear)
    }

    private var selectionStroke: Color {
        (isSelected || isStackSelected) ? Color.white.opacity(0.55) : .clear
    }

}
