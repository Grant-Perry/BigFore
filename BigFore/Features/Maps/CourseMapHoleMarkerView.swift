import SwiftUI

struct CourseMapHoleMarkerView: View {
    let marker: CourseMapHoleMarker

    var body: some View {
        ZStack {
            Image(marker.kind.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 58)
                .shadow(radius: 2)

            Text("\(marker.holeNumber)")
                .font(.title3.weight(.black))
                .monospacedDigit()
                .tracking(-1.0)
                .foregroundStyle(.black)
                .minimumScaleFactor(0.65)
                .offset(y: -9)
        }
        .scaleEffect(0.75)
        .accessibilityLabel(marker.kind == .tee ? "Tee box \(marker.holeNumber)" : "Pin \(marker.holeNumber)")
    }
}
