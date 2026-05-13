import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StartRoundViewModel {
    let course: RoundSetupCourse
    let tee: RoundSetupTee
    var scoringMode = ScoringMode.strokePlay
    var playerNames = ["Gp."]
    var newPlayerName = ""
    var createdRound: GolfRound?
    var errorMessage: String?
    private let roundBuilder: RoundBuilder

    init(course: RoundSetupCourse, tee: RoundSetupTee, roundBuilder: RoundBuilder = RoundBuilder()) {
        self.course = course
        self.tee = tee
        self.roundBuilder = roundBuilder
    }

    convenience init(course: GolfCourseAPICourse, tee: GolfCourseAPITeeBox) {
        self.init(course: RoundSetupCourse(apiCourse: course), tee: RoundSetupTee(apiTee: tee))
    }

    convenience init(savedCourse: GolfCourse, tee: GolfCourseTee) {
        self.init(course: RoundSetupCourse(savedCourse: savedCourse), tee: RoundSetupTee(savedTee: tee))
    }

    var trimmedPlayerNames: [String] {
        playerNames.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    var canAddPlayer: Bool {
        !newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && playerNames.count < 8
    }

    var canStartRound: Bool {
        !trimmedPlayerNames.isEmpty && !tee.holes.isEmpty
    }

    func addPlayer() {
        guard canAddPlayer else { return }
        playerNames.append(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines))
        newPlayerName = ""
    }

    func removePlayers(at offsets: IndexSet) {
        for offset in offsets.sorted(by: >) {
            playerNames.remove(at: offset)
        }

        if playerNames.isEmpty {
            playerNames = ["Gp."]
        }
    }

    func startRound(modelContext: ModelContext) {
        errorMessage = nil

        let round = roundBuilder.makeRound(
            course: course,
            tee: tee,
            scoringMode: scoringMode,
            playerNames: trimmedPlayerNames
        )

        modelContext.insert(round)

        do {
            try modelContext.save()
            createdRound = round
        } catch {
            modelContext.rollback()
            errorMessage = "Could not start round: \(error.localizedDescription)"
        }
    }
}
