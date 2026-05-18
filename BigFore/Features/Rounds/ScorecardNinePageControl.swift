import SwiftUI

/// Front / Back nine switcher, grid **#** / **+** mode, and **Stack** (last chip).
struct ScorecardNinePageControl: View {
    let nines: [ScorecardNine]
    @Binding var selectedNine: ScorecardNine
    @Binding var gridShowsStrokeCounts: Bool
    @Binding var stackScoringEnabled: Bool
    let scoringMode: ScoringMode
    let stackSelectionCount: Int
    let clearStackSelection: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(nines) { nine in
                chip(
                    title: nine.shortSwitcherTitle,
                    isSelected: selectedNine == nine,
                    useHeavyDigitFont: false
                ) {
                    selectedNine = nine
                }
                .accessibilityLabel("Show \(nine.title)")
                .accessibilityAddTraits(selectedNine == nine ? .isSelected : [])
            }

            chip(
                title: gridShowsStrokeCounts ? "#" : "+",
                isSelected: gridShowsStrokeCounts,
                useHeavyDigitFont: true
            ) {
                gridShowsStrokeCounts.toggle()
            }
            .accessibilityLabel(gridPlusModeAccessibilityLabel)
            .accessibilityHint(gridToggleAccessibilityHint)

            chip(
                title: "Stack",
                isSelected: stackScoringEnabled,
                useHeavyDigitFont: false
            ) {
                stackScoringEnabled.toggle()
            }
            .accessibilityLabel(stackScoringEnabled ? "Stack scoring on" : "Stack scoring off")
            .accessibilityHint("Select several holes, then apply one quick score to all selected.")

            if stackScoringEnabled {
                Text("\(stackSelectionCount) selected")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Button("Clear", action: clearStackSelection)
                    .font(.caption2.weight(.semibold))
                    .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            }

            Spacer(minLength: 0)
        }
    }

    private var gridPlusModeAccessibilityLabel: String {
        if gridShowsStrokeCounts {
            return "Stroke counts in grid"
        }
        return scoringMode == .stableford ? "Stableford points in grid" : "Versus par in grid"
    }

    private var gridToggleAccessibilityHint: String {
        let versus = scoringMode == .stableford ? "Stableford points" : "versus par"
        return "Switches hole squares between stroke counts (#) and \(versus) (+)."
    }

    private func chip(
        title: String,
        isSelected: Bool,
        useHeavyDigitFont: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(useHeavyDigitFont ? .caption.weight(.heavy) : .caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .buttonStyle(BigForePillButtonStyle.bigForeToggle(isSelected: isSelected))
    }
}
