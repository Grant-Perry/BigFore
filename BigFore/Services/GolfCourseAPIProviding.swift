import Foundation

@MainActor
protocol GolfCourseAPIProviding {
    func search(query: String) async throws -> [GolfCourseAPICourse]
    func course(id: Int) async throws -> GolfCourseAPICourse
}

extension GolfCourseAPIClient: GolfCourseAPIProviding {}
