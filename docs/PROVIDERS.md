# Provider connections

Settings → Providers selects one or two distinct providers. A single provider
occupies the left slot. Picking the provider already in the other slot swaps
them; the central swap button does the same. Existing Claude/Codex visibility
preferences migrate automatically, and order persists across launches.

All providers use the same Ring, Bar, Stepped, Numeric, and Sparkline views,
used/remaining preference, peek pills, and threshold alerts. A provider's data
selects the metrics; changing providers does not change the chart style.

## Codex limit windows

Codex charts follow the windows reported by the usage API, not the plan name.
A weekly-only response displays one compact chart centered in the provider column.
Two reported windows retain the 5h/week pair. The discovered window list survives
failed refreshes, so an offline request cannot bring back a removed 5h tile.
Zero-percent windows remain visible. Peek and alerts select the same available
window, and chart styles and history keys remain unchanged.

## Limits

Subscription limits and local cost history are separate sources. Cost, Tokens,
Value, Trend, model breakdowns, and the activity grid use the same aggregation
and views for every provider. Local history covers records on this Mac, across
local CLI accounts; it is not an account-wide billing statement.

An absent record is shown as unknown, rather than zero spend. Unreadable or
incomplete histories surface a local-records notice instead of a green Synced
status. Unknown model prices retain token/activity data and show an unpriced
warning. Local summaries do not depend on quota login succeeding.

Dollar values estimate API-equivalent token cost, not subscription charges.

## Provider colors

Provider identity colors live in `Sources/Theme/Colors.swift` and are routed
through `IslandProvider.color` for marks, usage charts, cost charts, and peek.
These are CodexIsland display colors, not claims about official brand palettes.

| Provider | Color | Hex |
| --- | --- | --- |
| Claude | Terracotta | `#CC785C` |
| Codex | Sky blue | `#5AA8F0` |

Green, amber, and red remain reserved for status and alerts. Keep provider
names and distinct marks visible so identification never depends only on color.
