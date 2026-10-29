# DevSessions

DevSessions is a macOS widget plus menu bar companion app that shows recently active OpenCode, Claude Code, Codex, Pi, and Oh My Pi sessions and resumes them in Terminal.

This repository is currently at **Phase 0: the platform walking skeleton**. It writes three demo sessions to a shared App Group cache, renders them in a widget, and proves that a widget click can hand off to Terminal. Real session discovery starts in Phase 1.

See `prd.txt` for the full product requirements.

## What Phase 0 proves

- A non-sandboxed host app and a sandboxed WidgetKit extension can share state through an App Group.
- The widget can render sessions and deep-link back to the host app.
- The host app can write a `.command` file and open it in Terminal without an Automation permission prompt.
- The app can request launch-at-login and expose a refresh/settings shell.
- The shared state and resume-command code are unit-checkable without Xcode.

## Current validation status

Phase 0 is complete and runtime-validated on this Mac:

- Signed app installed at `/Applications/DevSessions.app`.
- App Group cache written successfully at `~/Library/Group Containers/67Z29VG25Z.com.devsessions.shared/DevSessions/state.json`.
- Widget registered from the installed app and displays all three demo sessions.
- Clicking a widget row opens Terminal in the test project directory.
- `make verify` passes: core checks, plist lint, and host/widget type checks.

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
3. Make sure both targets use the same App Group. The checked-in default is `67Z29VG25Z.com.devsessions.shared`, using macOS’s `<TeamID>.<group-name>` convention.
4. Build and run the `DevSessions` scheme.

The project is preconfigured for team `67Z29VG25Z`. To use a different team, update:

- `DEVELOPMENT_TEAM` in `project.yml`
- `Config/DevSessions.entitlements`
- `Config/DevSessionsWidget.entitlements`
- `AppGroup.identifier` in `Packages/DevSessionsCore/Sources/DevSessionsCore/SharedStore.swift`

Then run `make project` again. The XcodeGen post-generation hook keeps the App Groups capability metadata valid.

## Phase 0 acceptance test

1. Launch the app. The menu bar shows a terminal icon.
2. Open **Show Phase 0 Window** from the menu bar.
3. The window should show three demo sessions and “Shared state” should not show an error.
4. Click **Refresh Widget**. The relative timestamps should reset.
5. Add the widget from Notification Center or the desktop:
   - Right-click the desktop → **Edit Widgets** → **DevSessions**.
6. The widget should show the demo sessions. Small shows one; medium shows two; large shows up to six.
7. Click a demo row in the widget.
8. DevSessions should launch/handle the deep link and open Terminal in the Phase 0 project directory. The Terminal window prints the agent, project, session, and working directory, then waits for a key press.
9. Open **Settings** and toggle **Launch at Login**. macOS may ask for approval in System Settings → General → Login Items.

If step 3 shows an App Group error, signing/App Group setup is not complete. If step 8 opens no Terminal, check Console for `Terminal.app could not be found` or `Terminal could not launch the hand-off script`.

## Checks

```sh
make check      # build the core and run its assertions
make lint       # validate plists and entitlements
make verify     # core checks + plist lint + host/widget type checks
make project    # regenerate DevSessions.xcodeproj from project.yml
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

## Phase 0 behavior notes

- The demo sessions all point at `~/Library/Application Support/DevSessions/Phase0Project`, which the host app creates.
- The demo Terminal script only prints diagnostics. It does not call the real agents yet.
- The widget reads a single `state.json` from the App Group. The host app writes it atomically with owner-only permissions.
- The App Group uses the team-prefixed macOS convention `67Z29VG25Z.com.devsessions.shared`; this is what allows local widget sharing with a free Apple Development team.
- A Debug-only `phase0-status.txt` is written to `~/Library/Application Support/DevSessions` for troubleshooting.
- The host app is intentionally not sandboxed; the widget extension is sandboxed.
- No network access, analytics, or third-party dependencies are used.
- Real adapters, the 1/3/7/14/30-day setting, and real resume commands land in later phases.

## Next phase

Phase 1 implements the five real adapters in `DevSessionsCore`:

- OpenCode: `session_v2` in the SQLite database.
- Claude Code: JSONL session files under `~/.claude/projects`.
- Codex: `threads` in `~/.codex/state_*.sqlite`.
- Pi: JSONL sessions under `~/.pi/agent/sessions`.
- Oh My Pi: JSONL sessions under `~/.omp/agent/sessions`; shares the Pi-family parser and handles OMP’s title slot.

Pi is installed on this machine but has no saved sessions yet. Oh My Pi (`omp`) is not installed, so its adapter will be fixture-tested until it is available for a real end-to-end run. Each adapter gets schema detection, failure isolation, and validation against real local data before the widget is wired to it.
