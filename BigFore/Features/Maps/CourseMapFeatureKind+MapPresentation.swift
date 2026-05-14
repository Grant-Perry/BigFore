import SwiftUI

extension CourseMapFeatureKind {
    var mapSystemImage: String {
        switch self {
        case .teeBox:
            "figure.golf"
        case .greenPin:
            "flag.fill"
        case .dogleg:
            "arrow.turn.up.right"
        case .hazard:
            "exclamationmark.triangle"
        case .layup:
            "flag.checkered"
        case .target:
            "scope"
        }
    }

    var mapTint: Color {
        switch self {
        case .teeBox:
            BigForeDesign.Palette.tee
        case .greenPin:
            BigForeDesign.Palette.holePin
        case .dogleg:
            BigForeDesign.Palette.dogleg
        case .hazard:
            BigForeDesign.Palette.hazard
        case .layup:
            BigForeDesign.Palette.hazard
        case .target:
            BigForeDesign.Palette.target
        }
    }
}
