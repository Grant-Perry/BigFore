import Foundation

struct OpenStreetMapOverpassResponse: Decodable {
    let elements: [OpenStreetMapElement]
}

struct OpenStreetMapElement: Decodable {
    let type: String
    let id: Int
    let lat: Double?
    let lon: Double?
    let tags: [String: String]
    let geometry: [OpenStreetMapCoordinate]?

    enum CodingKeys: String, CodingKey {
        case type
        case id
        case lat
        case lon
        case tags
        case geometry
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        id = try container.decodeFlexibleInt(forKey: .id) ?? 0
        lat = try container.decodeFlexibleDouble(forKey: .lat)
        lon = try container.decodeFlexibleDouble(forKey: .lon)
        tags = try container.decodeIfPresent([String: String].self, forKey: .tags) ?? [:]
        geometry = try container.decodeIfPresent([OpenStreetMapCoordinate].self, forKey: .geometry)
    }
}

struct OpenStreetMapCoordinate: Decodable {
    let lat: Double
    let lon: Double

    enum CodingKeys: String, CodingKey {
        case lat
        case lon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        lat = try container.decodeFlexibleDouble(forKey: .lat) ?? 0
        lon = try container.decodeFlexibleDouble(forKey: .lon) ?? 0
    }
}
