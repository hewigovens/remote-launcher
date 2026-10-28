# Remote Launcher

A native SwiftUI machine list that opens Apple's Screen Sharing app in High Performance mode. Each Mac gets a separate Screen Sharing process, avoiding the viewer's one-High-Performance-session-per-process limit. Click an open Mac again to bring its existing window forward.

## Run

Requires macOS 14+, Apple silicon, and the Swift 6 toolchain. Both ends of a High Performance connection need compatible Apple silicon Macs and a suitable network.

```sh
./script/build_and_run.sh
```

The script builds and stages `dist/Remote Launcher.app`, signs it, and opens it. If exactly one valid Developer ID Application identity is in the Keychain, it uses that identity with Hardened Runtime and a secure timestamp. If no Developer ID identity is available, local builds fall back to ad hoc signing; multiple identities require an explicit selection. The Codex Run action uses the same script. Use `--build-only` to package without opening, or `--verify` to confirm the launcher process starts.

Add a Mac with a name and host name/IP address, an optional username, and one or two virtual displays. Click its name or **Connect** to start a connection; **Show** brings an existing viewer forward. Use each row’s **…** menu to edit or remove the Mac. Select a row with the arrow keys and press Command-Return to connect or show its window, Command-I to edit, or Command-N to add another Mac. These actions are also available in the File and Connection menus. Removing a saved Mac or quitting the launcher leaves its Screen Sharing window running.

High Performance remains the default connection mode. The compact footer shows the machine count and open viewer count; it does not claim that a remote session is authenticated or streaming.

Screen Sharing handles authentication and Keychain passwords. This app stores no passwords. Machines, generated connection files, and process identities are saved locally in `~/Library/Application Support/dev.hewig.ScreenSharingLauncher/`.

The original bundle identifier and data directory are retained across the rename, so existing machines and running viewer records carry over.

## Developer ID distribution

Build an optimized, Developer ID-signed ZIP:

```sh
./script/package_release.sh
```

Build, notarize with credentials already stored in Keychain, staple, and verify Gatekeeper acceptance:

```sh
NOTARY_PROFILE=notarytool ./script/package_release.sh --notarize
```

Artifacts, notarization responses, the notary log, and the archive's SHA-256 are written under `dist/release/`. The notarized archive is recreated after stapling so the ticket ships inside the ZIP. This submits the app privately to Apple's notary service; it does not publish a release or submit it to the Mac App Store.

`SIGNING_IDENTITY` accepts a certificate name or SHA-1 when automatic selection is ambiguous. `SIGNING_IDENTITY=- ./script/build_and_run.sh` explicitly uses ad hoc signing for local development; `--debug` also defaults to ad hoc signing so LLDB can attach. Distribution builds refuse ad hoc signatures. The identity is team-wide; this app needs no separate certificate or provisioning profile for its current capabilities. Keep signing private keys and notarization credentials in Keychain, outside this repository.

The app is currently unsandboxed. A Mac App Store version would need a separate sandbox compatibility investigation, especially around inspecting another process's identity/sockets and activating separate Screen Sharing instances. Its undocumented Screen Sharing URL options also need review and compatibility validation. Developer ID signing is the supported distribution path implemented here; it is different from Mac App Store distribution signing. See [Apple's Mac App Store requirements](https://developer.apple.com/app-store/review/guidelines/#hardware-compatibility) and [notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

## Icon

The teal display and launch arrow are generated with built-in ImageGen. The source is [Resources/AppIcon.png](Resources/AppIcon.png), with the [original prompt](Resources/AppIcon.prompt.txt) alongside it. The build script creates a complete macOS `.icns` icon with standard and Retina sizes from 16px through 1024px; update the source PNG to rebuild it.

## Connection behavior

- A `.vncloc` document requests High Performance using the URL query `quality=high&numVirtualDisplays=1` (or `2` displays). Both options matter: a display count without `quality=high` is treated as Standard. The query skips Apple's sharing-type chooser; `restorationAttributes.displayType` alone does not. The document also carries the matching display type and enables dynamic resolution for one display. These are **undocumented Apple connection-format conventions**, checked against a native export from Screen Sharing 7.0 (776.27) on macOS 27; future versions may change them.
- `NSWorkspace.OpenConfiguration.createsNewApplicationInstance` launches one viewer per endpoint. No Apple binaries, private frameworks, or Apple preferences are modified or linked.
- While a launch is pending, further clicks do nothing. Afterwards, clicks activate the recorded process, with a standard PID-targeted reopen event if AppKit declines activation. The kernel's process ID, start time, and executable path are checked before reuse, including after restarting the launcher. This avoids AppKit's cached application state when multiple viewers share a bundle identifier.
- A viewer's TCP connection is checked after a short startup grace period. If its screen window closes while the Connections manager stays open, the next click starts a fresh connection instead of focusing an idle manager.
- The UI offers **Show** when a viewer window is already open. Screen Sharing owns connection errors, authentication, and reconnecting a disconnected session. Quit that viewer to start a fresh connection with changed settings.
- Connections opened outside the launcher are not adopted: Apple's app provides no supported session-discovery API. Host aliases are separate endpoints; use one canonical address for each Mac. Duplicate saved host/port pairs are rejected.
- This workaround enables outgoing connections to different Macs. It does not remove Apple's limit on simultaneous High Performance sessions into the same host.

## Verify

```sh
swift test
./script/build_and_run.sh --verify
```

Tests cover URL validation/escaping, connection-file display settings, concurrent click deduplication, reuse across launcher restarts, exited processes, launch/write failures, and machine-list persistence. Real video, audio, and concurrent High Performance streams require remote Macs and credentials; unit tests do not establish those behaviors.

On 2026-10-28, the app was built and its machine list and add/edit/remove flows inspected on macOS 27. Two remote Macs simultaneously started AVC video/audio streams and received their first video frames, with the sharing-type chooser skipped. Repeated clicks and restarting the launcher preserved the same two viewer PIDs. Audio stream startup was observed in logs; audible output, HDR, two virtual displays per host, and older client macOS versions were not tested.

Developer ID distribution was also validated: the optimized app was accepted by Apple's notary service with no issues, stapled, and accepted by Gatekeeper. The app extracted from the final ZIP passed the same checks. All 11 tests passed in release mode, and the signed/notarized app reused both existing viewers, including the standard reopen-event fallback, without additional Hardened Runtime entitlements.

The UI polish pass was checked in the running app: row actions, File/Connection menu commands, keyboard selection and editing, search with no results, initial editor focus, disabled empty submissions, and inline port validation. Both existing viewer PIDs were preserved. Dark appearance, VoiceOver, and older macOS versions were not manually tested in this pass.

References: [Apple High Performance requirements](https://support.apple.com/guide/remote-desktop/use-high-performance-screen-sharing-apdf8e09f5a9/mac), [per-process limit analysis](https://edx.sh/posts/multiple-sessions-macos-high-performance-screen-sharing/), [NSWorkspace launch configuration](https://developer.apple.com/documentation/appkit/nsworkspace/openconfiguration).
