import SwiftUI

struct MachineRow: View {
    let machine: Machine
    let isOpen: Bool
    let isOpening: Bool
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: "desktopcomputer").font(.title2).foregroundStyle(.secondary).frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(machine.name).fontWeight(.medium).foregroundStyle(.primary)
                    Text(machine.address).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 16)
                if isOpening {
                    ProgressView().controlSize(.small).accessibilityLabel("Opening \(machine.name)")
                } else {
                    VStack(alignment: .trailing, spacing: 3) {
                        Label(isOpen ? "Show Window" : "Connect", systemImage: isOpen ? "arrow.up.forward.app" : "arrow.up.right")
                            .foregroundStyle(isOpen ? Color.green : Color.accentColor)
                        Text("\(machine.virtualDisplays) \(machine.virtualDisplays == 1 ? "display" : "displays") · High Performance")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isOpening)
        .accessibilityLabel("\(isOpen ? "Show" : "Connect to") \(machine.name), \(machine.address)")
        .help(isOpen ? "Bring this Mac’s existing Screen Sharing window forward" : "Open a High Performance connection")
    }
}
