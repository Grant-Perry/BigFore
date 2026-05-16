import CoreLocation
import Foundation

struct OpenStreetMapGolfGeometryNormalizer {
    private let attribution = "© OpenStreetMap contributors, ODbL"

    init() {}

    func normalizedImport(
        courseExternalID: Int,
        elements: [OpenStreetMapElement]
    ) -> CourseGeometryImport {
        let routes = elements.compactMap { Self.route($0) }
        var holeBuilders: [Int: HoleGeometryImportBuilder] = [:]

        for element in elements {
            guard let areaKind = Self.areaKind(from: element.tags),
                  let coordinates = Self.areaCoordinates(for: element),
                  let coordinate = Self.coordinate(for: element) else {
                continue
            }

            let explicitHoleNumber = Self.holeNumber(from: element.tags)
            let inferredHoleNumber = Self.nearestRouteHoleNumber(to: coordinate, routes: routes)
            guard let holeNumber = explicitHoleNumber ?? inferredHoleNumber else {
                continue
            }

            var builder = holeBuilders[holeNumber] ?? HoleGeometryImportBuilder(number: holeNumber)
            builder.addAreaFeature(
                kind: areaKind,
                label: Self.areaLabel(from: element.tags, kind: areaKind, holeNumber: holeNumber),
                coordinates: coordinates
            )
            holeBuilders[holeNumber] = builder
        }

        for element in elements {
            guard let golfTag = element.tags["golf"]?.lowercased() else {
                continue
            }

            let coordinate = Self.coordinate(for: element)
            let explicitHoleNumber = Self.holeNumber(from: element.tags)
            let inferredHoleNumber = coordinate.flatMap { Self.nearestRouteHoleNumber(to: $0, routes: routes) }
            let holeNumber = explicitHoleNumber ?? inferredHoleNumber

            switch golfTag {
            case "hole":
                guard let route = Self.route(from: element) else {
                    continue
                }
                var builder = holeBuilders[route.number] ?? HoleGeometryImportBuilder(number: route.number)
                if let teeCoordinate = route.coordinates.first {
                    builder.addFeaturePoint(
                        kind: CourseMapFeatureKind.teeBox,
                        label: "OSM Tee \(route.number)",
                        coordinate: teeCoordinate
                    )
                }
                if let greenCoordinate = route.coordinates.last {
                    builder.greenCenterCoordinate = builder.greenCenterCoordinate ?? greenCoordinate
                }
                holeBuilders[route.number] = builder

            case "tee":
                guard let holeNumber, let coordinate else {
                    continue
                }
                var builder = holeBuilders[holeNumber] ?? HoleGeometryImportBuilder(number: holeNumber)
                builder.addFeaturePoint(
                    kind: CourseMapFeatureKind.teeBox,
                    label: Self.label(from: element.tags, fallback: "OSM Tee \(holeNumber)"),
                    coordinate: coordinate
                )
                holeBuilders[holeNumber] = builder

            case "green":
                guard let holeNumber, let coordinate else {
                    continue
                }
                var builder = holeBuilders[holeNumber] ?? HoleGeometryImportBuilder(number: holeNumber)
                builder.greenCenterCoordinate = coordinate

                if let route = routes.first(where: { $0.number == holeNumber }),
                   let teeCoordinate = route.coordinates.first,
                   let greenGeometry = element.geometry?.map(\.clLocationCoordinate),
                   greenGeometry.isEmpty == false {
                    builder.greenFrontCoordinate = greenGeometry.min { lhs, rhs in
                        Self.distanceMeters(from: teeCoordinate, to: lhs) < Self.distanceMeters(from: teeCoordinate, to: rhs)
                    }
                    builder.greenBackCoordinate = greenGeometry.max { lhs, rhs in
                        Self.distanceMeters(from: teeCoordinate, to: lhs) < Self.distanceMeters(from: teeCoordinate, to: rhs)
                    }
                }

                holeBuilders[holeNumber] = builder

            case "bunker", "water_hazard":
                guard let holeNumber, let coordinate else {
                    continue
                }
                var builder = holeBuilders[holeNumber] ?? HoleGeometryImportBuilder(number: holeNumber)
                builder.addFeaturePoint(
                    kind: CourseMapFeatureKind.hazard,
                    label: Self.label(from: element.tags, fallback: Self.hazardLabel(for: golfTag, holeNumber: holeNumber)),
                    coordinate: coordinate
                )
                holeBuilders[holeNumber] = builder

            default:
                continue
            }
        }

        let holes = holeBuilders.values
            .map { $0.geometryImport }
            .filter { $0.greenCenterCoordinate != nil || !$0.featurePoints.isEmpty }
            .sorted { $0.number < $1.number }

        return CourseGeometryImport(
            courseExternalID: courseExternalID,
            source: .openStreetMap,
            sourceName: "OpenStreetMap",
            attribution: attribution,
            holes: holes
        )
    }

