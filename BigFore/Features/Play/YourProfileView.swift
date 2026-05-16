import SwiftData
import SwiftUI
import UIKit

struct YourProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var profile: PlayerProfile
    @State private var handicapText: String
    @State private var isAvatarSourceDialogPresented = false
    @State private var selectedImageSource: ProfileImageSource?
    @State private var imagePendingCrop: ProfileImageCropItem?
    @State private var isExistingImageEditorPresented = false

    init(profile: PlayerProfile) {
        self.profile = profile
        _handicapText = State(initialValue: profile.handicapIndex.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "")
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: BigForeDesign.Spacing.medium) {
                    Button {
                        isAvatarSourceDialogPresented = true
                    } label: {
                        VStack(spacing: BigForeDesign.Spacing.small) {
                            EditableProfileAvatar(profile: profile, size: 104)
                            Text(profile.avatarImageData == nil ? "Add Photo" : "Edit Photo")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(BigForeDesign.Palette.primaryAction)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(profile.avatarImageData == nil ? "Add profile photo" : "Edit profile photo")

                    Text("Your Profile")
                        .font(.title3.bold())
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("Player") {
                TextField("Display name", text: $profile.displayName)
                    .textInputAutocapitalization(.words)
                    .onChange(of: profile.displayName) {
                        touchAndSave()
                    }

                TextField("Phone number", text: Binding(
                    get: { profile.phoneNumber ?? "" },
                    set: { profile.phoneNumber = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.phonePad)
                .onChange(of: profile.phoneNumber) {
                    touchAndSave()
                }

                TextField("Email address", text: Binding(
                    get: { profile.emailAddress ?? "" },
                    set: { profile.emailAddress = $0.isEmpty ? nil : $0 }
                ))
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: profile.emailAddress) {
                    touchAndSave()
                }

                TextField("Handicap Index", text: $handicapText)
                    .keyboardType(.decimalPad)
                    .onChange(of: handicapText) {
                        profile.handicapIndex = Double(handicapText.trimmingCharacters(in: .whitespacesAndNewlines))
                        touchAndSave()
                    }
            }

            Section("Golf") {
                TextField("Home course", text: Binding(
                    get: { profile.homeCourseName ?? "" },
                    set: { profile.homeCourseName = $0.isEmpty ? nil : $0 }
                ))
                .textInputAutocapitalization(.words)
                .onChange(of: profile.homeCourseName) {
                    touchAndSave()
                }

                TextField("Notes", text: $profile.notes, axis: .vertical)
                    .lineLimit(2...4)
                    .onChange(of: profile.notes) {
                        touchAndSave()
                    }
            }
        }
        .navigationTitle("Your Profile")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Profile Photo", isPresented: $isAvatarSourceDialogPresented, titleVisibility: .visible) {
            if profile.avatarImageData != nil {
                Button("Edit Current Photo") {
                    isExistingImageEditorPresented = true
                }
            }

            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") {
                    selectedImageSource = .camera
                }
            }

            Button("Choose From Library") {
                selectedImageSource = .photoLibrary
            }

            if profile.avatarImageData != nil {
                Button("Remove Photo", role: .destructive) {
                    profile.avatarImageData = nil
                    profile.avatarSource = .none
                    touchAndSave()
                }
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("After choosing a photo, move and scale it in the crop editor before saving.")
        }
        .sheet(item: $selectedImageSource) { source in
            ProfileImagePicker(sourceType: source.sourceType) { image in
                imagePendingCrop = ProfileImageCropItem(image: image)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $imagePendingCrop) { item in
            ProfileImageCropView(image: item.image) { croppedImage in
                saveProfileImage(croppedImage, source: selectedImageSource ?? .photoLibrary)
                selectedImageSource = nil
            }
        }
        .sheet(isPresented: $isExistingImageEditorPresented) {
            if let image = currentProfileImage {
                ProfileImageCropView(image: image) { croppedImage in
                    saveProfileImage(croppedImage, source: profile.avatarSource == .camera ? .camera : .photoLibrary)
                }
            }
        }
    }

    private func touchAndSave() {
        profile.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
        }
    }

    private func saveProfileImage(_ image: UIImage, source: ProfileImageSource) {
        let targetSide: CGFloat = 512
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: targetSide, height: targetSide))
        let scaledImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: CGSize(width: targetSide, height: targetSide)))
        }

        profile.avatarImageData = scaledImage.jpegData(compressionQuality: 0.86)
        profile.avatarSource = source == .camera ? .camera : .photoLibrary
        touchAndSave()
    }

    private var currentProfileImage: UIImage? {
        guard let data = profile.avatarImageData else {
            return nil
        }

        return UIImage(data: data)
    }
}

private struct ProfileImageCropItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

private struct EditableProfileAvatar: View {
    let profile: PlayerProfile
    let size: CGFloat

    var body: some View {
        PlayerProfileAvatar(profile: profile, size: size)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: profile.avatarImageData == nil ? "camera.fill" : "pencil")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(BigForeDesign.Palette.primaryAction, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 3)
                    }
                    .offset(x: 8, y: 8)
                    .accessibilityHidden(true)
            }
            .padding(10)
    }
}

struct PlayerProfileAvatar: View {
    let profile: PlayerProfile?
    let size: CGFloat

    var body: some View {
        Group {
            if let imageData = profile?.avatarImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(BigForeDesign.Gradients.cardFill)

                    Text(initials)
                        .font(.system(size: max(size * 0.34, 18), weight: .bold, design: .rounded))
                        .foregroundStyle(BigForeDesign.Palette.primaryAction)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(.white.opacity(0.55), lineWidth: 2)
        }
        .shadow(radius: 8, y: 4)
        .accessibilityHidden(true)
    }

    private var initials: String {
        guard let name = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else {
            return "BF"
        }

        let pieces = name.split(separator: " ")
        return pieces.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }
}
