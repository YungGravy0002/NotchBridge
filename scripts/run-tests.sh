#!/bin/bash
# Compiles the usage-resolution sources together with the test harness and
# runs it. No XCTest/SPM — mirrors build.sh's bare-swiftc approach. The env
# token stub routes resolveUsage through the injected probe deterministically
# (see Tests/ResolveUsageTests.swift).
set -euo pipefail

cd "$(dirname "$0")/.."

OUT_DIR=$(mktemp -d)
trap 'rm -rf "$OUT_DIR"' EXIT

swiftc -parse-as-library -o "$OUT_DIR/currency-tests" \
  Sources/Model/CurrencyStore.swift \
  Sources/Model/AppLanguageStore.swift \
  Sources/Localization/L10n.swift \
  Tests/CurrencyStoreTests.swift
"$OUT_DIR/currency-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/resolve-usage-tests" \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Sources/Usage/ClaudeCredentials.swift \
  Tests/ResolveUsageTests.swift

CLAUDE_CODE_OAUTH_TOKEN="test-stub-token" "$OUT_DIR/resolve-usage-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/notch-height-tests" \
  Sources/Model/NotchInfo.swift \
  Sources/Model/IslandSpacingStore.swift \
  Sources/Model/PreferenceStorage.swift \
  Tests/NotchHeightTests.swift

"$OUT_DIR/notch-height-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/usage-merge-tests" \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Tests/UsageMergeTests.swift

"$OUT_DIR/usage-merge-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/wake-recovery-tests" \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Sources/Usage/ClaudeCredentials.swift \
  Sources/Usage/WakeScheduling.swift \
  Tests/WakeRecoveryTests.swift

"$OUT_DIR/wake-recovery-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/codex-window-routing-tests" \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Sources/Usage/ClaudeCredentials.swift \
  Sources/Usage/CodexResetCredits.swift \
  Sources/Usage/UsageFetcher.swift \
  Tests/CodexWindowRoutingTests.swift

"$OUT_DIR/codex-window-routing-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/pricing-tests" \
  Sources/Cost/TokenEvent.swift \
  Sources/Cost/PricingCatalog.swift \
  Sources/Cost/Pricing.swift \
  Tests/PricingTests.swift

"$OUT_DIR/pricing-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/pricing-catalog-tests" \
  Sources/Cost/PricingCatalog.swift \
  Tests/PricingCatalogTests.swift

"$OUT_DIR/pricing-catalog-tests"

# NOTE(notchbridge): -sanitize=thread removed — the TSan runtime in Swift 6.2.4 CLT
# crashes in its own init on macOS 26.5 before any test code runs. Re-add when fixed.
swiftc \
  -parse-as-library \
  -o "$OUT_DIR/pricing-catalog-race-tests" \
  Sources/Cost/PricingCatalog.swift \
  Tests/PricingCatalogRaceTests.swift

"$OUT_DIR/pricing-catalog-race-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/pricing-tests" \
  Sources/Cost/TokenEvent.swift \
  Sources/Cost/PricingCatalog.swift \
  Sources/Cost/Pricing.swift \
  Tests/PricingTests.swift

"$OUT_DIR/pricing-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/pricing-precedence-tests" \
  Sources/Cost/TokenEvent.swift \
  Sources/Cost/PricingCatalog.swift \
  Sources/Cost/Pricing.swift \
  Tests/PricingPrecedenceTests.swift

"$OUT_DIR/pricing-precedence-tests"

swiftc \
  -parse-as-library \
  -o "$OUT_DIR/provider-connection-tests" \
  Sources/Model/IslandProvider.swift \
  Sources/Model/ProviderVisibilityStore.swift \
  Sources/Model/UsageDisplayModeStore.swift \
  Sources/Usage/AppUsage.swift \
  Tests/ProviderConnectionTests.swift

"$OUT_DIR/provider-connection-tests"


bash scripts/test-weekly-card.sh
bash scripts/test-usage-ledger.sh
bash scripts/test-claude-recovery.sh
