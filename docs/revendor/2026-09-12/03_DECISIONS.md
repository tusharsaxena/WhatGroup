# 03 — Decisions

This was a non-interactive run. The owner gave the adoption answers in advance (2026-09-12):

- **Adopt** means deleting a local shim only where the kit now provides the same contract and the
  suite stays green.
- **Decline** covers anything needing a harness migration.
- A decline is **proposed** as an issue, not filed. This run filed no GitHub issue and pushed nothing.

| Item | Decision | Why |
|---|---|---|
| #28 runner mode | **delivered** | The case arrived with the copy and passes. There was no local shim, so there is nothing to delete. It closes WG-51. |
| #30 `Printf` | **delivered, inert** | Carried through by `baseNewAddon`. No caller and no shim. |
| #29 AceEvent event half | **declined (harness migration)** | The mock's own `NewAddon` recorder (`mock.addonEvents`, handler-name values, `fireAddonEvent`) is a different contract that the suites depend on, and the addon never reaches `AceEvent:Embed`. Proposed as an issue: *adopt the kit's AceEvent recorder in the WhatGroup harness, or record why it stays local.* |
| #27 `AceGUI:Release` | **declined (inert)** | Nothing calls `Release`. The ScrollFrame `OnRelease`/`released` model is a different mechanism with nothing to delete. It shares the proposed issue above. |

No shim was removed. No production code changed.
