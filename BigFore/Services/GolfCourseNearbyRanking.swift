import CoreLocation
import Foundation

enum GolfCourseNearbyRanking {
    /// Default cap when callers do not pass `limit`. Find closest ranks the full enriched window, then applies the miles slider.
    nonisolated static let defaultResultLimit = 15

    /// Returns API search hits that include coordinates, ordered nearest-first.
    nonisolated static func rankedCourses(
        _ courses: [GolfCourseAPICourse],
        userLocation: CLLocation,
        limit: Int = defaultResultLimit
    ) -> [(course: GolfCourseAPICourse, distanceMeters: CLLocationDistance)] {
        let pairs: [(GolfCourseAPICourse, CLLocationDistance)] = courses.compactMap { course in
            guard let latitude = course.location.latitude,
                  let longitude = course.location.longitude else {
                return nil
            }
            let courseLocation = CLLocation(latitude: latitude, longitude: longitude)
            return (course, userLocation.distance(from: courseLocation))
        }
        return Array(pairs.sorted { $0.1 < $1.1 }.prefix(limit))
    }
}

enum CourseSearchDistanceFormatting {
    nonisolated static func caption(forMeters meters: CLLocationDistance) -> String {
        let yards = Int((meters * 1.09361).rounded())
        if yards < 250 {
            return "\(yards) yds"
        }
        let miles = meters / 1_609.34
        if miles < 100 {
            return String(format: "%.1f mi", miles)
        }
        return String(format: "%.0f mi", miles)
    }
}
