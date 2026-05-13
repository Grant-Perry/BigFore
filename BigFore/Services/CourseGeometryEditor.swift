import CoreLocation
import Foundation
import SwiftData

struct CourseGeometryEditor {
    nonisolated init() {}

    @MainActor
    func importGeometry(
        _ geometryImport: CourseGeometryImport,
        modelContext: ModelContext
    ) throws -> CourseGeometry {
        let geometry = try geometry(
            for: geometryImport.courseExternalID,
            source: geometryImport.source,
            sourceName: geometryImport.sourceName,
            attribution: geometryImport.attribution,
            modelContext: modelContext
        )

        geometry.sourceRawValue = geometryImport.source.rawValue
        geometry.sourceName = geometryImport.sourceName
        geometry.attribution = geometryImport.attribution

        for holeImport in geometryImport.holes {
            let hole = holeGeometry(number: holeImport.number, in: geometry)
            applyGreenCoordinates(from: holeImport, to: hole)
            replaceImportedFeaturePoints(
                from: holeImport,
                source: geometryImport.source,
                in: hole,
                modelContext: modelContext
            )
        }

        geometry.updatedAt = .now
        try modelContext.save()
        return geometry
    }

    @MainActor
    func addFeaturePoint(
        courseExternalID: Int,
        holeNumber: Int,
        kind: CourseMapFeatureKind,
        label: String,
        coordinate: CLLocationCoordinate2D,
        modelContext: ModelContext
    ) throws -> CourseMapFeaturePoint {
        let geometry = try geometry(for: courseExternalID, modelContext: modelContext)
        let hole = holeGeometry(number: holeNumber, in: geometry)
        let featurePoint = CourseMapFeaturePoint(
            kind: kind,
            label: label,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            source: .userMapped,
            sortOrder: hole.featurePoints.count
        )

        featurePoint.holeGeometry = hole
        hole.featurePoints.append(featurePoint)
        geometry.updatedAt = .now
        try modelContext.save()

        return featurePoint
    }

    @MainActor
    func setStickyHoleAnchor(
        courseExternalID: Int,
        holeNumber: Int,
        kind: CourseMapFeatureKind,
        coordinate: CLLocationCoordinate2D,
        modelContext: ModelContext
    ) throws -> CourseMapFeaturePoint {
        let geometry = try geometry(for: courseExternalID, modelContext: modelContext)
        let hole = holeGeometry(number: holeNumber, in: geometry)
        let label = kind == .teeBox ? "Tee \(holeNumber)" : "Pin \(holeNumber)"

        if let featurePoint = hole.featurePoints.first(where: { $0.kind == kind && $0.source == .userMapped }) {
            featurePoint.label = label
            featurePoint.latitude = coordinate.latitude
            featurePoint.longitude = coordinate.longitude
            geometry.updatedAt = .now
            try modelContext.save()
            return featurePoint
        }

        let featurePoint = CourseMapFeaturePoint(
            kind: kind,
            label: label,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            source: .userMapped,
            sortOrder: hole.featurePoints.count
        )
        featurePoint.holeGeometry = hole
        hole.featurePoints.append(featurePoint)
        geometry.updatedAt = .now
        try modelContext.save()

        return featurePoint
    }

    @MainActor
    func clearStickyHoleAnchors(
        courseExternalID: Int,
        holeNumber: Int,
        modelContext: ModelContext
    ) throws {
        guard let geometry = try geometryIfExists(for: courseExternalID, modelContext: modelContext),
              let hole = geometry.holes.first(where: { $0.number == holeNumber }) else {
            return
        }

        let stickyAnchors = hole.featurePoints.filter { $0.kind.isStickyHoleAnchor && $0.source == .userMapped }
        for anchor in stickyAnchors {
            modelContext.delete(anchor)
        }
        hole.featurePoints.removeAll { $0.kind.isStickyHoleAnchor && $0.source == .userMapped }
        geometry.updatedAt = .now
        try modelContext.save()
    }

