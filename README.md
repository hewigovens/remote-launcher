<img src="Resources/AppIcon.png" alt="Remote Launcher icon" width="112" align="right">

# Remote Launcher

A small native macOS launcher for your remote Macs. Open Apple's built-in Screen
Sharing in High Performance mode, keep several Macs side by side, and click again
to bring the same viewer forward—even after restarting the launcher.

- A searchable machine list with one-click **Connect** and **Show** actions.
- A separate Screen Sharing process for each Mac.
- One or two virtual displays per connection.
- Saved host names or IPv4/IPv6 addresses, optional usernames, and custom ports.
- Local storage. Screen Sharing handles passwords and Keychain access.

## Requirements

Both Macs need Apple silicon and macOS Sonoma 14 or later. Enable Screen Sharing
or Remote Management on each remote Mac and grant access to the account you use.
The Macs must be able to communicate over UDP ports 5900–5902; a fast wired
network is recommended. See [Apple's High Performance requirements](https://support.apple.com/guide/remote-desktop/use-high-performance-screen-sharing-apdf8e09f5a9/mac).

Building from source also requires the Swift 6 toolchain and macOS developer
command-line tools. There are no third-party package dependencies.

## Build and run

```sh
jj git clone --colocate git@github.com:hewigovens/remote-launcher.git
cd remote-launcher
./script/build_and_run.sh
```

The script builds `dist/Remote Launcher.app`, generates its icon, signs it, and
opens it. If exactly one valid Developer ID Application identity is available in
Keychain, it uses Hardened Runtime and a secure timestamp. With no Developer ID
identity, local builds use ad hoc signing. Select an identity explicitly when
multiple certificates are available:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./script/build_and_run.sh
```

To force local ad hoc signing, use `SIGNING_IDENTITY=-`.

## Use it

1. Choose **Add Mac**, then enter a name and host name or IP address. Enter the
   port separately; omit `vnc://`. A username is optional.
2. Choose one or two virtual displays and save.
3. Click the Mac's name or **Connect**. Authenticate in Screen Sharing when asked.
4. Click **Show** to bring an existing viewer forward. Use the row's **…** menu
   to edit or remove its saved entry.

High Performance is always the launch default. The footer shows saved-machine
and open-viewer counts; an open viewer does not guarantee an authenticated or
streaming connection. Quitting the launcher or removing a saved entry leaves
Screen Sharing running.

| Shortcut | Action |
| --- | --- |
| ⌘N | Add a Mac |
| ↑ / ↓ | Select a Mac |
| ⌘Return | Connect or show the selected Mac |
| ⌘I | Edit the selected Mac |

Commands are also available in the File and Connection menus.

## How connections work

The launcher creates a `.vncloc` document with
`quality=high&numVirtualDisplays=1` (or `2`) and matching restoration attributes.
Both query options are necessary to skip Screen Sharing's type chooser. It opens
the document with `NSWorkspace.OpenConfiguration.createsNewApplicationInstance`,
then records the viewer's process identity for reuse.

These connection-format options are **undocumented Apple behavior**, validated
against Screen Sharing 7.0 (776.27) on macOS 27. Future macOS versions may require
adjustments. No Apple binaries, private frameworks, or Apple preferences are
modified or linked.

The launcher checks the viewer's PID, start time, executable path, and TCP socket
before reuse. If a viewer closes while its Connections manager stays open, the
next click starts a fresh connection. Screen Sharing owns authentication,
connection errors, and reconnecting disconnected sessions.

Limitations:

- Connections opened outside the launcher are not adopted.
- Host aliases are separate endpoints; choose one canonical address per Mac.
- Quit a Mac's viewer before reconnecting with changed connection settings.
- This enables outgoing viewers to different Macs; it does not bypass the
  remote Mac's limit on incoming High Performance sessions.
- The app is currently unsandboxed and intended for Developer ID distribution.
  A Mac App Store version requires a separate compatibility investigation.

## Local data

The app stores data in:

```text
~/Library/Application Support/dev.hewig.ScreenSharingLauncher/
├── machines.json   # saved Macs and preferences
├── sessions.json   # viewer process identities
└── Connections/    # generated .vncloc documents
```

Passwords are never stored by the launcher. Invalid machine files are preserved
and reported instead of being overwritten. The original bundle identifier and
data directory are retained so existing installations keep their data.

## Development

```sh
swift test
./script/build_and_run.sh --verify
```

| Command | Purpose |
| --- | --- |
| `./script/build_and_run.sh --build-only` | Build, bundle, and sign without opening |
| `./script/build_and_run.sh --debug` | Launch under LLDB; ad hoc signing by default |
| `./script/build_and_run.sh --logs` | Run and stream process logs |
| `./script/build_and_run.sh --telemetry` | Run and stream the app's local unified logs |

The SwiftPM executable is `RemoteLauncher`; source and test modules retain the
original `ScreenSharingLauncher` name. There is no Xcode project. The build
script supplies the app bundle metadata and icon that `swift run` alone does not.
See [AGENTS.md](AGENTS.md) for code ownership, behavior invariants, and verification.

Tests cover validation and URL escaping, connection documents, concurrent clicks,
viewer reuse and restart recovery, process/socket identity, partial failures,
saved-list integrity, and persistence. Live video/audio and concurrent High
Performance streams require remote Macs; unit tests cannot establish them.

On macOS 27, two remote Macs were observed streaming simultaneously, and repeated
clicks and launcher restarts reused the same viewer PIDs. The list, search,
row/menu/keyboard actions, editor, and validation were manually checked. Audible
output, HDR, two-display streaming, VoiceOver, dark appearance, and older macOS
versions have not been manually verified.

## Developer ID distribution

Build an optimized, Developer ID-signed ZIP:

```sh
./script/package_release.sh
```

To submit to Apple's notary service, use a `notarytool` credential profile already
stored in Keychain:

```sh
NOTARY_PROFILE=remote-launcher ./script/package_release.sh --notarize
```

The script validates signing, submits and downloads the notary log, staples and
validates the ticket, checks Gatekeeper, then recreates the ZIP and its SHA-256.
Artifacts and notarization responses are written to `dist/release/`. Distribution
builds refuse ad hoc signatures. Keep signing private keys and credentials in
Keychain; see [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).
This workflow does not create a GitHub release or submit to the Mac App Store.

## Icon

The teal display and launch arrow were generated with ImageGen. The source
[PNG](Resources/AppIcon.png) and [original prompt](Resources/AppIcon.prompt.txt)
are included. The build script generates the standard and Retina `.icns` sizes.
