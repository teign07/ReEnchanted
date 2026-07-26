import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let noteField = UITextField()
    private let statusLabel = UILabel()
    private let keepButton = UIButton(type: .system)
    private var draft: ExternalShareCapture?
    private var isSaving = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.055, green: 0.047, blue: 0.075, alpha: 1)
        configureInterface()
        Task { await loadSharedMaterial() }
    }

    private func configureInterface() {
        let title = UILabel()
        title.text = "Press into the Book"
        title.textColor = UIColor(red: 0.94, green: 0.81, blue: 0.48, alpha: 1)
        title.font = .preferredFont(forTextStyle: .title2)

        statusLabel.text = "Gathering the scrap…"
        statusLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.numberOfLines = 2

        noteField.placeholder = "What caught you?  Optional."
        noteField.textColor = .white
        noteField.attributedPlaceholder = NSAttributedString(
            string: noteField.placeholder ?? "",
            attributes: [.foregroundColor: UIColor.white.withAlphaComponent(0.42)]
        )
        noteField.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        noteField.layer.cornerRadius = 12
        noteField.setLeftPadding(12)
        noteField.setRightPadding(12)
        noteField.returnKeyType = .done
        noteField.delegate = self

        var configuration = UIButton.Configuration.filled()
        configuration.title = "Keep in the Book"
        configuration.baseBackgroundColor = UIColor(red: 0.58, green: 0.39, blue: 0.17, alpha: 1)
        configuration.baseForegroundColor = .white
        configuration.cornerStyle = .large
        keepButton.configuration = configuration
        keepButton.isEnabled = false
        keepButton.addTarget(self, action: #selector(saveAndClose), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [title, statusLabel, noteField, keepButton])
        stack.axis = .vertical
        stack.spacing = 15
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            noteField.heightAnchor.constraint(equalToConstant: 48),
            keepButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }

    private func loadSharedMaterial() async {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else {
            await fail("The scrap would not come loose.")
            return
        }
        do {
            let capture = try await ExternalShareExtractor.extract(from: inputItems)
            await MainActor.run {
                draft = capture
                statusLabel.text = capture.title.nonEmpty
                    ?? capture.sourceName.nonEmpty
                    ?? "Ready to press between the pages."
                keepButton.isEnabled = true
            }
        } catch {
            await fail("The Book could not read this share.")
        }
    }

    @objc private func saveAndClose() {
        guard !isSaving, var capture = draft else { return }
        isSaving = true
        keepButton.isEnabled = false
        capture.readerNote = noteField.text ?? ""
        do {
            guard let baseURL = ExternalShareInbox.baseURL() else {
                throw CocoaError(.fileNoSuchFile)
            }
            try ExternalShareInbox.enqueue(capture, at: baseURL)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            statusLabel.text = "Pressed into the Book."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        } catch {
            isSaving = false
            keepButton.isEnabled = true
            statusLabel.text = "The page slipped. Try once more."
        }
    }

    private func fail(_ message: String) async {
        await MainActor.run {
            statusLabel.text = message
            keepButton.isEnabled = false
        }
    }
}

extension ShareViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        saveAndClose()
        return true
    }
}