    @MainActor
    func clearStickyHoleAnchor(
        courseExternalID: Int,
        holeNumber: Int,
        kind: CourseMapFeatureKind,
        modelContext: ModelContext
    ) throws {
        guard kind.isStickyHoleAnchor,
              let geometry = try geometryIfExists(for: courseExternalID, modelContext: modelContext),
              let hole = geometry.holes.first(where: { $0.number == holeNumber }) else {
            return
        }

        let stickyAnchors = hole.featurePoints.filter { $0.kind == kind && $0.source == .userMapped }
        for anchor in stickyAnchors {
            modelContext.delete(anchor)
        }
        hole.featurePoints.removeAll { $0.kind == kind && $0.source == .userMapped }
        geometry.updatedAt = .now
        try modelContext.save()
    }

    @MainActor
    func deleteUserMappedFeaturePoint(
        _ featurePoint: CourseMapFeaturePoint,
        modelContext: ModelContext
    ) throws {
        guard featurePoint.source == .userMapped else {
            return
        }

        let geometry = featurePoint.holeGeometry?.courseGeometry
        featurePoint.holeGeometry?.featurePoints.removeAll { $0 === featurePoint }
        modelContext.delete(featurePoint)
        geometry?.updatedAt = .now
        try modelContext.save()
    }

    @MainActor
    private func geometry(for courseExternalID: Int, modelContext: ModelContext) throws -> CourseGeometry {
        try geometry(
            for: courseExternalID,
            source: .userMapped,
            sourceName: "User Mapped",
            attribution: nil,
            modelContext: modelContext
        )
    }

    @MainActor
    private func geometry(
        for courseExternalID: Int,
        source: CourseGeometrySource,
        sourceName: String,
        attribution: String?,
        modelContext: ModelContext
    ) throws -> CourseGeometry {
        if let geometry = try geometryIfExists(for: courseExternalID, modelContext: modelContext) {
            return geometry
        }

        let geometry = CourseGeometry(
            courseExternalID: courseExternalID,
            source: source,
            sourceName: sourceName,
            attribution: attribution
        )
        modelContext.insert(geometry)
        return geometry
    }

    @MainActor
    private func geometryIfExists(for courseExternalID: Int, modelContext: ModelContext) throws -> CourseGeometry? {
        var descriptor = FetchDescriptor<CourseGeometry>(
            predicate: #Predicate { geometry in
                geometry.courseExternalID == courseExternalID
            }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    @MainActor
    private func holeGeometry(number: Int, in geometry: CourseGeometry) -> HoleGeometry {
        if let hole = geometry.holes.first(where: { $0.number == number }) {
            return hole
        }

        let hole = HoleGeometry(number: number)
        hole.courseGeometry = geometry
        geometry.holes.append(hole)
        return hole
    }

    @MainActor
    private func applyGreenCoordinates(from holeImport: HoleGeometryImport, to hole: HoleGeometry) {
        if let greenFrontCoordinate = holeImport.greenFrontCoordinate {
            hole.greenFrontLatitude = greenFrontCoordinate.latitude
            hole.greenFrontLongitude = greenFrontCoordinate.longitude
        }

        if let greenCenterCoordinate = holeImport.greenCenterCoordinate {
            hole.greenCenterLatitude = greenCenterCoordinate.latitude
            hole.greenCenterLongitude = greenCenterCoordinate.longitude
        }

        if let greenBackCoordinate = holeImport.greenBackCoordinate {
            hole.greenBackLatitude = greenBackCoordinate.latitude
            hole.greenBackLongitude = greenBackCoordinate.longitude
        }
    }

    @MainActor
    private func replaceImportedFeaturePoints(
        from holeImport: HoleGeometryImport,
        source: CourseGeometrySource,
        in hole: HoleGeometry,
        modelContext: ModelContext
    ) {
        let existingImportedPoints = hole.featurePoints.filter { $0.source == source }
        for featurePoint in existingImportedPoints {
            modelContext.delete(featurePoint)
        }
        hole.featurePoints.removeAll { $0.source == source }

        for featureImport in holeImport.featurePoints {
            let featurePoint = CourseMapFeaturePoint(
                kind: featureImport.kind,
                label: featureImport.label,
                latitude: featureImport.coordinate.latitude,
                longitude: featureImport.coordinate.longitude,
                source: source,
                sortOrder: featureImport.sortOrder
            )
            featurePoint.holeGeometry = hole
            hole.featurePoints.append(featurePoint)
        }
    }
}
