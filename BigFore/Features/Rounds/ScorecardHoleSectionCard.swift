import SwiftUI

struct ScorecardHoleSectionCard: View {
    let viewModel: ScorecardViewModel
    let selectHole: (Int) -> Void
    let setQuickScore: ([Int], Int) -> Void
    @State private var selectedNine: ScorecardNine = .front
    @State private var quickScoreHoleNumber: Int?
    @State private var isStackScoringEnabled = false
    @State private var stackedHoleNumbers: Set<Int> = []

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                HStack(alignment: .firstTextBaseline, spacing: BigForeDesign.Spacing.small) {
                    Text("Scorecard - \(viewModel.primaryPlayerName)")
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    Text(viewModel.round.scoringMode.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                Spacer(minLength: BigForeDesign.Spacing.medium)

                if let scoreText = viewModel.primaryPlayerScoreText {
                    Text(scoreText)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(BigForeDesign.Palette.primaryAction)
                }
            }

            ScorecardNinePageControl(
                nines: viewModel.scorecardNines,
                selectedNine: $selectedNine
            )

            stackControls

            TabView(selection: $selectedNine) {
                ForEach(viewModel.scorecardNines) { nine in
                    ScorecardNineGridPage(
                        nine: nine,
                        viewModel: viewModel,
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
            .frame(height: 126)
            .tabViewStyle(.page(indexDisplayMode: .never))

            Text(isStackScoringEnabled ? "Stack scoring: tap holes to select several, then tap any selected score to apply one quick score." : "Swipe between nines. Tap a hole column to edit that hole.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
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

    private func syncSelectedNine() {
        selectedNine = ScorecardNine.containing(viewModel.round.currentHole)
    }

    private var stackControls: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            Toggle(isStackScoringEnabled ? "Stack On" : "Stack", isOn: $isStackScoringEnabled)
                .font(.caption.weight(.semibold))
                .toggleStyle(.button)
                .tint(isStackScoringEnabled ? BigForeDesign.Palette.primaryAction : .secondary)
                .onChange(of: isStackScoringEnabled) { _, isEnabled in
                    if isEnabled {
                        stackedHoleNumbers = [viewModel.round.currentHole]
                    } else {
                        stackedHoleNumbers.removeAll()
                    }
                }

            if isStackScoringEnabled {
                Text("\(stackedHoleNumbers.count) selected")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Button("Clear") {
                    stackedHoleNumbers = [viewModel.round.currentHole]
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(BigForeDesign.Palette.primaryAction)
            }

            Spacer()
        }
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
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            Text(quickScoreTitle(for: score))
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BigForeDesign.Spacing.small) {
                ForEach(ScorecardQuickScoreOption.allCases) { option in
                    Button {
                        setQuickScore(quickScoreHoleNumbers(fallback: score.holeNumber), option.relativeToPar)
                        quickScoreHoleNumber = nil
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

                            Text("\(max(score.par + option.relativeToPar, 1))")
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
