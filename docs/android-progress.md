# Android progress (M7, A2–A5 in one run)

Handoff note for this run: the owner asked for A2, A3, A4 and A5 in one go, with one signed APK (`[apk]`) at the end.

## Done
- **AI export (ADR-025):** `WidgetKitCore/Resources/Spec/ai/` holds the system prompt, the review prompt, both AI schemas, the import example and the prompt version, all built by Swift. `AIExportTests` fails when they're stale and writes fresh copies to `package-renders/ai-export`. Android reads them as `assets/spec/ai/`.
- **A2:**
  - Editor (`ui/Editor.kt`): live preview with tap-to-select, fields, theme, clock, glass, colors including outer, photo with downscale and the mono/halftone filter, undo/redo.
  - Layer editor (`ui/Layers.kt`).
  - My widgets: edit, rename, duplicate, delete, empty state.
  - Configuration screen: designs first, then templates, with search and light/dark.
  - Saving updates every placed widget (`Widgets.updateAll`).
- **A3** (`data/LiveData.kt`):
  - Open-Meteo weather; adhan-java prayer times (Egyptian method, Shafi) and the Qibla bearing.
  - Health Connect steps and sleep; battery.
  - In-widget tasbeeh (four adhkar, count per dhikr, advance at 33) and stopwatch.
  - Torch toggles directly; the other tiles open system panels.
  - Qibla compass screen (rotation vector sensor).
  - WorkManager refresh every 30 min.
- **A4** (`ai/`):
  - Gemini client (JSON mode, low thinking, iOS error mapping).
  - Key encrypted with an Android Keystore AES key.
  - Model field with suggestions.
  - Parser port: palette, contrast, card shapes, icon and shape-kind cleanup, color tokens, mode and overlap problems, one retry, then the local layout fix.
  - Pixel-based card detector (Vision isn't available) with the crop step and Create all.
  - Use another AI: copy instructions, share the crop through FileProvider, paste, open a file or share in.
- **A5:**
  - Onboarding: three pages and the permissions page.
  - Settings: data, display, tasbeeh list, Gemini, Qibla, language (API 33+), intro, privacy and support links.
  - The launcher icon is the LogoMark geometry.
- **Tests:** `DesignLogicTest` (validator on every template, spec writer round trip, design JSON, layer editing, tasbeeh, AI parsing and import, prompt, Gemini errors, synthetic detector image).

## Left
- Arabic copy review on the device.
- Final `[apk]` commit, then the report to the owner.
