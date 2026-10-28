import Foundation
import Observation

@MainActor @Observable
final class SessionCoordinator {
    private(set) var sessions: [String: SessionRecord] = [:]
    private(set) var opening: Set<String> = []
    var errorMessage: String?
    private let client: any ScreenSharingClient
    private let files: LauncherFiles

    init(client: any ScreenSharingClient = SystemScreenSharingClient(), files: LauncherFiles = .application) {
        self.client = client
        self.files = files
        do {
            let records = try files.read([SessionRecord].self, from: "sessions.json", default: [])
            for record in records where client.isRunning(record) { sessions[record.endpointKey] = record }
        } catch {
            errorMessage = "Couldn’t restore the Screen Sharing window list. \(error.localizedDescription)"
        }
    }

    func open(_ machine: Machine) async {
        let key = machine.endpointKey
        guard !opening.contains(key) else { return }
        opening.insert(key)
        defer { opening.remove(key) }
        do {
            if let existing = sessions[key], client.isRunning(existing) {
                try client.activate(existing)
                return
            }
            sessions.removeValue(forKey: key)
            let document = files.directory.appendingPathComponent("Connections/\(machine.id.uuidString).vncloc")
            try files.write(ConnectionDocument.data(for: machine), to: document)
            let record = try await client.launch(document: document, endpointKey: key)
            sessions[key] = record
            // Keep the in-memory process even if persisting it fails: a retry must reuse it.
            do { try persist() }
            catch { errorMessage = "Screen Sharing opened, but its window couldn’t be saved for reuse after restarting the launcher. \(error.localizedDescription)" }
        } catch {
            errorMessage = "Couldn’t open \(machine.name). \(error.localizedDescription)"
        }
    }

    func refresh() {
        let alive = sessions.filter { client.isRunning($0.value) }
        guard alive.count != sessions.count else { return }
        sessions = alive
        do { try persist() }
        catch { errorMessage = "Couldn’t save the Screen Sharing window list. \(error.localizedDescription)" }
    }

    private func persist() throws {
        try files.write(sessions.values.sorted { $0.endpointKey < $1.endpointKey }, to: "sessions.json")
    }
}
