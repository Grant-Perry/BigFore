import Foundation

struct CourseRecent: Codable, Equatable, Identifiable {
    let id: Int
    let displayName: String
    let locationText: String?

    init(id: Int, displayName: String, locationText: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.locationText = locationText
    }

    init(course: GolfCourseAPICourse) {
        self.init(
            id: course.id,
            displayName: course.displayName,
            locationText: course.location.displayText
        )
    }
}
