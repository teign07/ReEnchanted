import AppIntents
import Foundation
import WidgetKit

struct ReEnchantedAdvanceCompassIntent: AppIntent {
    static var title: LocalizedStringResource = "Advance Wonder Compass"
    static var description = IntentDescription("Move to the next step of a Wonder Compass run.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        var run = ReEnchantedCompassWidgetRunStore.loadRun()
        let now = Date()
        if run.startedAt == nil {
            run.startedAt = now
            run.stepIndex = 0
        } else {
            run.stepIndex = min(run.stepIndex + 1, ReEnchantedCompassWidgetRun.stepCount - 1)
        }
        run.updatedAt = now
        try ReEnchantedCompassWidgetRunStore.saveRun(run)
        WidgetCenter.shared.reloadTimelines(ofKind: "ReEnchantedCompassWidget")
        return .result()
    }
}

struct ReEnchantedResetCompassIntent: AppIntent {
    static var title: LocalizedStringResource = "Reset Wonder Compass"
    static var description = IntentDescription("Start the Wonder Compass run over.")
    static var openAppWhenRun: Bool { false }

    func perform() async throws -> some IntentResult {
        try ReEnchantedCompassWidgetRunStore.saveRun(.idle)
        WidgetCenter.shared.reloadTimelines(ofKind: "ReEnchantedCompassWidget")
        return .result()
    }
}
