import SwiftUI

struct PlayStatGrid: View {
    let round: GolfRound
    let viewModel: PlayHomeViewModel

    var body: some View {
        Grid(horizontalSpacing: BigForeDesign.Spacing.medium, verticalSpacing: BigForeDesign.Spacing.medium) {
            GridRow {
                PlayStatTile(
                    title: "Current",
                    value: viewModel.currentHoleTitle(for: round),
                    detail: viewModel.currentHoleDetail(for: round),
                    systemImage: "flag.fill"
                )
                PlayStatTile(
                    title: "Scoring",
                    value: round.scoringMode.title,
                    detail: viewModel.roundSetupText(for: round),
                    systemImage: "list.number"
                )
            }
            GridRow {
                PlayStatTile(
                    title: "Players",
                    value: viewModel.playerSummary(for: round),
                    detail: viewModel.scoreStatusText(for: round),
                    systemImage: "person.2.fill"
                )
                PlayStatTile(
                    title: "GPS",
                    value: viewModel.gpsStatusText(for: round),
                    detail: CourseMapPoint(round: round) == nil ? "Set course pin" : "Map ready",
                    systemImage: "location.fill"
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

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
        .padding(BigForeDesign.Spacing.medium)
        .background(BigForeDesign.Palette.primaryAction.opacity(0.08), in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
