#if DEBUG
import SwiftUI
import UIKit
import QuartzCore

// MARK: - Scroll smoothness probe
//
// A launch-argument harness for measuring how smoothly the surfaces around the
// Book scroll, with no finger on the glass and no debugger on the process:
//
//     --perf-scroll desk,glow-pages,shop,radio [--perf-idle 3] [--perf-scroll-seconds 6]
//
// For each named surface the app opens it the way the reader would, waits for
// the presentation to settle, finds the scroll view that surface put on screen,
// sits still for a moment, then scrolls it at a steady hand speed. It reports:
//
// - while idle: how often the main thread woke and how long it stayed awake.
//   A surface that is only being looked at should cost almost nothing, so a
//   high number here is a perpetual animation or a timer.
// - while scrolling: frames the main thread delivered late, as Apple's
//   hitch-time ratio (ms of lateness per second), the worst frame, and the
//   main thread's awake time per run-loop turn.
// - in both windows: how many times the large views re-ran `body`.
//
// It cannot see the render server. Offscreen passes, blurs and blend modes are
// paid in backboardd; for those use Instruments' Animation Hitches on a device.
//
// The report is printed, logged, and written to
// Library/Caches/perf-scroll-probe.txt so an unattached device run can be read
// back with `devicectl device copy from`. While a surface sits idle its label
// is written to Library/Caches/perf-scroll-probe-now.txt, so a script outside
// the app can take a screenshot of each surface as it comes up.

@MainActor
enum PerfProbeCounter {
    private(set) static var isCounting = false
    private static var counts: [String: Int] = [:]

    /// Call from a view's `body`. Free when no probe window is open.
    static func body(_ name: String) {
        guard isCounting else { return }
        counts[name, default: 0] += 1
    }

    static func begin() {
        counts = [:]
        isCounting = true
    }

    static func end() -> [String: Int] {
        isCounting = false
        return counts
    }
}

@MainActor
final class ScrollHitchProbe: NSObject {
    struct Report {
        var label: String
        var target: String
        var idleSeconds: Double
        var idleWakesPerSecond: Double
        var idleAwakeMSPerSecond: Double
        var idleBodies: [String: Int]
        var scrollSeconds: Double
        var frames: Int
        var lateFrames: Int
        var missedFrames: Int
        var hitchMSPerSecond: Double
        var worstFrameMS: Double
        var awakeMedianMS: Double
        var awakeP95MS: Double
        var awakeMaxMS: Double
        var mainThreadUtilisation: Double
        var scrollBodies: [String: Int]

        var line: String {
            func bodies(_ counts: [String: Int]) -> String {
                counts.isEmpty
                    ? "none"
                    : counts.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
            }
            let idle = String(
                format: "idle %.1fs: wakes/s=%.1f awake-ms/s=%.1f bodies[%@]",
                idleSeconds, idleWakesPerSecond, idleAwakeMSPerSecond, bodies(idleBodies)
            )
            guard frames > 0 else {
                return "PERF \(label) | \(idle) | scroll skipped | target \(target)"
            }
            let scroll = String(
                format: "scroll %.1fs: frames=%d late=%d missed=%d hitch-ms/s=%.1f worst=%.1fms awake p50=%.2fms p95=%.2fms max=%.1fms main=%.0f%% bodies[%@]",
                scrollSeconds, frames, lateFrames, missedFrames, hitchMSPerSecond, worstFrameMS,
                awakeMedianMS, awakeP95MS, awakeMaxMS, mainThreadUtilisation * 100, bodies(scrollBodies)
            )
            return "PERF \(label) | \(idle) | \(scroll) | target \(target)"
        }
    }

    // MARK: Finding the scroll view

    static func scrollViews() -> [UIScrollView] {
        var found: [UIScrollView] = []
        func visit(_ view: UIView) {
            if let scroll = view as? UIScrollView { found.append(scroll) }
            for subview in view.subviews { visit(subview) }
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where !window.isHidden {
                visit(window)
            }
        }
        return found
    }