    private static func coordinate(for element: OpenStreetMapElement) -> CLLocationCoordinate2D? {
        if let latitude = element.lat, let longitude = element.lon {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        guard let geometry = element.geometry, !geometry.isEmpty else {
            return nil
        }

        let latitude = geometry.map(\.lat).reduce(0, +) / Double(geometry.count)
        let longitude = geometry.map(\.lon).reduce(0, +) / Double(geometry.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    private static func areaCoordinates(for element: OpenStreetMapElement) -> [CLLocationCoordinate2D]? {
        guard let geometry = element.geometry, geometry.count >= 3 else {
            return nil
        }

        return geometry.map(\.clLocationCoordinate)
    }

    private static func areaKind(from tags: [String: String]) -> CourseMapAreaKind? {
        if let golfTag = tags["golf"]?.lowercased() {
            switch golfTag {
            case "fairway":
                return .fairway
            case "rough":
                return .rough
            case "green":
                return .green
            case "bunker":
                return .bunker
            case "water_hazard", "lateral_water_hazard":
                return .water
            default:
                break
            }
        }

        if tags["natural"]?.lowercased() == "water" {
            return .water
        }

        if tags["natural"]?.lowercased() == "wood" || tags["landuse"]?.lowercased() == "forest" {
            return .woods
        }

        return nil
    }

    private static func route(_ element: OpenStreetMapElement) -> HoleRoute? {
        guard element.tags["golf"]?.lowercased() == "hole" else {
            return nil
        }

        return route(from: element)
    }

    private static func route(from element: OpenStreetMapElement) -> HoleRoute? {
        guard let holeNumber = holeNumber(from: element.tags),
              let geometry = element.geometry,
              geometry.count >= 2 else {
            return nil
        }

        return HoleRoute(number: holeNumber, coordinates: geometry.map(\.clLocationCoordinate))
    }

    private static func nearestRouteHoleNumber(to coordinate: CLLocationCoordinate2D, routes: [HoleRoute]) -> Int? {
        let nearestRoute = routes
            .map { route in
                (number: route.number, distance: route.distanceMeters(to: coordinate))
            }
            .min { $0.distance < $1.distance }

        guard let nearestRoute, nearestRoute.distance <= 150 else {
            return nil
        }

        return nearestRoute.number
    }

    private static func holeNumber(from tags: [String: String]) -> Int? {
        let candidates = [
            tags["ref"],
            tags["hole"],
            tags["name"]
        ]

        for candidate in candidates {
            guard let candidate else {
                continue
            }

            if let number = Int(candidate.trimmingCharacters(in: .whitespacesAndNewlines)),
               (1...36).contains(number) {
                return number
            }

            let digits = candidate
                .split(whereSeparator: { !$0.isNumber })
                .compactMap { Int($0) }
                .first { (1...36).contains($0) }

            if let digits {
                return digits
            }
        }

        return nil
    }

    private static func label(from tags: [String: String], fallback: String) -> String {
        let candidates = [tags["name"], tags["description"]]
        for candidate in candidates {
            let trimmed = candidate?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                return trimmed
            }
        }

        return fallback
    }

    private static func hazardLabel(for golfTag: String, holeNumber: Int) -> String {
        switch golfTag {
        case "water_hazard":
            "OSM Water Hazard \(holeNumber)"
        default:
            "OSM Bunker \(holeNumber)"
        }
    }

    private static func areaLabel(from tags: [String: String], kind: CourseMapAreaKind, holeNumber: Int) -> String {
        let fallback: String
        switch kind {
        case .fairway:
            fallback = "OSM Fairway \(holeNumber)"
        case .rough:
            fallback = "OSM Rough \(holeNumber)"
        case .green:
            fallback = "OSM Green \(holeNumber)"
        case .bunker:
            fallback = "OSM Bunker \(holeNumber)"
        case .water:
            fallback = "OSM Water \(holeNumber)"
        case .woods:
            fallback = "OSM Woods \(holeNumber)"
        }

        return label(from: tags, fallback: fallback)
    }

    private static func distanceMeters(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }
}

private struct HoleRoute {
    let number: Int
    let coordinates: [CLLocationCoordinate2D]

    func distanceMeters(to coordinate: CLLocationCoordinate2D) -> Double {
        guard coordinates.count >= 2 else {
            return coordinates.map { Self.distanceMeters(from: coordinate, to: $0) }.min() ?? .greatestFiniteMagnitude
        }

        return zip(coordinates, coordinates.dropFirst())
            .map { start, end in
                Self.distanceMeters(from: coordinate, toSegmentStart: start, end: end)
            }
            .min() ?? .greatestFiniteMagnitude
    }

    private static func distanceMeters(
        from point: CLLocationCoordinate2D,
        toSegmentStart start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D
    ) -> Double {
        let latitudeMeters = 111_320.0
        let longitudeMeters = latitudeMeters * cos(point.latitude * .pi / 180)
        let startX = (start.longitude - point.longitude) * longitudeMeters
        let startY = (start.latitude - point.latitude) * latitudeMeters
        let endX = (end.longitude - point.longitude) * longitudeMeters
        let endY = (end.latitude - point.latitude) * latitudeMeters
        let deltaX = endX - startX
        let deltaY = endY - startY
        let lengthSquared = deltaX * deltaX + deltaY * deltaY

        guard lengthSquared > 0 else {
            return hypot(startX, startY)
        }

        let projection = max(0, min(1, -((startX * deltaX) + (startY * deltaY)) / lengthSquared))
        let closestX = startX + projection * deltaX
        let closestY = startY + projection * deltaY
        return hypot(closestX, closestY)
    }

    private static func distanceMeters(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        return startLocation.distance(from: endLocation)
    }
}

private struct HoleGeometryImportBuilder {
    let number: Int
    var greenFrontCoordinate: CLLocationCoordinate2D?
    var greenCenterCoordinate: CLLocationCoordinate2D?
    var greenBackCoordinate: CLLocationCoordinate2D?
    private(set) var featurePoints: [CourseGeometryFeatureImport] = []
    private(set) var areaFeatures: [CourseGeometryAreaImport] = []

    var geometryImport: HoleGeometryImport {
        HoleGeometryImport(
            number: number,
            greenFrontCoordinate: greenFrontCoordinate,
            greenCenterCoordinate: greenCenterCoordinate,
            greenBackCoordinate: greenBackCoordinate,
            featurePoints: featurePoints,
            areaFeatures: areaFeatures
        )
    }

    mutating func addFeaturePoint(
        kind: CourseMapFeatureKind,
        label: String,
        coordinate: CLLocationCoordinate2D
    ) {
        let hasExistingPoint = featurePoints.contains { featurePoint in
            featurePoint.kind == kind &&
                abs(featurePoint.coordinate.latitude - coordinate.latitude) < 0.000001 &&
                abs(featurePoint.coordinate.longitude - coordinate.longitude) < 0.000001
        }

        guard !hasExistingPoint else {
            return
        }

        featurePoints.append(CourseGeometryFeatureImport(
            kind: kind,
            label: label,
            coordinate: coordinate,
            sortOrder: featurePoints.count
        ))
    }

    mutating func addAreaFeature(
        kind: CourseMapAreaKind,
        label: String,
        coordinates: [CLLocationCoordinate2D]
    ) {
        guard coordinates.count >= 3 else {
            return
        }

        let hasExistingArea = areaFeatures.contains { areaFeature in
            areaFeature.kind == kind &&
                areaFeature.coordinates.count == coordinates.count &&
                abs((areaFeature.coordinates.first?.latitude ?? 0) - (coordinates.first?.latitude ?? 1)) < 0.000001 &&
                abs((areaFeature.coordinates.first?.longitude ?? 0) - (coordinates.first?.longitude ?? 1)) < 0.000001
        }

        guard !hasExistingArea else {
            return
        }

        areaFeatures.append(CourseGeometryAreaImport(
            kind: kind,
            label: label,
            coordinates: coordinates,
            sortOrder: areaFeatures.count
        ))
    }
}

private extension OpenStreetMapCoordinate {
    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}
