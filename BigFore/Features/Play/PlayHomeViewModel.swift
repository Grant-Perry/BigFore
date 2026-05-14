import Foundation
import Observation

@MainActor
@Observable
final class PlayHomeViewModel {
    private let scoring = RoundScoring()
    private let roundDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    func activeRound(from rounds: [GolfRound]) -> GolfRound? {
        rounds.first { !$0.isComplete }
    }

    func recentCompletedRound(from rounds: [GolfRound]) -> GolfRound? {
        rounds.first(where: \.isComplete)
    }

    func savedCourseHighlights(from courses: [GolfCourse]) -> [GolfCourse] {
        Array(courses.prefix(3))
    }

    func roundDateText(for round: GolfRound) -> String {
        roundDateFormatter.string(from: round.startedAt)
    }

    func roundSetupText(for round: GolfRound) -> String {
        "\(round.teeName) \(round.teeGender.capitalized) tee · \(round.scoringMode.title)"
    }

    func currentHoleTitle(for round: GolfRound) -> String {
        "Hole \(round.currentHole)"
    }

    func currentHoleDetail(for round: GolfRound) -> String {
        guard let score = currentHoleScore(for: round) else {
            return "Ready for the next score"
        }

        var details = ["Par \(score.par)"]
        if let yardage = score.yardage {
            details.append("\(yardage) yds")
        }
        if let handicap = score.handicap {
            details.append("HCP \(handicap)")
        }

        return details.joined(separator: " · ")
    }

    func scoreStatusText(for round: GolfRound) -> String {
        let players = scoring.sortedPlayers(for: round)
        guard !players.isEmpty else {
            return "No players added"
        }

        let scoredPlayers = players.filter { player in
            player.scores.contains { $0.holeNumber == round.currentHole && $0.strokes > 0 }
        }

        return "\(scoredPlayers.count) of \(players.count) scored"
    }

    func playerSummary(for round: GolfRound) -> String {
        let count = scoring.sortedPlayers(for: round).count
        return "\(count) \(count == 1 ? "player" : "players")"
    }

    func leaderSummary(for round: GolfRound) -> String? {
        guard let leader = scoring.sortedPlayers(for: round).first else {
            return nil
        }

        return "Leader: \(leader.name) \(scoring.summary(for: leader, scoringMode: round.scoringMode))"
    }

    func gpsStatusText(for round: GolfRound) -> String {
        CourseMapPoint(round: round) == nil ? "Course pin needed" : "GPS ready"
    }

    func savedCourseSubtitle(for course: GolfCourse) -> String {
        if course.clubName == course.courseName {
            return locationText(for: course) ?? "Saved course"
        }

        if let location = locationText(for: course) {
            return "\(course.clubName) · \(location)"
        }

        return course.clubName
    }

    func savedCourseBadges(for course: GolfCourse) -> [String] {
        var badges = ["\(course.tees.count) \(course.tees.count == 1 ? "tee" : "tees")"]
        if course.latitude != nil && course.longitude != nil {
            badges.append("GPS")
        }
        return badges
    }

    private func currentHoleScore(for round: GolfRound) -> HoleScore? {
        scoring.sortedPlayers(for: round).first?.scores.first { $0.holeNumber == round.currentHole }
    }

    private func locationText(for course: GolfCourse) -> String? {
        let parts = [course.city, course.state, course.country]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            return course.address
        }

        return parts.joined(separator: ", ")
    }
}
