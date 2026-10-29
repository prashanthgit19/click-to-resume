# DevSessions

DevSessions is a macOS widget plus menu bar companion app that shows recently active OpenCode, Claude Code, Codex, Pi, and Oh My Pi sessions and resumes them in the user’s selected terminal.

Phases 0–2.1 are complete: the app, widget, App Group, deep link, terminal hand-off, five-agent discovery, real cache, scheduler, settings, global terminal preference, and real resume paths are implemented.

See `prd.txt` for the full product requirements and `PRIVACY.md` for the local-data policy.

## What is implemented

- Non-sandboxed menu bar host app + sandboxed WidgetKit extension sharing an App Group.
- Five discovery adapters: OpenCode, Claude Code, Codex, Pi, and Oh My Pi.
- Real scan → global recency cache → widget.
- Real resume commands with absolute CLI paths.
- Global terminal preference: Terminal.app (default) and Ghostty.
- 1/3/7/14/30-day activity window, diagnostics, launch-at-login, and background refresh.
- App icon and Release DMG packaging.

## Current validation status

Phases 0–2 are runtime-validated on this Mac:

- Signed app installed at `/Applications/DevSessions.app`.
- App Group cache written successfully at `~/Library/Group Containers/67Z29VG25Z.com.devsessions.shared2/DevSessions/state.json`.
- The host app scans real data and reports **200 cached sessions** on this machine.
- The widget was re-registered from the Phase 2.1 app.
- The widget list is a flat global recency order: no per-agent sections, quotas, or fairness rules.
- Ghostty 1.3.1 is installed, and its `open -na ... --command` resume path was exercised with a real cached session.
- Terminal.app resume was exercised with the same real session. A global Terminal/Ghostty preference is stored app-side.
- `make verify` passes: core checks, plist lint, host/widget type checks, and the five-agent fixture suite.

The real scan reports OpenCode 200 (cache cap), Claude 18, and Codex 24. Because OpenCode is heavily used here, the global top 200 is entirely OpenCode, which is the intended behavior. Pi has no saved sessions yet; Oh My Pi is installed but has not created `~/.omp` sessions yet.

The local build uses a free Apple Development certificate and the team-prefixed macOS App Group convention. Public distribution still requires the paid Apple Developer Program for Developer ID signing and notarization. Public users do not need Xcode, an Apple ID, or a developer account.

## Requirements

- macOS 14 or later.
- Xcode with the installed macOS SDK.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`.
- An Apple Developer team/signing identity. A free personal team works for local development; the paid Developer Program is required for public notarized distribution.

## Setup

```sh
brew install xcodegen
make project
open DevSessions.xcodeproj
```

In Xcode:

1. Select the `DevSessions` target → Signing & Capabilities → choose your team.
2. Select the `DevSessionsWidget` target → choose the same team.
3. Make sure both targets use the same App Group. The checked-in default is `67Z29VG25Z.com.devsessions.shared2`, using macOS’s `<TeamID>.<group-name>` convention.
4. Build and run the `DevSessions` scheme.

The project is preconfigured for team `67Z29VG25Z`. To use a different team, update:

- `DEVELOPMENT_TEAM` in `project.yml`
- `Config/DevSessions.entitlements`
- `Config/DevSessionsWidget.entitlements`
- `AppGroup.identifier` in `Packages/DevSessionsCore/Sources/DevSessionsCore/SharedStore.swift`

Then run `make project` again. The XcodeGen post-generation hook keeps the App Groups capability metadata valid.

## Current acceptance test

1. Launch `/Applications/DevSessions.app`. The menu bar shows a terminal icon.
2. Choose **Open Sessions** from the menu bar.
3. The window should show real recent sessions, ordered globally by last activity.
4. Change **Settings → Sessions → Show sessions from**. The widget should update to the selected window.
5. In **Settings → Terminal**, choose **Ghostty** and click **Test Terminal**. Then switch back to Terminal and test both.
6. Add or refresh the widget from the desktop:
   - Right-click the desktop → **Edit Widgets** → **DevSessions**.
   - If upgrading from the Phase 0 demo, remove and re-add the widget once.
7. The widget should show the same global recent sessions. Small shows one; medium shows two; large shows up to six.
8. Click a session row. DevSessions should launch the selected terminal in the original project directory and run the correct CLI resume command.
9. Open **Settings** and check the per-agent diagnostics and launch-at-login status.

If the app shows an App Group error, signing/App Group setup is not complete. If a resume fails, check the session’s project directory and the resolved CLI path; diagnostics are in the app, not the widget.

## Checks

```sh
make check      # build the core and run its assertions
make lint       # validate plists and entitlements
make verify     # core checks + plist lint + host/widget type checks
make icons      # regenerate the app icon asset catalog
make project    # regenerate DevSessions.xcodeproj from project.yml
make release    # Release build + DMG in dist/
```

Run the discovery scanner against the real home directory:

```sh
swift run --package-path Packages/DevSessionsCore DevSessionsScan --days 30
```

The shared-core checks cover state round-tripping, activity filtering, cache permissions, deep-link validation, session-ID validation, resume arguments, and shell quoting.

Full signed app/widget build:

```sh
xcodebuild -project DevSessions.xcodeproj -scheme DevSessions \
  -configuration Debug -allowProvisioningUpdates build