    private static func verticalTravel(_ scroll: UIScrollView) -> CGFloat {
        let inset = scroll.adjustedContentInset
        return scroll.contentSize.height + inset.top + inset.bottom - scroll.bounds.height
    }

    private static func visibleArea(_ scroll: UIScrollView) -> CGFloat {
        guard let window = scroll.window, scroll.alpha > 0.01 else { return 0 }
        var ancestor: UIView? = scroll
        while let view = ancestor {
            if view.isHidden || view.alpha < 0.01 { return 0 }
            ancestor = view.superview
        }
        let frame = scroll.convert(scroll.bounds, to: window).intersection(window.bounds)
        return frame.isNull ? 0 : frame.width * frame.height
    }

    /// The largest on-screen scroll view that can move, preferring ones that
    /// were not on screen before the surface was opened.
    static func target(excluding before: Set<ObjectIdentifier>) -> UIScrollView? {
        let candidates = scrollViews().filter {
            $0.isScrollEnabled && verticalTravel($0) > 40 && visibleArea($0) > 3_600
        }
        let fresh = candidates.filter { !before.contains(ObjectIdentifier($0)) }
        return (fresh.isEmpty ? candidates : fresh).max { visibleArea($0) < visibleArea($1) }
    }

    // MARK: Measuring

    private var link: CADisplayLink?
    private weak var scrollView: UIScrollView?
    private var observer: CFRunLoopObserver?
    private var awakeSince: CFAbsoluteTime = 0
    private var awakeSamples: [Double] = []
    private var startedAt: CFTimeInterval = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var scrollDuration: CFTimeInterval = 6
    private var frames = 0
    private var lateFrames = 0
    private var missedFrames = 0
    private var hitchTime: CFTimeInterval = 0
    private var worstFrame: CFTimeInterval = 0
    private var direction: CGFloat = 1
    private let pointsPerSecond: CGFloat = 1_400
    private var finished: CheckedContinuation<Void, Never>?

    /// Pass `scrolls: false` to measure a surface that is only looked at.
    static func measure(
        label: String,
        excluding before: Set<ObjectIdentifier>,
        scrolls: Bool = true,
        idleSeconds: Double = 2.5,
        scrollSeconds: Double = 6
    ) async -> Report? {
        let scroll = scrolls ? target(excluding: before) : nil
        if scrolls && scroll == nil { return nil }
        let probe = ScrollHitchProbe()
        return await probe.run(
            label: label,
            scroll: scroll,
            idleSeconds: idleSeconds,
            scrollSeconds: scrolls ? scrollSeconds : 0
        )
    }

