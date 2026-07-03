import AVFoundation
import SwiftUI

/// A small "phonograph" chip that plays back a kept voice recording on a page.
/// Tap to play, tap again to stop. Self-contained AVAudioPlayer.
struct KeptVoicePlaybackChip: View {
    let filePath: String

    @StateObject private var player = KeptVoicePlayer()

    var body: some View {
        Button {
            player.toggle(path: filePath)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: player.isPlaying ? "stop.fill" : "play.fill")
                    .font(.caption.weight(.bold))
                Text(player.isPlaying ? "Playing your voice…" : "Hear your voice")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(BookPalette.lampGold)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(BookPalette.page.opacity(0.72), in: Capsule())
            .overlay {
                Capsule().stroke(BookPalette.lampGold.opacity(0.4), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onDisappear { player.stop() }
        .accessibilityLabel(player.isPlaying ? "Stop playing your voice" : "Play your kept voice")
    }
}

@MainActor
private final class KeptVoicePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    private var player: AVAudioPlayer?

    func toggle(path: String) {
        if isPlaying {
            stop()
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let player = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
            player.delegate = self
            guard player.play() else { return }
            self.player = player
            isPlaying = true
            BookFeedback.play(.openPage)
        } catch {
            isPlaying = false
        }
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.stop() }
    }
}
