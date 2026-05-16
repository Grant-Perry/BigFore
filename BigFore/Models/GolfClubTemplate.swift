import Foundation

struct GolfClubTemplate: Identifiable, Equatable, Sendable {
    let id: String
    let kind: GolfClubKind
    let name: String
    let carryYards: Int
    let totalYards: Int
    let displayOrder: Int

    init(kind: GolfClubKind, name: String, carryYards: Int, totalYards: Int, displayOrder: Int) {
        self.id = "\(displayOrder)-\(name)"
        self.kind = kind
        self.name = name
        self.carryYards = carryYards
        self.totalYards = totalYards
        self.displayOrder = displayOrder
    }
}

extension GolfClubTemplate {
    static let defaultBag: [GolfClubTemplate] = [
        GolfClubTemplate(kind: .driver, name: "Driver", carryYards: 245, totalYards: 260, displayOrder: 0),
        GolfClubTemplate(kind: .fairwayWood, name: "3 Wood", carryYards: 220, totalYards: 235, displayOrder: 1),
        GolfClubTemplate(kind: .fairwayWood, name: "5 Wood", carryYards: 200, totalYards: 215, displayOrder: 2),
        GolfClubTemplate(kind: .hybrid, name: "4 Hybrid", carryYards: 190, totalYards: 200, displayOrder: 3),
        GolfClubTemplate(kind: .iron, name: "5 Iron", carryYards: 175, totalYards: 185, displayOrder: 4),
        GolfClubTemplate(kind: .iron, name: "6 Iron", carryYards: 165, totalYards: 172, displayOrder: 5),
        GolfClubTemplate(kind: .iron, name: "7 Iron", carryYards: 155, totalYards: 160, displayOrder: 6),
        GolfClubTemplate(kind: .iron, name: "8 Iron", carryYards: 145, totalYards: 150, displayOrder: 7),
        GolfClubTemplate(kind: .iron, name: "9 Iron", carryYards: 135, totalYards: 140, displayOrder: 8),
        GolfClubTemplate(kind: .wedge, name: "PW", carryYards: 120, totalYards: 125, displayOrder: 9),
        GolfClubTemplate(kind: .wedge, name: "GW", carryYards: 105, totalYards: 110, displayOrder: 10),
        GolfClubTemplate(kind: .wedge, name: "SW", carryYards: 85, totalYards: 90, displayOrder: 11),
        GolfClubTemplate(kind: .wedge, name: "LW", carryYards: 65, totalYards: 70, displayOrder: 12),
        GolfClubTemplate(kind: .putter, name: "Putter", carryYards: 0, totalYards: 0, displayOrder: 13)
    ]

    /// Extra clubs not in the starter bag; `displayOrder` is only used for sorting candidates before assigning a bag slot.
    static let optionalBagCatalog: [GolfClubTemplate] = [
        GolfClubTemplate(kind: .fairwayWood, name: "2 Wood", carryYards: 230, totalYards: 245, displayOrder: 50),
        GolfClubTemplate(kind: .fairwayWood, name: "4 Wood", carryYards: 210, totalYards: 225, displayOrder: 51),
        GolfClubTemplate(kind: .fairwayWood, name: "7 Wood", carryYards: 185, totalYards: 200, displayOrder: 52),
        GolfClubTemplate(kind: .fairwayWood, name: "9 Wood", carryYards: 170, totalYards: 185, displayOrder: 53),
        GolfClubTemplate(kind: .hybrid, name: "2 Hybrid", carryYards: 215, totalYards: 230, displayOrder: 60),
        GolfClubTemplate(kind: .hybrid, name: "3 Hybrid", carryYards: 205, totalYards: 220, displayOrder: 61),
        GolfClubTemplate(kind: .hybrid, name: "5 Hybrid", carryYards: 180, totalYards: 195, displayOrder: 62),
        GolfClubTemplate(kind: .hybrid, name: "6 Hybrid", carryYards: 170, totalYards: 185, displayOrder: 63),
        GolfClubTemplate(kind: .iron, name: "2 Iron", carryYards: 195, totalYards: 210, displayOrder: 70),
        GolfClubTemplate(kind: .iron, name: "3 Iron", carryYards: 185, totalYards: 200, displayOrder: 71),
        GolfClubTemplate(kind: .iron, name: "4 Iron", carryYards: 180, totalYards: 195, displayOrder: 72),
        GolfClubTemplate(kind: .wedge, name: "AW", carryYards: 115, totalYards: 130, displayOrder: 80),
        GolfClubTemplate(kind: .wedge, name: "52° Wedge", carryYards: 100, totalYards: 115, displayOrder: 81),
        GolfClubTemplate(kind: .wedge, name: "56° Wedge", carryYards: 90, totalYards: 105, displayOrder: 82),
        GolfClubTemplate(kind: .wedge, name: "60° Wedge", carryYards: 75, totalYards: 90, displayOrder: 83),
        GolfClubTemplate(kind: .driver, name: "Mini Driver", carryYards: 235, totalYards: 250, displayOrder: 90),
        GolfClubTemplate(kind: .other, name: "Driving Iron", carryYards: 200, totalYards: 215, displayOrder: 91)
    ]

    /// Unique catalog entries (starter + optional), stable order: starter first, then optional sorted by carry descending.
    static func fullBagCatalog() -> [GolfClubTemplate] {
        var seen = Set<String>()
        var merged: [GolfClubTemplate] = []
        for template in defaultBag + optionalBagCatalog.sorted(by: { $0.carryYards > $1.carryYards }) {
            let key = template.name.normalizedForBagCatalogKey
            if seen.insert(key).inserted {
                merged.append(template)
            }
        }
        return merged
    }

    /// Clubs from the catalog that are not already represented in the bag (matched by normalized club name).
    static func templatesAvailableToAdd(to clubs: [GolfClub]) -> [GolfClubTemplate] {
        let existing = Set(clubs.map(\.name.normalizedForBagCatalogKey))
        return fullBagCatalog()
            .filter { existing.contains($0.name.normalizedForBagCatalogKey) == false }
            .sorted { lhs, rhs in
                if lhs.carryYards != rhs.carryYards {
                    return lhs.carryYards > rhs.carryYards
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
    }

    /// Catalog clubs not in the bag whose default carry falls strictly between the two carries (for gap-fill suggestions).
    static func templatesSuggestedForCarryGap(longerCarryYards: Int, shorterCarryYards: Int, existingClubs: [GolfClub]) -> [GolfClubTemplate] {
        templatesAvailableToAdd(to: existingClubs).filter { template in
            template.carryYards < longerCarryYards && template.carryYards > shorterCarryYards
        }
        .sorted { lhs, rhs in
            if lhs.carryYards != rhs.carryYards {
                return lhs.carryYards > rhs.carryYards
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

private extension String {
    var normalizedForBagCatalogKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
