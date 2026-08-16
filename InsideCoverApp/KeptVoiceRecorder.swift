import AVFoundation
import Speech
import SwiftUI

/// Records a kept voice memo (.m4a) into the app-group container, to travel
/// alongside a page's dictated transcript. Small and self-contained: start,
/// stop, hand back the file URL. The microphone permission dictation already
/// requests covers this recorder too.
@MainActor
final class KeptVoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var elapsed: TimeInterval = 0
    private(set) var lastCadenceReceipt: VoiceCadenceReceipt?

    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var currentURL: URL?
    private var powerSamples: [Float] = []
    private let meterInterval: TimeInterval = 0.2

    /// Begin recording. Returns false if the recorder could not start.
    @discardableResult
    func start() -> Bool {
        guard !isRecording else { return true }
        let base = InsideCoverStore.containerURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("kept-voice-\(UUID().uuidString).m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else { return false }
            self.recorder = recorder
            self.currentURL = url
            self.lastCadenceReceipt = nil
            self.powerSamples = []
            isRecording = true
            elapsed = 0
            timer = Timer.scheduledTimer(withTimeInterval: meterInterval, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self, let recorder = self.recorder else { return }
                    recorder.updateMeters()
                    self.powerSamples.append(recorder.averagePower(forChannel: 0))
                    self.elapsed = recorder.currentTime
                }
            }
            return true
        } catch {
            return false
        }
    }

    /// Stop recording and return the finished file URL, or nil if nothing was
    /// captured.
    @discardableResult
    func stop() -> URL? {
        timer?.invalidate()
        timer = nil
        guard isRecording, let recorder else {
            isRecording = false
            return nil
        }
        recorder.updateMeters()
        powerSamples.append(recorder.averagePower(forChannel: 0))
        let duration = max(elapsed, recorder.currentTime)
        recorder.stop()
        lastCadenceReceipt = VoiceCadenceReceipt.analyze(
            decibels: powerSamples,
            sampleInterval: meterInterval,
            duration: duration
        )
        self.recorder = nil
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return currentURL
    }

    /// Discard the current recording and delete its file.
    func discard() {
        _ = stop()
        if let url = currentURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentURL = nil
        elapsed = 0
        powerSamples = []
        lastCadenceReceipt = nil
    }
}

/// Reads a finished kept recording with Apple's on-device speech recognizer.
/// The recording remains the authority; this small transcript is a local,
/// derived reading that lets the Book quote and answer the reader's spoken
/// words without sending the voice file through a model or a server.
@MainActor
enum KeptVoiceTranscriber {
    static let transcriptMetadataKey = BookPageMediaAsset.voiceTranscriptMetadataKey
    static let provenanceMetadataKey = BookPageMediaAsset.voiceTranscriptProvenanceMetadataKey
    static let provenance = BookPageMediaAsset.onDeviceSpeechTranscriptProvenance

    static func transcript(at url: URL) async -> String? {
        guard await speechRecognitionIsAuthorized(),
              let recognizer = SFSpeechRecognizer(locale: .current),
              recognizer.isAvailable,
              recognizer.supportsOnDeviceRecognition else {
            return nil
        }

        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = true
        request.taskHint = .dictation

        return await withCheckedContinuation { continuation in
            let completion = KeptVoiceTranscriptionCompletion(continuation: continuation)
            completion.task = recognizer.recognitionTask(with: request) { result, error in
                Task { @MainActor in
                    if let result, result.isFinal {
                        completion.finish(with: result.bestTranscription.formattedString)
                    } else if error != nil {
                        completion.finish(with: nil)
                    }
                }
            }
            // Speech can occasionally stay available without delivering a
            // final result. Never leave the Keep button waiting on it.
            Task { @MainActor [weak completion] in
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                completion?.finish(with: nil)
            }
        }
    }

    private static func speechRecognitionIsAuthorized() async -> Bool {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            return true
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status == .authorized)
                }
            }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}

@MainActor
private final class KeptVoiceTranscriptionCompletion {
    let continuation: CheckedContinuation<String?, Never>
    var task: SFSpeechRecognitionTask?
    private var didResume = false

    init(continuation: CheckedContinuation<String?, Never>) {
        self.continuation = continuation
    }

    func finish(with rawTranscript: String?) {
        guard !didResume else { return }
        didResume = true
        task?.cancel()
        task = nil
        let transcript = rawTranscript?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        continuation.resume(returning: transcript)
    }
}
