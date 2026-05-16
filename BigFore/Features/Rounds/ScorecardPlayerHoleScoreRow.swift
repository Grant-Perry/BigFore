import SwiftUI

struct ScorecardPlayerHoleScoreRow: View {
    @Bindable var player: RoundPlayer
    @Bindable var score: HoleScore
    let scoringMode: ScoringMode
    let result: ScorecardScoreResult?
    let isSelected: Bool
    let selectPlayer: () -> Void
    let saveScore: () -> Void
    private let scoring = RoundScoring()
    @State private var isEditingName = false
    @State private var isManualScoreEntryPresented = false
    @State private var isQuickScorePopoverPresented = false
    @State private var manualScoreText = ""
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isManualScoreFieldFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: BigForeDesign.Spacing.medium) {
            VStack(alignment: .leading, spacing: BigForeDesign.Spacing.small) {
                playerNameEditor

                ScorecardScoreResultPill(
                    result: result,
                    fallbackText: score.strokes == 0 ? "Not scored" : secondaryScoreText
                )

                if score.strokes > 0 {
                    Text(secondaryScoreText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: BigForeDesign.Spacing.medium)

            VStack(alignment: .trailing, spacing: BigForeDesign.Spacing.small) {
                HStack(spacing: BigForeDesign.Spacing.small) {
                    Button("Decrease \(player.name)", systemImage: "minus") {
                        adjustScore(by: -1)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(score.strokes <= 0)

                    Button {
                        selectPlayer()
                        isQuickScorePopoverPresented = true
                    } label: {
                        Text(score.strokes == 0 ? "—" : "\(score.strokes)")
                            .font(.title2.bold())
                            .monospacedDigit()
                            .frame(minWidth: 38)
                            .accessibilityLabel("Strokes")
                            .accessibilityValue(score.strokes == 0 ? "Not scored" : "\(score.strokes)")
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $isQuickScorePopoverPresented) {
                        quickScorePopover
                            .presentationCompactAdaptation(.popover)
                    }

                    Button("Increase \(player.name)", systemImage: "plus") {
                        adjustScore(by: 1)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(score.strokes >= 12)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)

                HStack(spacing: BigForeDesign.Spacing.small) {
                    Text("Putts")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Button("Decrease \(player.name) putts", systemImage: "minus") {
                        adjustPutts(by: -1)
                    }
                    .labelStyle(.iconOnly)
                    .disabled((score.putts ?? 0) <= 0)

                    Text(score.putts.map(String.init) ?? "—")
                        .font(.caption.weight(.bold))
                        .monospacedDigit()
                        .frame(minWidth: 24)

                    Button("Increase \(player.name) putts", systemImage: "plus") {
                        adjustPutts(by: 1)
                    }
                    .labelStyle(.iconOnly)
                    .disabled(score.strokes <= 0 || (score.putts ?? 0) >= score.strokes)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                VStack(alignment: .leading, spacing: BigForeDesign.Spacing.xSmall) {
                    Text("Tee result")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Tee result", selection: teeShotAccuracyBinding) {
                        Text("Not set").tag(TeeShotAccuracy?.none)
                        Text("Fairway").tag(Optional(TeeShotAccuracy.fairway))
                        Text("Left").tag(Optional(TeeShotAccuracy.left))
                        Text("Right").tag(Optional(TeeShotAccuracy.right))
                        Text("Bunker").tag(Optional(TeeShotAccuracy.bunker))
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: score.teeShotAccuracy) { _, _ in
                        selectPlayer()
                        saveScore()
                    }
                }
            }
            .frame(width: 210)
            .padding(.horizontal, BigForeDesign.Spacing.medium)
            .padding(.vertical, BigForeDesign.Spacing.small)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                        .fill(BigForeDesign.Palette.primaryAction.opacity(0.22))
                }
            }
            .tint(isSelected ? BigForeDesign.Palette.primaryAction : nil)
            .onTapGesture(count: 2) {
                selectPlayer()
                manualScoreText = score.strokes == 0 ? "" : "\(score.strokes)"
                isManualScoreEntryPresented = true
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectPlayer()
        }
        .alert("Enter Score", isPresented: $isManualScoreEntryPresented) {
            TextField("Strokes", text: $manualScoreText)
                .keyboardType(.numberPad)
                .focused($isManualScoreFieldFocused)
            Button("Save", action: saveManualScore)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter strokes for \(player.name).")
        }
        .onChange(of: isManualScoreEntryPresented) { _, isPresented in
            if isPresented {
                Task { @MainActor in
                    await Task.yield()
                    isManualScoreFieldFocused = true
                }
            } else {
                isManualScoreFieldFocused = false
            }
        }
        .frame(minHeight: 60)
    }

    @ViewBuilder
    private var playerNameEditor: some View {
        if isEditingName {
            TextField("Player name", text: $player.name)
                .font(.headline)
                .textFieldStyle(.roundedBorder)
                .focused($isNameFieldFocused)
                .submitLabel(.done)
                .onSubmit(finishNameEditing)
                .onAppear {
                    isNameFieldFocused = true
                }
                .onChange(of: isNameFieldFocused) { _, isFocused in
                    if !isFocused {
                        finishNameEditing()
                    }
                }
        } else {
            Text(player.name)
                .font(.headline)
                .lineLimit(1)
                .foregroundStyle(isSelected ? BigForeDesign.Palette.primaryAction : .primary)
                .padding(.horizontal, isSelected ? BigForeDesign.Spacing.small : 0)
                .padding(.vertical, isSelected ? BigForeDesign.Spacing.xSmall : 0)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(BigForeDesign.Palette.primaryAction.opacity(0.22))
                    }
                }
                .onTapGesture(count: 2) {
                    isEditingName = true
                }
                .accessibilityHint("Double tap to edit player name.")
        }
    }

    private func finishNameEditing() {
        isEditingName = false
        saveScore()
    }

    private func saveManualScore() {
        guard let strokes = Int(manualScoreText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        selectPlayer()
        updateScore(strokes)
        saveScore()
    }

    private var secondaryScoreText: String {
        if scoringMode == .stableford {
            return "\(scoring.stablefordPoints(for: score)) points"
        }

        guard let relative = scoring.scoreRelativeToPar(for: score) else {
            return "Not scored"
        }

        return scoring.relativeText(relative)
    }

    private var teeShotAccuracyBinding: Binding<TeeShotAccuracy?> {
        Binding(
            get: { score.teeShotAccuracy },
            set: { score.teeShotAccuracy = $0 }
        )
    }

    private var quickScorePopover: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            Text("Hole \(score.holeNumber) Quick Score - Par \(score.par)")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BigForeDesign.Spacing.small) {
                ForEach(ScorecardQuickScoreOption.allCases) { option in
                    Button {
                        updateScore(score.par + option.relativeToPar)
                        saveScore()
                        isQuickScorePopoverPresented = false
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

    private func adjustScore(by delta: Int) {
        selectPlayer()
        updateScore(score.strokes + delta)
        saveScore()
    }

    private func adjustPutts(by delta: Int) {
        selectPlayer()
        guard score.strokes > 0 else {
            return
        }

        score.putts = min(max((score.putts ?? 0) + delta, 0), score.strokes)
        saveScore()
    }

    private func updateScore(_ strokes: Int) {
        score.strokes = min(max(strokes, 0), 12)
        if score.strokes == 0 {
            score.putts = nil
            return
        }

        if score.putts == nil {
            score.putts = min(2, score.strokes)
        } else if let putts = score.putts, putts > score.strokes {
            score.putts = score.strokes
        }
    }
}

