import SwiftUI

struct CourseMapShotBallMarkerView: View {
    let shotNumber: Int
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(BigForeDesign.Palette.ball)
                .frame(width: 32, height: 32)
                .overlay {
                    Circle()
                        .stroke(isSelected ? .white : .clear, lineWidth: 3)
                }
                .shadow(radius: 2)

            Text("\(shotNumber)")
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(.white)
        }
        .frame(width: 44, height: 44)
        .accessibilityLabel("Shot \(shotNumber) ball marker")
    }
}
