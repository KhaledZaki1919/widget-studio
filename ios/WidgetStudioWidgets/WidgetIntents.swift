import AppIntents
import SwiftUI
import WidgetKit
import WidgetKitCore

// Interactive widget buttons (iOS 17, ADR-016): tasbeeh +1 / reset and stopwatch start/stop.
// They run in the widget extension and keep their state in its own container, so they need no
// App Group. Each run is logged; the large check widget shows whether they ran on this install
// (ADR-013 showed AppIntent configuration doesn't render on Fast Store).

struct CounterIncrementIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.counter.increment"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        var counter = CounterState.load()
        counter.increment()
        try counter.save()
        WidgetLog.add("intent counter +1 -> \(counter.value)")
        return .result()
    }
}

struct CounterResetIntent: AppIntent {
    static var title: LocalizedStringResource = "widget.intent.counter.reset"
    static var isDiscoverable = false

    func perform() async throws -> some IntentResult {
        var counter = CounterState.load()
        counter.reset()
        try counter.save()
        WidgetLog.add("intent counter reset")
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
    static let make: SpecActionButton = { action, _ in
        switch action {
        case .counterIncrement: AnyView(button(CounterIncrementIntent()))
        case .counterReset: AnyView(button(CounterResetIntent()))
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
