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
}
