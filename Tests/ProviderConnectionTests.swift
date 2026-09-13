import Foundation

@main
struct ProviderConnectionTests {
    static var failures = 0
    static func expect(_ value: Bool, _ label: String) {
        if value { print("PASS \(label)") } else { failures += 1; print("FAIL \(label)") }
    }
    static func data(_ text: String) -> Data { Data(text.utf8) }

    @MainActor
    static func main() throws {
        let suite = "NotchBridge.ProviderTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("Cannot create test defaults") }
        defer { defaults.removePersistentDomain(forName: suite) }
        var store = ProviderVisibilityStore(defaults: defaults)
        expect(store.selected == [.claude, .codex], "new install preserves the existing two providers")
        store.set(nil, at: 0)
        expect(store.selected.count == 2, "left slot cannot be removed")
        store.set(nil, at: 1)
        store.set(.codex, at: 0)
        expect(store.left == .codex && store.right == nil, "single Codex occupies left slot")
        store.swap()
        expect(store.selected == [.codex], "single provider swap is a no-op")
        store.set(.codex, at: 1)
        expect(store.selected == [.codex], "adding duplicate cannot consume second slot")
        store.set(.claude, at: 1)
        store.swap()
        expect(store.selected == [.claude, .codex], "swap changes both positions")
        store.set(.codex, at: 0)
        expect(store.selected == [.codex, .claude], "choosing occupied provider swaps slots")
        store = ProviderVisibilityStore(defaults: defaults)
        expect(store.selected == [.codex, .claude], "order survives relaunch")
        for left in IslandProvider.allCases {
            for right in IslandProvider.allCases {
                store.set(left, at: 0)
                store.set(right, at: 1)
                expect((1...2).contains(store.selected.count) && Set(store.selected).count == store.selected.count,
                       "valid selection for \(left) / \(right)")
            }
        }
        defaults.removeObject(forKey: ProviderVisibilityStore.selectionKey)
        defaults.set(false, forKey: "MacIsland.claudeVisible")
        defaults.set(true, forKey: "MacIsland.codexVisible")
        store = ProviderVisibilityStore(defaults: defaults)
        expect(store.selected == [.codex], "migrates Codex-only preference to left")
        defaults.removeObject(forKey: ProviderVisibilityStore.selectionKey)
        defaults.set(false, forKey: "MacIsland.codexVisible")
        store = ProviderVisibilityStore(defaults: defaults)
        expect(store.selected == [.claude], "migrates both hidden to one provider")
        defaults.set(["unknown", "codex", "codex", "claude", "codex"], forKey: ProviderVisibilityStore.selectionKey)
        store = ProviderVisibilityStore(defaults: defaults)
        expect(store.selected == [.codex, .claude], "repairs invalid, duplicate, and over-capacity preferences")

        if failures > 0 { exit(1) }
    }
}
