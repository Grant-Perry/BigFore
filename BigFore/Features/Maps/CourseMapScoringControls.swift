import SwiftData
import SwiftUI

struct CourseMapScoringControls: View {
    let courseMapViewModel: CourseMapViewModel
    let modelContext: ModelContext

    var body: some View {
        @Bindable var courseMapViewModel = courseMapViewModel

        if courseMapViewModel.scoringPlayers.isEmpty == false {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                if courseMapViewModel.scoringPlayers.count > 1 {
                    Picker("Ball / scoring player", selection: $courseMapViewModel.selectedScoringPlayerID) {
                        ForEach(courseMapViewModel.scoringPlayers) { player in
                            Text(player.name).tag(Optional(player.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Ball and scoring player")
                    .onChange(of: courseMapViewModel.selectedScoringPlayerID) { _, _ in
                        courseMapViewModel.syncManualShotCountToScore(modelContext: modelContext)
                    }
                }

                if let manualShotScoreText = courseMapViewModel.manualShotScoreText {
                    Text(manualShotScoreText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                scoreAdjustmentControls

                Button {
                    courseMapViewModel.saveCurrentHole(modelContext: modelContext)
                } label: {
                    Label(courseMapViewModel.saveHoleButtonTitle, systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BigForePillButtonStyle.bigForePrimary)
                .tint(BigForeDesign.Palette.primaryAction)
                .controlSize(.large)
                .disabled(!courseMapViewModel.canSaveHole)
                .accessibilityLabel(Text(courseMapViewModel.saveHoleActionAccessibilityLabel))

                if let saveHoleHelpText = courseMapViewModel.saveHoleHelpText {
                    Text(saveHoleHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var scoreAdjustmentControls: some View {
        if courseMapViewModel.selectedHoleScore != nil {
            HStack(spacing: BigForeDesign.Spacing.small) {
                Button("Decrease score", systemImage: "minus") {
                    courseMapViewModel.decrementSelectedHoleScore(modelContext: modelContext)
                }
                .labelStyle(.iconOnly)
                .disabled(!courseMapViewModel.canDecreaseSelectedHoleScore)

                Text(courseMapViewModel.selectedHoleScoreValueText)
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .frame(minWidth: 36)
                    .accessibilityLabel("Hole score")
                    .accessibilityValue(courseMapViewModel.selectedHoleScoreValueText == "-" ? "Not scored" : "\(courseMapViewModel.selectedHoleScoreValueText) strokes")

                Button("Increase score", systemImage: "plus") {
                    courseMapViewModel.incrementSelectedHoleScore(modelContext: modelContext)
                }
                .labelStyle(.iconOnly)
                .disabled(!courseMapViewModel.canIncreaseSelectedHoleScore)
            }
            .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
            .controlSize(.regular)
        }
    }
}
