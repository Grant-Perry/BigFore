import SwiftUI

struct ScorecardTotalsSectionCard: View {
    let viewModel: ScorecardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            Text("Totals")
                .font(.headline)

            VStack(spacing: BigForeDesign.Spacing.medium) {
                ForEach(viewModel.players) { player in
                    ScorecardPlayerTotalRow(player: player, scoringMode: viewModel.round.scoringMode)

                    if player.id != viewModel.players.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
    }
}
