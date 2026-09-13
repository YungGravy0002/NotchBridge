import Foundation

/// Parsing for api.anthropic.com/api/oauth/usage responses. Kept free of
/// networking so the fixture test can exercise it directly.
enum ClaudeUsageParsing {
    static func parse(_ obj: [String: Any], plan: String?) -> AppUsage {
        AppUsage(
            fiveHour: parseWindow(obj["five_hour"]),
            weekly: parseWindow(obj["seven_day"]),
            plan: plan,
            scopedWindows: parseScopedLimits(obj["limits"])
        )
    }

    static func parseWindow(_ obj: Any?) -> WindowUsage {
        guard let d = obj as? [String: Any] else { return .unknown }
        // Anthropic returns `utilization` as a percentage in [0, 100], not a
        // normalized [0, 1] fraction. An earlier `raw > 1 ? raw / 100 : raw`
        // heuristic broke the moment the 5h window reset: utilization values
        // in (0, 1] (e.g. 0.5% used -> 0.5) were treated as already-normalized
        // and rendered as 50%-100%. Always divide by 100; clamp below.
        let raw = (d["utilization"] as? Double) ?? (d["used_percent"] as? Double)
            ?? (d["percent"] as? Double) ?? 0
        let normalized = raw / 100.0
        return WindowUsage(usedPercent: min(1, max(0, normalized)),
                           resetAt: parseResetAt(d["resets_at"]), error: nil)
    }

    /// OBSERVED, not documented (fixture: Tests/Fixtures/claude-oauth-usage.observed.json):
    /// `limits` is an array of `{kind, group, percent, resets_at, scope}`.
    /// `kind == "weekly_scoped"` entries carry `scope.model.display_name`
    /// (e.g. "Fable") and are the per-model weekly limits the CLI shows.
    static func parseScopedLimits(_ obj: Any?) -> [ScopedWindow] {
        guard let limits = obj as? [[String: Any]] else { return [] }
        return limits.compactMap { limit in
            guard (limit["kind"] as? String) == "weekly_scoped",
                  let scope = limit["scope"] as? [String: Any],
                  let model = scope["model"] as? [String: Any],
                  let name = model["display_name"] as? String, !name.isEmpty
            else { return nil }
            return ScopedWindow(name: name, usage: parseWindow(limit))
        }
    }

    static func parseResetAt(_ value: Any?) -> Date? {
        if let r = value as? Double { return Date(timeIntervalSince1970: r) }
        if let s = value as? String {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f.date(from: s) ?? ISO8601DateFormatter().date(from: s)
        }
        return nil
    }
}
