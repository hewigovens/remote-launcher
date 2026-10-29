import Foundation
import AppKit
import Darwin
import Testing
@testable import ScreenSharingLauncher

@Suite @MainActor
struct LauncherTests {
    @Test func dockReopenRequestsTheLauncherScene() {
        let delegate = AppDelegate()
        var requests = 0
        delegate.openMainWindow = { requests += 1 }
        #expect(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        #expect(requests == 1)
        // An About panel can be visible even when the main window is closed.
        #expect(delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
        #expect(requests == 2)
    }

    @Test func machineIconsMigrateOldFilesAndRespectOverrides() throws {
        let data = Data("""
        [{"id":"00000000-0000-0000-0000-000000000001","name":"Office","host":"office.local","username":"","port":5900,"virtualDisplays":1}]
        """.utf8)
        var machine = try #require(JSONDecoder().decode([Machine].self, from: data).first)
        #expect(machine.modelIdentifier == nil)
        #expect(machine.kindOverride == nil)
        #expect(machine.kind == .mac)
        machine.modelIdentifier = "Mac14,14"
        #expect(machine.kind == .macStudio)
        machine.kindOverride = .macBook
        #expect(machine.kind == .macBook)
        let restored = try JSONDecoder().decode(Machine.self, from: JSONEncoder().encode(machine))
        #expect(restored == machine)
        #expect(MachineKind(modelIdentifier: "Mac16,11") == .macMini)
        #expect(MachineKind(modelIdentifier: "MacBookPro18,3") == .macBook)
        #expect(MachineKind(modelIdentifier: "Mac14,2") == .macBook)
        #expect(MachineKind(modelIdentifier: "Mac99,1") == .mac)
    }

    @Test func discoveryMatchesHostsAndPortsWithoutGuessingNames() {
        let discovered = DiscoveredMac(hosts: ["office.local.", "192.0.2.10", "2001:db8::1"], port: 5900, modelIdentifier: "Mac16,11")
        #expect(discovered.matches(Machine(name: "Any Name", host: "OFFICE.local")))
        #expect(discovered.matches(Machine(name: "Other", host: "192.0.2.10")))
        #expect(discovered.matches(Machine(name: "IPv6", host: "2001:0db8:0000:0000:0000:0000:0000:0001")))
        #expect(!discovered.matches(Machine(name: "Office", host: "other.local")))
        #expect(!discovered.matches(Machine(name: "Forwarded", host: "192.0.2.10", port: 5901)))
    }

