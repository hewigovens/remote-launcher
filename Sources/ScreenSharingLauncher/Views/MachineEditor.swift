import SwiftUI

struct MachineEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var machine: Machine
    let isNew: Bool
    let save: (Machine) throws -> Void
    @State private var errorMessage: String?
    @State private var portText = ""
    @FocusState private var nameFocused: Bool

    private var canSave: Bool {
        !machine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !machine.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(isNew ? "Add a Mac" : "Edit Mac").font(.title2.weight(.semibold))
            Form {
                TextField("Name", text: $machine.name, prompt: Text("Office Mac"))
                    .focused($nameFocused)
                TextField("Address", text: $machine.host, prompt: Text("mac-studio.local"))
                    .help("A host name, IPv4 address, or IPv6 address")
                TextField("Username", text: $machine.username, prompt: Text("Ask when connecting"))
                TextField("Port", text: $portText)
                Picker("Displays", selection: $machine.virtualDisplays) {
                    Text("1 display").tag(1)
                    Text("2 displays").tag(2)
                }
                .pickerStyle(.segmented)
                .help("Virtual displays for High Performance screen sharing")
            }
            .formStyle(.columns)
            .textFieldStyle(.roundedBorder)
            VStack(alignment: .leading, spacing: 4) {
                Text("Connects with High Performance screen sharing.")
                Text("Screen Sharing handles passwords and Keychain access.")
            }
            .font(.caption).foregroundStyle(.secondary)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle.fill")
                    .font(.callout).foregroundStyle(.red).textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }.keyboardShortcut(.cancelAction)
                Button(isNew ? "Add Mac" : "Save") { submit() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(24)
        .frame(width: 440)
        .onAppear {
            portText = String(machine.port)
            nameFocused = true
        }
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
