import AppKit
import SwiftUI

struct LauncherMenu: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    let store: MachineStore
    let connections: SessionCoordinator

    var body: some View {
        if store.loadError != nil {
            Text("Couldn’t Load Macs")
        } else if store.machines.isEmpty {
            Text("No saved Macs")
        } else {
            Section("Macs") {
                ForEach(store.machines) { machine in
                    Button {
                        Task {
                            await connections.open(machine)
                            // A closed main window cannot present connection errors.
                            if connections.errorMessage != nil { showLauncher() }
                        }
                    } label: {
                        Label(menuTitle(for: machine), systemImage: machine.kind.symbolName)
                    }
                    .disabled(connections.opening.contains(machine.endpointKey))
                    .help("\(machine.name) — \(machine.address)\nConnect or show the existing Screen Sharing window")
                    .accessibilityLabel("\(machine.name), \(machine.address)")
                }
            }
        }
        Divider()
        Button("Open Remote Launcher", systemImage: "macwindow", action: showLauncher)
        Button("Settings…", systemImage: "gearshape") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        Divider()
        Button("Quit Remote Launcher") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func showLauncher() {
        openWindow(id: "machines", value: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func menuTitle(for machine: Machine) -> String {
        let name = machine.name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let title = connections.opening.contains(machine.endpointKey) ? "Opening \(name)" : name
        return title.count <= 30 ? title : String(title.prefix(29)) + "…"
    }
}
