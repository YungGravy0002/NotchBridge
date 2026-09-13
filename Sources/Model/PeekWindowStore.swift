import Foundation
import SwiftUI

/// Which usage window the compact peek pill shows for a provider.
enum PeekWindowPreference: String, CaseIterable {
    case auto
    case fiveHour
    case weekly

    var label: String {
        switch self {
        case .auto: return "Auto"
        case .fiveHour: return "5-hour"
        case .weekly: return "Weekly"
        }
    }
}

/// Per-provider peek window choice. `auto` keeps the upstream behaviour
/// (5-hour when it has a reading, weekly otherwise).
@MainActor
final class PeekWindowStore: ObservableObject {
    static let shared = PeekWindowStore()

    private static func key(_ provider: IslandProvider) -> String {
        "MacIsland.peekWindow.\(provider.rawValue)"
    }

    @Published private(set) var preferences: [IslandProvider: PeekWindowPreference]

    private init() {
        var prefs: [IslandProvider: PeekWindowPreference] = [:]
        for provider in IslandProvider.allCases {
            let raw = UserDefaults.standard.string(forKey: Self.key(provider)) ?? ""
            prefs[provider] = PeekWindowPreference(rawValue: raw) ?? .auto
        }
        preferences = prefs
    }

    func preference(for provider: IslandProvider) -> PeekWindowPreference {
        preferences[provider] ?? .auto
    }

    func set(_ preference: PeekWindowPreference, for provider: IslandProvider) {
        preferences[provider] = preference
        UserDefaults.standard.set(preference.rawValue, forKey: Self.key(provider))
    }

    func binding(for provider: IslandProvider) -> Binding<PeekWindowPreference> {
        Binding(get: { self.preference(for: provider) }, set: { self.set($0, for: provider) })
    }

    /// Resolves the window to show. A forced window with no reading falls
    /// back to `auto` so the pill never shows a dash for a window the API
    /// simply doesn't report.
    func showsWeekly(for provider: IslandProvider, usage: AppUsage) -> Bool {
        switch preference(for: provider) {
        case .fiveHour where usage.fiveHour.hasReading: return false
        case .weekly where usage.weekly.hasReading: return true
        default: return usage.peekWindowIsWeekly
        }
    }
}
