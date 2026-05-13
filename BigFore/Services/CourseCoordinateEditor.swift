import CoreLocation
import Foundation
import SwiftData

enum CourseCoordinateEditorError: LocalizedError, Equatable {
    case invalidLatitude
    case invalidLongitude

    var errorDescription: String? {
        switch self {
        case .invalidLatitude:
            "Latitude must be a number from -90 to 90."
        case .invalidLongitude:
            "Longitude must be a number from -180 to 180."
        }
    }
}

struct CourseCoordinateEditor {
    nonisolated init() {}

    nonisolated func coordinate(latitudeText: String, longitudeText: String) throws -> CLLocationCoordinate2D {
        let trimmedLatitude = latitudeText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLongitude = longitudeText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let latitude = Double(trimmedLatitude), (-90...90).contains(latitude) else {
            throw CourseCoordinateEditorError.invalidLatitude
        }

        guard let longitude = Double(trimmedLongitude), (-180...180).contains(longitude) else {
            throw CourseCoordinateEditorError.invalidLongitude
        }

        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    @MainActor
    func save(latitudeText: String, longitudeText: String, for course: GolfCourse, modelContext: ModelContext) throws {
        let coordinate = try coordinate(latitudeText: latitudeText, longitudeText: longitudeText)
        course.latitude = coordinate.latitude
        course.longitude = coordinate.longitude
        try modelContext.save()
    }

    @MainActor
    func clearCoordinates(for course: GolfCourse, modelContext: ModelContext) throws {
        course.latitude = nil
        course.longitude = nil
        try modelContext.save()
    }
}
