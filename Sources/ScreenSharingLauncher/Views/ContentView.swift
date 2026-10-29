import AppKit
import SwiftUI

struct ContentView: View {
    @Environment(\.undoManager) private var undoManager
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
            hasOpenWindow: machine.map(isOpen) ?? false
        )
    }

    private func isOpen(_ machine: Machine) -> Bool { connections.sessions[machine.endpointKey] != nil }
    private func isOpening(_ machine: Machine) -> Bool { connections.opening.contains(machine.endpointKey) }
    private func machine(for ids: Set<Machine.ID>) -> Machine? {
        ids.count == 1 ? store.machines.first { ids.contains($0.id) } : nil
    }

    private var windowCount: Int {
        store.machines.filter(isOpen).count
    }

    var body: some View {
        VStack(spacing: 0) {
            if let loadError = store.loadError {
                ContentUnavailableView {
                    Label("Couldn’t Load Macs", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([store.fileURL]) }
                }
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
                        MachineRow(machine: machine, isSelected: selection == machine.id, isOpen: isOpen(machine), isOpening: isOpening(machine), open: {
                            selection = machine.id
                            open(machine)
                        }, edit: { edit(machine) }, remove: { remove(machine) })
                        .tag(machine.id)
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
                    }
                }
                .listStyle(.inset)
                // A click selects; double-click or Return connects.
                .contextMenu(forSelectionType: Machine.ID.self) { ids in
                    if let machine = machine(for: ids) {
                        Button(isOpen(machine) ? "Show Window" : "Connect") { open(machine) }
                            .disabled(isOpening(machine))
                        Button("Edit Mac…") { edit(machine) }
                        Divider()
                        Button("Remove from List", role: .destructive) { remove(machine) }
                    } else if ids.isEmpty {
                        Button("Add Mac…") { add() }
                    }
                } primaryAction: { ids in
                    if let machine = machine(for: ids), !isOpening(machine) { open(machine) }
                }
                .overlay {
                    if filtered.isEmpty { ContentUnavailableView.search(text: search) }
                }
            }
            Divider()
            HStack {
                if search.isEmpty {
                    Text("^[\(store.machines.count) Mac](inflect: true)")
                } else {
                    Text("\(filtered.count) of ^[\(store.machines.count) Mac](inflect: true)")
                }
                Spacer()
                if windowCount > 0 {
                    Text("^[\(windowCount) window](inflect: true) open")
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
            connections.removeDocuments(except: store.machines.map(\.id))
            undoManager?.registerUndo(withTarget: store) { _ in restore(machine) }
            undoManager?.setActionName("Remove “\(machine.name)”")
        } catch { errorMessage = error.localizedDescription }
    }

    /// Undoes a removal, registering the removal again as the redo action.
    private func restore(_ machine: Machine) {
        do {
            try store.save(machine)
            selection = machine.id
            undoManager?.registerUndo(withTarget: store) { _ in remove(machine) }
            undoManager?.setActionName("Remove “\(machine.name)”")
        } catch { errorMessage = "Couldn’t restore \(machine.name). \(error.localizedDescription)" }
    }
}
