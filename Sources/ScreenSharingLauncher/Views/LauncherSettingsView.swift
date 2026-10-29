import SwiftUI

struct LauncherSettingsView: View {
    @AppStorage("showInMenuBar") private var showInMenuBar = true

    var body: some View {
        Form {
            Toggle("Show in menu bar", isOn: $showInMenuBar)
                .help("Connect to your saved Macs from the menu bar")
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .frame(width: 420, height: 80)
    }
}