    private func run(
        label: String,
        scroll: UIScrollView?,
        idleSeconds: Double,
        scrollSeconds: Double
    ) async -> Report {
        scrollView = scroll
        let description = scroll.map {
            "\(type(of: $0)) \(Int($0.bounds.width))x\(Int($0.bounds.height)) content=\(Int($0.contentSize.height))"
        } ?? "none"

        // Idle: the surface is open and nobody is touching it.
        Self.mark(label)
        startObservingRunLoop()
        PerfProbeCounter.begin()
        let idleStart = CFAbsoluteTimeGetCurrent()
        try? await Task.sleep(for: .seconds(idleSeconds))
        let idleElapsed = CFAbsoluteTimeGetCurrent() - idleStart
        let idleBodies = PerfProbeCounter.end()
        let idleSamples = stopObservingRunLoop()
        let idleAwake = idleSamples.reduce(0, +)
        Self.mark("")

        var scrollElapsed: Double = 0
        var scrollBodies: [String: Int] = [:]
        var samples: [Double] = []
        if scroll != nil, scrollSeconds > 0 {
            scrollDuration = scrollSeconds
            startObservingRunLoop()
            PerfProbeCounter.begin()
            let scrollStart = CFAbsoluteTimeGetCurrent()
            await withCheckedContinuation { continuation in
                finished = continuation
                let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
                link.add(to: .main, forMode: .common)
                self.link = link
            }
            scrollElapsed = CFAbsoluteTimeGetCurrent() - scrollStart
            scrollBodies = PerfProbeCounter.end()
            samples = stopObservingRunLoop().sorted()
        }

        func percentile(_ p: Double) -> Double {
            guard !samples.isEmpty else { return 0 }
            let index = min(samples.count - 1, Int((Double(samples.count - 1) * p).rounded()))
            return samples[index]
        }

        return Report(
            label: label,
            target: description,
            idleSeconds: idleElapsed,
            idleWakesPerSecond: Double(idleSamples.count) / max(0.001, idleElapsed),
            idleAwakeMSPerSecond: idleAwake / max(0.001, idleElapsed),
            idleBodies: idleBodies,
            scrollSeconds: scrollElapsed,
            frames: frames,
            lateFrames: lateFrames,
            missedFrames: missedFrames,
            hitchMSPerSecond: hitchTime * 1_000 / max(0.001, scrollElapsed),
            worstFrameMS: worstFrame * 1_000,
            awakeMedianMS: percentile(0.5),
            awakeP95MS: percentile(0.95),
            awakeMaxMS: samples.last ?? 0,
            mainThreadUtilisation: samples.reduce(0, +) / 1_000 / max(0.001, scrollElapsed),
            scrollBodies: scrollBodies
        )
    }

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp
        guard lastTimestamp > 0 else {
            lastTimestamp = now
            startedAt = now
            return
        }
        let nominal = link.duration > 0 ? link.duration : 1.0 / 60.0
        let interval = now - lastTimestamp
        lastTimestamp = now
        frames += 1

        let late = Int((interval / nominal).rounded()) - 1
        if late > 0 {
            lateFrames += 1
            missedFrames += late
            hitchTime += interval - nominal
        }
        worstFrame = max(worstFrame, interval)

        if let scrollView {
            let inset = scrollView.adjustedContentInset
            let top = -inset.top
            let bottom = max(top, scrollView.contentSize.height + inset.bottom - scrollView.bounds.height)
            var y = scrollView.contentOffset.y + direction * pointsPerSecond * CGFloat(interval)
            if y >= bottom {
                y = bottom
                direction = -1
            } else if y <= top {
                y = top
                direction = 1
            }
            scrollView.contentOffset = CGPoint(x: scrollView.contentOffset.x, y: y)
        }

        if now - startedAt >= scrollDuration || scrollView == nil {
            link.invalidate()
            self.link = nil
            finished?.resume()
            finished = nil
        }
    }

    private func startObservingRunLoop() {
        awakeSamples = []
        awakeSince = 0
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.afterWaiting.rawValue | CFRunLoopActivity.beforeWaiting.rawValue,
            true,
            0
        ) { [weak self] _, activity in
            MainActor.assumeIsolated {
                self?.noteRunLoop(activity)
            }
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        self.observer = observer
    }

    private func stopObservingRunLoop() -> [Double] {
        if let observer {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
        }
        observer = nil
        return awakeSamples
    }

    private func noteRunLoop(_ activity: CFRunLoopActivity) {
        let now = CFAbsoluteTimeGetCurrent()
        if activity == .afterWaiting {
            awakeSince = now
        } else if activity == .beforeWaiting, awakeSince > 0 {
            awakeSamples.append((now - awakeSince) * 1_000)
            awakeSince = 0
        }
    }

    // MARK: Reporting

    private static var cachesDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    /// Names the surface currently sitting idle, for an outside screenshot script.
    static func mark(_ label: String) {
        guard let cachesDirectory else { return }
        try? label.write(
            to: cachesDirectory.appendingPathComponent("perf-scroll-probe-now.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func publish(_ lines: [String]) {
        let text = (["perf-scroll-probe \(Date())"] + lines).joined(separator: "\n")
        print(text)
        for line in lines {
            appLog.info("\(line, privacy: .public)")
        }
        if let cachesDirectory {
            try? text.write(
                to: cachesDirectory.appendingPathComponent("perf-scroll-probe.txt"),
                atomically: true,
                encoding: .utf8
            )
        }
    }
}
#endif
