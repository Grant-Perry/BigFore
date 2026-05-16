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
    /// Rollout beyond carry used for an estimated total when we are not tracking measured rollout.
    static let rolloutBeyondCarryYards = 15

    static func rolloutBeyondCarry(for kind: GolfClubKind) -> Int {
        kind == .putter ? 0 : Self.rolloutBeyondCarryYards
    }

    /// Carry plus a fixed rollout estimate (putter stays zero).
    var estimatedTotalYards: Int {
        carryYards + Self.rolloutBeyondCarry(for: kind)
    }

    /// Keeps persisted `totalYards` aligned with the carry + rollout rule.
    func syncTotalYardsFromCarry() {
        totalYards = estimatedTotalYards
    }

    var kind: GolfClubKind {
        get { GolfClubKind(rawValue: kindRawValue) ?? .other }
        set { kindRawValue = newValue.rawValue }
    }

    convenience init(template: GolfClubTemplate) {
        let kind = template.kind
        let total: Int
        if kind == .putter {
            total = 0
        } else {
            total = template.carryYards + Self.rolloutBeyondCarryYards
        }
        self.init(
            kind: kind,
            name: template.name,
            carryYards: template.carryYards,
            totalYards: total,
            displayOrder: template.displayOrder
        )
    }

    /// Longest carry first, then name (bag list, Woody, and gap checks stay aligned).
    static func bagCarrySort(lhs: GolfClub, rhs: GolfClub) -> Bool {
        if lhs.carryYards != rhs.carryYards {
            return lhs.carryYards > rhs.carryYards
        }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
