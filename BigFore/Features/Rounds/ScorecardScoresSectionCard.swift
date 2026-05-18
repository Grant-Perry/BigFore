import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ScorecardScoresSectionCard: View {
    let viewModel: ScorecardViewModel
    let modelContext: ModelContext
    let saveScore: () -> Void
    @State private var newPlayerName = ""
    @State private var playerPendingDeletion: RoundPlayer?
    @State private var draggingPlayerID: UUID?
    @State private var dropTargetIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: BigForeDesign.Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                Text("Scores")
                    .font(.headline)

                Spacer()

                Text(viewModel.currentHoleScoreStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if viewModel.players.count > 1 {
                Text("Use the lines on the left to reorder. Long-press a player card to remove them from the round.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: BigForeDesign.Spacing.medium) {
                let players = viewModel.scoreEntryPlayers
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    insertionDropZone(at: index)

                    if let score = viewModel.sortedScores(for: player).first(where: { $0.holeNumber == viewModel.round.currentHole }) {
                        let showReorderHandle = viewModel.players.count > 1
                        HStack(alignment: .center, spacing: BigForeDesign.Spacing.small) {
                            if showReorderHandle {
                                Image(systemName: "line.3.horizontal")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 28, height: 44)
                                    .contentShape(Rectangle())
                                    .accessibilityLabel("Drag to reorder players")
                                    .onDrag {
                                        draggingPlayerID = player.id
                                        return NSItemProvider(object: player.id.uuidString as NSString)
                                    }
                            }

                            ScorecardPlayerHoleScoreRow(
                                player: player,
                                score: score,
                                scoringMode: viewModel.round.scoringMode,
                                result: viewModel.scoreResult(for: score),
                                isSelected: player.id == viewModel.primaryPlayer?.id,
                                selectPlayer: {
                                    viewModel.selectPlayer(player.id, modelContext: modelContext)
                                },
                                saveScore: saveScore,
                                onRequestDelete: showReorderHandle
                                    ? { playerPendingDeletion = player }
                                    : nil
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: ScorecardPlayerInsertionDropDelegate(
                                targetIndex: index,
                                draggingPlayerID: $draggingPlayerID,
                                dropTargetIndex: $dropTargetIndex,
                                movePlayerToIndex: { movingID, targetIndex in
                                    viewModel.movePlayer(movingID, to: targetIndex, modelContext: modelContext)
                                }
                            )
                        )
                    }
                }

                insertionDropZone(at: players.count)
            }

            addPlayerControls
        }
        .padding(BigForeDesign.Spacing.large)
        .scorecardCardBackground()
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
                    viewModel.deletePlayer(playerPendingDeletion, modelContext: modelContext)
                    self.playerPendingDeletion = nil
                }
            }
            Button("Cancel", role: .cancel) {
                playerPendingDeletion = nil
            }
        } message: {
            Text("This removes the player and all of their scores from this round. This can’t be undone.")
        }
    }

    private var addPlayerControls: some View {
        HStack(spacing: BigForeDesign.Spacing.small) {
            TextField("Add player", text: $newPlayerName)
                .submitLabel(.done)
                .onSubmit(addPlayer)

            Button("Add", action: addPlayer)
                .buttonStyle(BigForePillButtonStyle.bigForeSecondary)
                .disabled(!canAddPlayer)
        }
    }

    private var canAddPlayer: Bool {
        viewModel.canAddPlayer && !newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func addPlayer() {
        guard canAddPlayer else {
            return
        }

        viewModel.addPlayer(named: newPlayerName, modelContext: modelContext)
        newPlayerName = ""
    }

    private func insertionDropZone(at index: Int) -> some View {
        ZStack {
            if dropTargetIndex == index {
                HStack(spacing: BigForeDesign.Spacing.small) {
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(height: 4)
                    Text("Drop here")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .transition(.opacity)
            } else {
                Color.clear
            }
        }
        .frame(height: 18)
        .contentShape(Rectangle())
        .onDrop(
            of: [UTType.text],
            delegate: ScorecardPlayerInsertionDropDelegate(
                targetIndex: index,
                draggingPlayerID: $draggingPlayerID,
                dropTargetIndex: $dropTargetIndex,
                movePlayerToIndex: { movingID, targetIndex in
                    viewModel.movePlayer(movingID, to: targetIndex, modelContext: modelContext)
                }
            )
        )
    }
}

private struct ScorecardPlayerInsertionDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggingPlayerID: UUID?
    @Binding var dropTargetIndex: Int?
    let movePlayerToIndex: (UUID, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard draggingPlayerID != nil else {
            return
        }

        withAnimation(.snappy) {
            dropTargetIndex = targetIndex
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            draggingPlayerID = nil
            dropTargetIndex = nil
        }

        guard let draggingPlayerID else {
            return false
        }

        withAnimation(.snappy) {
            movePlayerToIndex(draggingPlayerID, targetIndex)
        }
        return true
    }

    func dropExited(info: DropInfo) {
        if dropTargetIndex == targetIndex {
            dropTargetIndex = nil
        }
    }
}
