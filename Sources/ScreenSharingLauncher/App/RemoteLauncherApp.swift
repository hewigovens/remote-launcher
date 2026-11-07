import AppKit
import SwiftUI

@main
struct RemoteLauncherApp: App {
    init() {
        LauncherPreferences.registerDefaults()
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = MachineStore()
    @State private var connections = SessionCoordinator()
    @State private var discovery = MachineDiscovery()
    @AppStorage(LauncherPreferences.showInMenuBarKey) private var showInMenuBar = true

    var body: some Scene {
        WindowGroup("Remote Launcher", id: "machines", for: String.self) { _ in
            LauncherWindow(store: store, connections: connections, delegate: delegate, discovery: discovery)
        } defaultValue: { "main" }
        .defaultSize(width: 600, height: 360)
        .commands { LauncherCommands() }

        Settings {
            LauncherSettingsView()
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Remote Launcher", systemImage: "display.2", isInserted: $showInMenuBar) {
            LauncherMenu(store: store, connections: connections)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var openMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.applyActivationPolicy()
        NSApp.activate(ignoringOtherApps: true)
        // Settings and the menu bar item both write the preferences; apply them in one place.
        NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { Self.applyActivationPolicy() }
        }
    }

    @MainActor private static func applyActivationPolicy() {
        let defaults = UserDefaults.standard
        let policy = LauncherPreferences.activationPolicy(showInDock: defaults.bool(forKey: LauncherPreferences.showInDockKey),
                                                          showInMenuBar: defaults.bool(forKey: LauncherPreferences.showInMenuBarKey))
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // Leaving the Dock deactivates the app; keep its open windows in front.
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow?()
        return true
    }
}
