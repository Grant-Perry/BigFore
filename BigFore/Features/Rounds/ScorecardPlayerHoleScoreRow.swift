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

            Stepper(value: $score.strokes, in: 0...12) {
                Text(score.strokes == 0 ? "—" : "\(score.strokes)")
                    .font(.title2.bold())
                    .monospacedDigit()
                    .frame(minWidth: 34, alignment: .trailing)
                    .accessibilityLabel("Strokes")
                    .accessibilityValue(score.strokes == 0 ? "Not scored" : "\(score.strokes)")
            }
            .frame(maxWidth: 176)
            .padding(.horizontal, isSelected ? BigForeDesign.Spacing.small : 0)
            .padding(.vertical, isSelected ? BigForeDesign.Spacing.xSmall : 0)
            .background {
                if isSelected {
                    Capsule()
                        .fill(BigForeDesign.Palette.primaryAction.opacity(0.22))
                }
            }
            .tint(isSelected ? BigForeDesign.Palette.primaryAction : nil)
            .onTapGesture(count: 2) {
                selectPlayer()
                manualScoreText = score.strokes == 0 ? "" : "\(score.strokes)"
                isManualScoreEntryPresented = true
            }
            .onChange(of: score.strokes) { _, _ in
                selectPlayer()
                saveScore()
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
        score.strokes = min(max(strokes, 0), 12)
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
}
