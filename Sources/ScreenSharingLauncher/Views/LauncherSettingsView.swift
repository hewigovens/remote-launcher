import AppKit
import SwiftUI

struct LauncherSettingsView: View {
    @AppStorage(LauncherPreferences.showInDockKey) private var showInDock = true
    @AppStorage(LauncherPreferences.showInMenuBarKey) private var showInMenuBar = true

    var body: some View {
        Form {
            // Disable whichever switch would hide the last way to reach the launcher.
            Toggle(isOn: $showInDock) {
                Label("Show in Dock", systemImage: "dock.rectangle")
            }
            .disabled(!showInMenuBar)
            .help(showInMenuBar ? "Keep Remote Launcher in the Dock" : "Show the menu bar item before hiding the Dock icon")
            Toggle(isOn: $showInMenuBar) {
                Label("Show in menu bar", systemImage: "menubar.rectangle")
            }
            .disabled(!showInDock)
            .help(showInDock ? "Connect to your saved Macs from the menu bar" : "Show the Dock icon before hiding the menu bar item")
        }
        .formStyle(.grouped)
        .background(SettingsFocusReset())
        .scrollDisabled(true)
        .frame(width: 420, height: 112)
    }
}

/// Keep Settings from auto-focusing the first toggle when the window opens.
private struct SettingsFocusReset: NSViewRepresentable {
    func makeNSView(context: Context) -> SettingsFocusResetView {
        SettingsFocusResetView()
    }

    func updateNSView(_ nsView: SettingsFocusResetView, context: Context) {}
}

private final class SettingsFocusResetView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.window?.makeFirstResponder(nil)
        }
    }
}
