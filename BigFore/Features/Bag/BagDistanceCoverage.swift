import Foundation

/// Read-only sanity check for whether active carry distances leave awkward gaps.
enum BagDistanceCoverage {
    enum Level {
        case ok
        case caution
    }

    struct Summary: Equatable {
        let level: Level
        let title: String
        let detail: String
    }

    /// Carry drop from the longer club to the next shorter club that counts as a “hole” in the bag ladder.
    static let carryGapHighlightThresholdYards = 30
    private static let tightClusterYards = 8

    private static func carryLadder(from clubs: [GolfClub]) -> [GolfClub] {
        clubs
            .filter(\.isActive)
            .filter { $0.kind != .putter && $0.carryYards > 0 }
            .sorted(by: GolfClub.bagCarrySort)
    }

    /// A wide step in the active carry ladder (long club above, shorter club below in the bag list).
    struct CarryGapCallout: Equatable, Identifiable {
        /// The shorter club in the pair (same id used for row highlight).
        var id: UUID { shorterClubID }
        let longerClubID: UUID
        let longerClubName: String
        let longerCarryYards: Int
        let shorterClubID: UUID
        let shorterClubName: String
        let shorterCarryYards: Int
        let gapYards: Int
    }

    /// IDs of the **shorter** club in each adjacent pair where carry drops by at least `carryGapHighlightThresholdYards`.
    static func clubIDsFollowingCarryGap(in clubs: [GolfClub]) -> Set<UUID> {
        Set(carryGapCallouts(in: clubs).map(\.shorterClubID))
    }

    /// One entry per wide gap: the club **below** the jump (e.g. 4 iron under 3 wood).
    static func carryGapCallouts(in clubs: [GolfClub]) -> [CarryGapCallout] {
        let ladder = carryLadder(from: clubs)
        var out: [CarryGapCallout] = []
        for pair in zip(ladder, ladder.dropFirst()) {
            let gap = pair.0.carryYards - pair.1.carryYards
            guard gap > Self.carryGapHighlightThresholdYards else {
                continue
            }
            out.append(
                CarryGapCallout(
                    longerClubID: pair.0.id,
                    longerClubName: pair.0.name,
                    longerCarryYards: pair.0.carryYards,
                    shorterClubID: pair.1.id,
                    shorterClubName: pair.1.name,
                    shorterCarryYards: pair.1.carryYards,
                    gapYards: gap
                )
            )
        }
        return out
    }

    static func summary(for clubs: [GolfClub]) -> Summary {
        let ladder = carryLadder(from: clubs)

        guard ladder.count >= 2 else {
            return Summary(
                level: .caution,
                title: "Distance ladder",
                detail: "Activate at least two clubs with carry yardages so Woody can spot gaps between clubs."
            )
        }

        var largestGap = 0
        var largestGapDescription = ""
        for pair in zip(ladder, ladder.dropFirst()) {
            let gap = pair.0.carryYards - pair.1.carryYards
            if gap > largestGap {
                largestGap = gap
                largestGapDescription = "\(pair.0.name) (\(pair.0.carryYards) yd) down to \(pair.1.name) (\(pair.1.carryYards) yd)"
            }
        }

        var tightPairDescription = ""
        for pair in zip(ladder, ladder.dropFirst()) {
            let gap = pair.0.carryYards - pair.1.carryYards
            if gap < Self.tightClusterYards {
                tightPairDescription = "\(pair.0.name) and \(pair.1.name) are only \(gap) yds apart on carry."
                break
            }
        }

        if largestGap > Self.carryGapHighlightThresholdYards {
            return Summary(
                level: .caution,
                title: "Wide gap in your bag",
                detail: "Largest spacing is \(largestGap) yds between \(largestGapDescription). Consider a club that fills that window."
            )
        }

        if tightPairDescription.isEmpty == false {
            return Summary(
                level: .caution,
                title: "Overlapping carries",
                detail: "\(tightPairDescription) Woody can still pick one, but separating them helps on the course."
            )
        }

        return Summary(
            level: .ok,
            title: "Carry ladder looks solid",
            detail: "Active clubs step down in reasonable chunks for full-shot coverage."
        )
    }
}
