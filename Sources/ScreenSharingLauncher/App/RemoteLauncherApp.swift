import AppKit
import SwiftUI

@main
struct RemoteLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = MachineStore()
    @State private var connections = SessionCoordinator()
    @State private var discovery = MachineDiscovery()
    @AppStorage("showInMenuBar") private var showInMenuBar = true

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

        MenuBarExtra("Remote Launcher", systemImage: "rectangle.connected.to.line.below", isInserted: $showInMenuBar) {
            LauncherMenu(store: store, connections: connections)
        }
        .menuBarExtraStyle(.menu)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var openMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openMainWindow?()
        return true
    }
}
