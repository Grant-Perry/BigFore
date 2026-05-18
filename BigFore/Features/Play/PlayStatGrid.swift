import SwiftUI

struct PlayStatGrid: View {
    let round: GolfRound
    let playHomeViewModel: PlayHomeViewModel
    let onSelectPlayerScorecard: (UUID) -> Void

    var body: some View {
        Grid(horizontalSpacing: BigForeDesign.Spacing.medium, verticalSpacing: BigForeDesign.Spacing.small) {
            GridRow {
                PlayStatTile(
                    title: "Current",
                    value: playHomeViewModel.currentHoleTitle(for: round),
                    detail: playHomeViewModel.currentHoleDetail(for: round),
                    systemImage: "flag.fill"
                )
                PlayStatTile(
                    title: "Scoring",
                    value: round.scoringMode.title,
                    detail: playHomeViewModel.roundSetupText(for: round),
                    systemImage: "list.number"
                )
            }
            GridRow {
                PlayPlayerScoresTile(
                    round: round,
                    playerCount: playHomeViewModel.playerCount(for: round),
                    scoreSummaries: playHomeViewModel.playerScoreSummaries(for: round),
                    onSelectPlayerScorecard: onSelectPlayerScorecard
                )
                PlayStatTile(
                    title: playHomeViewModel.gpsTitleText(for: round),
                    value: playHomeViewModel.gpsStatusText(for: round),
                    detail: playHomeViewModel.gpsDetailText(for: round),
                    systemImage: "location.fill",
                    valueColor: playHomeViewModel.isGPSReady(for: round) ? BigForeDesign.Palette.primaryAction : BigForeDesign.Palette.destructive
                )
            }
        }
    }
}

private struct PlayStatTile: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    var valueColor: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(BigForeDesign.Spacing.medium)
        .playStatCardBackground()
        .accessibilityElement(children: .combine)
    }
}

private struct PlayPlayerScoresTile: View {
    let round: GolfRound
    let playerCount: Int
    let scoreSummaries: [PlayPlayerScoreSummary]
    let onSelectPlayerScorecard: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Players - \(playerCount)", systemImage: "person.2.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.vertical) {
                VStack(spacing: 3) {
                    ForEach(scoreSummaries) { summary in
                        Button {
                            onSelectPlayerScorecard(summary.id)
                        } label: {
                            PlayPlayerScoreRow(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 46)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(BigForeDesign.Spacing.medium)
        .playStatCardBackground()
        .accessibilityElement(children: .combine)
    }
}

private struct PlayPlayerScoreRow: View {
    let summary: PlayPlayerScoreSummary

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Text(summary.name)
                .frame(maxWidth: .infinity, alignment: .trailing)
            Text("\(summary.score) - \(summary.completedHoles)")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension View {
    func playStatCardBackground() -> some View {
        background {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                .fill(Color(.systemBackground).opacity(BigForeDesign.AerialGlass.statTileFillOpacity))
                .overlay {
                    RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                        .stroke(BigForeDesign.Palette.primaryAction.opacity(0.30), lineWidth: 1)
                }
        }
    }
}
