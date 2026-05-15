import Foundation
import SwiftData

@Model
final class GolfClub {
    var id: UUID
    var kindRawValue: String
    var name: String
    var carryYards: Int
    var totalYards: Int
    var displayOrder: Int
    var isActive: Bool
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .nullify, inverse: \ShotRecord.club) var shotRecords: [ShotRecord]

    init(
        id: UUID = UUID(),
        kind: GolfClubKind,
        name: String,
        carryYards: Int,
        totalYards: Int,
        displayOrder: Int,
        isActive: Bool = true,
        notes: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        shotRecords: [ShotRecord] = []
    ) {
        self.id = id
        self.kindRawValue = kind.rawValue
        self.name = name
        self.carryYards = carryYards
        self.totalYards = totalYards
        self.displayOrder = displayOrder
        self.isActive = isActive
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.shotRecords = shotRecords
    }
}

extension GolfClub {
    var kind: GolfClubKind {
        get { GolfClubKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    convenience init(template: GolfClubTemplate) {
        self.init(
            kind: template.kind,
            name: template.name,
            carryYards: template.carryYards,
            totalYards: template.totalYards,
            displayOrder: template.displayOrder
        )
    }
}
