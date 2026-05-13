import CoreLocation
import Foundation
import SwiftData

struct CourseGeometryEditor {
    nonisolated init() {}

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
    private func geometry(for courseExternalID: Int, modelContext: ModelContext) throws -> CourseGeometry {
        if let geometry = try geometryIfExists(for: courseExternalID, modelContext: modelContext) {
            return geometry
        }

        let geometry = CourseGeometry(
            courseExternalID: courseExternalID,
            source: .userMapped,
            sourceName: "User Mapped"
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
}
