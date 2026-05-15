import SwiftUI

struct PlayActiveRoundCard: View {
    let round: GolfRound
    let viewModel: PlayHomeViewModel
    let weatherSummary: WeatherSummary?
    let weatherErrorText: String?

    private var mapPoint: CourseMapPoint? {
        CourseMapPoint(round: round)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.large) {
            header
            weatherContext
            PlayStatGrid(round: round, viewModel: viewModel)
            leaderSummary
            actions
            gpsMissingMessage
        }
        .padding(BigForeDesign.Spacing.large)
        .background {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel, style: .continuous)
                .fill(.background)
                .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.panel, style: .continuous)
                .stroke(BigForeDesign.Palette.primaryAction.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var weatherContext: some View {
        if let weatherSummary {
            HStack(spacing: BigForeDesign.Spacing.medium) {
                Label(weatherSummary.temperatureText, systemImage: weatherSummary.symbolName)
                    .font(.subheadline.weight(.semibold))

                if let windText = weatherSummary.windText {
                    Label(windText, systemImage: "wind")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .foregroundStyle(.secondary)
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

                Text(viewModel.roundDateText(for: round))
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
        HStack(spacing: BigForeDesign.Spacing.medium) {
            NavigationLink {
                ScorecardView(round: round)
            } label: {
                Label("Resume", systemImage: "scorecard")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(BigForeDesign.Palette.primaryAction)

            if let mapPoint {
                NavigationLink {
                    CourseMapView(course: mapPoint, currentHoleNumber: round.currentHole, round: round)
                } label: {
                    Label("GPS", systemImage: "location.viewfinder")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(BigForeDesign.Palette.primaryAction)
            }
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
