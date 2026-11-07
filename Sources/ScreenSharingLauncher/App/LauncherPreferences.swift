import AppKit

enum LauncherPreferences {
    static let showInDockKey = "showInDock"
    static let showInMenuBarKey = "showInMenuBar"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            showInDockKey: true,
            showInMenuBarKey: true,
        ])
    }

    /// The launcher must stay reachable, so hiding both entry points keeps the Dock.
    static func activationPolicy(showInDock: Bool, showInMenuBar: Bool) -> NSApplication.ActivationPolicy {
        showInDock || !showInMenuBar ? .regular : .accessory
    }
}
