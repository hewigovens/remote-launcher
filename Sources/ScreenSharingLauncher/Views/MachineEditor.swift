import SwiftUI

struct MachineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var machine: Machine
    let isNew: Bool
    let save: (Machine) throws -> Void
    @State private var errorMessage: String?
    @State private var portText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isNew ? "Add a Mac" : "Edit Mac").font(.title2.bold())
            Form {
                TextField("Name", text: $machine.name, prompt: Text("Office Mac"))
                TextField("Address", text: $machine.host, prompt: Text("mac-studio.local"))
                    .help("A host name, IPv4 address, or IPv6 address")
                TextField("Username", text: $machine.username, prompt: Text("Ask when connecting"))
                TextField("Port", text: $portText)
                Picker("High Performance", selection: $machine.virtualDisplays) {
                    Text("1 virtual display").tag(1)
                    Text("2 virtual displays").tag(2)
                }
            }
            Text("Passwords are handled by Screen Sharing and your Keychain.")
                .font(.callout).foregroundStyle(.secondary)
            if let errorMessage { Text(errorMessage).font(.callout).foregroundStyle(.red).textSelection(.enabled) }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "Add Mac" : "Save") { submit() }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear { portText = String(machine.port) }
    }

    private func submit() {
        do {
            guard let port = Int(portText) else { throw LauncherError("Enter a numeric port between 1 and 65535.") }
            machine.port = port
            try save(machine)
            dismiss()
        } catch { errorMessage = error.localizedDescription }
    }
}
