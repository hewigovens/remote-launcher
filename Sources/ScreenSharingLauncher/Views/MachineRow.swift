import SwiftUI

struct MachineRow: View {
    let machine: Machine
    let isOpen: Bool
    let isOpening: Bool
    let open: () -> Void
    let edit: () -> Void
    let remove: () -> Void

    private var openHelp: String {
        isOpen ? "Show \(machine.name)’s existing Screen Sharing window" : "Connect to \(machine.name) with High Performance screen sharing"
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: open) {
                HStack(spacing: 12) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 23)).foregroundStyle(.secondary).frame(width: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(machine.name).fontWeight(.semibold).foregroundStyle(.primary)
                            .lineLimit(1).help(machine.name)
                        HStack(spacing: 6) {
                            Text(machine.address).truncationMode(.middle).help(machine.address)
                            Text("·").accessibilityHidden(true)
                            Text("\(machine.virtualDisplays) \(machine.virtualDisplays == 1 ? "display" : "displays")")
                                .fixedSize()
                        }
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isOpening)
            .accessibilityLabel("\(machine.name), \(machine.address), \(machine.virtualDisplays) \(machine.virtualDisplays == 1 ? "display" : "displays")")
            .accessibilityHint(openHelp)

            Button(action: open) {
                ZStack {
                    Label(isOpen ? "Show" : "Connect", systemImage: isOpen ? "arrow.up.forward.app" : "arrow.up.right")
                        .opacity(isOpening ? 0 : 1)
                    if isOpening { ProgressView().controlSize(.small) }
                }
                .frame(width: 84)
            }
            .buttonStyle(.bordered)
            .disabled(isOpening)
            .accessibilityLabel(isOpening ? "Opening \(machine.name)" : openHelp)
            .help(openHelp)

            Menu {
                Button("Edit Mac…", systemImage: "pencil", action: edit)
                Divider()
                Button("Remove from List", systemImage: "minus.circle", role: .destructive, action: remove)
            } label: {
                Image(systemName: "ellipsis").frame(width: 16, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("Actions for \(machine.name)")
            .help("Edit or remove \(machine.name)")
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(machine.name), \(machine.address), \(machine.virtualDisplays) \(machine.virtualDisplays == 1 ? "display" : "displays")")
        .accessibilityValue(isOpening ? "Opening" : isOpen ? "Window open" : "Ready to connect")
        .accessibilityAction { if !isOpening { open() } }
        .accessibilityActions {
            if !isOpening { Button(isOpen ? "Show Window" : "Connect", action: open) }
            Button("Edit Mac…", action: edit)
            Button("Remove from List", role: .destructive, action: remove)
        }
    }
}
