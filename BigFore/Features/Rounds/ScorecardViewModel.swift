import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ScorecardViewModel {
    var round: GolfRound
    var errorMessage: String?
    var focusedPlayerID: UUID?
    /// `true` = hole squares show stroke counts (**#** on the toggle); `false` = vs par / Stableford (**+** on the toggle).
    var scorecardGridShowsStrokeCounts = true
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

    struct PrimaryScorecardHeaderCounts: Equatable {
        let thisNine: String
        let total: String
    }

    /// Stroke totals for the scorecard headline: **Front** or **Back** (visible nine) and **Round** (full round strokes), independent of the + / # grid mode.
    func primaryPlayerHeaderCounts(for nine: ScorecardNine) -> PrimaryScorecardHeaderCounts? {
        guard let primaryPlayer else {
            return nil
        }

        let nineSummary = nineSummary(for: nine)
        let thisNine = nineSummary.strokes.map(String.init) ?? "—"
        let strokesTotal = scoring.totalStrokes(for: primaryPlayer)
        let total = strokesTotal > 0 ? "\(strokesTotal)" : "—"
        return PrimaryScorecardHeaderCounts(thisNine: thisNine, total: total)
    }

    var scoreEntryPlayers: [RoundPlayer] {
        players
    }

    func selectPlayer(_ playerID: UUID, modelContext: ModelContext) {
        focusedPlayerID = playerID
        syncDisplayedRoundTeeFromFocusedPlayer()
        save(modelContext: modelContext)
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
        let templatePlayer = players.first
        let inheritedTeeName: String = {
            guard let templatePlayer else { return round.teeName }
            let trimmed = templatePlayer.teeName.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? round.teeName : templatePlayer.teeName
        }()
        let inheritedTeeGender: String = {
            guard let templatePlayer else { return round.teeGender }
            let trimmed = templatePlayer.teeGender.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? round.teeGender : templatePlayer.teeGender
        }()
        let newPlayer = RoundPlayer(
            name: trimmedName,
            displayOrder: players.count,
            teeName: inheritedTeeName,
            teeGender: inheritedTeeGender,
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
        syncDisplayedRoundTeeFromFocusedPlayer()
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

        syncDisplayedRoundTeeFromFocusedPlayer()
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
        guard let hole = adjacentHole(from: round.currentHole, offset: 1) else {
            return "Finish"
        }
        return "#\(hole) Tee Box"
    }

    /// Left navigation pill when moving to the prior hole’s tee.
    var previousTeeBoxButtonTitle: String {
        guard let hole = adjacentHole(from: round.currentHole, offset: -1) else {
            return "— Tee Box"
        }
        return "#\(hole) Tee Box"
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
        let stablefordPointsTotal: Int? = {
            guard round.scoringMode == .stableford, !scored.isEmpty else { return nil }
            return scored.reduce(0) { $0 + scoring.stablefordPoints(for: $1) }
        }()

        return ScorecardNineSummary(
            strokes: strokes,
            par: par,
            yards: yards > 0 ? yards : nil,
            relativeToPar: relativeToPar,
            stablefordPointsTotal: stablefordPointsTotal
        )
    }

    /// Square label for the primary player’s hole cell (`#` strokes vs `+` / Stableford points).
    func primaryHoleSquareDisplay(forHoleNumber holeNumber: Int, showStrokes: Bool) -> (text: String, result: ScorecardScoreResult?) {
        guard let score = primaryScore(forHoleNumber: holeNumber) else {
            return ("—", nil)
        }

        let result = scoreResult(for: score)

        if showStrokes {
            guard score.strokes > 0 else { return ("—", result) }
            return ("\(score.strokes)", result)
        }

        if round.scoringMode == .stableford {
            guard score.strokes > 0 else { return ("—", result) }
            return ("\(stablefordPoints(for: score))", result)
        }

        let text = relativeScoreText(forHoleNumber: holeNumber) ?? "—"
        return (text, result)
    }

    /// Square label for the IN/OUT totals row.
    func nineTotalSquareDisplay(for nine: ScorecardNine, showStrokes: Bool) -> (text: String, result: ScorecardScoreResult?) {
        let summary = nineSummary(for: nine)
        let result = summary.relativeToPar.flatMap { ScorecardScoreResult(relativeToPar: $0) }

        if showStrokes {
            return (summary.scoreText, result)
        }

        if round.scoringMode == .stableford {
            let text = summary.stablefordPointsTotal.map(String.init) ?? "—"
            return (text, result)
        }

        let text = summary.relativeToPar.map { relativeText($0) } ?? "—"
        return (text, result)
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

    /// Marks the round finished from the venue header (any hole). Idempotent if already complete.
    func markRoundComplete(modelContext: ModelContext) {
        guard !round.isComplete else {
            return
        }

        round.completedAt = .now
        save(modelContext: modelContext)
    }

    /// Reasons the scorecard isn’t “full” — empty means safe to complete without extra warnings.
    func roundCompletionAssessment() -> RoundCompletionAssessment {
        var issues: [String] = []

        if players.isEmpty {
            issues.append("This round has no players.")
        }

        for player in players {
            let scores = scoring.sortedScores(for: player)

            for hole in availableHoles {
                guard let score = scores.first(where: { $0.holeNumber == hole }) else {
                    issues.append("\(player.name): no score row for hole #\(hole).")
                    continue
                }

                if score.strokes == 0 {
                    issues.append("\(player.name): hole #\(hole) has no score entered.")
                }
            }
        }

        return RoundCompletionAssessment(issues: issues)
    }

    /// Multi-line copy for the complete-round confirmation dialog.
    func completeRoundConfirmationMessage(assessment: RoundCompletionAssessment) -> String {
        if assessment.isReadyToComplete {
            return """
            This marks the round as finished. You can still open it from Rounds.

            Are you certain you want to complete now?
            """
        }

        let bullets = assessment.issues.map { "• \($0)" }.joined(separator: "\n")
        return """
        Are you certain? The round isn’t fully scored yet:

        \(bullets)

        You can go back and enter missing scores, or complete anyway and keep the round as-is.
        """
    }

    struct RoundCompletionAssessment: Equatable {
        let issues: [String]
        var isReadyToComplete: Bool { issues.isEmpty }
    }

    func applySavedTee(_ tee: GolfCourseTee, modelContext: ModelContext, for player: RoundPlayer? = nil) {
        guard let target = player ?? primaryPlayer else {
            return
        }

        target.teeName = tee.name
        target.teeGender = tee.gender

        let holesByNumber = tee.holes.reduce(into: [Int: GolfCourseHole]()) { dict, hole in
            dict[hole.number] = hole
        }

        for score in target.scores {
            guard let hole = holesByNumber[score.holeNumber] else {
                continue
            }

            score.par = hole.par ?? score.par
            score.yardage = hole.yardage
            score.handicap = hole.handicap

            let par = hole.par ?? 4
            if par < 4 {
                score.teeShotAccuracy = .notApplicable
            } else if score.teeShotAccuracy == .notApplicable {
                score.teeShotAccuracy = nil
            }
        }

        syncDisplayedRoundTeeFromFocusedPlayer()
        save(modelContext: modelContext)
    }

    private func syncDisplayedRoundTeeFromFocusedPlayer() {
        guard let player = primaryPlayer else {
            return
        }

        round.teeName = player.resolvedTeeName(in: round)
        round.teeGender = player.resolvedTeeGender(in: round)
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
