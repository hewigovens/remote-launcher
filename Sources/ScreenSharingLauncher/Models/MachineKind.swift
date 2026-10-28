import Foundation

enum MachineKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case macBook, macMini, macStudio, iMac, macPro, mac

    var id: Self { self }

    var title: String {
        switch self {
        case .macBook: "MacBook"
        case .macMini: "Mac mini"
        case .macStudio: "Mac Studio"
        case .iMac: "iMac"
        case .macPro: "Mac Pro"
        case .mac: "Mac"
        }
    }

    var symbolName: String {
        switch self {
        case .macBook: "macbook"
        case .macMini: "macmini"
        case .macStudio: "macstudio"
        case .iMac, .mac: "desktopcomputer"
        case .macPro: "macpro.gen3"
        }
    }

    init(modelIdentifier: String) {
        let model = modelIdentifier.lowercased()
        if model.hasPrefix("macbook") { self = .macBook; return }
        if model.hasPrefix("macmini") { self = .macMini; return }
        if model.hasPrefix("imac") { self = .iMac; return }
        if model.hasPrefix("macpro") { self = .macPro; return }
        // Generic Apple silicon identifiers need an explicit mapping. Unknown
        // models retain the generic icon; do not guess from the machine's name.
        // Sources: Apple's model identification pages 102852, 102231, 108052,
        // 102869, 108054, and 102887 (checked 2026-10-28).
        switch model {
        case "mac14,3", "mac14,12", "mac16,10", "mac16,11", "mac17,16", "mac18,5":
            self = .macMini
        case "mac13,1", "mac13,2", "mac14,13", "mac14,14", "mac15,14", "mac16,9", "mac17,14", "mac17,15":
            self = .macStudio
        case "mac14,2", "mac14,5", "mac14,6", "mac14,7", "mac14,9", "mac14,10", "mac14,15",
             "mac15,3", "mac15,6", "mac15,7", "mac15,8", "mac15,9", "mac15,10", "mac15,11", "mac15,12", "mac15,13",
             "mac16,1", "mac16,5", "mac16,6", "mac16,7", "mac16,8", "mac16,12", "mac16,13",
             "mac17,2", "mac17,3", "mac17,4", "mac17,6", "mac17,7", "mac17,8", "mac17,9":
            self = .macBook
        case "mac15,4", "mac15,5", "mac16,2", "mac16,3":
            self = .iMac
        case "mac14,8":
            self = .macPro
        default:
            self = .mac
        }
    }
}
