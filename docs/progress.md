# Progress: interactive widgets run (ADR-027)

Handoff note for the run the owner asked for in one go: every widget live and interactive, plus bulk import and Android sizes. One IPA and one signed APK at the very end, not before.

## Done
- **Catalog:** `ios/WidgetKitCore/Sources/WidgetKitCore/Resources/Spec/capabilities.json` is the single source (Android copies `Resources/Spec` at build time). Swift `Spec/Capabilities.swift`, Kotlin `spec/Capabilities.kt`.
- **Built from it:** validator whitelists, AI schema, prompt section (`$CAPABILITIES$`), Use another AI, permissions per spec. Drift tests: `CapabilityDriftTests.swift`, `CapabilityCatalogTest.kt`.
- **Live values:** `DataSnapshot.live` (id → value) on both sides, so a new capability needs a catalog entry and a provider, no resolver case. iOS `Data/DeviceData.swift`; Android `data/DeviceState.kt` (with `MediaHub`, `MediaListener`).
- **Actions:** iOS `WidgetIntents.swift` (extension) and `WidgetActions` in `RootView.swift` (app); Android `widget/ActionRouter.kt`.
- **Prompt v5:** `Prompts/generate_v5.md`, wiring list, `decorative` notes stored on the spec.
- **Auto-wire:** `AI/Widget/AutoWire.swift`, `design/AutoWire.kt`; shared vectors in `Tests/WidgetKitCoreTests/Fixtures/AutoWire/vectors.json`.
- **Android sizes:** Small, Medium, Large receivers; the old receiver is hidden from the picker; the config screen filters by size; `WidgetPreviews` on Android 15+.

## Left
- Bulk import core and screens on both platforms; share/open-with for .zip and .json.
- iOS import bug: cause from `ImportPickerUITests`, then the picker fix.
- Result screen Interactive summary, layer editor Live data and On tap, permissions after save, both platforms.
- Three interactive templates, because a Fast Store install shows only fixed templates on the home screen: `mono.media.player`, `mono.control.center` (large), `mono.timer.focus`. Record their snapshots, then point `preview_large` at the large one.
- Eval: 12+ drawn interactive cases, `expected` wiring, score, CI gate, at most 6 runs. Then the 10 zip widgets before/after. The zip stays out of the repo: pass it to the workflow as a base64 input.
- ADR-027, CLAUDE.md, privacy page and PrivacyInfo, capability table.
- Final `[ipa]` and `[apk]`.

## Facts to keep in the report
- Without an App Group (Fast Store), saved designs don't reach the iPhone home screen: My widget says so. Only the fixed templates do. That's why the three templates exist.
- iOS now playing and transport controls cover Apple Music only. Not verified on the owner's Fast Store install; Diagnostics and the step log show it.
- `widgets-set3.zip` was in Downloads, not `D:\widget`.
