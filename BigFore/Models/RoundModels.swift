import Foundation
import SwiftData

@Model
final class GolfRound {
    var id: UUID
    var courseExternalID: Int
    var courseName: String
    var clubName: String
    var courseLatitude: Double?
    var courseLongitude: Double?
    var teeName: String
    var teeGender: String
    var scoringModeRawValue: String
    var startedAt: Date
    var completedAt: Date?
    var currentHole: Int
    @Relationship(deleteRule: .cascade, inverse: \RoundPlayer.round) var players: [RoundPlayer]
    @Relationship(deleteRule: .cascade, inverse: \ShotRecord.round) var shotRecords: [ShotRecord] = []
    @Relationship(deleteRule: .cascade, inverse: \RoundWeatherSnapshot.round) var weatherSnapshots: [RoundWeatherSnapshot] = []

    init(id: UUID = UUID(), courseExternalID: Int, courseName: String, clubName: String, courseLatitude: Double? = nil, courseLongitude: Double? = nil, teeName: String, teeGender: String, scoringMode: ScoringMode = .strokePlay, startedAt: Date = .now, completedAt: Date? = nil, currentHole: Int = 1, players: [RoundPlayer] = []) {
        self.id = id
        self.courseExternalID = courseExternalID
        self.courseName = courseName
        self.clubName = clubName
        self.courseLatitude = courseLatitude
        self.courseLongitude = courseLongitude
        self.teeName = teeName
        self.teeGender = teeGender
        self.scoringModeRawValue = scoringMode.rawValue
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.currentHole = currentHole
        self.players = players
    }
}

@Model
final class RoundPlayer {
    var round: GolfRound?
    var playerProfile: PlayerProfile?
    var id: UUID
    var name: String
    var displayOrder: Int
    @Relationship(deleteRule: .cascade, inverse: \HoleScore.player) var scores: [HoleScore]
    @Relationship(deleteRule: .cascade, inverse: \ShotRecord.player) var shotRecords: [ShotRecord] = []

    init(id: UUID = UUID(), playerProfile: PlayerProfile? = nil, name: String, displayOrder: Int, scores: [HoleScore] = []) {
        self.id = id
        self.playerProfile = playerProfile
        self.name = name
        self.displayOrder = displayOrder
        self.scores = scores
    }
}

@Model
final class HoleScore {
    var player: RoundPlayer?
    var holeNumber: Int
    var par: Int
    var yardage: Int?
    var handicap: Int?
    var strokes: Int

    init(holeNumber: Int, par: Int, yardage: Int? = nil, handicap: Int? = nil, strokes: Int = 0) {
        self.holeNumber = holeNumber
        self.par = par
        self.yardage = yardage
        self.handicap = handicap
        self.strokes = strokes
    }
}

enum ScoringMode: String, CaseIterable, Identifiable, Codable {
    case strokePlay
    case stableford

    var id: String { rawValue }

    var title: String {
        switch self {
        case .strokePlay:
            "Stroke Play"
        case .stableford:
            "Stableford"
        }
    }
}

extension GolfRound {
    var scoringMode: ScoringMode {
        get { ScoringMode(rawValue: scoringModeRawValue) ?? .strokePlay }
        set { scoringModeRawValue = newValue.rawValue }
    }

    var isComplete: Bool {
        completedAt != nil
    }
}
