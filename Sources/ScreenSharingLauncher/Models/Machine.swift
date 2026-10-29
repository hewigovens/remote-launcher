import Foundation
import Darwin

struct Machine: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var host: String
    var username = ""
    var port = 5900
    var virtualDisplays = 1
    var modelIdentifier: String?
    var kindOverride: MachineKind?

    var normalizedHost: String { host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
    var endpointKey: String { "\(normalizedHost)|\(port)" }
    var kind: MachineKind { kindOverride ?? MachineKind(modelIdentifier: modelIdentifier ?? "") }
    var address: String {
        let server = host.contains(":") ? "[\(host)]" : host
        return port == 5900 ? server : "\(server):\(port)"
    }
    var displayDescription: String {
        String(AttributedString(localized: "^[\(virtualDisplays) display](inflect: true)").characters)
    }

    var connectionURL: URL {
        get throws {
            var components = URLComponents()
            components.scheme = "vnc"
            if host.contains(":") {
                // Bracket IPv6 literals and encode a zone delimiter as %25 (RFC 6874).
                components.percentEncodedHost = "[\(host.replacingOccurrences(of: "%", with: "%25"))]"
            } else {
                components.host = host
            }
            components.port = port
            // Screen Sharing exports this query option in its own .vncloc URLs.
            components.queryItems = [
                URLQueryItem(name: "quality", value: "high"),
                URLQueryItem(name: "numVirtualDisplays", value: String(virtualDisplays)),
            ]
            if !username.isEmpty { components.user = username }
            guard let url = components.url else { throw LauncherError("This server address is invalid.") }
            return url
        }
    }

    func validated() throws -> Machine {
        var result = self
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        result.username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if result.host.hasPrefix("["), result.host.hasSuffix("]") {
            result.host = String(result.host.dropFirst().dropLast())
        }
        guard !result.name.isEmpty else { throw LauncherError("Enter a name for this Mac.") }
        guard !result.host.isEmpty,
              result.host.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              !result.host.contains(where: { "/?#@\\[]".contains($0) }),
              !result.host.contains("%") || result.host.contains(":") else {
            throw LauncherError("Enter a host name or IP address, without vnc:// or a port.")
        }
        guard (1...65535).contains(port) else { throw LauncherError("The port must be between 1 and 65535.") }
        if result.host.contains(":") {
            // A link-local address may name its interface zone, such as fe80::1%en0 or fe80::1%4.
            // Interface names start with a letter, which rejects an already-encoded %25en0.
            let parts = result.host.split(separator: "%", maxSplits: 1, omittingEmptySubsequences: false)
            let zone = parts.count == 2 ? parts[1] : nil
            let zoneIsValid = zone.map { zone in
                zone.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) }
                    && (zone.first?.isLetter == true || !zone.isEmpty && zone.allSatisfy(\.isNumber))
            } ?? true
            var address = in6_addr()
            guard zoneIsValid, inet_pton(AF_INET6, String(parts[0]), &address) == 1 else {
                throw LauncherError("Enter the host without a port; use the Port field below.")
            }
        }
        guard (1...2).contains(virtualDisplays) else { throw LauncherError("Choose one or two virtual displays.") }
        _ = try result.connectionURL
        return result
    }
}

struct LauncherError: LocalizedError {
    var errorDescription: String?
    init(_ description: String) { errorDescription = description }
}
