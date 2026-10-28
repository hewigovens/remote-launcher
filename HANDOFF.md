# Remote Launcher handoff

Snapshot: 2026-10-28. Start with [AGENTS.md](AGENTS.md) for engineering guidance
and [CONTRIBUTING.md](CONTRIBUTING.md) for builds, tests, and distribution.

## Released state

- Public repository: <https://github.com/hewigovens/remote-launcher>.
- Latest release: [0.1.1, build 3](https://github.com/hewigovens/remote-launcher/releases/tag/v0.1.1).
- Release source commit: `39737d2be74830dedd8e81612273d3450d313b28`.
- Tap update: `hewigovens/tap` commit `8ae5d9bb88f8225e939ddc4c60b2cb5ee94583d5`.
- ZIP: `RemoteLauncher-0.1.1-macos-arm64.zip`.
- SHA-256: `596c30bdc3b919f199d02eb43591bacf1d75243c82b03bf6eb1179744d837289`.

```sh
brew install --cask hewigovens/tap/remote-launcher
# Existing installation:
brew upgrade --cask hewigovens/tap/remote-launcher
```

The installed app is `/Applications/Remote Launcher.app`. Its settings and saved
Macs live outside the checkout. Keep the bundle identifier and data directory
`dev.hewig.ScreenSharingLauncher` unchanged when renaming or moving the project.

## Local release artifacts

The ignored `dist/release/` directory retains the 0.1.1 app, ZIP, checksum,
release notes, notarization response/log, and
`RemoteLauncher-0.1.1-macos-arm64.dSYM`. The symbol bundle matches both the
published binary and the installed app:

```text
E8C2ACD2-A987-30B7-A4FE-1079078F66F1 (arm64)
```

These local artifacts are not included in a fresh clone. The ZIP and checksum
are available on GitHub Releases; retain the local dSYM for crash symbolication.
Signing keys and notary credentials remain in Keychain. On this Mac, the existing
notary credential profile is named `notarytool`.

## Verification and remaining checks

The 0.1.1 release passed all 16 release-mode tests, notarization, stapling,
Gatekeeper, local/public ZIP checks, Homebrew style and strict online audit,
and an installed upgrade from 0.1.0. Saved Macs and the menu bar preference
were preserved across the upgrade.

The latest Settings/menu UI still needs a manual smoke check because native UI
automation was unavailable:

- Open Settings with ⌘, and toggle **Show in menu bar** off/on across a restart.
- Select saved Macs from the menu; verify existing viewers are reused and
  pending launches cannot duplicate a viewer.
- Close the main window and verify a failed menu connection reopens it with
  the error; confirm Dock reopening also works with the menu bar item hidden.

Older macOS versions, VoiceOver, dark appearance, audible audio, HDR, and
streaming with two virtual displays remain outside the manual coverage.

## Standalone checkout

The checkout is self-contained, with colocated `.git` and `.jj` directories and
one default workspace. Run commands from the repository root. The build scripts
resolve that root from their own location, and the Codex Run action uses the
relative command `./script/build_and_run.sh`.

After relocation, a fresh build and all 16 tests passed using a temporary
SwiftPM scratch directory. JJ's workspace root and repo-specific config were
verified at the new location, with no orphaned repo configs.

Generated SwiftPM caches and the stale debug app were removed for relocation.
A subsequent local build will recreate them. The Swift module name
`ScreenSharingLauncher` remains intentional; changing the checkout folder name
does not require a bundle identifier or data migration.
