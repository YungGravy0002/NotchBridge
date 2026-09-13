import Foundation

enum IslandProvider: String, CaseIterable, Identifiable, Codable {
    case claude, codex

    var id: String { rawValue }
    var name: String {
        switch self {
        case .claude: return "Claude"
        case .codex: return "Codex"
        }
    }
}
