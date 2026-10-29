# Notes for App Review (M6)

Paste into App Store Connect → App Review Information → Notes.

---

Thank you for reviewing Widget Studio.

**No login.** The app has no account and no server. Everything works offline except the weather and the optional "Create from image" feature.

**How to see the app's main function**
1. Open the app → Templates → tap any template → Customize → Save. The design appears in "My widgets".
2. Add widgets from the Home Screen: touch and hold → Edit → Add Widget → Widget Studio. Each template is offered as its own widget in the gallery (swipe through the sizes and designs).
3. Location (weather, prayer times, Qibla) and Health (steps, sleep) are optional. Without them the widgets show "--" and the app explains how to allow access.

**Create from image (optional, bring your own key).** The app has no built-in AI account. The user pastes their own API key in Settings → AI (Google Gemini, Anthropic, OpenAI or OpenRouter). A free Google Gemini key works: https://aistudio.google.com/apikey. Before the first upload to a provider, the app shows a consent sheet naming the provider; consent can be withdrawn in Settings → AI. The image (downscaled, metadata removed) goes directly from the device to that provider; the AI returns a JSON description of a widget that the app validates and draws with its own native renderer. **No code is downloaded or executed.** All other features work without a key. If you'd like to try it, any free Gemini key will do; we can't include one because keys are personal.

**Shortcut tiles.** iOS widgets can't toggle Wi-Fi, the flashlight and similar settings, so tile widgets open the app, which runs a Shortcut the user created in Apple's Shortcuts app, through the public `shortcuts://x-callback-url/run-shortcut` URL scheme. On the first tap the app shows a setup screen that explains how to create the Shortcut. No private APIs are used.

**Interactive widgets.** The tasbeeh counter and the stopwatch use App Intents buttons (`Button(intent:)`) inside the widget.

**Support screen.** For user support, long-pressing the version number (bottom of Templates, or Settings) opens a Diagnostics screen that shows permissions and storage status and can share a plain-text report. It doesn't unlock any feature.

**Privacy.** No analytics, ads or tracking. Health data is read on the device only and never transmitted. Weather requests send coordinates rounded to about 1 km to Open-Meteo. Privacy policy: https://khaledzaki1919.github.io/widget-studio/privacy.html

Contact: khaled96960@gmail.com

---

## Before submitting (checklist)

- [ ] The build is from the account-signed pipeline in `when-account.md` (developer mode, App Group working).
- [ ] App Privacy answers entered from `privacy-label.md`.
- [ ] Screenshots uploaded from `screenshots/ar` and `screenshots/en` (6.9").
- [ ] Open-Meteo terms re-checked for commercial use (brief §2); the app is free.
- [ ] Credit or permission for the reference image's style is not needed: the app ships no part of it (ADR-019, history cleaned).
