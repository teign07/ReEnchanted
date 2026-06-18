import AVFoundation
import Speech
import SwiftUI

@MainActor
final class DictationInputModel: ObservableObject {
    enum State: Equatable {
        case idle
        case requesting
        case listening
        case unavailable(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript = ""

    private let recognizer = SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    var isListening: Bool {
        state == .listening
    }

    func start() {
        guard !isListening else { return }
        state = .requesting
        transcript = ""

        Task {
            let speechAllowed = await requestSpeechAuthorization()
            guard speechAllowed else {
                state = .unavailable("Speech recognition is not allowed.")
                return
            }

            let micAllowed = await requestMicrophoneAuthorization()
            guard micAllowed else {
                state = .unavailable("Microphone access is not allowed.")
                return
            }

            do {
                try beginRecognition()
            } catch {
                state = .unavailable("The microphone could not start.")
                stop()
            }
        }
    }

    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        request = nil
        if case .unavailable = state {
            return
        }
        state = .idle
    }

    private func beginRecognition() throws {
        stop()

        guard recognizer?.isAvailable == true else {
            state = .unavailable("Speech recognition is unavailable right now.")
            return
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
        state = .listening

        task = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                if error != nil || result?.isFinal == true {
                    self.stop()
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { allowed in
                continuation.resume(returning: allowed)
            }
        }
    }
}

private struct DictationInputModifier: ViewModifier {
    @Binding var text: String
    let alignment: Alignment

    @StateObject private var model = DictationInputModel()
    @State private var baseText = ""

    func body(content: Content) -> some View {
        content
            .padding(.trailing, 34)
            .overlay(alignment: alignment) {
                Button {
                    if model.isListening {
                        model.stop()
                    } else {
                        baseText = text
                        BookFeedback.play(.tap)
                        model.start()
                    }
                } label: {
                    Image(systemName: model.isListening ? "mic.fill" : "mic")
                        .font(.caption.weight(.bold))
                        .symbolEffect(.pulse, isActive: model.isListening)
                        .frame(width: 28, height: 28)
                        .foregroundStyle(model.isListening ? BookPalette.lampGold : BookPalette.ink.opacity(0.56))
                        .background(BookPalette.page.opacity(0.72), in: Circle())
                        .overlay {
                            Circle()
                                .stroke(model.isListening ? BookPalette.lampGold.opacity(0.72) : BookPalette.ink.opacity(0.14), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(model.isListening ? "Stop voice input" : "Start voice input")
                .padding(6)
            }
            .onChange(of: model.transcript) { _, transcript in
                guard model.isListening, !transcript.isEmpty else { return }
                text = Self.append(transcript, to: baseText)
            }
            .onDisappear {
                model.stop()
            }
    }

    private static func append(_ transcript: String, to base: String) -> String {
        let cleanBase = base.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBase.isEmpty else { return transcript }
        return "\(cleanBase) \(transcript)"
    }
}

extension View {
    func dictationInput(text: Binding<String>, alignment: Alignment = .bottomTrailing) -> some View {
        modifier(DictationInputModifier(text: text, alignment: alignment))
    }
}
