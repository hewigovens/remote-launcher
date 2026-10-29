import Foundation
import Observation

@MainActor @Observable
final class MachineStore {
    private(set) var machines: [Machine] = []
    private(set) var loadError: String?
    private let files: LauncherFiles
    var fileURL: URL { files.directory.appendingPathComponent("machines.json") }

    init(files: LauncherFiles = .application) {
        self.files = files
        do {
            let loaded = try files.read([Machine].self, from: "machines.json", default: [])
            let validated = try loaded.map { try $0.validated() }
            guard Set(validated.map(\.id)).count == validated.count else {
                throw LauncherError("The saved Mac list contains duplicate identifiers.")
            }
            guard Set(validated.map(\.endpointKey)).count == validated.count else {
                throw LauncherError("The saved Mac list contains duplicate addresses and ports.")
            }
            machines = validated
        } catch {
            loadError = "Couldn’t load your Macs. The saved file has been preserved. \(error.localizedDescription)"
        }
    }

    func save(_ machine: Machine) throws {
        if let loadError { throw LauncherError(loadError) }
        var machine = try machine.validated()
        guard !machines.contains(where: { $0.id != machine.id && $0.endpointKey == machine.endpointKey }) else {
            throw LauncherError("This address and port are already in your list.")
        }
        var updated = machines
        if let index = updated.firstIndex(where: { $0.id == machine.id }) {
            // The editor can predate a discovery result. Keep metadata owned by
            // discovery for the same endpoint; never carry it to another host.
            machine.modelIdentifier = updated[index].endpointKey == machine.endpointKey ? updated[index].modelIdentifier : nil
            updated[index] = machine
        } else {
            updated.append(machine)
        }
        try persist(updated)
    }

    func remove(_ id: Machine.ID) throws {
        if let loadError { throw LauncherError(loadError) }
        try persist(machines.filter { $0.id != id })
    }

    func applyDiscovery(_ discovered: DiscoveredMac) throws {
        guard loadError == nil else { return }
        var updated = machines
        var changed = false
        for index in updated.indices where discovered.matches(updated[index]) {
            guard updated[index].modelIdentifier != discovered.modelIdentifier else { continue }
            updated[index].modelIdentifier = discovered.modelIdentifier
            changed = true
        }
        if changed { try persist(updated) }
    }

    private func persist(_ updated: [Machine]) throws {
        let sorted = updated.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        try files.write(sorted, to: "machines.json")
        machines = sorted
    }
}