private enum ExternalShareExtractor {
    static func extract(from items: [NSExtensionItem]) async throws -> ExternalShareCapture {
        let captureID = UUID().uuidString
        guard let baseURL = ExternalShareInbox.baseURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let assetDirectory = try ExternalShareInbox.assetDirectory(for: captureID, at: baseURL)
        var urls: [URL] = []
        var texts: [String] = []
        var attachments: [ExternalShareCapture.Attachment] = []
        var suggestedTitle = items.compactMap(\.attributedTitle?.string.nonEmpty).first ?? ""

        for item in items {
            if let text = item.attributedContentText?.string.nonEmpty {
                texts.append(text)
            }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let value = try? await provider.loadSharedURL() {
                    urls.append(value)
                    continue
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let value = try? await provider.loadSharedText(),
                   let value = value.nonEmpty {
                    texts.append(value)
                    continue
                }
                if let attachment = try await copyAttachment(
                    provider,
                    captureID: captureID,
                    directory: assetDirectory,
                    baseURL: baseURL
                ) {
                    attachments.append(attachment)
                }
            }
        }

        let url = urls.first
        let source = url?.host?.replacingOccurrences(of: "www.", with: "") ?? ""
        if suggestedTitle.isEmpty {
            suggestedTitle = texts.first?.split(separator: "\n").first.map(String.init) ?? source
        }
        let kind: ExternalShareCapture.Kind
        let kinds = Set(attachments.map(\.kind))
        if url != nil && (!texts.isEmpty || !attachments.isEmpty) {
            kind = .mixed
        } else if url != nil {
            kind = .link
        } else if kinds.contains(.image) {
            kind = attachments.count == 1 && texts.isEmpty ? .image : .mixed
        } else if !attachments.isEmpty {
            kind = attachments.count == 1 && texts.isEmpty ? .file : .mixed
        } else {
            kind = .text
        }
        let capture = ExternalShareCapture(
            id: captureID,
            kind: kind,
            title: suggestedTitle,
            text: texts.joined(separator: "\n\n"),
            url: url?.absoluteString,
            sourceName: source,
            attachments: attachments,
            wasRecentlyPromptedByBook: ExternalSharePromptClock.wasRecentlyPrompted()
        )
        guard !capture.archiveText.isEmpty || !attachments.isEmpty else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return capture
    }

    private static func copyAttachment(
        _ provider: NSItemProvider,
        captureID: String,
        directory: URL,
        baseURL: URL
    ) async throws -> ExternalShareCapture.Attachment? {
        let candidates: [(UTType, ExternalShareCapture.Kind)] = [
            (.image, .image),
            (.movie, .file),
            (.audio, .file),
            (.pdf, .file),
            (.data, .file)
        ]
        guard let candidate = candidates.first(where: {
            provider.hasItemConformingToTypeIdentifier($0.0.identifier)
        }) else { return nil }
        let filename = ExternalShareInbox.safeComponent(
            provider.suggestedName?.nonEmpty ?? UUID().uuidString
        )
        let ext = candidate.0.preferredFilenameExtension ?? "data"
        let destination = directory.appendingPathComponent("\(filename).\(ext)")
        // Provider file URLs are only promised to live for the duration of
        // this callback. Copy while the lease is valid, then resume.
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: candidate.0.identifier) { loaded, error in
                do {
                    if let error { throw error }
                    guard let loaded else { throw CocoaError(.fileReadCorruptFile) }
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    try FileManager.default.copyItem(at: loaded, to: destination)
                    let relative = destination.path.replacingOccurrences(of: baseURL.path + "/", with: "")
                    continuation.resume(returning: ExternalShareCapture.Attachment(
                        kind: candidate.1,
                        relativePath: relative,
                        typeIdentifier: candidate.0.identifier,
                        originalFilename: provider.suggestedName
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

private extension NSItemProvider {
    func loadSharedURL() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.url.identifier) {
                value, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let url = value as? URL {
                    continuation.resume(returning: url)
                } else if let text = value as? String, let url = URL(string: text) {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadCorruptFile))
                }
            }
        }
    }

    func loadSharedText() async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            loadItem(forTypeIdentifier: UTType.plainText.identifier) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let text = value as? String {
                    continuation.resume(returning: text)
                } else if let text = value as? NSString {
                    continuation.resume(returning: text as String)
                } else if let url = value as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else {
                    continuation.resume(throwing: CocoaError(.fileReadCorruptFile))
                }
            }
        }
    }

    func loadFileRepresentation(forTypeIdentifier identifier: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: identifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url {
                    continuation.resume(returning: url)
                } else {
                    continuation.resume(throwing: CocoaError(.fileNoSuchFile))
                }
            }
        }
    }
}

private extension UITextField {
    func setLeftPadding(_ amount: CGFloat) {
        let spacer = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))
        leftView = spacer
        leftViewMode = .always
    }

    func setRightPadding(_ amount: CGFloat) {
        let spacer = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))
        rightView = spacer
        rightViewMode = .always
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
