# Remote Launcher engineering guide

Remote Launcher is a macOS SwiftUI app built with SwiftPM. Read [README.md](README.md)
for installation, usage, requirements, and connection limits. See
[CONTRIBUTING.md](CONTRIBUTING.md) for builds, tests, implementation notes,
signing, and distribution.
There is no Xcode project or third-party package dependency.

## Commands

Run commands from the repository root:

```sh
swift test
./script/build_and_run.sh --build-only
./script/build_and_run.sh --verify
```

The build script creates a real app bundle; `swift run` alone does not exercise
bundle metadata, icons, signing, or normal app launching. It restarts only the
launcher in run modes and leaves Screen Sharing viewers running. `--build-only`
does not stop or launch applications. See [CONTRIBUTING.md](CONTRIBUTING.md#local-signing)
for signing and debug modes.

## Ownership

| Path | Responsibility |
| --- | --- |
| `Sources/ScreenSharingLauncher/App/` | Scenes, app lifecycle, focused menu commands, shared store ownership |
| `Sources/ScreenSharingLauncher/Views/` | Machine rows, search/selection, editor, native controls and accessibility |
| `Sources/ScreenSharingLauncher/Models/` | Machine validation, endpoint identity, connection URL, persisted session records |
| `Sources/ScreenSharingLauncher/Stores/` | Atomic local persistence and saved-list integrity |
| `Sources/ScreenSharingLauncher/Services/` | Connection documents, launch/reuse coordination, AppKit client, kernel process/socket inspection |
| `Tests/ScreenSharingLauncherTests/` | Swift Testing coverage with isolated files, a fake viewer client, and local socket fixtures |
| `script/` | App bundle/icon generation, signing, release ZIP, notarization and Gatekeeper checks |

The executable is `RemoteLauncher`; the original Swift module name remains
`ScreenSharingLauncher`. The bundle identifier and local data directory remain
`dev.hewig.ScreenSharingLauncher` to preserve saved Macs and viewer records.

## Behavior to preserve

- Request High Performance with **both** `quality=high` and
  `numVirtualDisplays=1` or `2`. Keep undocumented `.vncloc` restoration details
  in `ConnectionDocument`, with URL construction in `Machine`; do not patch
  Apple's applications or preferences.
- Launch a separate Screen Sharing process per endpoint. Deduplicate pending
  clicks by endpoint, and reuse live viewers across launcher restarts. Validate
  PID, process start time, executable path, and socket liveness; AppKit's cached
  application state alone is insufficient for multiple instances.
- Keep a successfully launched viewer in memory if saving its record fails, so
  retrying cannot create a duplicate process. Report partial failures clearly.
- Validate loaded and edited machines. IDs and normalized host/port pairs must
  be unique. Preserve malformed or invalid saved files and block edits rather
  than silently replacing them with an empty list. Publish in-memory edits only
  after persistence succeeds.
- Screen Sharing owns authentication, passwords, Keychain access, and remote
  connection errors. Keep credentials and real machine lists out of source,
  fixtures, screenshots committed to the repo, and logs.
- Removing a saved Mac or quitting the launcher leaves its viewer running.
  Describe viewer windows as open; do not equate their existence with an
  authenticated or streaming remote session.
- Preserve macOS 14 support, system colors, keyboard selection/shortcuts, and
  accessible row actions. Keep selection and editor state in the view; route
  menu commands through focused scene actions.
- Reopen the main window through SwiftUI's scene action with the fixed `main`
  presentation value, from both the Dock and menu bar. A closed window may have
  been released; enumerating `NSApp.windows` cannot recreate it. Keep the Dock
  available when the main window closes, and keep menu bar visibility bound to
  the persistent `showInMenuBar` preference (on by default). Settings must remain
  reachable through the app menu when the menu bar item is hidden.
- Menu bar machines share `MachineStore` and `SessionCoordinator` with the main
  window. Reuse the same connection path and opening guard. Bring connection
  errors back to the main window when a menu action fails while it is closed.
- Model discovery uses Bonjour and matches resolved addresses and ports, never
  machine names. Cache last-known model identifiers, respect manual type
  overrides, and clear detected metadata when an endpoint changes. An editor
  opened before a discovery result must not overwrite that newer metadata.

## Verification

- For behavior changes, reproduce the failure with a focused test, then run
  `swift test`. Use temporary `LauncherFiles` and the fake client; tests must not
  modify the user's Application Support directory or require remote Macs.
- For UI changes, build and inspect the actual app. Check row controls, menu and
  keyboard actions, search, editing, errors, and relevant window sizes. State
  which appearances, accessibility tools, and macOS versions were exercised.
- Changes to the Apple connection format or viewer lifecycle also need a live
  integration check when authorized remote machines are available. Unit tests
  and successful compilation do not prove video, audio, or High Performance.
- Use the release/notarization workflow for distribution work. Verify the final
  extracted ZIP as well as the staged app, and keep private signing keys and
  notary credentials in Keychain. `dist/` and `.build/` are generated and ignored.

## Repository workflow

Use `jj` for history, bookmarks, fetch, and push. Preserve unrelated changes and
existing commit boundaries. Before an authorized push, fetch `origin`, inspect
the intended bookmark against its remote state, and run affected checks. After
pushing, verify the remote commit and an empty `conflicts() | divergent()` revset.
Do not publish tags, releases, or additional branches without authorization.
