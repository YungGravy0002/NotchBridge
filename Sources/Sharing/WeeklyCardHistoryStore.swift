import Foundation
import Combine

@MainActor
final class WeeklyCardHistoryStore: ObservableObject {
    @Published private(set) var buckets: [IslandProvider: [DailyTokenBucket]]?
    @Published private(set) var isLoading = false
    @Published private(set) var partialProviders = Set<IslandProvider>()
    @Published private(set) var saveErrors: [IslandProvider: String] = [:]

    func loadIfNeeded() {
        if buckets == nil { refresh() }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task {
            let result = await Task.detached(priority: .utility) {
                let now = Date()
                var buckets: [IslandProvider: [DailyTokenBucket]] = [:]
                let partial = Set<IslandProvider>()
                var saveErrors: [IslandProvider: String] = [:]
                let claude = UsageLedger.shared.retain(ClaudeLogReader.scan(lookbackDays: nil),
                                                       source: .claude, now: now, observedAt: now)
                let codex = UsageLedger.shared.retain(CodexLogReader.scan(lookbackDays: nil),
                                                      source: .codex, now: now, observedAt: now)
                buckets[.claude] = CostSummary.summarize(
                    events: claude.events,
                    now: now, includeAllHistory: true, historicalDays: claude.historicalDays
                ).dailyTokens
                buckets[.codex] = CostSummary.summarize(
                    events: codex.events,
                    now: now, includeAllHistory: true, historicalDays: codex.historicalDays
                ).dailyTokens
                saveErrors[.claude] = claude.saveError
                saveErrors[.codex] = codex.saveError
                return (buckets, partial, saveErrors)
            }.value
            buckets = result.0
            partialProviders = result.1
            saveErrors = result.2
            isLoading = false
        }
    }
}
