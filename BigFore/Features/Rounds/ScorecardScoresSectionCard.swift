import SwiftUI

struct ScorecardScoresSectionCard: View {
    let viewModel: ScorecardViewModel
    let saveScore: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scores")
                    .font(.headline)

                Spacer()

                Text(viewModel.currentHoleScoreStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            VStack(spacing: BigForeDesign.Spacing.medium) {
                ForEach(viewModel.players) { player in
                    if let score = viewModel.sortedScores(for: player).first(where: { $0.holeNumber == viewModel.round.currentHole }) {
                        ScorecardPlayerHoleScoreRow(
                            playerName: player.name,
                            score: score,
                            scoringMode: viewModel.round.scoringMode,
                            result: viewModel.scoreResult(for: score),
                            saveScore: saveScore
                        )

                        if player.id != viewModel.players.last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
    }
}
