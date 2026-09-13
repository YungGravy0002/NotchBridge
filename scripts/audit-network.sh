#!/bin/bash
# Local-only invariant (PLAN.md §5.4): every URL literal under Sources/ must be
# on this allowlist. Fails loudly on anything else so a new endpoint cannot
# slip in unnoticed. Run: scripts/audit-network.sh
set -uo pipefail
cd "$(dirname "$0")/.."

ALLOW=(
  "https://api.anthropic.com/api/oauth/usage"                     # Claude quota (undocumented, inherited)
  "https://chatgpt.com/backend-api/wham/usage"                    # Codex quota (undocumented, inherited)
  "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits" # Codex reset credits (inherited)
  "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json" # pricing
  "https://ericjypark.github.io/codex-island-model-catalog/v1/models.json" # model catalog (upstream-hosted)
  "https://open.er-api.com/v6/latest/USD"                         # currency rates
  "https://www.exchangerate-api.com"                              # attribution link only (opened in browser)
  "https://github.com/YungGravy0002/NotchBridge"                  # share-card link, not fetched
  "https://github.com/ericjypark/codex-island"                    # credit link, not fetched
  "https://github.com/ericjypark/codex-island/blob/main/LICENSE"  # credit link, not fetched
  "http://127.0.0.1"                                              # hook server (Phase 2)
  "http://localhost"                                              # hook server (Phase 2)
)

status=0
while IFS= read -r line; do
  url="${line#*:}"; url="${url#*:}"
  ok=0
  for a in "${ALLOW[@]}"; do
    [[ "$url" == "$a"* ]] && { ok=1; break; }
  done
  if [[ $ok -eq 0 ]]; then
    echo "DISALLOWED: $line"; status=1
  fi
done < <(grep -rnoE 'https?://[A-Za-z0-9./_:-]+' Sources)

if [[ $status -eq 0 ]]; then echo "✓ network audit: all URL literals in Sources/ are allowlisted"; fi
exit $status