    @Test func discoveredModelsSurviveEditingAndResetWhenAddressChanges() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let store = MachineStore(files: fixture.files)
        var editorSnapshot = Machine(name: "Office", host: "office.local")
        try store.save(editorSnapshot)
        try store.applyDiscovery(DiscoveredMac(hosts: ["office.local"], port: 5900, modelIdentifier: "Mac14,14"))
        editorSnapshot.name = "Work"
        editorSnapshot.kindOverride = .macMini
        try store.save(editorSnapshot)
        let restored = MachineStore(files: fixture.files)
        #expect(restored.machines.first?.modelIdentifier == "Mac14,14")
        #expect(restored.machines.first?.kind == .macMini)
        var edited = try #require(restored.machines.first)
        edited.host = "other.local"
        try restored.save(edited)
        #expect(restored.machines.first?.modelIdentifier == nil)
        #expect(restored.machines.first?.kindOverride == .macMini)
    }

    @Test func closedTCPConnectionIsNotMistakenForAnOpenViewer() throws {
        let server = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(server) }
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(server, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        try #require(bound == 0 && listen(server, 1) == 0)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let named = withUnsafeMutablePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { getsockname(server, $0, &length) }
        }
        try #require(named == 0)
        var client = socket(AF_INET, SOCK_STREAM, 0)
        defer { if client >= 0 { close(client) } }
        let connected = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { connect(client, $0, length) }
        }
        try #require(connected == 0)
        var peer = accept(server, nil, nil)
        defer { if peer >= 0 { close(peer) } }
        try #require(peer >= 0)
        let pid = ProcessInfo.processInfo.processIdentifier
        let port = UInt16(bigEndian: address.sin_port)
        #expect(ProcessIdentity.hasTCPConnection(pid, port: port) == true)
        close(client)
        client = -1
        close(peer)
        peer = -1
        #expect(ProcessIdentity.hasTCPConnection(pid, port: port) == false)
        #expect(ProcessIdentity.read(pid) != nil) // The process itself is still alive.
    }

    @Test func processIdentityRejectsRecycledPIDAndDifferentExecutable() throws {
        let identity = try #require(ProcessIdentity.read(ProcessInfo.processInfo.processIdentifier))
        let executable = URL(fileURLWithPath: identity.executablePath)
        var record = SessionRecord(endpointKey: "test|5900", processIdentifier: identity.processIdentifier, launchDate: identity.launchDate)
        #expect(identity.matches(record, executable: executable))
        record.launchDate.addTimeInterval(-60)
        #expect(!identity.matches(record, executable: executable))
        record.launchDate = identity.launchDate
        #expect(!identity.matches(record, executable: URL(fileURLWithPath: "/another/application")))
        #expect(ProcessIdentity.read(-1) == nil)
    }

    @Test func connectionDocumentRequestsHighPerformanceWithoutPassword() throws {
        let machine = Machine(name: "Office", host: "office.local", username: "a user@work", virtualDisplays: 2)
        let data = try ConnectionDocument.data(for: machine)
        let plist = try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        let urlString = try #require(plist["URL"] as? String)
        let url = try #require(URL(string: urlString))
        #expect(url.host == "office.local")
        #expect(url.user(percentEncoded: false) == "a user@work")
        #expect(url.password == nil)
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query?.contains(URLQueryItem(name: "quality", value: "high")) == true)
        #expect(query?.contains(URLQueryItem(name: "numVirtualDisplays", value: "2")) == true)
        let attributes = try #require(plist["restorationAttributes"] as? [String: Any])
        #expect(attributes["displayType"] as? Int == 2)
        #expect(attributes["dynamicResolution"] as? Bool == false)
        #expect(attributes["targetAddress"] as? String == url.absoluteString)
        let single = try ConnectionDocument.data(for: Machine(name: "One", host: "one.local"))
        let singlePlist = try #require(PropertyListSerialization.propertyList(from: single, format: nil) as? [String: Any])
        let singleAttributes = try #require(singlePlist["restorationAttributes"] as? [String: Any])
        #expect(singleAttributes["displayType"] as? Int == 1)
        #expect(singleAttributes["dynamicResolution"] as? Bool == true)
    }

    @Test func validatesIPv6AndRejectsURLInjection() throws {
        let ipv6 = try Machine(name: " IPv6 ", host: " [2001:db8::1] ", port: 5901).validated()
        #expect(ipv6.name == "IPv6")
        #expect(try ipv6.connectionURL.absoluteString == "vnc://[2001:db8::1]:5901?quality=high&numVirtualDisplays=1")
        for host in ["vnc://office.local", "office.local/path", "user@host", "host?password=secret", "host\nname", "host%20name", "office.local:5901"] {
            #expect(throws: (any Error).self) { try Machine(name: "Invalid", host: host).validated() }
        }
        #expect(throws: (any Error).self) { try Machine(name: "Invalid", host: "host", port: 0).validated() }
    }

    @Test func linkLocalIPv6KeepsItsInterfaceZone() throws {
        let machine = try Machine(name: "Link", host: "fe80::1%en0").validated()
        let url = try machine.connectionURL
        #expect(url.absoluteString == "vnc://[fe80::1%25en0]:5900?quality=high&numVirtualDisplays=1")
        #expect(url.host(percentEncoded: false) == "fe80::1%en0")
        for host in ["fe80::1%", "fe80::1%en0/1", "fe80::1%%en0", "fe80::1%25en0", "zz::1%en0"] {
            #expect(throws: (any Error).self) { try Machine(name: "Invalid", host: host).validated() }
        }
    }

    @Test func displayCountsUseInflectedPlurals() {
        #expect(Machine(name: "One", host: "one.local").displayDescription == "1 display")
        #expect(Machine(name: "Two", host: "two.local", virtualDisplays: 2).displayDescription == "2 displays")
    }

    @Test func removedMacsLoseTheirConnectionDocuments() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let client = FakeScreenSharingClient()
        let coordinator = SessionCoordinator(client: client, files: fixture.files)
        let kept = Machine(name: "One", host: "one.local")
        await coordinator.open(kept)
        await coordinator.open(Machine(name: "Two", host: "two.local"))
        let other = fixture.files.directory.appendingPathComponent("Connections/notes.txt")
        try fixture.files.write(Data(), to: other)
        coordinator.removeDocuments(except: [kept.id])
        let remaining = try FileManager.default.contentsOfDirectory(atPath: other.deletingLastPathComponent().path)
        #expect(Set(remaining) == ["\(kept.id.uuidString).vncloc", "notes.txt"])
        // Removing a document leaves its viewer tracked for reuse.
        #expect(coordinator.sessions.count == 2)
    }

    @Test func repeatedClicksReuseAndSeparateMachinesLaunchIndependently() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let client = FakeScreenSharingClient()
        let coordinator = SessionCoordinator(client: client, files: fixture.files)
        let first = Machine(name: "One", host: "one.local")
        await coordinator.open(first)
        await coordinator.open(first)
        #expect(client.launches.count == 1)
        #expect(client.activations == [1])
        await coordinator.open(Machine(name: "Two", host: "two.local"))
        #expect(client.launches.count == 2)
        #expect(coordinator.sessions.count == 2)
        #expect(client.launches[0].document != client.launches[1].document)
        #expect(coordinator.errorMessage == nil)
    }

    @Test func clicksDuringLaunchDoNotCreateDuplicateProcess() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let client = FakeScreenSharingClient()
        client.holdLaunch = true
        let coordinator = SessionCoordinator(client: client, files: fixture.files)
        let machine = Machine(name: "One", host: "one.local")
        var started = client.launchStarted.stream.makeAsyncIterator()
        let first = Task { await coordinator.open(machine) }
        await started.next()
        await coordinator.open(machine)
        #expect(client.launches.count == 1)
        client.finishLaunch()
        await first.value
        #expect(coordinator.sessions.count == 1)
        #expect(coordinator.opening.isEmpty)
    }

    @Test func restartRestoresLiveProcessAndReplacesExitedProcess() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let client = FakeScreenSharingClient()
        let machine = Machine(name: "One", host: "one.local")
        await SessionCoordinator(client: client, files: fixture.files).open(machine)
        let restarted = SessionCoordinator(client: client, files: fixture.files)
        await restarted.open(machine)
        #expect(client.launches.count == 1)
        #expect(client.activations == [1])
        client.live.remove(1)
        restarted.refresh()
        #expect(restarted.sessions.isEmpty)
        await restarted.open(machine)
        #expect(client.launches.count == 2)
        #expect(restarted.sessions[machine.endpointKey]?.processIdentifier == 2)
    }

    @Test func failedLaunchCanBeRetried() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let client = FakeScreenSharingClient()
        client.failNextLaunch = true
        let coordinator = SessionCoordinator(client: client, files: fixture.files)
        let machine = Machine(name: "One", host: "one.local")
        await coordinator.open(machine)
        #expect(coordinator.sessions.isEmpty)
        #expect(coordinator.opening.isEmpty)
        #expect(coordinator.errorMessage != nil)
        await coordinator.open(machine)
        #expect(coordinator.sessions.count == 1)
        #expect(client.launches.count == 2)
    }

    @Test func persistenceFailureAfterLaunchStillReusesProcess() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        // A directory at the session-file path makes the atomic write fail.
        try FileManager.default.createDirectory(at: fixture.files.directory.appendingPathComponent("sessions.json"), withIntermediateDirectories: true)
        let client = FakeScreenSharingClient()
        let coordinator = SessionCoordinator(client: client, files: fixture.files)
        let machine = Machine(name: "One", host: "one.local")
        await coordinator.open(machine)
        #expect(coordinator.errorMessage != nil)
        await coordinator.open(machine)
        #expect(client.launches.count == 1)
        #expect(client.activations == [1])
    }

    @Test func machineListPersistsEditsAndRejectsDuplicateEndpoints() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let store = MachineStore(files: fixture.files)
        var first = Machine(name: "Zebra", host: "ONE.local.")
        try store.save(first)
        #expect(throws: (any Error).self) { try store.save(Machine(name: "Duplicate", host: "one.local")) }
        first.name = "Office"
        try store.save(first)
        try store.save(Machine(name: "Build", host: "build.local"))
        let restored = MachineStore(files: fixture.files)
        #expect(restored.machines.map(\.name) == ["Build", "Office"])
        try restored.remove(first.id)
        #expect(MachineStore(files: fixture.files).machines.map(\.name) == ["Build"])
    }

    @Test func malformedMachineFileIsNeverOverwritten() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let original = Data("invalid json".utf8)
        let file = fixture.files.directory.appendingPathComponent("machines.json")
        try fixture.files.write(original, to: file)
        let store = MachineStore(files: fixture.files)
        #expect(store.loadError != nil)
        #expect(throws: (any Error).self) { try store.save(Machine(name: "One", host: "one.local")) }
        #expect(try Data(contentsOf: file) == original)
    }

    @Test func duplicateMachineIDsOrEndpointsPreserveSavedFile() throws {
        let first = Machine(name: "Office", host: "OFFICE.local.")
        let duplicateID = Machine(id: first.id, name: "Build", host: "build.local")
        let duplicateEndpoint = Machine(name: "Other Office", host: "office.local")
        for duplicate in [duplicateID, duplicateEndpoint] {
            let fixture = try Fixture()
            defer { fixture.remove() }
            try fixture.files.write([first, duplicate], to: "machines.json")
            let file = fixture.files.directory.appendingPathComponent("machines.json")
            let original = try Data(contentsOf: file)

            let store = MachineStore(files: fixture.files)
            #expect(store.loadError != nil)
            #expect(store.machines.isEmpty)
            #expect(throws: (any Error).self) { try store.remove(first.id) }
            #expect(throws: (any Error).self) { try store.save(Machine(name: "New", host: "new.local")) }
            #expect(try Data(contentsOf: file) == original)
        }
    }
}

