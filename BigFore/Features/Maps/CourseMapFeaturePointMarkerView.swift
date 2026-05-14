import SwiftUI

struct CourseMapFeaturePointMarkerView: View {
    let featurePoint: CourseMapFeaturePoint

    var body: some View {
        if featurePoint.kind == .hazard {
            CourseMapSymbolMarker(
                systemImage: featurePoint.kind.mapSystemImage,
                tint: featurePoint.kind.mapTint,
                size: 24
            )
        } else {
            VStack(spacing: BigForeDesign.Spacing.xSmall) {
                CourseMapSymbolMarker(
                    systemImage: featurePoint.kind.mapSystemImage,
                    tint: featurePoint.kind.mapTint
                )

                Text(featurePoint.markerTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .shadow(color: .white.opacity(0.8), radius: 1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
    }
}
