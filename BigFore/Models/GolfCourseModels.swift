import Foundation
import SwiftData

@Model
final class GolfCourse {
    @Attribute(.unique) var externalID: Int
    var clubName: String
    var courseName: String
    var address: String?
    var city: String?
    var state: String?
    var country: String?
    var latitude: Double?
    var longitude: Double?
    var source: String
    @Relationship(deleteRule: .cascade, inverse: \GolfCourseTee.course) var tees: [GolfCourseTee]

    init(externalID: Int, clubName: String, courseName: String, address: String? = nil, city: String? = nil, state: String? = nil, country: String? = nil, latitude: Double? = nil, longitude: Double? = nil, source: String = "GolfCourseAPI", tees: [GolfCourseTee] = []) {
        self.externalID = externalID
        self.clubName = clubName
        self.courseName = courseName
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.source = source
        self.tees = tees
        self.tees.forEach { $0.course = self }
    }
}

@Model
final class GolfCourseTee {
    var course: GolfCourse?
    var gender: String
    var name: String
    var courseRating: Double?
    var slopeRating: Int?
    var bogeyRating: Double?
    var totalYards: Int?
    var totalMeters: Int?
    var numberOfHoles: Int?
    var parTotal: Int?
    var frontCourseRating: Double?
    var frontSlopeRating: Int?
    var frontBogeyRating: Double?
    var backCourseRating: Double?
    var backSlopeRating: Int?
    var backBogeyRating: Double?
    @Relationship(deleteRule: .cascade, inverse: \GolfCourseHole.tee) var holes: [GolfCourseHole]

    init(gender: String, name: String, courseRating: Double? = nil, slopeRating: Int? = nil, bogeyRating: Double? = nil, totalYards: Int? = nil, totalMeters: Int? = nil, numberOfHoles: Int? = nil, parTotal: Int? = nil, frontCourseRating: Double? = nil, frontSlopeRating: Int? = nil, frontBogeyRating: Double? = nil, backCourseRating: Double? = nil, backSlopeRating: Int? = nil, backBogeyRating: Double? = nil, holes: [GolfCourseHole] = []) {
        self.gender = gender
        self.name = name
        self.courseRating = courseRating
        self.slopeRating = slopeRating
        self.bogeyRating = bogeyRating
        self.totalYards = totalYards
        self.totalMeters = totalMeters
        self.numberOfHoles = numberOfHoles
        self.parTotal = parTotal
        self.frontCourseRating = frontCourseRating
        self.frontSlopeRating = frontSlopeRating
        self.frontBogeyRating = frontBogeyRating
        self.backCourseRating = backCourseRating
        self.backSlopeRating = backSlopeRating
        self.backBogeyRating = backBogeyRating
        self.holes = holes
        self.holes.forEach { $0.tee = self }
    }
}

@Model
final class GolfCourseHole {
    var tee: GolfCourseTee?
    var number: Int
    var par: Int?
    var yardage: Int?
    var handicap: Int?

    init(number: Int, par: Int? = nil, yardage: Int? = nil, handicap: Int? = nil) {
        self.number = number
        self.par = par
        self.yardage = yardage
        self.handicap = handicap
    }
}

extension GolfCourse {
    convenience init(apiCourse: GolfCourseAPICourse) {
        self.init(
            externalID: apiCourse.id,
            clubName: apiCourse.clubName,
            courseName: apiCourse.courseName,
            address: apiCourse.location.address,
            city: apiCourse.location.city,
            state: apiCourse.location.state,
            country: apiCourse.location.country,
            latitude: apiCourse.location.latitude,
            longitude: apiCourse.location.longitude,
            tees: apiCourse.allTees.map(GolfCourseTee.init(apiTee:))
        )
    }
}

extension GolfCourseTee {
    convenience init(apiTee: GolfCourseAPITeeBox) {
        self.init(
            gender: apiTee.gender,
            name: apiTee.teeName,
            courseRating: apiTee.courseRating,
            slopeRating: apiTee.slopeRating,
            bogeyRating: apiTee.bogeyRating,
            totalYards: apiTee.totalYards,
            totalMeters: apiTee.totalMeters,
            numberOfHoles: apiTee.numberOfHoles,
            parTotal: apiTee.parTotal,
            frontCourseRating: apiTee.frontCourseRating,
            frontSlopeRating: apiTee.frontSlopeRating,
            frontBogeyRating: apiTee.frontBogeyRating,
            backCourseRating: apiTee.backCourseRating,
            backSlopeRating: apiTee.backSlopeRating,
            backBogeyRating: apiTee.backBogeyRating,
            holes: apiTee.holesWithNumbers.map(GolfCourseHole.init(apiHole:))
        )
    }
}

extension GolfCourseHole {
    convenience init(apiHole: GolfCourseAPIHole) {
        self.init(number: apiHole.number, par: apiHole.par, yardage: apiHole.yardage, handicap: apiHole.handicap)
    }
}
