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
