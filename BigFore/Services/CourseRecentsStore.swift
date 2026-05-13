import Foundation

@MainActor
protocol CourseRecentsStoring {
    func load() -> [CourseRecent]
    func save(_ recents: [CourseRecent])
}

@MainActor
struct UserDefaultsCourseRecentsStore: CourseRecentsStoring {
    static let limit = 20
    static let defaultKey = "courseSearchRecents"

    private let userDefaults: UserDefaults
    private let key: String

    init(userDefaults: UserDefaults = .standard, key: String = Self.defaultKey) {
        self.userDefaults = userDefaults
        self.key = key
    }

    func load() -> [CourseRecent] {
        guard let data = userDefaults.data(forKey: key),
              let recents = try? JSONDecoder().decode([CourseRecent].self, from: data) else {
            return []
        }

        return Array(recents.prefix(Self.limit))
    }

    func save(_ recents: [CourseRecent]) {
        let cappedRecents = Array(recents.prefix(Self.limit))
        guard let data = try? JSONEncoder().encode(cappedRecents) else {
            return
        }

        userDefaults.set(data, forKey: key)
    }
}
