import Foundation

enum GolfCourseAPIConfiguration {
    // Temporary static configuration. Keep callers injected so this can move to obfuscated/config storage later.
    static let defaultAPIKey = "DPP3A3BWZYVZELH6DIBLHQRNUE"
}

struct GolfCourseAPISearchResponse: Decodable {
    let courses: [GolfCourseAPICourse]
}

struct GolfCourseAPIDetailResponse: Decodable {
    let course: GolfCourseAPICourse
}

struct GolfCourseAPICourse: Decodable, Identifiable {
    let id: Int
    let clubName: String
    let courseName: String
    let location: GolfCourseAPILocation
    let tees: GolfCourseAPITees?

    enum CodingKeys: String, CodingKey {
        case id
        case clubName = "club_name"
        case courseName = "course_name"
        case location
        case tees
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        clubName = try container.decodeIfPresent(String.self, forKey: .clubName) ?? "Unknown Club"
        courseName = try container.decodeIfPresent(String.self, forKey: .courseName) ?? clubName
        location = try container.decodeIfPresent(GolfCourseAPILocation.self, forKey: .location) ?? GolfCourseAPILocation()
        tees = try container.decodeIfPresent(GolfCourseAPITees.self, forKey: .tees)
    }
}

struct GolfCourseAPILocation: Decodable {
    let address: String?
    let city: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?

    init(address: String? = nil, city: String? = nil, state: String? = nil, country: String? = nil, latitude: Double? = nil, longitude: Double? = nil) {
        self.address = address
        self.city = city
        self.state = state
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
    }

    enum CodingKeys: String, CodingKey {
        case address
        case city
        case state
        case country
        case latitude
        case longitude
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        city = try container.decodeIfPresent(String.self, forKey: .city)
        state = try container.decodeIfPresent(String.self, forKey: .state)
        country = try container.decodeIfPresent(String.self, forKey: .country)
        latitude = try container.decodeFlexibleDouble(forKey: .latitude)
        longitude = try container.decodeFlexibleDouble(forKey: .longitude)
    }
}

struct GolfCourseAPITees: Decodable {
    let female: [GolfCourseAPITeeBox]
    let male: [GolfCourseAPITeeBox]

    enum CodingKeys: String, CodingKey {
        case female
        case male
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        female = try container.decodeIfPresent([GolfCourseAPITeeBox].self, forKey: .female) ?? []
        male = try container.decodeIfPresent([GolfCourseAPITeeBox].self, forKey: .male) ?? []
    }
}

struct GolfCourseAPITeeBox: Decodable, Identifiable {
    var id: String { "\(gender)-\(teeName)-\(totalYards ?? 0)" }
    var gender: String = "unknown"
    let teeName: String
    let courseRating: Double?
    let slopeRating: Int?
    let bogeyRating: Double?
    let totalYards: Int?
    let totalMeters: Int?
    let numberOfHoles: Int?
    let parTotal: Int?
    let frontCourseRating: Double?
    let frontSlopeRating: Int?
    let frontBogeyRating: Double?
    let backCourseRating: Double?
    let backSlopeRating: Int?
    let backBogeyRating: Double?
    let holes: [GolfCourseAPIHole]

    enum CodingKeys: String, CodingKey {
        case teeName = "tee_name"
        case courseRating = "course_rating"
        case slopeRating = "slope_rating"
        case bogeyRating = "bogey_rating"
        case totalYards = "total_yards"
        case totalMeters = "total_meters"
        case numberOfHoles = "number_of_holes"
        case parTotal = "par_total"
        case frontCourseRating = "front_course_rating"
        case frontSlopeRating = "front_slope_rating"
        case frontBogeyRating = "front_bogey_rating"
        case backCourseRating = "back_course_rating"
        case backSlopeRating = "back_slope_rating"
        case backBogeyRating = "back_bogey_rating"
        case holes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        teeName = try container.decodeIfPresent(String.self, forKey: .teeName) ?? "Unknown"
        courseRating = try container.decodeFlexibleDouble(forKey: .courseRating)
        slopeRating = try container.decodeFlexibleInt(forKey: .slopeRating)
        bogeyRating = try container.decodeFlexibleDouble(forKey: .bogeyRating)
        totalYards = try container.decodeFlexibleInt(forKey: .totalYards)
        totalMeters = try container.decodeFlexibleInt(forKey: .totalMeters)
        numberOfHoles = try container.decodeFlexibleInt(forKey: .numberOfHoles)
        parTotal = try container.decodeFlexibleInt(forKey: .parTotal)
        frontCourseRating = try container.decodeFlexibleDouble(forKey: .frontCourseRating)
        frontSlopeRating = try container.decodeFlexibleInt(forKey: .frontSlopeRating)
        frontBogeyRating = try container.decodeFlexibleDouble(forKey: .frontBogeyRating)
        backCourseRating = try container.decodeFlexibleDouble(forKey: .backCourseRating)
        backSlopeRating = try container.decodeFlexibleInt(forKey: .backSlopeRating)
        backBogeyRating = try container.decodeFlexibleDouble(forKey: .backBogeyRating)
        holes = try container.decodeIfPresent([GolfCourseAPIHole].self, forKey: .holes) ?? []
    }
}

