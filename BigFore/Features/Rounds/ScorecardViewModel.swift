import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ScorecardViewModel {
    var round: GolfRound
    var errorMessage: String?
    var focusedPlayerID: UUID?
    private let scoring = RoundScoring()

    init(round: GolfRound, focusedPlayerID: UUID? = nil) {
        self.round = round
        self.focusedPlayerID = focusedPlayerID
    }

    var players: [RoundPlayer] {
        scoring.sortedPlayers(for: round)
    }

    var primaryPlayer: RoundPlayer? {
        guard let focusedPlayerID else {
            return players.first
        }

        return players.first { $0.id == focusedPlayerID } ?? players.first
    }

    var primaryPlayerName: String {
        primaryPlayer?.name ?? "Player"
    }

    var primaryPlayerScoreSummaryText: String? {
        guard let primaryPlayer else {
            return nil
        }

        return "\(scoring.summary(for: primaryPlayer, scoringMode: round.scoringMode)) - \(scoring.completedHoles(for: primaryPlayer))"
    }

    var primaryPlayerScoreText: String? {
        guard let primaryPlayer else {
            return nil
        }

        return scoring.summary(for: primaryPlayer, scoringMode: round.scoringMode)
    }

    var scoreEntryPlayers: [RoundPlayer] {
        players
    }

    func selectPlayer(_ playerID: UUID) {
        focusedPlayerID = playerID
    }

    var canAddPlayer: Bool {
        players.count < 8
    }

    func addPlayer(named name: String, modelContext: ModelContext) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, canAddPlayer else {
            return
        }

        let scoreTemplates = players.first.map(scoring.sortedScores(for:)) ?? []
        let newPlayer = RoundPlayer(
            name: trimmedName,
            displayOrder: players.count,
            scores: scoreTemplates.map { score in
                HoleScore(
                    holeNumber: score.holeNumber,
                    par: score.par,
                    yardage: score.yardage,
                    handicap: score.handicap,
                    teeShotAccuracy: score.isFairwayTrackingAvailable ? nil : .notApplicable
                )
            }
        )
        newPlayer.round = round
        round.players.append(newPlayer)
        focusedPlayerID = newPlayer.id
        reindexPlayers(round.players.sorted { $0.displayOrder < $1.displayOrder })
        save(modelContext: modelContext)
    }

    func deletePlayer(_ player: RoundPlayer, modelContext: ModelContext) {
        guard players.count > 1 else {
            errorMessage = "A round needs at least one player."
            return
        }

        round.players.removeAll { $0.id == player.id }
        modelContext.delete(player)
        let orderedPlayers = round.players.sorted { $0.displayOrder < $1.displayOrder }
        reindexPlayers(orderedPlayers)

        if focusedPlayerID == player.id {
            focusedPlayerID = orderedPlayers.first?.id
        }

        save(modelContext: modelContext)
    }

    func movePlayer(_ movingPlayerID: UUID, to targetIndex: Int, modelContext: ModelContext) {
        guard targetIndex >= 0,
              let movingPlayer = players.first(where: { $0.id == movingPlayerID }) else {
            return
        }

        var orderedPlayers = players.filter { $0.id != movingPlayerID }
        let boundedIndex = min(targetIndex, orderedPlayers.count)
        orderedPlayers.insert(movingPlayer, at: boundedIndex)
        round.players = orderedPlayers
        reindexPlayers(orderedPlayers)
        save(modelContext: modelContext)
    }

    var scorecardNines: [ScorecardNine] {
        ScorecardNine.allCases.filter { nine in
            !Set(availableHoles).isDisjoint(with: nine.holeNumbers)
        }
    }

    var availableHoles: [Int] {
        players.first.map { scoring.sortedScores(for: $0).map(\.holeNumber) } ?? Array(1...18)
    }

    var frontNineHoles: [Int] {
        availableHoles.filter { (1...9).contains($0) }
    }

    var backNineHoles: [Int] {
        availableHoles.filter { (10...18).contains($0) }
    }

    var frontNineSummaryText: String {
        summaryText(for: frontNineHoles)
    }

    var backNineSummaryText: String {
        summaryText(for: backNineHoles)
    }

    var roundSummaryText: String {
        summaryText(for: availableHoles)
    }

    var canMoveToPreviousHole: Bool {
        previousHoleNumber != nil
    }

    var canAdvanceHole: Bool {
        nextHoleNumber != nil || round.currentHole == availableHoles.last
    }

    var advanceButtonTitle: String {
        nextHoleNumber == nil ? "Finish" : "Next Hole"
    }

    var currentHoleScore: HoleScore? {
        players.first?.scores.first { $0.holeNumber == round.currentHole }
    }

    var currentHoleScoreStatusText: String {
        let scoredPlayers = players.filter { player in
            player.scores.contains { $0.holeNumber == round.currentHole && $0.strokes > 0 }
        }

        return "\(scoredPlayers.count) of \(players.count) players scored this hole"
    }

    func sortedScores(for player: RoundPlayer) -> [HoleScore] {
        scoring.sortedScores(for: player)
    }

    func selectHole(_ holeNumber: Int, modelContext: ModelContext) {
        guard availableHoles.contains(holeNumber) else {
            return
        }

        round.currentHole = holeNumber
        save(modelContext: modelContext)
    }

    func stablefordPoints(for player: RoundPlayer) -> Int {
        scoring.stablefordPoints(for: player)
    }

    func stablefordPoints(for score: HoleScore) -> Int {
        scoring.stablefordPoints(for: score)
    }

    func completedHoles(for player: RoundPlayer) -> Int {
        scoring.completedHoles(for: player)
    }

    func totalStrokes(for player: RoundPlayer) -> Int {
        scoring.totalStrokes(for: player)
    }

    func scoreRelativeToPar(for player: RoundPlayer) -> Int {
        scoring.scoreRelativeToPar(for: player)
    }

    func scoreRelativeToPar(for score: HoleScore) -> Int? {
        scoring.scoreRelativeToPar(for: score)
    }

    func scoreResult(for score: HoleScore) -> ScorecardScoreResult? {
        guard let relative = scoring.scoreRelativeToPar(for: score) else {
            return nil
        }

        return ScorecardScoreResult(relativeToPar: relative)
    }

    func scoreResult(forHoleNumber holeNumber: Int) -> ScorecardScoreResult? {
        guard let score = primaryScore(forHoleNumber: holeNumber) else {
            return nil
        }

        return scoreResult(for: score)
    }

    func setPrimaryScoreRelativeToPar(_ relativeToPar: Int, forHoleNumber holeNumber: Int, modelContext: ModelContext) {
        guard let score = primaryScore(forHoleNumber: holeNumber) else {
            return
        }

        updateScore(score, strokes: score.par + relativeToPar)
        save(modelContext: modelContext)
    }

    func setPrimaryScoreRelativeToPar(_ relativeToPar: Int, forHoleNumbers holeNumbers: [Int], modelContext: ModelContext) {
        for holeNumber in holeNumbers {
            guard let score = primaryScore(forHoleNumber: holeNumber) else {
                continue
            }

            updateScore(score, strokes: score.par + relativeToPar)
        }

        save(modelContext: modelContext)
    }

    func primaryScore(forHoleNumber holeNumber: Int) -> HoleScore? {
        primaryPlayer?.scores.first { $0.holeNumber == holeNumber }
    }

    func nineSummary(for nine: ScorecardNine) -> ScorecardNineSummary {
        let scores = primaryPlayer.map(scoring.sortedScores(for:)) ?? []
        let selectedScores = scores.filter { nine.holeNumbers.contains($0.holeNumber) }
        let scored = selectedScores.filter { $0.strokes > 0 }
        let strokes = scored.isEmpty ? nil : scored.reduce(0) { $0 + $1.strokes }
        let par = selectedScores.reduce(0) { $0 + $1.par }
        let yards = selectedScores.compactMap(\.yardage).reduce(0, +)
        let relativeToPar = strokes.map { $0 - scored.reduce(0) { $0 + $1.par } }

        return ScorecardNineSummary(
            strokes: strokes,
            par: par,
            yards: yards > 0 ? yards : nil,
            relativeToPar: relativeToPar
        )
    }

    func relativeScoreText(forHoleNumber holeNumber: Int) -> String? {
        guard let score = primaryScore(forHoleNumber: holeNumber),
              let relative = scoring.scoreRelativeToPar(for: score) else {
            return nil
        }

        return scoring.relativeText(relative)
    }

    func scoreStatusAccessibilityText(forHoleNumber holeNumber: Int) -> String {
        guard let score = primaryScore(forHoleNumber: holeNumber) else {
            return "Hole \(holeNumber), not scored"
        }

        if score.strokes == 0 {
            return "Hole \(holeNumber), not scored"
        }

        guard let result = scoreResult(for: score) else {
            return "Hole \(holeNumber), \(score.strokes) strokes"
        }

        let playerPrefix = players.first.map { "\($0.name), " } ?? ""
        return "Hole \(holeNumber), \(playerPrefix)\(score.strokes) strokes, \(result.title)"
    }

    func relativeText(_ value: Int) -> String {
        scoring.relativeText(value)
    }

    func moveToPreviousHole(modelContext: ModelContext) {
        guard let previousHoleNumber else {
            return
        }

        round.currentHole = previousHoleNumber
        save(modelContext: modelContext)
    }

    func advanceOrFinish(modelContext: ModelContext) {
        if let nextHoleNumber {
            round.currentHole = nextHoleNumber
        } else {
            round.completedAt = .now
        }
        save(modelContext: modelContext)
    }

    func save(modelContext: ModelContext) {
        errorMessage = nil

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = "Could not save scorecard: \(error.localizedDescription)"
        }
    }

    private var previousHoleNumber: Int? {
        adjacentHole(from: round.currentHole, offset: -1)
    }

    private var nextHoleNumber: Int? {
        adjacentHole(from: round.currentHole, offset: 1)
    }

    private func adjacentHole(from holeNumber: Int, offset: Int) -> Int? {
        guard let index = availableHoles.firstIndex(of: holeNumber) else {
            return nil
        }

        let limit = offset < 0 ? availableHoles.startIndex : availableHoles.index(before: availableHoles.endIndex)
        guard let adjacentIndex = availableHoles.index(index, offsetBy: offset, limitedBy: limit),
              adjacentIndex != index else {
            return nil
        }

        return availableHoles[adjacentIndex]
    }

    private func reindexPlayers(_ orderedPlayers: [RoundPlayer]) {
        for (index, player) in orderedPlayers.enumerated() {
            player.displayOrder = index
        }
    }

    private func updateScore(_ score: HoleScore, strokes: Int) {
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

    private func summaryText(for holeNumbers: [Int]) -> String {
        let scores = players.first.map(scoring.sortedScores(for:)) ?? []
        let selectedScores = scores.filter { holeNumbers.contains($0.holeNumber) }
        let parTotal = selectedScores.map(\.par).reduce(0, +)
        let yardsTotal = selectedScores.compactMap(\.yardage).reduce(0, +)

        if yardsTotal > 0 {
            return "Par \(parTotal) · \(yardsTotal) yds"
        }

        return "Par \(parTotal)"
    }
}
