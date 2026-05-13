import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ScorecardViewModel {
    var round: GolfRound
    var errorMessage: String?
    private let scoring = RoundScoring()
    private let geometryStrategy: CourseGeometryStrategy

    init(round: GolfRound, geometryStrategy: CourseGeometryStrategy = CourseGeometryStrategy()) {
        self.round = round
        self.geometryStrategy = geometryStrategy
    }

    var players: [RoundPlayer] {
        scoring.sortedPlayers(for: round)
    }

    var availableHoles: [Int] {
        players.first.map { scoring.sortedScores(for: $0).map(\.holeNumber) } ?? Array(1...18)
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

    var currentHoleSummary: String {
        guard let currentHoleScore else {
            return "Hole \(round.currentHole)"
        }

        var details = ["Par \(currentHoleScore.par)"]
        if let yardage = currentHoleScore.yardage {
            details.append("\(yardage) yds")
        }
        if let handicap = currentHoleScore.handicap {
            details.append("HCP \(handicap)")
        }

        return "Hole \(round.currentHole) · \(details.joined(separator: " · "))"
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

    func relativeText(_ value: Int) -> String {
        scoring.relativeText(value)
    }

    var courseGeometryNotice: String {
        geometryStrategy.currentLimitationsNotice
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
}
