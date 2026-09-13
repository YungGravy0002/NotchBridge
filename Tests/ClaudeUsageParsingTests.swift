import Foundation

// Fixture test for the observed (undocumented) oauth/usage shape. If Anthropic
// changes the `limits[]` layout this fails loudly instead of silently hiding
// the per-model weekly limit.
@main
struct ClaudeUsageParsingTests {
    static var failures = 0

    static func check(_ cond: Bool, _ name: String) {
        if cond { print("PASS \(name)") } else { failures += 1; print("FAIL \(name)") }
    }

    static func main() {
        let url = URL(fileURLWithPath: "Tests/Fixtures/claude-oauth-usage.observed.json")
        guard let data = try? Data(contentsOf: url),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { print("FAIL fixture missing or unparseable"); exit(1) }

        let usage = ClaudeUsageParsing.parse(obj, plan: "max")
        check(abs(usage.fiveHour.usedPercent - 0.10) < 0.001, "five_hour utilization parses to 0.10")
        check(abs(usage.weekly.usedPercent - 0.69) < 0.001, "seven_day utilization parses to 0.69")
        check(usage.fiveHour.resetAt != nil, "five_hour resets_at parses")
        check(usage.scopedWindows.count == 1, "exactly one weekly_scoped limit")
        check(usage.scopedWindows.first?.name == "Fable", "scoped limit is named Fable")
        check(abs((usage.scopedWindows.first?.usage.usedPercent ?? 0) - 0.94) < 0.001, "Fable weekly parses to 0.94")
        check(usage.scopedWindows.first?.usage.resetAt != nil, "Fable resets_at parses")

        check(ClaudeUsageParsing.parseScopedLimits(nil).isEmpty, "missing limits -> no scoped windows")
        check(ClaudeUsageParsing.parseScopedLimits([["kind": "session", "percent": 5]]).isEmpty, "unscoped kinds ignored")
        let noName: [[String: Any]] = [["kind": "weekly_scoped", "percent": 50, "scope": ["model": ["display_name": ""]]]]
        check(ClaudeUsageParsing.parseScopedLimits(noName).isEmpty, "empty display_name ignored")

        // Carry-forward keeps a scoped reading when the next fetch fails.
        let failed = AppUsage(fiveHour: WindowUsage(usedPercent: 0, resetAt: nil, error: "boom"),
                              weekly: WindowUsage(usedPercent: 0, resetAt: nil, error: "boom"))
        let merged = AppUsage.merged(fetched: failed, retaining: usage, at: Date())
        check(merged.scopedWindows.first?.name == "Fable", "scoped window survives a failed fetch")
        check(abs((merged.scopedWindows.first?.usage.usedPercent ?? 0) - 0.94) < 0.001, "scoped percent carried forward")
        let fresh = AppUsage(fiveHour: usage.fiveHour, weekly: usage.weekly)
        check(AppUsage.merged(fetched: fresh, retaining: usage, at: Date()).scopedWindows.isEmpty,
              "successful fetch with no scoped limits clears them")

        if failures == 0 { print("ALL PASS") } else { exit(1) }
    }
}
