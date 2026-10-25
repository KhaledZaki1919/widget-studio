# CLAUDE.md — Widget Studio

Home-screen widget builder for iOS 17+ (native Swift / SwiftUI). Arabic default (RTL) + English. Every widget is a **spec JSON + optional user image**, drawn by one renderer shared by the app preview and the widget. Templates are bundled; an optional AI flow uses the user's own key (BYOK). No backend, no accounts, no analytics. App Store later.

**Install method (owner, since M2):** every IPA is installed with **Fast Store**, a paid signing store that re-signs the app and the widget extension with its own certificate and profile. No Sideloadly. The store decides bundle IDs, team, profile and entitlements (the App Group was not granted in the M2 test), so never assume the compiled values at runtime (ADR-004) and check Diagnostics → Signing when a capability fails.

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
| `ios/WidgetStudio/` | App target: `App/` (entry, root), `Features/<Area>/` (Library: home, detail, previews; Diagnostics with TestSpecs; …), `Resources/` |
| `ios/WidgetStudioWidgets/` | Widget extension: `SpecWidget.swift` (one `StaticConfiguration` widget per template, `TemplateWidget<ID>`, picked by swiping the widget gallery; error text instead of gray; step log — ADR-013), `ProbeWidget` (check widget; large shows the step log). **No AppIntentConfiguration**: it never renders on the owner's Fast Store install (ADR-013). A new template needs a `TemplateIDs` entry and a line in its category bundle |
| `ios/WidgetStudioTests/` | App-hosted unit tests: font availability, RTL invariants, every spec through the widget view, snapshots (`Snapshots/<id>.<lang>.png`) |
| `ios/WidgetStudioUITests/` | Simulator UI smoke tests |
| `ios/Fonts/` | Doto (static instances) + IBM Plex Sans Arabic, OFL; bundled in app and widget, declared in `UIAppFonts` (ADR-010) |
| `ios/WidgetKitCore/` | Swift package shared by app + extension: `Environment/` (App Group resolver, profile, code signature reader), `Probe/` (incl. `WidgetLog`), `Spec/` (models, bindings, validator, icon whitelist, test spec loader), `Render/` (SpecView, layer views, binding resolver, fonts, timelines), `Resources/` (Templates: the Mono library, TestSpecs, Spec schema); `TemplateLibrary` loads templates. **Unit tests live here** |
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
1. **every push:** secret scan + localization check + compile-only build (all errors, full `xcodebuild.log` artifact), and `WidgetKitCore` unit tests (`swift test`);
2. **only when the head commit message contains `[full]` or `[ipa]`** (or a manual run): app tests on the Simulator (renders, RTL invariants, snapshots, every template through the widget view) + UI smoke tests; every render goes to the `snapshots` artifact;
3. **only with `[ipa]`** (or a manual run), after everything above is green: unsigned IPA → artifact `WidgetStudio-ipa` (30 days). `build-ipa.sh` fails if the app or the widget lacks the App Group entitlement or a font declared in `UIAppFonts`.

Docs-only commits (`**.md`, `docs/**`) skip CI. SwiftLint is a separate, non-blocking job. Superseded runs are cancelled.

**Build rule (owner, since M2):**
- Do **not** build an IPA after each fix. Commit each fix and push; that runs compile + unit tests only. Fix all errors per commit.
- Use `[full]` on a commit when the change needs the Simulator tests (rendering, UI); it never builds an IPA.
- Build the IPA **once**, with `[ipa]` in the commit message, only after **all** requested fixes are done and every test is green. Then tell the owner the IPA is ready; they test everything in one go.

**After each push:**
1. Poll the run in the **foreground**, at most 7 minutes per wait (`timeout 400 gh run watch <id> --exit-status`, Bash tool timeout ~480000 ms so the call can never be moved to the background). Never start a background watcher (low-memory PC).
2. Fetch logs in a **separate call**, never chained after a watch: `gh run view <id> --log-failed` (or `--job <id> --log`).
3. On failure, fix **all** errors in one commit, push, and watch again until green.

## Conventions
**Swift / iOS**
- Swift 5 language mode, minimal concurrency checking (ADR-006), iOS 17+, SwiftUI. No third-party UI libraries or AI SDKs.
- Never hand-edit `.pbxproj`; change `project.yml`. Generated `Info.plist`s and the `.xcodeproj` are gitignored.
- No force unwraps or force casts.
- **No duplicate file names** within a Swift module.
- **Strings:** every user-facing string comes from a String Catalog (`Localizable.xcstrings` per target, `InfoPlist.xcstrings`) with both `ar` and `en`. Keys are `area.name` (`diag.title`); prefixes are listed in `ios/scripts/check-strings.py`, so add new areas there. Values that aren't UI text use `Text(verbatim:)`.
- **Accessibility identifiers** start with `ax.` (`ax.diag.run`).
- **Layout:** leading/trailing only; test RTL and LTR.
- **RTL in specs (ADR-010):** never flip anything like an image and never set `layoutDirection` on a `List`/UIKit-backed view to preview Arabic. Inside `SpecView` only `mirror: true` layers change: position, alignment, item order. Glyphs, digits and clocks keep their shape.
- **Fonts (ADR-010):** reference bundled fonts by PostScript name only (`FontRegistry`); every font file goes in `ios/Fonts` and both `UIAppFonts` lists. No runtime registration, no CoreText variation fonts.
- **Templates (ADR-011):** one JSON per template in `Resources/Templates/<id>.json`, colors as tokens (`@bg`, `@fg`, `@accent`…), every visible text `{en, ar}`, and `catalogOrder` in `TemplateLibrary` updated. Spec extensions (`when`, `rotation`, `highlightColor`, `icon` fields, new bindings) are listed in ADR-011.
- **Snapshots:** an intended visual change means re-recording references from the `snapshots` artifact (`ios/WidgetStudioTests/Snapshots/README.md`); look at the renders before committing them.
- **Sideloading (ADR-004):** never hardcode the bundle ID, team prefix or App Group at runtime. Use `AppGroupResolver.resolve()`. The widget extension never calls the network for AI and never reads the Keychain.
- **Data on the device only:** write shared files through `FileProtection.write`. Secrets only in the Keychain.
- **Widget memory (~30 MB):** downscale images to the widget's pixel size before saving them to the App Group.
- **AI (D4, D6):** AI returns a JSON spec, never code; every spec is validated before rendering. The BYOK client is ported from Lakhas in M5 (ADR-008).
