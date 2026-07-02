import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UIKit)
import UIKit
#endif

struct CustomCastMemberDraft: Equatable {
    var name: String
    var kind: NarrativeEntityKind
    var meaning: String
    var description: String
    var traits: [String]
    var beliefs: [String]
    var goals: [String]
    var tags: [String]
    var imageData: Data?
    var startingGlow: Int?
}

struct CustomCastMemberSheet: View {
    let onSave: (CustomCastMemberDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var kind: NarrativeEntityKind = .object
    @State private var meaning = ""
    @State private var description = ""
    @State private var traits = ""
    @State private var beliefs = ""
    @State private var goals = ""
    @State private var tags = ""
    @State private var imageData: Data?
    @State private var imageMessage = "Optional. A photo can make this Cast Member easier for the Book to remember."
    @State private var isCameraPresented = false
    #if canImport(PhotosUI)
    @State private var selectedPhotoItem: PhotosPickerItem?
    #endif

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        (!description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || imageData != nil)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BookBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        field("What is it called?", text: $name, prompt: "A name the Book can put on the shelf.")
                        kindPicker
                        editor(
                            "What does this entry mean to you?",
                            text: $meaning,
                            prompt: "Why does it deserve Belief? What should the game understand about it?",
                            minHeight: 120
                        )
                        editor(
                            "State what it is.",
                            text: $description,
                            prompt: "Describe the person, object, place, idea, talisman, habit, or presence.",
                            minHeight: 110
                        )
                        photoPicker
                        field("What traits should the Book remember?", text: $traits, prompt: "Comma separated. Warm, stubborn, protective...")
                        field("What does it believe?", text: $beliefs, prompt: "Comma separated or one sentence.")
                        field("What does it want?", text: $goals, prompt: "Comma separated or one sentence.")
                        field("Tags for surfacing", text: $tags, prompt: "Comma separated. music, home, courage...")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 44)
                }
            }
            .navigationTitle("New Cast Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Give Belief") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            #if canImport(PhotosUI)
            .onChange(of: selectedPhotoItem) { _, newValue in
                guard let newValue else { return }
                Task { await loadPhoto(from: newValue) }
            }
            #endif
            .keepsFocusedTextInputVisible()
        }
    }

    private var draft: CustomCastMemberDraft {
        CustomCastMemberDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            kind: kind,
            meaning: meaning.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            traits: splitList(traits),
            beliefs: splitList(beliefs),
            goals: splitList(goals),
            tags: splitList(tags),
            imageData: imageData,
            startingGlow: nil
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Give Belief to something new", systemImage: "sparkle.magnifyingglass")
                .font(.headline.weight(.bold))
                .foregroundStyle(BookPalette.lampGold)
            Text("The Book will add it to the Cast, the World Register, and the Belief menu. High Glow helps it surface, but low Glow never disappears entirely.")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(BookPalette.nightText.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(BookPalette.nightPanel.opacity(0.52), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(BookPalette.lampGold.opacity(0.22), lineWidth: 1)
        }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What kind of Cast Member is it?")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
            Picker("Kind", selection: $kind) {
                Text("Person").tag(NarrativeEntityKind.character)
                Text("Object").tag(NarrativeEntityKind.object)
                Text("Place").tag(NarrativeEntityKind.location)
                Text("Motif").tag(NarrativeEntityKind.motif)
                Text("Talisman").tag(NarrativeEntityKind.talisman)
            }
            .pickerStyle(.segmented)
        }
    }

    @ViewBuilder
    private var photoPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Photo")
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.78))

            HStack(spacing: 12) {
                photoPreview

                VStack(alignment: .leading, spacing: 8) {
                    Text(imageMessage)
                        .font(.caption)
                        .foregroundStyle(BookPalette.nightText.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                    #if canImport(PhotosUI)
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                        Label(imageData == nil ? "Choose photo" : "Change photo", systemImage: "photo")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.bordered)
                    .tint(BookPalette.teal)
                    #endif
                    #if canImport(UIKit)
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            isCameraPresented = true
                        } label: {
                            Label(imageData == nil ? "Take photo" : "Retake photo", systemImage: "camera")
                                .font(.caption.weight(.bold))
                        }
                        .buttonStyle(.bordered)
                        .tint(BookPalette.lampGold)
                    }
                    #endif
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        #if canImport(UIKit)
        .fullScreenCover(isPresented: $isCameraPresented) {
            BookCameraCaptureView { data in
                imageData = data
                imageMessage = "Photo taken. The Book will keep a private local copy."
            }
            .ignoresSafeArea()
        }
        #endif
    }

    @ViewBuilder
    private var photoPreview: some View {
        if let image {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 82, height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ZStack {
                BookPalette.paper.opacity(0.18)
                Image(systemName: "photo")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(BookPalette.nightText.opacity(0.48))
            }
            .frame(width: 82, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var image: Image? {
        #if canImport(UIKit)
        guard let imageData, let uiImage = UIImage(data: imageData) else { return nil }
        return Image(uiImage: uiImage)
        #else
        return nil
        #endif
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
            TextField(prompt, text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .foregroundStyle(BookPalette.ink)
                .dictationInput(text: text)
                .padding(12)
                .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func editor(_ title: String, text: Binding<String>, prompt: String, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(BookPalette.nightText.opacity(0.78))
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(prompt)
                        .font(.body)
                        .foregroundStyle(BookPalette.ink.opacity(0.42))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                }
                TextEditor(text: text)
                    .font(.body)
                    .foregroundStyle(BookPalette.ink)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(minHeight: minHeight)
                    .dictationInput(text: text)
            }
            .background(BookPalette.page, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func splitList(_ value: String) -> [String] {
        value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    #if canImport(PhotosUI)
    @MainActor
    private func loadPhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            imageMessage = "The photo did not open. Try another one."
            return
        }
        imageData = data
        imageMessage = "Photo chosen. The Book will keep a private local copy."
    }
    #endif
}
