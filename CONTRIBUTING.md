# Contributing to Remote Launcher

For installation and usage, see [README.md](README.md). Read [AGENTS.md](AGENTS.md)
for code ownership, behavior invariants, verification expectations, and the JJ
repository workflow.
See [HANDOFF.md](HANDOFF.md) for the latest release handoff and remaining manual checks.

## Build and run

Source builds require an Apple silicon Mac, macOS 14 or later, the Swift 6
toolchain, and macOS developer command-line tools. There are no third-party
package dependencies or Xcode project.

```sh
jj git clone --colocate https://github.com/hewigovens/remote-launcher.git
cd remote-launcher
./script/build_and_run.sh
```

The script builds `dist/Remote Launcher.app`, generates its icon, signs it, and
opens it. The SwiftPM executable is `RemoteLauncher`; the source and test modules
retain the original `ScreenSharingLauncher` name. The build script supplies the
bundle metadata and icon that `swift run` alone does not.

| Command | Purpose |
| --- | --- |
| `./script/build_and_run.sh --build-only` | Build, bundle, and sign without opening |
| `./script/build_and_run.sh --verify` | Build, bundle, sign, launch, and check the process |
| `./script/build_and_run.sh --debug` | Launch under LLDB; ad hoc signing by default |
| `./script/build_and_run.sh --logs` | Run and stream process logs |
| `./script/build_and_run.sh --telemetry` | Run and stream the app's local unified logs |

### Local signing

If exactly one valid Developer ID Application identity is available in Keychain,
the build script uses Hardened Runtime and a secure timestamp. With no Developer
ID identity, local builds use ad hoc signing. Select a certificate name or SHA-1
explicitly when multiple identities are available:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' ./script/build_and_run.sh
```

To force local ad hoc signing, use `SIGNING_IDENTITY=-`. Keep private keys and
credentials in Keychain, outside the repository.

## Tests and verification

```sh
swift test
```

The Swift Testing suite covers validation and URL escaping, connection documents,
concurrent clicks, viewer reuse and restart recovery, process/socket identity,
partial failures, saved-list integrity, model discovery matching, icon overrides,
and persistence. Tests use isolated files, a fake viewer client, and local socket
fixtures; they do not require remote Macs or modify the user's saved machines.

Live video/audio and concurrent High Performance streams require remote Macs.
Successful unit tests and compilation cannot establish those behaviors. For UI
changes, inspect the built app and exercise the affected controls, keyboard
commands, window lifecycle, and error states. Follow [AGENTS.md](AGENTS.md#verification)
for the relevant verification scope.

### Verified behavior and remaining coverage

On macOS 27, two remote Macs were observed streaming simultaneously, and repeated
clicks and launcher restarts reused the same viewer PIDs. The list, search,
row/app-menu/keyboard actions, editor, and validation were manually checked.
Bonjour hardware-model discovery was verified against two local Macs, and Dock
reopening was confirmed in the running app.

The 0.1.0 release passed notarization, stapling, Gatekeeper assessment, a public
ZIP download/checksum check, Homebrew's strict online cask audit, and installation.
Audible output, HDR, two-display streaming, VoiceOver, dark appearance, and older
macOS versions have not been manually verified. The menu bar UI was not automated
in the last pass because native UI automation was unavailable.

## Connection implementation

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

The bundle identifier and local data directory remain
`dev.hewig.ScreenSharingLauncher` so existing installations retain saved Macs and
viewer records. That directory contains `machines.json`, `sessions.json`, and
generated `.vncloc` files under `Connections/`.

### Hardware-model discovery

Bonjour discovery uses `_rfb._tcp` services and `_device-info._tcp` TXT records.
It matches resolved host addresses and ports, rather than machine names, and
caches model identifiers for offline display. Unknown models use the generic
Mac icon unless the user chooses a manual override.

The model mapping follows Apple's identification pages for
[Mac mini](https://support.apple.com/en-us/102852),
[Mac Studio](https://support.apple.com/en-us/102231),
[MacBook Pro](https://support.apple.com/en-us/108052),
[MacBook Air](https://support.apple.com/en-us/102869),
[iMac](https://support.apple.com/en-us/108054), and
[Mac Pro](https://support.apple.com/en-us/102887).

## Packaging and distribution

The app is currently unsandboxed and distributed with Developer ID signing.
A Mac App Store version requires a separate compatibility investigation,
including process/socket inspection and the undocumented connection options.

Release versions and build numbers are set in `script/build_and_run.sh` through
`CFBundleShortVersionString` and `CFBundleVersion`. Before packaging a release,
run `swift test -c release`.

Build an optimized, Developer ID-signed ZIP:

```sh
./script/package_release.sh
```

To submit to Apple's notary service, use a `notarytool` credential profile already
stored in Keychain. Replace `remote-launcher` with your configured profile name:

```sh
NOTARY_PROFILE=remote-launcher ./script/package_release.sh --notarize
```

The script validates signing, submits and downloads the notary log, staples and
validates the ticket, checks Gatekeeper, then recreates the ZIP and its SHA-256.
Artifacts and notarization responses are written to `dist/release/`. Distribution
builds refuse ad hoc signatures. See [Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow).

Before publishing, extract the final ZIP and verify the extracted app's strict
code signature, stapled ticket, Gatekeeper acceptance, version, and architecture.
Verify the public download's checksum after publishing. Update the
[Homebrew cask](https://github.com/hewigovens/tap/blob/main/Casks/remote-launcher.rb)
with the release URL and exact archive checksum, then run cask style/audit checks
and test installation. The packaging script itself does not publish a GitHub
release or submit to the Mac App Store.

## Icon assets

The teal display and launch arrow were generated with ImageGen. The source
[PNG](Resources/AppIcon.png) and [original prompt](Resources/AppIcon.prompt.txt)
are included. The build script generates the standard and Retina `.icns` sizes
from the PNG.
