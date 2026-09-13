import SwiftUI

extension IslandProvider {
    func planDisplayName(_ plan: String?) -> String? {
        guard let plan else { return nil }
        if self == .codex {
            switch plan.lowercased() {
            case "prolite", "pro": return "Pro"
            case "plus": return "Plus"
            default: break
            }
        }
        return plan
    }

    var color: Color {
        switch self {
        case .claude: return IslandColor.claude
        case .codex: return IslandColor.codex
        }
    }
}

struct ProviderMark: View {
    let provider: IslandProvider
    private static let claude = Bundle.main.url(forResource: "claude_logo", withExtension: "pdf").flatMap { NSImage(contentsOf: $0) }
    private static let codex = Bundle.main.url(forResource: "openai_logo", withExtension: "pdf").flatMap { NSImage(contentsOf: $0) }

    private var image: NSImage? {
        switch provider {
        case .claude: return Self.claude
        case .codex: return Self.codex
        }
    }

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().renderingMode(.template).scaledToFit()
            } else {
                Image(systemName: "a.circle")
                    .resizable().scaledToFit()
            }
        }
        .foregroundStyle(provider.color)
        .frame(width: 20, height: 20)
        .accessibilityLabel(provider.name)
    }
}
