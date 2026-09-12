# 03 — Decisions

Non-interactive run (triage wave B2, 2026-09-12). The owner decided in advance that harness
declines migrate onto the kit, and that WhatGroup#19 takes option 1. Filing and pushing were skipped
by instruction: this run opened no GitHub issue and pushed nothing.

| Item | Decision | Why |
|---|---|---|
| `OptionsWidgets` minor 15 (no-path rows) | **delivered, inert** | Every WhatGroup row is path-keyed. |
| `OptionsCompose` minor 4 (`spec.bind`) | **delivered, inert** | WhatGroup has no registry records to bind. |
| Kit 17 `__fireTimers` cancellation, `NewTimer` Cancel | **delivered via B-1** | Reached the harness once the mock stopped running its own AceTimer queue. |
| Kit 17 AceGUI `WidgetVersions` / layouts | **delivered, unused** | Nothing reads them. |
| B-1 harness onto the kit's Ace fakes (#19, option 1) | **adopted** | Owner decision. Commit "Harness: run the addon object on the kit's Ace fakes, for #19". |
| B-2 `C_SpellBook` in the mock | **adopted** | Orchestrator reading 7. Its own commit, "for #19". |

**One departure from the letter of the instruction, recorded:** #19 asked for "the wrapper" to forward
the name and the mixin list to the kit's `NewAddon`. Once the local recorder, the AceTimer queue, the
chat-command recorder and the no-op stamps were gone, the wrapper had nothing left to do. So it was
removed rather than kept as a pass-through, and the addon's own call now reaches the kit's `NewAddon`
directly, with its name and all three libraries. This has the effect the instruction wanted (the
kit's named path, and the end of the kit's divergence 1 for WhatGroup), without leaving a second
place for the two to drift apart.
