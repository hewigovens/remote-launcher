import AppKit
import SwiftUI

struct LauncherWindow: View {
    @Environment(\.openWindow) private var openWindow
    let store: MachineStore
    let connections: SessionCoordinator
    let delegate: AppDelegate
    let discovery: MachineDiscovery

    var body: some View {
        ContentView(store: store, connections: connections)
            .onAppear {
                // Keep the scene action available after this window is closed.
                // A fixed presentation value reuses an existing launcher window.
                let action = openWindow
                delegate.openMainWindow = {
                    action(id: "machines", value: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }
                if store.loadError == nil { connections.removeDocuments(except: store.machines.map(\.id)) }
                discovery.start(store: store)
                discovery.refresh()
            }
            .onChange(of: store.machines.map(\.endpointKey)) { discovery.refresh() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                discovery.refresh()
            }
    }
}
