import SwiftUI

struct ScorecardPlayerHoleScoreRow: View {
    @Bindable var player: RoundPlayer
    @Bindable var score: HoleScore
    let scoringMode: ScoringMode
    let result: ScorecardScoreResult?
    let isSelected: Bool
    let selectPlayer: () -> Void
    let saveScore: () -> Void
    /// When non-`nil`, **long-press** the player card (~0.65s) to remove them (used where list swipe isn’t available).
    var onRequestDelete: (() -> Void)?
    private let scoring = RoundScoring()
    @State private var isEditingName = false
    @State private var isManualScoreEntryPresented = false
    @State private var isQuickScorePopoverPresented = false
    @State private var manualScoreText = ""
    @State private var strokeDragSnapIndex: Int = 0
    @State private var strokeDragTranslationY: CGFloat = 0
    @State private var strokeDidApplyQuantizedSteps: Bool = false
    @State private var puttsDragSnapIndex: Int = 0
    @State private var puttsDragTranslationY: CGFloat = 0
    @FocusState private var isNameFieldFocused: Bool
    @FocusState private var isManualScoreFieldFocused: Bool

    var body: some View {
        Group {
            if let delete = onRequestDelete {
                playerCardChrome
                    .contentShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
                    .onLongPressGesture(minimumDuration: 0.65) {
                        delete()
                    }
                    .accessibilityHint("Long-press this card to remove this player from the round.")
            } else {
                playerCardChrome
            }
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
    }

    /// Glass card + border.
    private var playerCardChrome: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            playerCardHeader

            scoringAndTeeRow
        }
        .padding(BigForeDesign.Spacing.medium)
        .bigForeScorecardGlassCardBackground(
            cornerRadius: BigForeDesign.Radius.card,
            dropShadow: true,
            nestedInScorecardShell: true
        )
        .clipShape(RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: BigForeDesign.Radius.card, style: .continuous)
                .strokeBorder(
                    isSelected ? Color.white.opacity(0.52) : Color.white.opacity(0.14),
                    lineWidth: isSelected ? 2 : 1
                )
        }
        .tint(isSelected ? .white : nil)
        .frame(minHeight: 56)
    }

    private var playerCardHeader: some View {
        HStack(alignment: .center, spacing: BigForeDesign.Spacing.small) {
            playerNameEditor

            holeResultCaption
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            if score.strokes > 0 {
                Text(secondaryScoreText)
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectPlayer()
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Select \(player.name)")
    }

    private var scoringAndTeeRow: some View {
        HStack(alignment: .top, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .top, spacing: BigForeDesign.Spacing.small) {
                VStack(spacing: 5) {
                    strokeDragSquare
                    Text("Score")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 44)

                VStack(spacing: 5) {
                    puttsDragSquare
                        .overlay(alignment: .topTrailing) {
                            CBadge(
                                title: "Score & putts",
                                message: scoringBoxesHelpMessage,
                                tint: .secondary,
                                accessibilityHint: "Shows how to enter strokes and putts.",
                                layoutOffset: .zero,
                                placement: .cornerPinned
                            )
                            /// Ring sits **outside** the putts rect (superscript); values tuned for 40×40 square + 14pt ring.
                            .offset(x: 14, y: -14)
                        }
                    Text("Putts")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .frame(width: 40)
            }
            .padding(.leading, 20)
            .padding(.vertical, 2)

            teeShotAccessory
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: -12)
        }
    }

    @ViewBuilder
    private var teeShotAccessory: some View {
        if score.isFairwayTrackingAvailable {
            teeShotChipPanel
        } else {
            Text("Par 3 — tee mark off")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 6)
        }
    }

    private var teeShotChipPanel: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text("Tee shot")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.35)

            HStack(spacing: 3) {
                teeShotChip(nil, shortLabel: "None", systemImage: "circle.slash")
                teeShotChip(.left, shortLabel: "Left", systemImage: "arrow.left")
                teeShotChip(.fairway, shortLabel: "Fair", systemImage: "target")
                teeShotChip(.right, shortLabel: "Right", systemImage: "arrow.right")
                teeShotChip(.bunker, shortLabel: "Bunk", systemImage: "beach.umbrella")
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(isSelected ? 0.14 : 0.07))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(isSelected ? 0.22 : 0.11), lineWidth: 1)
                    }
            }
        }
    }

    private func teeShotChip(_ value: TeeShotAccuracy?, shortLabel: String, systemImage: String) -> some View {
        let selected: Bool = {
            switch (value, score.teeShotAccuracy) {
            case (nil, nil):
                return true
            case let (.some(expected), .some(actual)):
                return expected == actual
            default:
                return false
            }
        }()

        return Button {
            selectPlayer()
            score.teeShotAccuracy = value
            saveScore()
        } label: {
            VStack(spacing: 1) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(shortLabel)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 30, height: 34)
        }
        .buttonStyle(BigForePillButtonStyle.bigForeToggle(isSelected: selected, metrics: .chip))
        .accessibilityLabel("\(shortLabel) tee result")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var strokeDragSquare: some View {
        let side: CGFloat = 44
        let step: CGFloat = 22
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.38), lineWidth: 1)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.primary.opacity(isSelected ? 0.12 : 0.05))
                }

            if abs(strokeDragTranslationY) > 6 {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Capsule()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 3, height: side * 0.45)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
            }

            Text(score.strokes == 0 ? "—" : "\(score.strokes)")
                .font(.title3.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: side, height: side)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .highPriorityGesture(strokeDragGesture(step: step))
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                selectPlayer()
                manualScoreText = score.strokes == 0 ? "" : "\(score.strokes)"
                isManualScoreEntryPresented = true
            }
        )
        .popover(isPresented: $isQuickScorePopoverPresented) {
            quickScorePopover
                .presentationCompactAdaptation(.popover)
        }
        .accessibilityLabel("Strokes")
        .accessibilityValue(score.strokes == 0 ? "Not scored" : "\(score.strokes)")
        .accessibilityHint("Drag up or down to change. Tap for quick score.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                adjustScore(by: 1)
            case .decrement:
                adjustScore(by: -1)
            default:
                break
            }
        }
    }

    private var puttsDragSquare: some View {
        let side: CGFloat = 40
        let step: CGFloat = 18
        return ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.32), lineWidth: 1)
                .background {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Color.primary.opacity(isSelected ? 0.1 : 0.04))
                }

            if abs(puttsDragTranslationY) > 5 {
                VStack(spacing: 2) {
                    Image(systemName: "chevron.up")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Capsule()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 3, height: side * 0.42)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .allowsHitTesting(false)
            }

            Text(score.putts.map(String.init) ?? "—")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: side, height: side)
        .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .highPriorityGesture(puttsDragGesture(step: step))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Putts")
        .accessibilityValue(score.putts.map { "\($0)" } ?? "Not set")
        .accessibilityHint("Drag up or down to change putts.")
        .accessibilityAdjustableAction { direction in
            guard score.strokes > 0 else {
                return
            }

            switch direction {
            case .increment:
                adjustPutts(by: 1)
            case .decrement:
                adjustPutts(by: -1)
            default:
                break
            }
        }
    }

    private var scoringBoxesHelpMessage: String {
        var body = """
        Both boxes use the same vertical drag gesture.

        Score: drag up to add strokes, drag down to subtract. Tap the Score box (without dragging much) for the quick score popover. Double-tap the Score box to type strokes manually.

        Putts: drag up or down on the Putts box the same way. Enter a score for the hole first. Putts stay between 0 and the score you entered.
        """
        if onRequestDelete != nil {
            body += """

            Reorder players using the lines on the left of each row. To remove this player from the round, long-press their card for about a second, then confirm in the dialog.
            """
        }
        return body
    }

    private func strokeDragGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                strokeDragTranslationY = value.translation.height
                let q = Int(floor(-value.translation.height / step))
                if q != strokeDragSnapIndex {
                    let delta = q - strokeDragSnapIndex
                    strokeDragSnapIndex = q
                    if delta != 0 {
                        strokeDidApplyQuantizedSteps = true
                        selectPlayer()
                        updateScore(score.strokes + delta)
                        saveScore()
                    }
                }
            }
            .onEnded { value in
                strokeDragTranslationY = 0
                let dragDistance = hypot(value.translation.width, value.translation.height)
                let wasTap = dragDistance < 12 && !strokeDidApplyQuantizedSteps
                strokeDragSnapIndex = 0
                strokeDidApplyQuantizedSteps = false
                if wasTap {
                    selectPlayer()
                    isQuickScorePopoverPresented = true
                }
            }
    }

    private func puttsDragGesture(step: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard score.strokes > 0 else {
                    return
                }

                puttsDragTranslationY = value.translation.height
                let q = Int(floor(-value.translation.height / step))
                if q != puttsDragSnapIndex {
                    let delta = q - puttsDragSnapIndex
                    puttsDragSnapIndex = q
                    selectPlayer()
                    let current = score.putts ?? min(2, score.strokes)
                    let next = min(max(current + delta, 0), score.strokes)
                    score.putts = next
                    saveScore()
                }
            }
            .onEnded { _ in
                puttsDragTranslationY = 0
                puttsDragSnapIndex = 0
            }
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
                .foregroundStyle(isSelected ? Color.white : .primary)
                .padding(.horizontal, isSelected ? BigForeDesign.Spacing.small : 0)
                .padding(.vertical, isSelected ? BigForeDesign.Spacing.xSmall : 0)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.22))
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

    @ViewBuilder
    private var holeResultCaption: some View {
        if score.strokes == 0 {
            HStack(spacing: 0) {
                Text("Hole \(score.holeNumber) - ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Not scored")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        } else if let result {
            HStack(spacing: 0) {
                Text("Hole \(score.holeNumber) - ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(result.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(result.tint)
            }
        } else {
            EmptyView()
        }
    }

    private var quickScorePopover: some View {
        ScorecardQuickScoreOrbClockPicker(
            title: "Hole \(score.holeNumber) Quick Score - Par \(score.par)",
            score: score,
            onPick: { option in
                updateScore(score.par + option.relativeToPar)
                saveScore()
                isQuickScorePopoverPresented = false
            }
        )
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

