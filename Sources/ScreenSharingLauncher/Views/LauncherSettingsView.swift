import SwiftUI

struct LauncherSettingsView: View {
    @AppStorage("showInMenuBar") private var showInMenuBar = true

    var body: some View {
        Form {
            Section {
                Toggle("Show in menu bar", isOn: $showInMenuBar)
            } footer: {
                Text("Connect to your saved Macs from the menu bar. You can always reopen Remote Launcher from the Dock.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 160)
    }
}
