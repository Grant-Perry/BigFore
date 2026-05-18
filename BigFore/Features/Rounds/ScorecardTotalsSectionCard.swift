import SwiftUI

struct ScorecardTotalsSectionCard: View {
    let scorecardViewModel: ScorecardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            Text("Totals")
                .font(.headline)

            VStack(spacing: BigForeDesign.Spacing.medium) {
                ForEach(scorecardViewModel.players) { player in
                    ScorecardPlayerTotalRow(player: player, scoringMode: scorecardViewModel.round.scoringMode)

                    if player.id != scorecardViewModel.players.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
    }
}
