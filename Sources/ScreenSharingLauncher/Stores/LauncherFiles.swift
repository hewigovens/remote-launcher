import Foundation

struct LauncherFiles: Sendable {
    var directory: URL

    static var application: LauncherFiles {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return LauncherFiles(directory: support.appendingPathComponent("dev.hewig.ScreenSharingLauncher", isDirectory: true))
    }

    func read<T: Decodable>(_ type: T.Type, from name: String, default fallback: T) throws -> T {
        let file = directory.appendingPathComponent(name)
        guard FileManager.default.fileExists(atPath: file.path) else { return fallback }
        return try JSONDecoder().decode(type, from: Data(contentsOf: file))
    }

    func write<T: Encodable>(_ value: T, to name: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try write(encoder.encode(value), to: directory.appendingPathComponent(name))
    }

    func write(_ data: Data, to file: URL) throws {
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
}
