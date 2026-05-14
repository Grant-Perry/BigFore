import SwiftUI

struct ScorecardHoleChip: View {
    let holeNumber: Int
    let isSelected: Bool
    let relativeText: String?
    let result: ScorecardScoreResult?
    let accessibilityText: String
    let selectHole: () -> Void

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        Button(action: selectHole) {
            VStack(spacing: BigForeDesign.Spacing.xSmall) {
                Text("\(holeNumber)")
                    .font(.headline)
                    .monospacedDigit()
                    .frame(width: 34, height: 34)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .background(chipFill, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(chipStroke, lineWidth: differentiateWithoutColor || isSelected ? 2 : 1)
                    }

                Text(relativeText ?? "—")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(result?.tint ?? .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: 48)
            .frame(minHeight: 58)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var chipFill: Color {
        if isSelected {
            return result?.tint ?? BigForeDesign.Palette.primaryAction
        }

        if let result {
            return result.tint.opacity(0.16)
        }

        return Color.secondary.opacity(0.12)
    }

    private var chipStroke: Color {
        if isSelected {
            return result?.tint ?? BigForeDesign.Palette.primaryAction
        }

        return result?.tint ?? Color.secondary.opacity(0.22)
    }
}
