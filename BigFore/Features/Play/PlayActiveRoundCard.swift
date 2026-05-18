import SwiftUI

struct PlayActiveRoundCard: View {
    let round: GolfRound
    let viewModel: PlayHomeViewModel
    let weatherSummary: WeatherSummary?
    let weatherErrorText: String?
    let onResume: () -> Void
    let onOpenGPS: () -> Void
    let onSelectPlayerScorecard: (UUID) -> Void

    private var mapPoint: CourseMapPoint? {
        CourseMapPoint(round: round)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.large) {
            header
            weatherContext
            PlayStatGrid(
                round: round,
                viewModel: viewModel,
                onSelectPlayerScorecard: onSelectPlayerScorecard
            )
            leaderSummary
            actions
            gpsMissingMessage
        }
        .padding(BigForeDesign.Spacing.large)
        .bigForeAerialGlassCardBackground(cornerRadius: BigForeDesign.Radius.panel, dropShadow: true)
        .overlay {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel, style: .continuous)
                .stroke(BigForeDesign.Palette.primaryAction.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var weatherContext: some View {
        if let weatherSummary {
            HStack(alignment: .center, spacing: BigForeDesign.Spacing.medium) {
                WeatherGlyph(symbolName: weatherSummary.symbolName, font: .title2)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if let conditionText = weatherSummary.conditionText {
                            Text(conditionText)
                                .font(.subheadline.weight(.semibold))
                        }
                        Text(weatherSummary.temperatureText)
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(.secondary)

                    if let windText = weatherSummary.windText {
                        Label(windText, systemImage: "wind")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        } else if let weatherErrorText {
            Label(weatherErrorText, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            HStack(alignment: .center) {
                Label("Active Round", systemImage: "figure.golf")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(BigForeDesign.Palette.primaryAction)
                    .textCase(.uppercase)

                Spacer()

                Text("Started: \(viewModel.roundDateText(for: round))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, BigForeDesign.Spacing.medium)
                    .padding(.vertical, BigForeDesign.Spacing.small)
                    .background(.secondary.opacity(0.12), in: Capsule())
            }

            Text(round.courseName)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.56)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.distanceText(for: round))
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var leaderSummary: some View {
        if let leaderSummary = viewModel.leaderSummary(for: round) {
            Label(leaderSummary, systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .accessibilityLabel(leaderSummary)
        }
    }

    private var actions: some View {
        HStack(alignment: .center, spacing: BigForeDesign.Spacing.medium) {
            Button(action: onResume) {
                HStack(spacing: 8) {
                    Image(systemName: "list.clipboard")
                        .symbolRenderingMode(.hierarchical)
                        .font(.subheadline.weight(.bold))
                    Text("Resume")
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, BigForeDesign.Spacing.large)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.gpGreen.opacity(0.95),
                                    Color.gpFlatGreen.opacity(0.92)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.gpGreen.opacity(0.35), radius: 8, x: 0, y: 3)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Resume round, scorecard")

            if mapPoint != nil {
                Button(action: onOpenGPS) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.viewfinder")
                            .font(.subheadline.weight(.bold))
                        Text("GPS")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(BigForeDesign.Palette.primaryAction)
                    .padding(.horizontal, BigForeDesign.Spacing.large)
                    .padding(.vertical, 12)
                    .background {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.primary.opacity(0.06))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(BigForeDesign.Palette.primaryAction.opacity(0.55), lineWidth: 1.5)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open GPS map")
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var gpsMissingMessage: some View {
        if mapPoint == nil {
            Label("Add a course pin from the saved course detail to enable GPS.", systemImage: "location.slash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
