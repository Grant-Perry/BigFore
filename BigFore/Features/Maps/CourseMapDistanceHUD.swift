import Foundation
import SwiftData
import SwiftUI

struct CourseMapVenueChip: View {
    let courseMapViewModel: CourseMapViewModel

    var body: some View {
        Text(courseMapViewModel.course.courseName)
            .font(.headline.weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, BigForeDesign.Spacing.large)
            .padding(.vertical, BigForeDesign.Spacing.medium)
            .frame(maxWidth: 320)
            .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.capsulePanel)
            .accessibilityLabel("Course")
            .accessibilityValue(courseMapViewModel.course.courseName)
    }
}

struct CourseMapDistanceMetricStack: View {
    let viewModel: CourseMapViewModel
    let modelContext: ModelContext
    let activeGolfClubs: [GolfClub]
    let courseGeometries: [CourseGeometry]
    @State private var isScoreSheetPresented = false
    @State private var isWoodyExpanded = false

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

            if let recommendation = viewModel.clubRecommendation(from: activeGolfClubs, geometries: courseGeometries) {
                woodyCard(recommendation)
            }
        }
        .accessibilityElement(children: .combine)
        .sheet(isPresented: $isScoreSheetPresented) {
            CourseMapAllPlayersScoreSheet(courseMapViewModel: viewModel, modelContext: modelContext)
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
        ZStack(alignment: .bottomLeading) {
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

                if isWoodyExpanded {
                    Text(recommendation.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Image(systemName: isWoodyExpanded ? "chevron.down" : "chevron.up")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, BigForeDesign.Spacing.medium)
        .padding(.vertical, BigForeDesign.Spacing.small)
        .frame(width: 156, alignment: .trailing)
        .bigForePanelBackground(cornerRadius: BigForeDesign.Radius.card, materialOpacity: 0.58)
        .contentShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        .onTapGesture {
            withAnimation(.snappy) {
                isWoodyExpanded.toggle()
            }
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isWoodyExpanded ? "Collapses Woody's advice." : "Expands Woody's advice.")
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
    let courseMapViewModel: CourseMapViewModel
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var playerForQuickScore: RoundPlayer?
    @State private var playerPendingDeletion: RoundPlayer?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Ball tracking stays with \(courseMapViewModel.selectedScoringPlayerName ?? "the selected player"). This sheet only edits scores.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Hole \(courseMapViewModel.targetHoleNumber) Scores - \(holeParText)") {
                    ForEach(courseMapViewModel.scoringPlayers) { player in
                        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
                            HStack(spacing: BigForeDesign.Spacing.medium) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(player.name)
                                        .font(.headline)
                                    if let result = courseMapViewModel.scoreResult(for: player) {
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
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playerForQuickScore = player
                            }
                            .popover(item: quickScoreBinding(for: player)) { player in
                                quickScorePopover(for: player)
                                    .presentationCompactAdaptation(.popover)
                            }

                            HStack {
                                Text("Putts")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                puttsStepper(for: player)
                            }

                            teeResultPicker(for: player)
                        }
                        .padding(.vertical, BigForeDesign.Spacing.xSmall)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                playerPendingDeletion = player
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(courseMapViewModel.scoringPlayers.count <= 1)
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
        .confirmationDialog(
            "Delete \(playerPendingDeletion?.name ?? "player")?",
            isPresented: Binding(
                get: { playerPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        playerPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let playerPendingDeletion {
                Button("Delete Player", role: .destructive) {
                    courseMapViewModel.deleteScoringPlayer(playerPendingDeletion, modelContext: modelContext)
                    self.playerPendingDeletion = nil
                }
            }

            Button("Cancel", role: .cancel) {
                playerPendingDeletion = nil
            }
        } message: {
            Text("This removes the player and all of their scores from this round. This can't be undone.")
        }
    }

    private func scoreStepper(for player: RoundPlayer) -> some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Button("Decrease \(player.name)", systemImage: "minus") {
                courseMapViewModel.decrementScore(for: player, modelContext: modelContext)
            }
            .labelStyle(.iconOnly)
            .disabled(!courseMapViewModel.canDecreaseScore(for: player))

            Text(courseMapViewModel.scoreValueText(for: player))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(courseMapViewModel.scoreResult(for: player)?.tint ?? .primary)
                .frame(minWidth: 30)

            Button("Increase \(player.name)", systemImage: "plus") {
                courseMapViewModel.incrementScore(for: player, modelContext: modelContext)
            }
            .labelStyle(.iconOnly)
            .disabled(!courseMapViewModel.canIncreaseScore(for: player))
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
    }

    private func puttsStepper(for player: RoundPlayer) -> some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Button("Decrease \(player.name) putts", systemImage: "minus") {
                courseMapViewModel.decrementPutts(for: player, modelContext: modelContext)
            }
            .labelStyle(.iconOnly)
            .disabled(!courseMapViewModel.canDecreasePutts(for: player))

            Text(courseMapViewModel.puttsValueText(for: player))
                .font(.headline.weight(.bold))
                .monospacedDigit()
                .frame(minWidth: 30)
                .accessibilityLabel("Putts")

            Button("Increase \(player.name) putts", systemImage: "plus") {
                courseMapViewModel.incrementPutts(for: player, modelContext: modelContext)
            }
            .labelStyle(.iconOnly)
            .disabled(!courseMapViewModel.canIncreasePutts(for: player))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func teeResultPicker(for player: RoundPlayer) -> some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
            Text("Tee result")
                .font(.subheadline.weight(.semibold))

            Picker("Tee result", selection: Binding(
                get: { courseMapViewModel.teeShotAccuracy(for: player) },
                set: { courseMapViewModel.setTeeShotAccuracy($0, for: player, modelContext: modelContext) }
            )) {
                Text("None")
                    .tag(nil as TeeShotAccuracy?)
                    .accessibilityLabel("Tee result, not set")
                Text("Fair")
                    .tag(Optional(TeeShotAccuracy.fairway))
                    .accessibilityLabel("Fairway")
                Text("Left")
                    .tag(Optional(TeeShotAccuracy.left))
                    .accessibilityLabel("Left of fairway")
                Text("Right")
                    .tag(Optional(TeeShotAccuracy.right))
                    .accessibilityLabel("Right of fairway")
                Text("Bunk")
                    .tag(Optional(TeeShotAccuracy.bunker))
                    .accessibilityLabel("Bunker")
            }
            .pickerStyle(.segmented)
        }
    }

    private var holeParText: String {
        guard let par = courseMapViewModel.selectedHoleScore?.par else {
            return "Par --"
        }

        return "Par \(par)"
    }

    private func quickScoreBinding(for player: RoundPlayer) -> Binding<RoundPlayer?> {
        Binding(
            get: {
                playerForQuickScore?.id == player.id ? playerForQuickScore : nil
            },
            set: { newValue in
                playerForQuickScore = newValue
            }
        )
    }

    private func quickScorePopover(for player: RoundPlayer) -> some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hole \(courseMapViewModel.targetHoleNumber) Quick Score - \(holeParText)")
                        .font(.headline)
                }

                Spacer()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BigForeDesign.Spacing.small) {
                ForEach(CourseMapQuickScoreOption.allCases) { option in
                    Button {
                        courseMapViewModel.setScoreRelativeToPar(option.relativeToPar, for: player, modelContext: modelContext)
                        playerForQuickScore = nil
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: option.systemImage)
                                    .font(.caption.bold())
                                Text(option.title)
                                    .font(.caption.weight(.bold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }

                            Text(option.scoreText(for: player, holeNumber: courseMapViewModel.targetHoleNumber))
                                .font(.title3.weight(.black))
                                .monospacedDigit()
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, BigForeDesign.Spacing.small)
                        .padding(.vertical, BigForeDesign.Spacing.small)
                        .background(option.color.gradient, in: RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(BigForeDesign.Spacing.medium)
        .frame(width: 320)
    }
}
private enum CourseMapQuickScoreOption: CaseIterable, Identifiable {
    case tripleBogey
    case doubleBogey
    case bogey
    case par
    case birdie
    case eagle
    case albatross

    var id: String { title }

    var title: String {
        switch self {
        case .tripleBogey:
            "Triple"
        case .doubleBogey:
            "Double"
        case .bogey:
            "Bogey"
        case .par:
            "Par"
        case .birdie:
            "Birdie"
        case .eagle:
            "Eagle"
        case .albatross:
            "Albatross"
        }
    }

    var relativeToPar: Int {
        switch self {
        case .tripleBogey:
            3
        case .doubleBogey:
            2
        case .bogey:
            1
        case .par:
            0
        case .birdie:
            -1
        case .eagle:
            -2
        case .albatross:
            -3
        }
    }

    var color: Color {
        ScorecardScoreResult(relativeToPar: relativeToPar).tint
    }

    var systemImage: String {
        ScorecardScoreResult(relativeToPar: relativeToPar).systemImage
    }

    func scoreText(for player: RoundPlayer, holeNumber: Int) -> String {
        guard let score = player.scores.first(where: { $0.holeNumber == holeNumber }) else {
            return "--"
        }

        return "\(max(score.par + relativeToPar, 1))"
    }
}
