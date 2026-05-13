import CoreLocation
import Foundation

enum OpenStreetMapGolfGeometryError: LocalizedError {
    case invalidResponse
    case requestFailed(Int)
    case emptyGeometry

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "OpenStreetMap returned an invalid response."
        case .requestFailed(let statusCode):
            "OpenStreetMap geometry failed with status code \(statusCode)."
        case .emptyGeometry:
            "No OpenStreetMap golf geometry was found for this course."
        }
    }
}

@MainActor
final class OpenStreetMapGolfGeometryClient: OpenStreetMapGolfGeometryProviding {
    private let endpointURL: URL
    private let session: URLSession
    private let normalizer: OpenStreetMapGolfGeometryNormalizer

    init(
        endpointURL: URL = URL(string: "https://overpass-api.de/api/interpreter")!,
        session: URLSession = .shared,
        normalizer: OpenStreetMapGolfGeometryNormalizer = OpenStreetMapGolfGeometryNormalizer()
    ) {
        self.endpointURL = endpointURL
        self.session = session
        self.normalizer = normalizer
    }

    func geometry(for request: OpenStreetMapGolfGeometryRequest) async throws -> CourseGeometryImport {
        let query = Self.query(for: request)
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = query.data(using: .utf8)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenStreetMapGolfGeometryError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw OpenStreetMapGolfGeometryError.requestFailed(httpResponse.statusCode)
        }

        let overpassResponse = try JSONDecoder().decode(OpenStreetMapOverpassResponse.self, from: data)
        let geometryImport = normalizer.normalizedImport(
            courseExternalID: request.courseExternalID,
            elements: overpassResponse.elements
        )

        guard !geometryImport.holes.isEmpty else {
            throw OpenStreetMapGolfGeometryError.emptyGeometry
        }

        return geometryImport
    }

    private static func query(for request: OpenStreetMapGolfGeometryRequest) -> String {
        let latitude = request.centerCoordinate.latitude
        let longitude = request.centerCoordinate.longitude
        let radius = request.searchRadiusMeters

        return """
        [out:json][timeout:25];
        (
          node(around:\(radius),\(latitude),\(longitude))["golf"];
          way(around:\(radius),\(latitude),\(longitude))["golf"];
          relation(around:\(radius),\(latitude),\(longitude))["golf"];
        );
        out body geom;
        """
    }
}
