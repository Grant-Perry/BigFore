import Foundation
import SwiftData
import SwiftUI

struct CourseMapVenueChip: View {
    let viewModel: CourseMapViewModel

    var body: some View {
        Text(viewModel.course.courseName)
            .font(.headline.weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, BigForeDesign.Spacing.large)
            .padding(.vertical, BigForeDesign.Spacing.medium)
            .frame(maxWidth: 320)
            .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.capsulePanel)
            .accessibilityLabel("Course")
            .accessibilityValue(viewModel.course.courseName)
    }
}

struct CourseMapDistanceMetricStack: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    let activeGolfClubs: [GolfClub]
    @State private var isScoreSheetPresented = false

    var body: some View {
        VStack(alignment: .trailing, spacing: BigForeDesign.Spacing.small) {
            metricCard(title: "Hole", value: "\(viewModel.targetHoleNumber)", detail: viewModel.holeParText(for: viewModel.targetHoleNumber))

            if let scoringPlayerDetailText = viewModel.scoringPlayerDetailText {
                scoringCard(title: "Scoring", value: scoringPlayerDetailText)
            }

            if let teeDistanceText = viewModel.teeToHolePinDistanceText {
                metricCard(title: "Tee to pin", value: displayDistance(teeDistanceText))
            } else {
                metricCard(title: "Setup", value: "Set", detail: "Tee + pin")
            }

            if let shotToPinText = viewModel.shotLocationToHolePinDistanceText,
               viewModel.shotLocationToHolePinLabel != "Tee to pin" {
                metricCard(title: viewModel.shotLocationToHolePinLabel, value: displayDistance(shotToPinText))
            }

            if let shotDistanceText = viewModel.shotDistanceText {
                metricCard(
                    title: viewModel.isTrackingShot ? "Live shot" : "Shot distance",
                    value: displayDistance(shotDistanceText)
                )
            }

            if let recommendation = viewModel.clubRecommendation(from: activeGolfClubs) {
                woodyCard(recommendation)
            }
        }
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $isScoreSheetPresented) {
            CourseMapAllPlayersScoreSheet(viewModel: viewModel, modelContext: modelContext)
                .presentationDetents([.fraction(0.78), .large])
                .presentationContentInteraction(.scrolls)
                .presentationDragIndicator(.visible)
        }
    }

    private func scoringCard(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: BigForeDesign.Spacing.xSmall) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(value)
                    .font(.headline.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                if let resultText = viewModel.selectedHoleScoreResultText {
                    Text(resultText)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(viewModel.selectedHoleScoreResult?.tint ?? .secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isScoreSheetPresented = true
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Shows all player score controls.")

            HStack(spacing: BigForeDesign.Spacing.xSmall) {
                Button("Decrease score", systemImage: "minus") {
                    viewModel.decrementSelectedHoleScore(modelContext: modelContext)
                }
                .labelStyle(.iconOnly)
                .disabled(!viewModel.canDecreaseSelectedHoleScore)

                Text(viewModel.selectedHoleScoreValueText)
                    .font(.callout.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(viewModel.selectedHoleScoreResult?.tint ?? .primary)
                    .frame(minWidth: 24)
                    .accessibilityLabel("Current score")
                    .accessibilityValue(viewModel.selectedHoleScoreValueText == "-" ? "Not scored" : "\(viewModel.selectedHoleScoreValueText) strokes")

                Button("Increase score", systemImage: "plus") {
                    viewModel.incrementSelectedHoleScore(modelContext: modelContext)
                }
                .labelStyle(.iconOnly)
                .disabled(!viewModel.canIncreaseSelectedHoleScore)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.small)
        .frame(width: 136, alignment: .trailing)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.card, materialOpacity: 0.58)
    }

    private func metricCard(title: String, value: String, detail: String? = nil, width: CGFloat = 112) -> some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(value)
                .font(.headline.weight(.black))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.small)
        .frame(width: width, alignment: .trailing)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.card, materialOpacity: 0.58)
    }

    private func woodyCard(_ recommendation: CourseMapClubRecommendation) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("Woody thinks")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(recommendation.title.replacingOccurrences(of: "Woody says ", with: ""))
                .font(.headline.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(recommendation.distanceText)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(recommendation.detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
                .lineLimit(3)
        }
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.small)
        .frame(width: 156, alignment: .trailing)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.card, materialOpacity: 0.58)
    }

    private func displayDistance(_ distanceText: String) -> String {
        let components = distanceText.split(separator: " ")
        guard components.count == 2,
              components[1] == "yds",
              let yards = Int(components[0]),
              yards >= 1_760 else {
            return distanceText
        }

        let miles = Double(yards) / 1_760
        if miles > 1_000 {
            return "\(miles.rounded().formatted(.number.grouping(.automatic).precision(.fractionLength(0)))) mi"
        }

        return "\(miles.formatted(.number.grouping(.never).precision(.fractionLength(1)))) mi"
    }
}

private struct CourseMapAllPlayersScoreSheet: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Ball tracking stays with \(viewModel.selectedScoringPlayerName ?? "the selected player"). This sheet only edits scores.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Hole \(viewModel.targetHoleNumber) Scores") {
                    ForEach(viewModel.scoringPlayers) { player in
                        HStack(spacing: BigForeDesign.Spacing.medium) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(player.name)
                                    .font(.headline)
                                if let result = viewModel.scoreResult(for: player) {
                                    Text(result.title)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(result.tint)
                                } else {
                                    Text("Not scored")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            scoreStepper(for: player)
                        }
                    }
                }
            }
            .navigationTitle("Score Players")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func scoreStepper(for player: RoundPlayer) -> some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Button("Decrease \(player.name)", systemImage: "minus") {
                viewModel.decrementScore(for: player, modelContext: modelContext)
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canDecreaseScore(for: player))

            Text(viewModel.scoreValueText(for: player))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(viewModel.scoreResult(for: player)?.tint ?? .primary)
                .frame(minWidth: 30)

            Button("Increase \(player.name)", systemImage: "plus") {
                viewModel.incrementScore(for: player, modelContext: modelContext)
            }
            .labelStyle(.iconOnly)
            .disabled(!viewModel.canIncreaseScore(for: player))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }
}
