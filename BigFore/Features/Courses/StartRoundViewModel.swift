import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class StartRoundViewModel {
    let course: RoundSetupCourse
    let tee: RoundSetupTee
    var scoringMode = ScoringMode.strokePlay
    var playerNames = ["Player"]
    var newPlayerName = ""
    var createdRound: GolfRound?
    var errorMessage: String?
    private let roundBuilder: RoundBuilder
    private var primaryPlayerProfile: PlayerProfile?

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

    func configurePrimaryPlayer(_ profile: PlayerProfile?) {
        primaryPlayerProfile = profile
        guard let profile else {
            if trimmedPlayerNames.isEmpty {
                playerNames = ["Player"]
            }
            return
        }

        if playerNames.count == 1 && ["Player", "Gp."].contains(playerNames[0]) {
            playerNames[0] = profile.displayName
        }
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
            playerNames = [primaryPlayerProfile?.displayName ?? "Player"]
        }
    }

    func startRound(modelContext: ModelContext) {
        errorMessage = nil

        let round = roundBuilder.makeRound(
            course: course,
            tee: tee,
            scoringMode: scoringMode,
            playerNames: trimmedPlayerNames,
            primaryPlayerProfile: primaryPlayerProfile
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
