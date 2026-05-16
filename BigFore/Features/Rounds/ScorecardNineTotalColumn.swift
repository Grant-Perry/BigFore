import SwiftUI

struct ScorecardNineTotalColumn: View {
    let title: String
    let summary: ScorecardNineSummary
    let relativeText: String?

    var body: some View {
        VStack(spacing: ScorecardGridMetrics.rowSpacing) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .frame(height: ScorecardGridMetrics.holeHeaderHeight)

            ScorecardScoreSquare(
                text: summary.scoreText,
                result: result,
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

    private var result: ScorecardScoreResult? {
        summary.relativeToPar.flatMap { ScorecardScoreResult(relativeToPar: $0) }
    }

    private var accessibilityLabel: String {
        let scoreText = summary.strokes.map { "\($0) strokes" } ?? "not scored"
        let yardsText = summary.yards.map { ", \($0) yards" } ?? ""
        let relativeText = relativeText.map { ", \($0) to par" } ?? ""

        return "\(title) total, \(scoreText), par \(summary.par)\(yardsText)\(relativeText)"
    }

}