```

## Project layout

```
DevSessions/              Menu bar host app
DevSessionsWidget/        WidgetKit extension
Packages/DevSessionsCore/ Shared models, state, deep links, command building
Config/                   Info.plists and entitlements
scripts/                  XcodeGen post-generation fixes
project.yml               XcodeGen project definition
prd.txt                   Product requirements
```

## Current behavior

- The host app scans all five agents at launch, every five minutes, on wake, and on manual refresh.
- Only the global top 200 sessions by last activity are cached, with no per-agent quota. A heavily used agent naturally fills the top rows.
- The widget reads a single `state.json` from the App Group. The host app writes it atomically with owner-only permissions.
- Resume validates the session against the cache, checks the project directory, resolves the CLI to an absolute path, writes an executable script, and opens it in the globally selected terminal.
- **Terminal.app** is the default. **Ghostty** is available when installed and opens a new Ghostty instance per resume.
- The terminal choice is global for all sessions, stored app-side; the widget always deep-links back to DevSessions first.
- The app rescans shortly after a resume.
- The App Group uses the team-prefixed macOS convention `67Z29VG25Z.com.devsessions.shared2`; this is what allows local widget sharing with a free Apple Development team.
- A Debug-only `scan-status.txt` is written to `~/Library/Application Support/DevSessions` for troubleshooting.
- The host app is intentionally not sandboxed; the widget extension is sandboxed.
- No network access, analytics, or third-party dependencies are used.

## Release packaging

Build a Release app and DMG:

```sh
make release
# dist/DevSessions-0.1.0.dmg
```

The local Release build uses the Apple Development certificate. For public distribution, set a Developer ID identity and notarization credentials:

```sh
DEVELOPER_ID_APPLICATION="Developer ID Application: ..." \
APPLE_ID="..." \
APPLE_TEAM_ID="..." \
APPLE_APP_PASSWORD="..." \
make release
```

The packaging script signs with the supplied Developer ID, submits the DMG to `notarytool`, and staples it when all three Apple credentials are present. Without them, the DMG is a local Apple Development build and is not suitable for public download.

## Next phase

Phase 4 is public distribution:

- Developer ID signing and notarization (requires the paid Apple Developer Program).
- Clean-install test from the DMG.
- Final privacy note and release checklist.

The Phase 3 widget redesign is parked locally on the `phase3-attempt` branch. The shipping widget is the working Phase 2.1 layout; the Phase 3 work should be reintroduced incrementally later.

Pi and Oh My Pi still need one real session each for live end-to-end validation. Their adapters are fixture-tested and installed. Ghostty’s no-Automation launch path is verified; AppleScript window reuse remains future work.
