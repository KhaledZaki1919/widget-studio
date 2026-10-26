import AppIntents
import SwiftUI
import WidgetKit
import WidgetKitCore

// Interactive widget buttons (iOS 17, ADR-016): tasbeeh +1 / next dhikr / reset and stopwatch
// start/stop. They run in the widget extension and keep their state in its own container, so
// they need no App Group. Each run is logged; the large check widget shows whether they ran on
// this install (ADR-013 showed AppIntent configuration doesn't render on Fast Store).

struct CounterIncrementIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.counter.increment"
    static var isDiscoverable = false

    /// The template's `target` field (the button's arg), for auto-advance; 0 = none.
    @Parameter(title: "widget.intent.counter.target", default: 0)
    var target: Int

    init() {}

    init(target: Int) {
        self.target = target
    }

    func perform() async throws -> some IntentResult {
        let settings = AppSettings.load()
        var counter = CounterState.load()
        counter.increment(list: settings.dhikrList, target: target, autoAdvance: settings.tasbeehAutoAdvance)
        try counter.save()
        WidgetLog.add("intent counter +1 -> \(counter.count(in: settings.dhikrList)) (dhikr \(counter.index + 1))")
        return .result()
    }
}

/// Resets the current dhikr only.
struct CounterResetIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.counter.reset"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        var counter = CounterState.load()
        counter.reset(list: AppSettings.load().dhikrList)
        try counter.save()
        WidgetLog.add("intent counter reset")
        return .result()
    }
}

/// The next dhikr in the list (each keeps its own count).
struct CounterNextIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.counter.next"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        var counter = CounterState.load()
        counter.next(list: AppSettings.load().dhikrList)
        try counter.save()
        WidgetLog.add("intent counter next -> dhikr \(counter.index + 1)")
        return .result()
    }
}

struct StopwatchToggleIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.stopwatch.toggle"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        var stopwatch = StopwatchState.load()
        stopwatch.toggle()
        try stopwatch.save()
        WidgetLog.add("intent stopwatch \(stopwatch.isRunning ? "started" : "stopped")")
        return .result()
    }
}

/// Interactive controls for the renderer's button layers (`specActionButton`); other actions
/// keep the default link to the app (shortcut tiles, links, open app).
enum WidgetActionButtons {
    static let make: SpecActionButton = { action, arg in
        switch action {
        case .counterIncrement: AnyView(button(CounterIncrementIntent(target: arg.flatMap { Int($0) } ?? 0)))
        case .counterReset: AnyView(button(CounterResetIntent()))
        case .counterNext: AnyView(button(CounterNextIntent()))
        case .stopwatchToggle: AnyView(button(StopwatchToggleIntent()))
        case .shortcutRun, .openURL, .openApp: nil
        }
    }

    static func button<Intent: AppIntent>(_ intent: Intent) -> some View {
        Button(intent: intent) {
            Color.clear.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
