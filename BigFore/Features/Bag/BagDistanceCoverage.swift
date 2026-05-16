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

    private static let largeGapYards = 30
    private static let tightClusterYards = 8

    static func summary(for clubs: [GolfClub]) -> Summary {
        let ladder = clubs
            .filter(\.isActive)
            .filter { $0.kind != .putter && $0.carryYards > 0 }
            .sorted { $0.carryYards > $1.carryYards }

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

        if largestGap > Self.largeGapYards {
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
