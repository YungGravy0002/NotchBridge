import SwiftUI

struct ProviderSelectionView: View {
    @ObservedObject private var selection = ProviderVisibilityStore.shared
    @ObservedObject private var usage = UsageStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.tr("On your island")).font(.system(size: 15, weight: .semibold))
                Text(L10n.tr("Choose up to two providers."))
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.68))
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .bottom, spacing: 10) {
                slot(0, provider: selection.left)
                Button {
                    withAnimation(reduceMotion ? nil : .openMorph) { selection.swap() }
                } label: {
                    Image(systemName: "arrow.left.arrow.right")
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .disabled(selection.right == nil)
                .opacity(selection.right == nil ? 0.3 : 1)
                .help(L10n.tr("Swap left and right"))
                .accessibilityLabel(L10n.tr("Swap left and right"))
                slot(1, provider: selection.right)
            }
            Divider().overlay(.white.opacity(0.08))
            ForEach(selection.selected) { provider in
                connectionRow(provider)
            }
        }
        .padding(24)
    }

    private func slot(_ index: Int, provider: IslandProvider?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr(index == 0 ? "Left" : "Right"))
                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.65))
            HStack(spacing: 8) {
                if let provider { ProviderMark(provider: provider) }
                else { Image(systemName: "plus").frame(width: 20, height: 20) }
                Menu {
                    ForEach(IslandProvider.allCases) { candidate in
                        Button {
                            withAnimation(reduceMotion ? nil : .openMorph) { selection.set(candidate, at: index) }
                        } label: {
                            if candidate == provider { Label(candidate.name, systemImage: "checkmark") }
                            else { Text(candidate.name) }
                        }
                        .disabled(index == 1 && selection.right == nil && candidate == selection.left)
                    }
                    if index == 1 {
                        Divider()
                        Button(L10n.tr("None — use one provider")) {
                            withAnimation(reduceMotion ? nil : .openMorph) { selection.set(nil, at: 1) }
                        }
                    }
                } label: {
                    Text(provider?.name ?? L10n.tr("Add provider"))
                        .font(.system(size: 13, weight: .medium)).lineLimit(1)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel(L10n.tr(index == 0 ? "Left provider" : "Right provider"))
                .accessibilityValue(provider?.name ?? L10n.tr("None"))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func connectionRow(_ provider: IslandProvider) -> some View {
        let value = provider == .claude ? usage.claude : usage.codex
        VStack(alignment: .leading, spacing: 8) {
            ProviderAccountHeading(provider: provider, plan: value.plan)
            if let error = [value.fiveHour.error, value.weekly.error]
                .compactMap({ $0 }).first(where: { $0 != "no data" }) {
                VStack(alignment: .leading, spacing: 8) {
                    if provider == .claude, ClaudeCredentials.isReauthActionable(error) {
                        Label(L10n.tr("Sign-in required"), systemImage: "info.circle")
                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                        if ClaudeCredentials.canPromptReauth() {
                            ReauthButton(title: "Sign in with Claude")
                        } else {
                            Text(L10n.tr("Open Claude Code and run /login."))
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                                .textSelection(.enabled)
                        }
                    } else {
                        Text(L10n.tr(error))
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 28)
            }
        }
    }
}

private struct ProviderAccountHeading: View {
    let provider: IslandProvider
    let plan: String?

    var body: some View {
        HStack(spacing: 8) {
            ProviderMark(provider: provider)
            Text(provider.name).font(.system(size: 13, weight: .semibold))
            if let plan = provider.planDisplayName(plan) {
                Text(plan)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.65))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 4))
                    .lineLimit(1).help(plan)
            }
            Spacer(minLength: 0)
        }
    }
}
