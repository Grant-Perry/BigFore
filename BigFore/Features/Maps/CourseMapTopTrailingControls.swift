import SwiftUI

struct CourseMapTopTrailingControls: View {
    let courseMapViewModel: CourseMapViewModel

    var body: some View {
        Button {
            courseMapViewModel.toggleGPS()
        } label: {
            passiveCompass
        }
        .buttonStyle(.plain)
        .accessibilityLabel(courseMapViewModel.isGPSCentered ? "Center on tee" : "Center on my GPS")
    }

    private var passiveCompass: some View {
        ZStack {
            Circle()
                .fill(.regularMaterial.opacity(0.62))
            Circle()
                .stroke(.secondary.opacity(0.35), lineWidth: 1)
            Image(systemName: "location.north.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(BigForeDesign.Palette.destructive)
                .rotationEffect(.degrees(-courseMapViewModel.cameraHeading))
            Text(compassText)
                .font(.caption2.weight(.black))
                .foregroundStyle(.primary)
                .offset(y: 11)
            Image(systemName: courseMapViewModel.isGPSCentered ? "location.fill" : "location")
                .font(.caption2.weight(.bold))
                .foregroundStyle(courseMapViewModel.isGPSCentered ? BigForeDesign.Palette.secondaryAction : .secondary)
                .offset(y: -11)
        }
        .frame(width: 44, height: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Compass")
        .accessibilityValue(compassText)
    }

    private var compassText: String {
        let heading = courseMapViewModel.cameraHeading
        switch heading {
        case 315...360, 0..<45:
            return "N"
        case 45..<135:
            return "E"
        case 135..<225:
            return "S"
        default:
            return "W"
        }
    }
}
