import AppKit
import SwiftUI

@main
struct RemoteLauncherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var store = MachineStore()
    @State private var connections = SessionCoordinator()

    var body: some Scene {
        WindowGroup("Remote Launcher", id: "machines") {
            ContentView(store: store, connections: connections)
        }
        .defaultSize(width: 600, height: 360)
        .commands { LauncherCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { sender.windows.first { $0.canBecomeMain }?.makeKeyAndOrderFront(nil) }
        return true
    }
}
