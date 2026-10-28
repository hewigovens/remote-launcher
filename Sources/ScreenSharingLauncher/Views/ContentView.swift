import AppKit
import SwiftUI

struct ContentView: View {
    let store: MachineStore
    @Bindable var connections: SessionCoordinator
    @State private var selection: Machine.ID?
    @State private var search = ""
    @State private var editor: Machine?
    @State private var errorMessage: String?

    private var selected: Machine? { filtered.first { $0.id == selection } }
    private var filtered: [Machine] {
        store.machines.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.host.localizedCaseInsensitiveContains(search) }
    }

    private var actions: LauncherActions {
        let machine = editor == nil ? selected : nil
        return LauncherActions(
            add: editor == nil && store.loadError == nil ? { add() } : nil,
            open: machine.flatMap { machine in
                connections.opening.contains(machine.endpointKey) ? nil : { open(machine) }
            },
            edit: machine.map { machine in { edit(machine) } },
            remove: machine.map { machine in { remove(machine) } },
            hasOpenWindow: machine.map { connections.sessions[$0.endpointKey] != nil } ?? false
        )
    }

    private var windowCount: Int {
        store.machines.filter { connections.sessions[$0.endpointKey] != nil }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loadError = store.loadError {
                ContentUnavailableView("Couldn’t Load Macs", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else if store.machines.isEmpty {
                ContentUnavailableView {
                    Label("Your Macs, one click away", systemImage: "desktopcomputer")
                } description: {
                    Text("Add a Mac to open it with High Performance screen sharing.")
                } actions: {
                    Button("Add Mac", systemImage: "plus") { add() }.buttonStyle(.borderedProminent)
                }
            } else {
                List(selection: $selection) {
                    ForEach(filtered) { machine in
                        MachineRow(machine: machine, isOpen: connections.sessions[machine.endpointKey] != nil,
                                   isOpening: connections.opening.contains(machine.endpointKey), open: {
                            selection = machine.id
                            open(machine)
                        }, edit: { edit(machine) }, remove: { remove(machine) })
                        .tag(machine.id)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                        .contextMenu {
                            Button(connections.sessions[machine.endpointKey] == nil ? "Connect" : "Show Window") {
                                selection = machine.id
                                open(machine)
                            }
                            .disabled(connections.opening.contains(machine.endpointKey))
                            Button("Edit Mac…") { edit(machine) }
                            Divider()
                            Button("Remove from List", role: .destructive) { remove(machine) }
                        }
                    }
                }
                .listStyle(.inset)
                .overlay {
                    if filtered.isEmpty { ContentUnavailableView.search(text: search) }
                }
            }
            Divider()
            HStack {
                Text("\(search.isEmpty ? "" : "\(filtered.count) of ")\(store.machines.count) \(store.machines.count == 1 ? "Mac" : "Macs")")
                Spacer()
                if windowCount > 0 {
                    Text("\(windowCount) \(windowCount == 1 ? "window" : "windows") open")
                }
            }
            .font(.caption).foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 8)
        }
        .frame(minWidth: 520, minHeight: 280)
        .focusedSceneValue(\.launcherActions, actions)
        .searchable(text: $search, prompt: "Find a Mac")
        .navigationTitle("Remote Launcher")
        .toolbar {
            ToolbarItem {
                Button("Add Mac", systemImage: "plus") { add() }
                    .labelStyle(.titleAndIcon)
                    .disabled(store.loadError != nil || editor != nil)
                    .help("Add a Mac (⌘N)")
            }
        }
        .sheet(item: $editor) { machine in
            MachineEditor(machine: machine, isNew: !store.machines.contains { $0.id == machine.id }) { try store.save($0) }
        }
        .alert("Remote Launcher", isPresented: Binding(
            get: { errorMessage != nil || connections.errorMessage != nil },
            set: { if !$0 { errorMessage = nil; connections.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil; connections.errorMessage = nil }
        } message: { Text(errorMessage ?? connections.errorMessage ?? "") }
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didTerminateApplicationNotification)) { _ in connections.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in connections.refresh() }
    }

    private func add() { editor = Machine(name: "", host: "") }
    private func edit(_ machine: Machine) {
        selection = machine.id
        editor = machine
    }
    private func open(_ machine: Machine) { Task { await connections.open(machine) } }
    private func remove(_ machine: Machine) {
        do {
            try store.remove(machine.id)
            if selection == machine.id { selection = nil }
        } catch { errorMessage = error.localizedDescription }
    }
}