private struct Fixture {
    let files: LauncherFiles
    init() throws {
        files = LauncherFiles(directory: FileManager.default.temporaryDirectory.appendingPathComponent("ScreenSharingLauncherTests-\(UUID())"))
        try FileManager.default.createDirectory(at: files.directory, withIntermediateDirectories: true)
    }
    func remove() { try? FileManager.default.removeItem(at: files.directory) }
}

@MainActor
private final class FakeScreenSharingClient: ScreenSharingClient {
    var launches: [(document: URL, key: String)] = []
    var activations: [Int32] = []
    var live: Set<Int32> = []
    var holdLaunch = false
    var failNextLaunch = false
    let launchStarted = AsyncStream<Void>.makeStream()
    private var continuation: CheckedContinuation<Void, Never>?

    func launch(document: URL, endpointKey: String) async throws -> SessionRecord {
        launches.append((document, endpointKey))
        launchStarted.continuation.yield(())
        if failNextLaunch {
            failNextLaunch = false
            throw LauncherError("Test launch failure")
        }
        if holdLaunch { await withCheckedContinuation { continuation = $0 } }
        let pid = Int32(launches.count)
        live.insert(pid)
        return SessionRecord(endpointKey: endpointKey, processIdentifier: pid, launchDate: Date(timeIntervalSince1970: Double(pid)))
    }
    func isRunning(_ session: SessionRecord) -> Bool { live.contains(session.processIdentifier) }
    func activate(_ session: SessionRecord) throws { activations.append(session.processIdentifier) }
    func finishLaunch() { holdLaunch = false; continuation?.resume(); continuation = nil }
}
