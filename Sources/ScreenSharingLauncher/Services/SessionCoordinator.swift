import Foundation
import Observation
import OSLog

@MainActor @Observable
final class SessionCoordinator {
    private(set) var sessions: [String: SessionRecord] = [:]
    private(set) var opening: Set<String> = []
    var errorMessage: String?
    private let client: any ScreenSharingClient
    private let files: LauncherFiles
    private var documentsDirectory: URL { files.directory.appendingPathComponent("Connections", isDirectory: true) }

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
            let document = documentsDirectory.appendingPathComponent("\(machine.id.uuidString).vncloc")
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

    /// Deletes connection documents, which contain the host and username, for Macs no
    /// longer in the list. Open viewers keep running; each launch writes a fresh document.
    func removeDocuments(except ids: [Machine.ID]) {
        let keep = Set(ids.map { "\($0.uuidString).vncloc" })
        // The folder does not exist until the first connection.
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: documentsDirectory.path) else { return }
        for name in names where name.hasSuffix(".vncloc") && !keep.contains(name) {
            do { try FileManager.default.removeItem(at: documentsDirectory.appendingPathComponent(name)) }
            catch {
                Logger(subsystem: "dev.hewig.ScreenSharingLauncher", category: "sessions")
                    .error("Couldn’t delete a connection document: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    private func persist() throws {
        try files.write(sessions.values.sorted { $0.endpointKey < $1.endpointKey }, to: "sessions.json")
    }
}