struct GolfCourseAPIHole: Decodable, Identifiable {
    var id: Int { number }
    var number: Int = 0
    let par: Int?
    let yardage: Int?
    let handicap: Int?

    enum CodingKeys: String, CodingKey {
        case par
        case yardage
        case handicap
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        par = try container.decodeFlexibleInt(forKey: .par)
        yardage = try container.decodeFlexibleInt(forKey: .yardage)
        handicap = try container.decodeFlexibleInt(forKey: .handicap)
    }
}

extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Int(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }

    func decodeFlexibleDouble(forKey key: Key) throws -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }

        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }

        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return nil
    }
}

enum GolfCourseAPIError: LocalizedError {
    case missingAPIKey
    case invalidURL
    case invalidResponse
    case requestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "Course search is not configured yet."
        case .invalidURL:
            "The course search request could not be created."
        case .invalidResponse:
            "Course search returned an invalid response."
        case .requestFailed(let statusCode):
            "Course search failed with status code \(statusCode)."
        }
    }
}

@MainActor
final class GolfCourseAPIClient {
    private let apiKey: String
    private let baseURL: URL
    private let session: URLSession

    init(apiKey: String = GolfCourseAPIConfiguration.defaultAPIKey, baseURL: URL = URL(string: "https://api.golfcourseapi.com")!, session: URLSession = .shared) {
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        self.baseURL = baseURL
        self.session = session
    }

    func search(query: String) async throws -> [GolfCourseAPICourse] {
        let response: GolfCourseAPISearchResponse = try await send(path: "/v1/search", queryItems: [
            URLQueryItem(name: "search_query", value: query)
        ])
        return response.courses
    }

    func course(id: Int) async throws -> GolfCourseAPICourse {
        let response: GolfCourseAPIDetailResponse = try await send(path: "/v1/courses/\(id)", queryItems: [])
        return response.course
    }

    private func send<Value: Decodable>(path: String, queryItems: [URLQueryItem]) async throws -> Value {
        guard !apiKey.isEmpty else {
            throw GolfCourseAPIError.missingAPIKey
        }

        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw GolfCourseAPIError.invalidURL
        }

        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw GolfCourseAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Key \(apiKey)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GolfCourseAPIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GolfCourseAPIError.requestFailed(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        return try decoder.decode(Value.self, from: data)
    }
}

extension GolfCourseAPICourse {
    nonisolated var displayName: String {
        courseName == clubName ? courseName : "\(clubName) - \(courseName)"
    }

    nonisolated var allTees: [GolfCourseAPITeeBox] {
        var teesWithGender: [GolfCourseAPITeeBox] = []

        for tee in tees?.male ?? [] {
            var updatedTee = tee
            updatedTee.gender = "male"
            teesWithGender.append(updatedTee)
        }

        for tee in tees?.female ?? [] {
            var updatedTee = tee
            updatedTee.gender = "female"
            teesWithGender.append(updatedTee)
        }

        return teesWithGender
    }
}

extension GolfCourseAPILocation {
    nonisolated var displayText: String? {
        if let address = address?.trimmingCharacters(in: .whitespacesAndNewlines), !address.isEmpty {
            return address
        }

        let locationComponents = [city, state, country].compactMap { component in
            let trimmedComponent = component?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedComponent?.isEmpty == false ? trimmedComponent : nil
        }

        return locationComponents.isEmpty ? nil : locationComponents.joined(separator: ", ")
    }
}

extension GolfCourseAPITeeBox {
    nonisolated var holesWithNumbers: [GolfCourseAPIHole] {
        holes.enumerated().map { index, hole in
            var updatedHole = hole
            updatedHole.number = index + 1
            return updatedHole
        }
    }
}
