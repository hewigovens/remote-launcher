import AppKit
import Carbon
import OSLog

@MainActor
protocol ScreenSharingClient {
    func launch(document: URL, endpointKey: String) async throws -> SessionRecord
    func isRunning(_ session: SessionRecord) -> Bool
    func activate(_ session: SessionRecord) throws
}

@MainActor
struct SystemScreenSharingClient: ScreenSharingClient {
    private let applicationURL = URL(fileURLWithPath: "/System/Applications/Utilities/Screen Sharing.app")

    func launch(document: URL, endpointKey: String) async throws -> SessionRecord {
        guard FileManager.default.fileExists(atPath: applicationURL.path) else {
            throw LauncherError("Screen Sharing couldn’t be found in /System/Applications/Utilities.")
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.arguments = ["-NSQuitAlwaysKeepsWindows", "NO"]
        let application = try await NSWorkspace.shared.open([document], withApplicationAt: applicationURL, configuration: configuration)
        guard let identity = ProcessIdentity.read(application.processIdentifier) else {
            throw LauncherError("Screen Sharing quit before its process could be tracked. Try connecting again.")
        }
        return SessionRecord(endpointKey: endpointKey, processIdentifier: identity.processIdentifier, launchDate: identity.launchDate)
    }

    func isRunning(_ session: SessionRecord) -> Bool {
        let executable = applicationURL.appendingPathComponent("Contents/MacOS/Screen Sharing")
        guard ProcessIdentity.read(session.processIdentifier)?.matches(session, executable: executable) == true else { return false }
        // Closing a viewer can leave the Connections window/process open. An idle
        // process is not a reusable connection. Allow time for a fresh launch to connect.
        guard Date().timeIntervalSince(session.launchDate) > 5,
              let port = session.endpointKey.split(separator: "|").last.flatMap({ UInt16($0) }) else { return true }
        return ProcessIdentity.hasTCPConnection(session.processIdentifier, port: port) != false
    }

    func activate(_ session: SessionRecord) throws {
        guard isRunning(session) else {
            throw LauncherError("This Screen Sharing process has ended. Try opening this Mac again.")
        }
        var accepted = false
        if let app = NSRunningApplication(processIdentifier: session.processIdentifier) {
            NSApp.yieldActivation(to: app)
            accepted = app.activate(from: .current, options: [.activateAllWindows])
        }
        if !accepted {
            // AppKit can reject activation of a second instance with the same bundle ID.
            // A standard reopen event targets the exact PID and never opens a new session.
            let reopen = NSAppleEventDescriptor(
                eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
                targetDescriptor: NSAppleEventDescriptor(processIdentifier: session.processIdentifier),
                returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID)
            )
            _ = try reopen.sendEvent(options: [.noReply, .canInteract, .canSwitchLayer], timeout: 1)
        }
        Logger(subsystem: "dev.hewig.ScreenSharingLauncher", category: "activation")
            .info("Reused viewer PID \(session.processIdentifier), reopen event: \(!accepted)")
    }
}
