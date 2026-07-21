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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model = DictationInputModel()
    @State private var baseText = ""

    func body(content: Content) -> some View {
        content
            .padding(.trailing, 38)
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
                    DictationVoiceControl(state: model.state, reduceMotion: reduceMotion)
                }
                .buttonStyle(.bookPress(scale: 0.9, playsHaptic: false))
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

/// The microphone changes mode visibly instead of leaving the reader to infer
/// state from a tiny filled symbol. While listening, a short ink meter occupies
/// the margin; when speech ends it folds back into the ordinary mic button.
private struct DictationVoiceControl: View {
    let state: DictationInputModel.State
    let reduceMotion: Bool

    private var isListening: Bool { state == .listening }
    private var isExpanded: Bool { state != .idle }

    private var status: String? {
        switch state {
        case .idle: return nil
        case .requesting: return "Waking…"
        case .listening: return "Listening"
        case .unavailable: return "Mic unavailable"
        }
    }

    private var symbol: String {
        switch state {
        case .idle: return "mic"
        case .requesting: return "ellipsis"
        case .listening: return "mic.fill"
        case .unavailable: return "exclamationmark"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            if isExpanded {
                BookVoiceInkMeter(active: isListening, reduceMotion: reduceMotion)
                    .transition(BookMotion.riseTransition(reduceMotion: reduceMotion))

                if let status {
                    Text(status)
                        .font(.caption2.weight(.bold))
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }

            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .symbolEffect(.pulse, isActive: isListening && !reduceMotion)
                .frame(width: 20, height: 20)
        }
        .foregroundStyle(isListening ? BookPalette.lampGold : BookPalette.ink.opacity(0.64))
        .padding(.horizontal, isExpanded ? 9 : 4)
        .frame(minWidth: 28, minHeight: 28)
        .background(BookPalette.page.opacity(0.94), in: Capsule())
        .overlay {
            Capsule()
                .stroke(
                    isListening ? BookPalette.lampGold.opacity(0.78) : BookPalette.ink.opacity(0.16),
                    lineWidth: 1
                )
        }
        .shadow(
            color: isListening ? BookPalette.lampGold.opacity(0.22) : .clear,
            radius: 10
        )
        .animation(BookMotion.direct(reduceMotion), value: state)
    }
}

struct BookVoiceInkMeter: View {
    let active: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.09, paused: !active || reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    let wave = abs(sin(time * 7.4 + Double(index) * 1.45))
                    Capsule()
                        .frame(width: 2, height: active && !reduceMotion ? 4 + wave * 10 : 5)
                }
            }
            .frame(width: 16, height: 16)
        }
        .foregroundStyle(BookPalette.lampGold)
        .accessibilityHidden(true)
    }
}

extension View {
    func dictationInput(text: Binding<String>, alignment: Alignment = .bottomTrailing) -> some View {
        modifier(DictationInputModifier(text: text, alignment: alignment))
    }
}
