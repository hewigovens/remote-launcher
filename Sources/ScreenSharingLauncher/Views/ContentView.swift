import AppKit
import SwiftUI

struct ContentView: View {
    let store: MachineStore
    @Bindable var connections: SessionCoordinator
    @State private var selection: Machine.ID?
    @State private var search = ""
    @State private var editor: Machine?
    @State private var errorMessage: String?

    private var selected: Machine? { store.machines.first { $0.id == selection } }
    private var filtered: [Machine] {
        store.machines.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) || $0.host.localizedCaseInsensitiveContains(search) }
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
                                   isOpening: connections.opening.contains(machine.endpointKey)) {
                            selection = machine.id
                            open(machine)
                        }
                        .tag(machine.id)
                        .contextMenu {
                            Button("Connect") { open(machine) }
                            Button("Edit…") { editor = machine }
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
                Image(systemName: "bolt.fill").foregroundStyle(.secondary)
                Text("High Performance by default").foregroundStyle(.secondary)
                Spacer()
                Text("\(store.machines.count) \(store.machines.count == 1 ? "Mac" : "Macs")").foregroundStyle(.tertiary)
            }
            .font(.caption).padding(.horizontal, 20).padding(.vertical, 12)
        }
        .frame(minWidth: 530, minHeight: 340)
        .searchable(text: $search, prompt: "Find a Mac")
        .navigationTitle("Remote Launcher")
        .toolbar {
            ToolbarItemGroup {
                Button("Connect", systemImage: "arrow.up.right") { if let selected { open(selected) } }
                    .disabled(selected == nil).keyboardShortcut(.return, modifiers: .command)
                Button("Edit Mac", systemImage: "pencil") { editor = selected }
                    .disabled(selected == nil).keyboardShortcut("i")
                Button("Add Mac", systemImage: "plus") { add() }
                    .disabled(store.loadError != nil).keyboardShortcut("n")
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
    private func open(_ machine: Machine) { Task { await connections.open(machine) } }
    private func remove(_ machine: Machine) {
        do {
            try store.remove(machine.id)
            if selection == machine.id { selection = nil }
        } catch { errorMessage = error.localizedDescription }
    }
}
