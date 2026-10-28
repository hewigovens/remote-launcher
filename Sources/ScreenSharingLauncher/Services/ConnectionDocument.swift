import Foundation

struct ConnectionDocument {
    static func data(for machine: Machine) throws -> Data {
        let machine = try machine.validated()
        let address = try machine.connectionURL.absoluteString
        // Match Screen Sharing 7's exported restoration state, alongside the URL's
        // numVirtualDisplays option (which is required to skip the type chooser):
        // 0 = Standard, 1/2 = one/two virtual displays, 3 = remote Mac's display.
        // Keep this undocumented file-format detail here; do not modify Apple's preferences.
        let document: [String: Any] = [
            "URL": address,
            "restorationAttributes": [
                "targetAddress": address,
                "displayType": machine.virtualDisplays,
                "dynamicResolution": machine.virtualDisplays == 1,
            ],
        ]
        return try PropertyListSerialization.data(fromPropertyList: document, format: .xml, options: 0)
    }
}
