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

            VStack(spacing: BigForeDesign.Spacing.small) {
                let players = viewModel.scoreEntryPlayers
                ForEach(Array(players.enumerated()), id: \.element.id) { index, player in
                    insertionDropZone(at: index)

                    if let score = viewModel.sortedScores(for: player).first(where: { $0.holeNumber == viewModel.round.currentHole }) {
                        ScorecardPlayerHoleScoreRow(
                            player: player,
                            score: score,
                            scoringMode: viewModel.round.scoringMode,
                            result: viewModel.scoreResult(for: score),
                            isSelected: player.id == viewModel.primaryPlayer?.id,
                            selectPlayer: {
                                viewModel.selectPlayer(player.id)
                            },
                            saveScore: saveScore
                        )
                        .opacity(draggingPlayerID == player.id ? 0.55 : 1)
                        .onDrag {
                            draggingPlayerID = player.id
                            return NSItemProvider(object: player.id.uuidString as NSString)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                playerPendingDeletion = player
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .disabled(viewModel.players.count <= 1)
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

                        if player.id != players.last?.id {
                            Divider()
                        }
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
                .buttonStyle(.bordered)
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
                        .fill(BigForeDesign.Palette.primaryAction)
                        .frame(height: 4)
                    Text("Drop here")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BigForeDesign.Palette.primaryAction)
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
