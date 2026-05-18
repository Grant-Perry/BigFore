import SwiftUI

struct CourseMapMeasuredPointAnnotation: View {
    let courseMapViewModel: CourseMapViewModel
    @Binding var isDeleteVisible: Bool

    var body: some View {
        HStack(spacing: BigForeDesign.Spacing.xSmall) {
            Button {
                isDeleteVisible.toggle()
                if let measuredCoordinate = courseMapViewModel.measuredCoordinate {
                    courseMapViewModel.selectMapInfo(title: "Measured Point", coordinate: measuredCoordinate)
                }
            } label: {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, BigForeDesign.Palette.mapPin)
                    .shadow(radius: 2)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Measured point")
            .accessibilityHint("Shows the delete measured point button.")

            if isDeleteVisible {
                Button(role: .destructive) {
                    courseMapViewModel.deleteMeasuredPoint()
                    isDeleteVisible = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, BigForeDesign.Palette.destructive)
                        .shadow(radius: 2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete measured point")
            }
        }
    }
}
