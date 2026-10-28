import Foundation

struct SessionRecord: Codable, Equatable, Sendable {
    var endpointKey: String
    var processIdentifier: Int32
    var launchDate: Date
}
