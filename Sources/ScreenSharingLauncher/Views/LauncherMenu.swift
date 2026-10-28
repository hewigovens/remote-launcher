import AppKit
import SwiftUI

struct LauncherMenu: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Remote Launcher", systemImage: "macwindow") {
            openWindow(id: "machines", value: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Divider()
        Button("Quit Remote Launcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
