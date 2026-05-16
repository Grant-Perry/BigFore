import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class BagViewModel {
    var statusMessage: String?
    var errorMessage: String?

    func seedDefaultBagIfNeeded(existingClubs: [GolfClub], modelContext: ModelContext) {
        guard existingClubs.isEmpty else {
            return
        }

        for template in GolfClubTemplate.defaultBag {
            modelContext.insert(GolfClub(template: template))
        }

        save(modelContext: modelContext, successMessage: "Loaded Woody's starter bag.")
    }

    func addClub(from template: GolfClubTemplate, modelContext: ModelContext) {
        let club = GolfClub(template: template)
        club.updatedAt = .now
        modelContext.insert(club)
        save(modelContext: modelContext, successMessage: "Added \(template.name). Woody will use it when it is active.")
    }

    func addSpecialClub(name: String, carryYards: Int, modelContext: ModelContext) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            errorMessage = "Enter a club name before saving."
            return false
        }

        let club = GolfClub(
            kind: .other,
            name: trimmed,
            carryYards: carryYards,
            totalYards: carryYards + GolfClub.rolloutBeyondCarry(for: .other),
            displayOrder: 0,
            isActive: true
        )
        modelContext.insert(club)
        save(modelContext: modelContext, successMessage: "Added \(trimmed). Woody will use it when it is active.")
        return errorMessage == nil
    }

    func deleteClub(_ club: GolfClub, modelContext: ModelContext) {
        modelContext.delete(club)
        save(modelContext: modelContext, successMessage: "Removed \(club.name).")
    }

    func save(modelContext: ModelContext, successMessage: String? = nil) {
        do {
            try modelContext.save()
            statusMessage = successMessage
            errorMessage = nil
        } catch {
            modelContext.rollback()
            errorMessage = "Could not save bag: \(error.localizedDescription)"
        }
    }
}
