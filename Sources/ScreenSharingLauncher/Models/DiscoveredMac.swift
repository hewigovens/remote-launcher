import Foundation
import Network

struct DiscoveredMac: Sendable {
    var hosts: Set<String>
    var port: Int
    var modelIdentifier: String

    func matches(_ machine: Machine) -> Bool {
        machine.port == port && hosts.contains { host in
            if host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) == machine.normalizedHost {
                return true
            }
            if let saved = IPv6Address(machine.host), let discovered = IPv6Address(host) {
                return saved == discovered
            }
            return false
        }
    }
}
