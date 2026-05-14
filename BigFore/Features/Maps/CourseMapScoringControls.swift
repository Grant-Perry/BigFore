import SwiftData
import SwiftUI

struct CourseMapScoringControls: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext

    var body: some View {
        @Bindable var viewModel = viewModel

        if viewModel.scoringPlayers.isEmpty == false {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                if viewModel.scoringPlayers.count > 1 {
                    Picker("Scoring player", selection: $viewModel.selectedScoringPlayerID) {
                        ForEach(viewModel.scoringPlayers) { player in
                            Text(player.name).tag(Optional(player.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: viewModel.selectedScoringPlayerID) {
                        viewModel.syncManualShotCountToScore(modelContext: modelContext)
                    }
                }

                if let manualShotScoreText = viewModel.manualShotScoreText {
                    Text(manualShotScoreText)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.saveCurrentHole(modelContext: modelContext)
                } label: {
                    Label(viewModel.saveHoleButtonTitle, systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(BigForeDesign.Palette.primaryAction)
                .controlSize(.large)
                .disabled(!viewModel.canSaveHole)
                .accessibilityLabel(Text(viewModel.saveHoleActionAccessibilityLabel))

                if let saveHoleHelpText = viewModel.saveHoleHelpText {
                    Text(saveHoleHelpText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
