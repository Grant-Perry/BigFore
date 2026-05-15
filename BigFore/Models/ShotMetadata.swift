import Foundation

enum ShotLie: String, CaseIterable, Codable, Identifiable, Sendable {
    case tee
    case fairway
    case rough
    case bunker
    case recovery
    case green
    case unknown

    var id: String { rawValue }
}

enum ShotResult: String, CaseIterable, Codable, Identifiable, Sendable {
    case playable
    case greenInRegulation
    case fairwayHit
    case missedLeft
    case missedRight
    case short
    case long
    case penalty
    case unknown

    var id: String { rawValue }
}

enum ShotRecordSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case manualMap
    case gps
    case watch
    case imported

    var id: String { rawValue }
}
