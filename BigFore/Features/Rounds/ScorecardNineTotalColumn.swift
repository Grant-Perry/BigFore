import SwiftUI

struct ScorecardNineTotalColumn: View {
    let title: String
    let summary: ScorecardNineSummary
    let squareText: String
    let squareResult: ScorecardScoreResult?
    let accessibilityRelativeSummary: String?

    var body: some View {
        VStack(spacing: ScorecardGridMetrics.rowSpacing) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(height: ScorecardGridMetrics.holeHeaderHeight)

            ScorecardScoreSquare(
                text: squareText,
                result: squareResult,
                isSelected: false
            )

            ScorecardGridMetricText(text: summary.parText, weight: .semibold)
            ScorecardGridMetricText(text: summary.yardsText, weight: .semibold)
            ScorecardGridMetricText(text: "—", weight: .semibold)
        }
        .frame(width: ScorecardGridMetrics.totalColumnWidth)
        .padding(.vertical, BigForeDesign.Spacing.xSmall)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: BigForeDesign.Spacing.medium, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let strokesText = summary.strokes.map { "\($0) strokes" } ?? "not scored"
        let yardsText = summary.yards.map { ", \($0) yards" } ?? ""
        let relativePhrase = accessibilityRelativeSummary.map { ", \($0) to par for this nine" } ?? ""

        return "\(title) total, square shows \(squareText), \(strokesText), par \(summary.par)\(yardsText)\(relativePhrase)"
    }

}
