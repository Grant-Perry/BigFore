import SwiftUI
import UIKit

struct ProfileImageCropView: View {
    let image: UIImage
    let onSave: (UIImage) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: BigForeDesign.Spacing.large) {
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)

                    ZStack {
                        Color.black.opacity(0.92)

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: side, height: side)
                            .scaleEffect(scale)
                            .offset(offset)
                            .clipShape(Circle())
                            .gesture(dragGesture)
                            .simultaneousGesture(magnificationGesture)

                        Circle()
                            .stroke(.white, lineWidth: 2)
                            .frame(width: side, height: side)
                            .allowsHitTesting(false)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(height: 360)

                Text("Move and pinch to frame your profile photo.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(croppedImage())
                        dismiss()
                    }
                }
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), 4)
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private func croppedImage() -> UIImage {
        let side = min(image.size.width, image.size.height)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side))

        return renderer.image { context in
            let cgContext = context.cgContext
            let rect = CGRect(origin: .zero, size: CGSize(width: side, height: side))
            cgContext.addEllipse(in: rect)
            cgContext.clip()

            let drawSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let origin = CGPoint(
                width: (side - drawSize.width) / 2 + offset.width * scale,
                height: (side - drawSize.height) / 2 + offset.height * scale
            )
            image.draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}

private extension CGPoint {
    init(width: CGFloat, height: CGFloat) {
        self.init(x: width, y: height)
    }
}
