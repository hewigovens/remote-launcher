import Darwin
import Foundation
import OSLog

@MainActor
final class MachineDiscovery: NSObject, @preconcurrency NetServiceBrowserDelegate, @preconcurrency NetServiceDelegate {
    private struct Candidate {
        var service: NetService
        var info: NetService
        var modelIdentifier: String?
    }

    private let browser = NetServiceBrowser()
    private var candidates: [String: Candidate] = [:]
    private var store: MachineStore?
    private let logger = Logger(subsystem: "dev.hewig.ScreenSharingLauncher", category: "discovery")

    func start(store: MachineStore) {
        guard self.store == nil else { return }
        self.store = store
        browser.delegate = self
        browser.searchForServices(ofType: "_rfb._tcp.", inDomain: "local.")
    }

    func refresh() {
        for candidate in candidates.values {
            if candidate.service.addresses?.isEmpty != false {
                candidate.service.resolve(withTimeout: 5)
            } else {
                apply(candidate)
            }
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        logger.info("Bonjour discovery is unavailable; saved and manual icons remain available.")
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        let key = service.domain + service.type + service.name
        guard candidates[key] == nil else { return }
        let info = NetService(domain: service.domain, type: "_device-info._tcp.", name: service.name)
        candidates[key] = Candidate(service: service, info: info)
        service.delegate = self
        info.delegate = self
        service.resolve(withTimeout: 5)
        // _device-info advertises a TXT record without a connectable service.
        // Monitor it directly; resolving its SRV record would fail.
        info.startMonitoring()
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        let key = service.domain + service.type + service.name
        guard let candidate = candidates.removeValue(forKey: key) else { return }
        candidate.service.stop()
        candidate.info.stopMonitoring()
        // Keep the last known model for a saved Mac when it leaves the network.
    }

    func netServiceDidResolveAddress(_ sender: NetService) {
        guard let candidate = candidates.values.first(where: { $0.service === sender }) else { return }
        apply(candidate)
    }

    func netService(_ sender: NetService, didUpdateTXTRecord data: Data) {
        guard let key = candidates.first(where: { $0.value.info === sender })?.key,
              let value = NetService.dictionary(fromTXTRecord: data)["model"],
              let model = String(data: value, encoding: .utf8),
              !model.isEmpty, model.utf8.count <= 80,
              model.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) || $0 == "," }) else { return }
        candidates[key]?.modelIdentifier = model
        if let candidate = candidates[key] { apply(candidate) }
    }

    private func apply(_ candidate: Candidate) {
        guard let model = candidate.modelIdentifier, let store else { return }
        var hosts = Set((candidate.service.addresses ?? []).compactMap(Self.numericHost))
        if let hostName = candidate.service.hostName { hosts.insert(hostName) }
        guard !hosts.isEmpty else { return }
        do {
            try store.applyDiscovery(DiscoveredMac(hosts: hosts, port: candidate.service.port, modelIdentifier: model))
        } catch {
            logger.error("Couldn’t save discovered Mac models: \(error.localizedDescription, privacy: .private)")
        }
    }

    private static func numericHost(_ data: Data) -> String? {
        data.withUnsafeBytes { bytes in
            guard let address = bytes.baseAddress?.assumingMemoryBound(to: sockaddr.self),
                  bytes.count >= MemoryLayout<sockaddr>.size,
                  (address.pointee.sa_family == AF_INET && bytes.count >= MemoryLayout<sockaddr_in>.size) ||
                  (address.pointee.sa_family == AF_INET6 && bytes.count >= MemoryLayout<sockaddr_in6>.size) else { return nil }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address, socklen_t(bytes.count), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { return nil }
            return String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        }
    }
}
