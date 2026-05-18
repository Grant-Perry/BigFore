import SwiftUI

struct ScorecardHoleSectionCard: View {
    @Bindable var viewModel: ScorecardViewModel
    let selectHole: (Int) -> Void
    let setQuickScore: ([Int], Int) -> Void
    let onTeeSelected: (GolfCourseTee) -> Void
    @State private var selectedNine: ScorecardNine = .front
    @State private var quickScoreHoleNumber: Int?
    @State private var isStackScoringEnabled = false
    @State private var stackedHoleNumbers: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .top, spacing: BigForeDesign.Spacing.medium) {
                VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
                    HStack(alignment: .center, spacing: BigForeDesign.Spacing.small) {
                        Text("Scorecard - \(viewModel.primaryPlayerName)")
                            .font(.headline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(viewModel.round.scoringMode.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)

                            CBadge(
                                title: "Scorecard",
                                message: scorecardHelpMessage,
                                tint: .secondary,
                                layoutOffset: CGSize(width: 0, height: -5)
                            )
                        }

                        if let player = viewModel.primaryPlayer {
                            ScorecardPlayerTeeControl(player: player, round: viewModel.round, onTeeSelected: onTeeSelected)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }

                    ScorecardNinePageControl(
                        nines: viewModel.scorecardNines,
                        selectedNine: $selectedNine,
                        gridShowsStrokeCounts: $viewModel.scorecardGridShowsStrokeCounts,
                        stackScoringEnabled: $isStackScoringEnabled,
                        scoringMode: viewModel.round.scoringMode,
                        stackSelectionCount: stackedHoleNumbers.count,
                        clearStackSelection: {
                            stackedHoleNumbers = [viewModel.round.currentHole]
                        }
                    )
                    .padding(.top, 10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let counts = viewModel.primaryPlayerHeaderCounts(for: selectedNine) {
                    VStack(alignment: .trailing, spacing: 3) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(selectedNine.shortSwitcherTitle)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(counts.thisNine)
                                .font(.system(size: 22, weight: .heavy))
                                .monospacedDigit()
                                .kerning(-0.6)
                                .foregroundStyle(.white)
                                .opacity(0.55)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("Round")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(counts.total)
                                .font(.system(size: 22, weight: .heavy))
                                .monospacedDigit()
                                .kerning(-0.6)
                                .foregroundStyle(Color.gpGreen)
                                .opacity(0.4)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .shadow(color: .black.opacity(0.92), radius: 0, x: 0, y: 2)
                    .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 0)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(selectedNine.shortSwitcherTitle) nine, \(counts.thisNine) strokes, Round \(counts.total)")
                }
            }

            TabView(selection: $selectedNine) {
                ForEach(viewModel.scorecardNines) { nine in
                    ScorecardNineGridPage(
                        nine: nine,
                        viewModel: viewModel,
                        gridShowsStrokes: $viewModel.scorecardGridShowsStrokeCounts,
                        stackedHoleNumbers: stackedHoleNumbers,
                        selectHole: { holeNumber in
                            if isStackScoringEnabled {
                                toggleStackedHole(holeNumber)
                            } else {
                                selectHole(holeNumber)
                            }
                        },
                        showQuickScore: { holeNumber in
                            if isStackScoringEnabled {
                                stackedHoleNumbers.insert(holeNumber)
                            } else {
                                selectHole(holeNumber)
                            }
                            quickScoreHoleNumber = holeNumber
                        }
                    )
                    .tag(nine)
                }
            }
            .frame(height: 136)
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
        .onChange(of: isStackScoringEnabled) { _, isEnabled in
            if isEnabled {
                stackedHoleNumbers = [viewModel.round.currentHole]
            } else {
                stackedHoleNumbers.removeAll()
            }
        }
        .onAppear(perform: syncSelectedNine)
        .onChange(of: viewModel.round.currentHole) { _, _ in
            syncSelectedNine()
        }
        .popover(isPresented: Binding(
            get: { quickScoreHoleNumber != nil },
            set: { isPresented in
                if !isPresented {
                    quickScoreHoleNumber = nil
                }
            }
        )) {
            if let quickScoreHoleNumber,
               let score = viewModel.primaryScore(forHoleNumber: quickScoreHoleNumber) {
                quickScorePopover(score: score)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private var scorecardHelpMessage: String {
        let plusExplained: String = {
            switch viewModel.round.scoringMode {
            case .strokePlay:
                "versus par"
            case .stableford:
                "Stableford points"
            }
        }()

        return """
        Swipe the grid for Front or Back. Tap a column to pick that hole.

        The # key shows stroke counts in the squares. + shows \(plusExplained).

        Front or Back and Round show stroke totals (not the + / # grid mode).

        Stack mode: turn on Stack, tap holes to select several, then tap a selected score to apply one quick score to all selected holes.
        """
    }

    private func syncSelectedNine() {
        selectedNine = ScorecardNine.containing(viewModel.round.currentHole)
    }

    private func toggleStackedHole(_ holeNumber: Int) {
        if stackedHoleNumbers.contains(holeNumber) {
            stackedHoleNumbers.remove(holeNumber)
        } else {
            stackedHoleNumbers.insert(holeNumber)
        }

        if stackedHoleNumbers.isEmpty {
            stackedHoleNumbers.insert(holeNumber)
        }
    }

    private func quickScorePopover(score: HoleScore) -> some View {
        ScorecardQuickScoreOrbClockPicker(
            title: quickScoreTitle(for: score),
            score: score,
            onPick: { option in
                setQuickScore(quickScoreHoleNumbers(fallback: score.holeNumber), option.relativeToPar)
                quickScoreHoleNumber = nil
            }
        )
    }

    private func quickScoreTitle(for score: HoleScore) -> String {
        let selectedHoles = quickScoreHoleNumbers(fallback: score.holeNumber)
        if selectedHoles.count > 1 {
            return "\(selectedHoles.count) Holes Quick Score"
        }

        return "Hole \(score.holeNumber) Quick Score - Par \(score.par)"
    }

    private func quickScoreHoleNumbers(fallback holeNumber: Int) -> [Int] {
        guard isStackScoringEnabled else {
            return [holeNumber]
        }

        let holes = stackedHoleNumbers.isEmpty ? [holeNumber] : stackedHoleNumbers
        return holes.sorted()
    }
}
