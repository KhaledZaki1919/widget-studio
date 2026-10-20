# CLAUDE.md — Widget Studio

Home-screen widget builder for iOS 17+ (native Swift / SwiftUI). Arabic default (RTL) + English. Every widget is a **spec JSON + optional user image**, drawn by one renderer shared by the app preview and the widget. Templates are bundled; an optional AI flow uses the user's own key (BYOK). No backend, no accounts, no analytics. Sideloaded with a free Apple ID for now; App Store later.

The product brief is `widget-app-brief.md` (template catalog: `TEMPLATES.md`, visual reference: `docs/reference/widgets-reference.jpg`). Read them before changing behavior. Decisions live in `docs/decisions.md`.

## Working rules
- **Commit after every finished step** and push (`origin` = github.com/KhaledZaki1919/widget-studio, branch `main`). Small commits; end messages with the `Co-Authored-By: Claude …` line.
- Work in the milestones of the brief §10 (M0…M7). Stop at the end of each milestone and tell the owner the IPA is ready and how to test it; the next milestone starts in a new conversation.
- Record decisions as short ADRs in `docs/decisions.md`. Keep this file current.
- Git identity for this repo: `Khaled <khaled96960@gmail.com>` (repo-local config).
- Run `bash scripts/secret-scan.sh` before every push (the repo is public). `git config core.hooksPath .githooks` installs it as a pre-push hook.

## Repository map
| Path | What |
|---|---|
| `ios/project.yml` | XcodeGen spec (app + widget extension + tests). Never hand-edit the generated `.xcodeproj` |
| `ios/WidgetStudio/` | App target: `App/` (entry, root), `Features/<Area>/` (Diagnostics, …), `Resources/` |
| `ios/WidgetStudioWidgets/` | Widget extension (WidgetKit) |
| `ios/WidgetStudioUITests/` | Simulator UI smoke tests |
| `ios/WidgetKitCore/` | Swift package shared by app + extension: environment (App Group resolver, probes), later spec models, validator, renderer. **Unit tests live here** |
| `ios/Config/` | Entitlements (written by XcodeGen from `project.yml`) |
| `ios/scripts/` | `build-ipa.sh`, `check-strings.py`, `pick-simulator.py` |
| `scripts/secret-scan.sh` | Secret scan, run before push and in CI |
| `docs/` | `decisions.md` (ADRs), `reference/` |

## Environment
- Development machine is **Windows**; there is no Mac. iOS builds and tests run **only in GitHub Actions** (`.github/workflows/ios.yml`, `macos-15`).
- Node.js is at `C:\Program Files\nodejs` (no Python locally; CI has `python3`).
- GitHub CLI is at `C:\Program Files\GitHub CLI\gh.exe`.

## Commands
iOS (CI only; locally you can only edit), from `ios/`:
```
xcodegen generate                         # WidgetStudio.xcodeproj
swift test --package-path WidgetKitCore
python3 scripts/check-strings.py          # fails on missing ar/en translations or unknown keys
swiftlint lint
```
**CI** (`ios.yml`), on push to `main`, PRs and manual runs:
1. secret scan + localization check + compile-only build (all errors, full `xcodebuild.log` artifact);
2. `WidgetKitCore` unit tests + Simulator UI smoke test (skipped for docs-only commits);
3. unsigned IPA → artifact `WidgetStudio-ipa` (30 days). `build-ipa.sh` fails if the app or the widget lacks the App Group entitlement.

SwiftLint is a separate, non-blocking job. Superseded runs are cancelled.

**After each push:**
1. Poll the run in the **foreground**, capped at 8 minutes per wait (`timeout 480 gh run watch <id> --exit-status`). Never start a background watcher (low-memory PC).
2. On failure, read `gh run view <id> --log-failed`, fix **all** errors in one commit, push, and watch again until green.

## Conventions
**Swift / iOS**
- Swift 5 language mode, minimal concurrency checking (ADR-006), iOS 17+, SwiftUI. No third-party UI libraries or AI SDKs.
- Never hand-edit `.pbxproj`; change `project.yml`. Generated `Info.plist`s and the `.xcodeproj` are gitignored.
- No force unwraps or force casts.
- **No duplicate file names** within a Swift module.
- **Strings:** every user-facing string comes from a String Catalog (`Localizable.xcstrings` per target, `InfoPlist.xcstrings`) with both `ar` and `en`. Keys are `area.name` (`diag.title`); prefixes are listed in `ios/scripts/check-strings.py`, so add new areas there. Values that aren't UI text use `Text(verbatim:)`.
- **Accessibility identifiers** start with `ax.` (`ax.diag.run`).
- **Layout:** leading/trailing only; test RTL and LTR. Numbers and clocks are never mirrored.
- **Sideloading (ADR-004):** never hardcode the bundle ID, team prefix or App Group at runtime. Use `AppGroupResolver.resolve()`. The widget extension never calls the network for AI and never reads the Keychain.
- **Data on the device only:** write shared files through `FileProtection.write`. Secrets only in the Keychain.
- **Widget memory (~30 MB):** downscale images to the widget's pixel size before saving them to the App Group.
- **AI (D4, D6):** AI returns a JSON spec, never code; every spec is validated before rendering. The BYOK client is ported from Lakhas in M5 (ADR-008).
