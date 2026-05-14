import SwiftUI

struct ScorecardScoreSquare: View {
    let text: String
    let result: ScorecardScoreResult?
    let isSelected: Bool

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: BigForeDesign.Spacing.small, style: .continuous)
                .fill(fill)
                .overlay {
                    RoundedRectangle(cornerRadius: BigForeDesign.Spacing.small, style: .continuous)
                        .stroke(stroke, lineWidth: isSelected || differentiateWithoutColor ? 2 : 1)
                }

            Text(text)
                .font(.caption.bold())
                .monospacedDigit()
                .foregroundStyle(result == nil ? Color.primary : Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            if differentiateWithoutColor, let result {
                Image(systemName: result.systemImage)
                    .font(.caption2.bold())
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(2)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: ScorecardGridMetrics.scoreSquareSide, height: ScorecardGridMetrics.scoreSquareSide)
    }

    private var fill: LinearGradient {
        result?.fill ?? BigForeDesign.Gradients.softFill(for: .secondary)
    }

    private var stroke: Color {
        if isSelected {
            return .primary.opacity(0.72)
        }

        return result?.tint.opacity(0.72) ?? .secondary.opacity(0.20)
    }
}
