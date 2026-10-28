import SwiftUI

struct LauncherActions {
    var add: (() -> Void)?
    var open: (() -> Void)?
    var edit: (() -> Void)?
    var remove: (() -> Void)?
    var hasOpenWindow: Bool
}

private struct LauncherActionsKey: FocusedValueKey {
    typealias Value = LauncherActions
}

extension FocusedValues {
    var launcherActions: LauncherActions? {
        get { self[LauncherActionsKey.self] }
        set { self[LauncherActionsKey.self] = newValue }
    }
}

struct LauncherCommands: Commands {
    @FocusedValue(\.launcherActions) private var actions

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Add Mac…") { actions?.add?() }
                .keyboardShortcut("n")
                .disabled(actions?.add == nil)
        }
        CommandMenu("Connection") {
            Button(actions?.hasOpenWindow == true ? "Show Screen Sharing Window" : "Connect") { actions?.open?() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(actions?.open == nil)
            Button("Edit Mac…") { actions?.edit?() }
                .keyboardShortcut("i")
                .disabled(actions?.edit == nil)
            Divider()
            Button("Remove from List", role: .destructive) { actions?.remove?() }
                .disabled(actions?.remove == nil)
        }
    }
}
