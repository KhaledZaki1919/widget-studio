# Progress: rules, states, tasks, delete run (ADR-028)

Handoff note for the run the owner asked for in one go. One IPA and one signed APK at the very end. Decisions are in ADR-028.

## Done
- Standing rules in `CLAUDE.md`, detectors (`DesignRules`), post-pass (`AutoWireRules`), four-metric gate.
- `states` layer, conditions, built-in sets, time shares, `weather.kind`, `forecast.N.*`, prompt v6, editor States panel.
- Android taps: live session redraw, absolute tap areas, ten-child limit, tap log, Diagnostics, Allow access.
- Tasks tab on both platforms, `mono.tasks.*`, `task.toggle`, `task.add`.
- Delete: swipe, long press, editor button, Select mode, Undo, "Design deleted, choose another".
- Templates: `mono.year.dots`, `mono.battery.mood`, `mono.weather.art`, Music Card live; `everyTemplatePasses` on both platforms.

## Open
- Nothing here has run on a real phone. Android's first report comes from Settings → Diagnostics → Copy report.
- Whether the iOS extension gets Reminders on the Fast Store install is unverified.
- The owner's two screenshots weren't in `D:\widget`; the fixed designs come from the written description.

# Progress: interactive widgets run (ADR-027)

Handoff note for the run the owner asked for in one go: every widget live and interactive, plus bulk import and Android sizes. One IPA and one signed APK at the very end. Decisions are in ADR-027 and the capability table in `capabilities.md`.

## Done
- **Catalog:** `Resources/Spec/capabilities.json`, with `Spec/Capabilities.swift` and `spec/Capabilities.kt`. Validators, AI schema, prompt, Use another AI, pickers and auto-wire read it. Drift tests: `CapabilityDriftTests.swift`, `CapabilityCatalogTest.kt`.
- **Providers and actions:** `Data/DeviceData.swift`, `WidgetIntents.swift`, `WidgetActions` in `RootView.swift`; `data/DeviceState.kt` (with `MediaHub`, `MediaListener`), `widget/ActionRouter.kt`.
- **Prompt v5, auto-wire:** `Prompts/generate_v5.md`, `AutoWire.swift`, `AutoWire.kt`, shared vectors in `Fixtures/AutoWire/vectors.json`.
- **Result screen and editor:** Interactive summary, Live data, On tap, permissions after saving, on both platforms.
- **Android sizes:** Small, Medium and Large receivers; the old receiver stays, hidden from the picker.
- **Bulk import:** `BulkImport.swift`, `BulkImport.kt`, screens on both platforms, share and open-with.
- **Import bug:** cause and fix in ADR-027; `ImportPickerUITests`, workflow **Import UI tests**.
- **Templates:** `mono.media.player`, `mono.control.center`, `mono.timer.focus`, snapshots recorded.
- **Eval:** 14 drawn cases, score, gate on every push (`wiring-best.json`, `recorded/`).

## Eval runs (6 allowed, 4 used; the gate holds 14 cases)
| Run | Model | Result |
|---|---|---|
| 1 | gemini-3.5-flash-lite | 94% on 13 cases, model alone 92%. One case failed on a color word, fixed since. This is the gate's baseline |
| 2 | gemini-3.5-flash | Daily quota: 5 of 14 cases, 92% on those. Not comparable |
| 3 | nemotron-3.5-super-vl:free | 100% on 9 cases, 5 lost to the free model's limits. Also the 10 set widgets through v5: 7 returned |
| 4 | nemotron-3.5-super-vl:free | 97% on 3 cases: control center 91%, batteries and compass 100%. Set: battery returned, sleep and timer timed out |

## Open
- Nothing here has run on a real phone. iOS Apple Music from the extension, and whether the extension shares the app's Apple Music, calendar and reminders permission on Fast Store, are unverified.
- Without an App Group (Fast Store), saved designs don't reach the iPhone home screen. The three new templates are how to test live controls there.
- The compass arrow on Android moves once a minute.
