import Foundation

struct RoundSetupCourse {
    let externalID: Int
    let clubName: String
    let courseName: String
    let latitude: Double?
    let longitude: Double?

    nonisolated var displayName: String {
        courseName == clubName ? courseName : "\(clubName) - \(courseName)"
    }

    nonisolated init(externalID: Int, clubName: String, courseName: String, latitude: Double?, longitude: Double?) {
        self.externalID = externalID
        self.clubName = clubName
        self.courseName = courseName
        self.latitude = latitude
        self.longitude = longitude
    }
}

struct RoundSetupTee {
    let gender: String
    let name: String
    let totalYards: Int?
    let parTotal: Int?
    let holes: [RoundSetupHole]

    nonisolated init(gender: String, name: String, totalYards: Int?, parTotal: Int?, holes: [RoundSetupHole]) {
        self.gender = gender
        self.name = name
        self.totalYards = totalYards
        self.parTotal = parTotal
        self.holes = holes
    }
}

struct RoundSetupHole {
    let number: Int
    let par: Int?
    let yardage: Int?
    let handicap: Int?

    nonisolated init(number: Int, par: Int?, yardage: Int?, handicap: Int?) {
        self.number = number
        self.par = par
        self.yardage = yardage
        self.handicap = handicap
    }
}

struct RoundBuilder {
    nonisolated init() {}

    @MainActor
    func makeRound(
        course: RoundSetupCourse,
        tee: RoundSetupTee,
        scoringMode: ScoringMode,
        playerNames: [String],
        primaryPlayerProfile: PlayerProfile? = nil,
        startedAt: Date = .now
    ) -> GolfRound {
        let players = playerNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(8)
            .enumerated()
            .map { index, name in
                RoundPlayer(
                    playerProfile: index == 0 ? primaryPlayerProfile : nil,
                    name: name,
                    displayOrder: index,
                    teeName: tee.name,
                    teeGender: tee.gender,
                    scores: tee.holes.map { hole in
                        HoleScore(
                            holeNumber: hole.number,
                            par: hole.par ?? 4,
                            yardage: hole.yardage,
                            handicap: hole.handicap,
                            teeShotAccuracy: (hole.par ?? 4) >= 4 ? nil : .notApplicable
                        )
                    }
                )
            }

        return GolfRound(
            courseExternalID: course.externalID,
            courseName: course.courseName,
            clubName: course.clubName,
            courseLatitude: course.latitude,
            courseLongitude: course.longitude,
            teeName: tee.name,
            teeGender: tee.gender,
            scoringMode: scoringMode,
            startedAt: startedAt,
            players: Array(players)
        )
    }
}

extension RoundSetupCourse {
    init(apiCourse: GolfCourseAPICourse) {
        self.init(
            externalID: apiCourse.id,
            clubName: apiCourse.clubName,
            courseName: apiCourse.courseName,
            latitude: apiCourse.location.latitude,
            longitude: apiCourse.location.longitude
        )
    }

    init(savedCourse: GolfCourse) {
        self.init(
            externalID: savedCourse.externalID,
            clubName: savedCourse.clubName,
            courseName: savedCourse.courseName,
            latitude: savedCourse.latitude,
            longitude: savedCourse.longitude
        )
    }
}

extension RoundSetupTee {
    init(apiTee: GolfCourseAPITeeBox) {
        self.init(
            gender: apiTee.gender,
            name: apiTee.teeName,
            totalYards: apiTee.totalYards,
            parTotal: apiTee.parTotal,
            holes: apiTee.holesWithNumbers.map(RoundSetupHole.init(apiHole:))
        )
    }

    init(savedTee: GolfCourseTee) {
        self.init(
            gender: savedTee.gender,
            name: savedTee.name,
            totalYards: savedTee.totalYards,
            parTotal: savedTee.parTotal,
            holes: savedTee.holes.map(RoundSetupHole.init(savedHole:)).sorted { $0.number < $1.number }
        )
    }
}

extension RoundSetupHole {
    nonisolated init(apiHole: GolfCourseAPIHole) {
        self.init(number: apiHole.number, par: apiHole.par, yardage: apiHole.yardage, handicap: apiHole.handicap)
    }

    nonisolated init(savedHole: GolfCourseHole) {
        self.init(number: savedHole.number, par: savedHole.par, yardage: savedHole.yardage, handicap: savedHole.handicap)
    }
}
