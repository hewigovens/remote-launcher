import SwiftUI

struct MachineRow: View {
    let machine: Machine
    let isSelected: Bool
    let isOpen: Bool
    let isOpening: Bool
    let open: () -> Void
    let edit: () -> Void
    let remove: () -> Void

    private var openHelp: String {
        isOpen ? "Show \(machine.name)’s existing Screen Sharing window" : "Connect to \(machine.name) with High Performance screen sharing"
    }

    /// The accent color is invisible on a selected row's accent background.
    private var openStyle: AnyShapeStyle {
        isSelected ? AnyShapeStyle(.primary) : AnyShapeStyle(.tint)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: machine.kind.symbolName)
                .font(.system(size: 23)).foregroundStyle(isOpen ? openStyle : AnyShapeStyle(.secondary)).frame(width: 30)
                .help(machine.kind.title)
            VStack(alignment: .leading, spacing: 4) {
                Text(machine.name).fontWeight(.semibold).foregroundStyle(.primary)
                    .lineLimit(1).help(machine.name)
                HStack(spacing: 6) {
                    Text(machine.address).truncationMode(.middle).help(machine.address)
                    Text("·")
                    Text(machine.displayDescription).fixedSize()
                    if isOpen {
                        Text("·")
                        Text("Window open").fontWeight(.medium).foregroundStyle(openStyle).fixedSize()
                    }
                }
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 0)

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
            .help("Edit or remove \(machine.name)")
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        // VoiceOver reads one element per row; its actions replace the hidden controls.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(machine.name), \(machine.kind.title), \(machine.address), \(machine.displayDescription)")
        .accessibilityValue(isOpening ? "Opening" : isOpen ? "Window open" : "Ready to connect")
        .accessibilityHint(openHelp)
        .accessibilityAction { if !isOpening { open() } }
        .accessibilityActions {
            if !isOpening { Button(isOpen ? "Show Window" : "Connect", action: open) }
            Button("Edit Mac…", action: edit)
            Button("Remove from List", role: .destructive, action: remove)
        }
    }
}
