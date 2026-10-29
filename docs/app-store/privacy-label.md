# App Privacy ("nutrition label") answers (M6)

These answers match `PrivacyInfo.xcprivacy` in the app and the widget extension and the public [privacy policy](https://khaledzaki1919.github.io/widget-studio/privacy.html).

## Does the app collect data?

**Yes**, two types, both for **App Functionality** only, **not linked** to the user's identity, **not used for tracking**.

Apple defines "collect" as sending data off the device so that the developer *or third-party partners* can access it longer than needed to serve the request. We never receive any data, but two features send data to third parties that may keep it under their own terms, so we declare them conservatively:

| Data type | Why it leaves the device | Linked to user | Tracking | Purpose |
|---|---|---|---|---|
| **Location → Coarse Location** | Weather: coordinates rounded to ~1 km go to Open-Meteo (no identifier). | No | No | App Functionality |
| **User Content → Photos or Videos** | Create from image (optional): the picked image, downscaled and without metadata, goes to the AI provider the user chose, with the user's own key, after consent. | No | No | App Functionality |

## Data not collected

- **Health & Fitness** (steps, sleep): read on the device through HealthKit, shown in widgets, never transmitted.
- **Precise Location**: never sent (only the rounded value above). Prayer times and the Qibla are calculated on the device.
- **Contact info, identifiers, usage data, diagnostics, purchases, browsing history, search history, financial info, sensitive info, contacts, messages, audio**: none. There is no account, no analytics SDK, no crash reporter, no ads.
- **User Content → Other**: the optional extra instructions typed for Create from image go to the same AI provider as the photo; they are short design wishes, covered by the same disclosure if Apple asks (declare "Other User Content", same answers as Photos, if the reviewer requests it).

## Tracking

**No.** `NSPrivacyTracking` is `false`, no tracking domains.

## Required-reason APIs (privacy manifest)

| API category | Reason | Where |
|---|---|---|
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` — read/write the app's own settings | AI settings, onboarding flag, diagnostics (app); shared package code compiled into the widget too |

No file-timestamp, system-boot-time, disk-space or active-keyboard APIs are used (checked with a code search on 2026-10-28; `os_proc_available_memory` is not a required-reason API and only feeds the debug-only widget log).

## Third parties

| Service | What it receives | Their terms |
|---|---|---|
| Open-Meteo | Rounded coordinates, temperature unit | https://open-meteo.com/en/terms |
| Google Gemini / Anthropic / OpenAI / OpenRouter (user's choice, optional) | The picked image, the prompt, the user's own API key | The provider's own privacy policy |
