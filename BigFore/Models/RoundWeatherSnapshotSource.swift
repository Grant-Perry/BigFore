import Foundation

enum RoundWeatherSnapshotSource: String, CaseIterable, Codable, Identifiable, Sendable {
    case weatherKit
    case manual
    case imported

    var id: String { rawValue }
}
