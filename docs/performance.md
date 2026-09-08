# Performance

**Ka0s WhatGroup brackets nothing, and this page is why.**

This addon claimed the **no-combat-path exemption** (`performance-§12`) until **2026-08-06**, when
the teleport cooldown countdown ticker ended criterion (a). The wiring is **still declined** — now
as a ratified deviation in its own right, on criteria (b) and (c), which the ticker does not touch.
Either way the outcome on disk is the same: it vendors `libs/LibKa0s/` whole — Perf.lua included,
because the folder is copied whole or not at all (library-stack-§7, anti-patterns #48) — and does
**not** wire it: there is no `core/PerfSetup.lua`, no `WhatGroupPerfDB`, no `perf` verb
registration, no suspend/resume contract, no `tests/perf.lua` and no `docs/perf-analysis/`. The `perf`
verb stays **reserved** (slash-commands-§2) so it can never come to mean anything else here; it is
simply not registered.

Both the original exemption and the deviation that replaced it are ratified as rows in
[`ARCHITECTURE.md` → `## Documented deviations`](./ARCHITECTURE.md#documented-deviations). This
page is the answer to *"how much does this addon cost?"* — **one `C_Spell.GetSpellCooldown`, one
formatted string and one `SetText` per second while an open popup is showing a live cooldown, and
nothing else measurable — and here is how we know**.

## Criterion (a) — no combat path: the whole-repo sweep

The evidence, not the claim. Regenerate it with:

```sh
grep -rnE 'RegisterEvent|SetScript\("OnUpdate"|C_Timer|ScheduleRepeatingTimer|ScheduleTimer|hooksecurefunc' \
  core modules settings defaults locales
```

The sweep returns **seventeen lines across three files** today. Five of them are prose: the pattern
names appear inside comments at `core/WhatGroup.lua:16`, `:26`, `:46`, `:579` and `:635`, which
describe the hook and timer discipline rather than doing anything. The other **twelve are call
sites**, and they are the eleven rows below — the two `C_Timer.After(0, …)` hops share a row. The
rows are in the order the grep prints them, so the two can be read side by side. A hit that maps
onto neither list is the end of this page's claim.

Every call site, with the per-hit work:

| Site | What it is | Work while the player is in combat |
|---|---|---|
| `core/WhatGroup.lua:56` | `hooksecurefunc(C_LFGList, "ApplyToGroup", …)` | Fires only when the **player clicks Apply** in the LFG browser, which is not a combat action. Stashes one table. |
| `core/WhatGroup.lua:62` | `hooksecurefunc("SetItemRef", …)` | Fires only on a **chat-link click**. One prefix compare, then a return for every link that is not ours. |
| `core/WhatGroup.lua:192` | `RegisterEvent("GROUP_ROSTER_UPDATE")` | The one handler that can fire mid-combat. `IsInGroup()` plus three comparisons; the debug line is suppressed unless the in-group state actually transitioned. On most pulls it fires **zero** times. |
| `core/WhatGroup.lua:193` | `RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")` | Fires on an LFG application status change — a state the player reaches out of combat. |
| `core/WhatGroup.lua:199` | `RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChanged")` | Fires **once per pull**, on the edge into the lockdown. Until the first popup is built `f` is `nil` and the whole handler is one comparison. With a popup built: `visibilityAllows` — one profile read and up to three string compares — and then at most one `Show`, which needs `visibility = inCombat` and a capture still pending. **No `Hide` runs on this edge, and none can.** `f` parents a `SecureActionButtonTemplate` child, so the client refuses `Hide` on it under lockdown; the one `hidePopup()` seam returns `false` rather than calling into that refusal, and the `outOfCombat` gate's hide is honored one edge late, on the row below (`M2-28`). Nothing walks, nothing allocates. |
| `core/WhatGroup.lua:200` | `RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatStateChanged")` | The same handler on the other edge, running strictly *after* combat, where both directions are legal — so this is where every deferred hide lands: a `Close` the player pressed during the fight, which outranks the gate, or the `outOfCombat` gate's own hide. The same one gate evaluation, then at most one `Hide` **or** one `Show`, the `Show` only when a capture is still pending. Still nothing that walks or allocates. |
| `core/WhatGroup.lua:638` | `self:ScheduleTimer(…)` | **One-shot** AceTimer, armed once per group join, for the notify delay. Not repeating. |
| `modules/Frame.lua:351` | `WhatGroup:ScheduleRepeatingTimer(…, 1)` | **The one repeating timer in the addon**, and the reason criterion (a) no longer holds. Armed only when the popup is **on screen** *and* the dungeon's teleport is on cooldown — the arm sits behind an `f:IsShown()` check and is re-run from the popup's `OnShow`, so it cannot exist against a hidden frame. Canceled from the popup's `OnHide`, from the top of every `ConfigureTeleportButton` run, and by the tick that sees the cooldown reach zero. Per tick: one `C_Spell.GetSpellCooldown` call, one `NS.FormatDuration` string build, and one `SetText`. It can fire during combat — the popup can be open then — so this is the addon's first in-combat repeating work, however small. |
| `modules/Frame.lua:394` | `f:RegisterEvent("PLAYER_REGEN_ENABLED")` | Registered **only** when a secure-attribute write was blocked by `InCombatLockdown()`, and the handler **unregisters itself** on the first fire. It exists to do its work strictly *after* combat. |
| `modules/Frame.lua:733` | `waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")` | Same shape: a transient frame that defers the popup build to combat-end and then `UnregisterAllEvents()`. |
| `settings/OptionsSetup.lua:239`, `:247` | `C_Timer.After(0, …)` | Two **next-frame** secure-defer hops in the settings panel build. One-shot, and only ever reached from a settings-panel `OnShow`. |

**Zero `OnUpdate` handlers. One repeating timer** — the cooldown countdown at
`modules/Frame.lua:351`, added 2026-08-06. Everything else above is one-shot or self-unregistering.
Three *event* handlers are reachable inside or on the edge of a combat window: `GROUP_ROSTER_UPDATE`,
whose body is an `IsInGroup()` and three comparisons, and the two combat-transition registrations
sharing `OnCombatStateChanged`, whose body is one gate evaluation and then at most one `Show` on the
way in, or one `Show` or `Hide` on the way out. The asymmetry is the client's rule and not a choice:
a `Hide` is refused while the lockdown holds, so the entering edge can only ever show and the
leaving edge carries both directions. The combat-transition pair fires **twice per pull** and is the
price of `visibility`'s two combat-dependent values behaving the way their labels say they do; it is named here rather than
waved past, because a handler registered on `PLAYER_REGEN_DISABLED` is by definition combat-path
work.

**Criterion (a) therefore no longer holds, and this page no longer claims it.** The re-check trigger
in the `performance-§12` register row has fired: `performance-§12` names *"the first `OnUpdate`
handler, repeating ticker, or in-combat event handler doing real work"* as re-arming the full wiring
MUST, and the countdown ticker is a repeating ticker whether or not it is gated on a visible window.
The wiring is still declined — now as a **ratified deviation in its own right** rather than as a
qualified exemption, on grounds (b) and (c), which are untouched by the ticker. Both rows are in
[`ARCHITECTURE.md`](./ARCHITECTURE.md) `## Documented deviations`; this page is the evidence they
cite, and the sweep above is what an audit reads first.

## Criteria (b) and (c) — both apply, and (c) is the stronger

- **(b) — every declared bucket would read `0.000` by construction.** The capture protocol opens its
  windows on the player's combat state (`performance-§7`). With no code running in that window there
  is nothing for a bracket to contain, and `performance-§3` is explicit that a bucket no bracket
  meaningfully reaches is *a lie in every report*.
- **(c) — `suspend` would suppress the data the addon exists to record.** WhatGroup is a **capture**
  addon: `OnApplyToGroup` records the group applied to, and the LFG status event carries it forward
  to the invite. Making it inert for a measurement window means an apply or an invite-accept inside
  that window is **never recorded** — so the popup and the chat summary the player installed it for
  silently do not appear. The capture would cost the user the feature, not pause a display.

The long-form reasoning, and the date the user ratified it, are at
[`LIBKA0S-15`](https://github.com/tusharsaxena/WhatGroup/issues/7).

## The re-check trigger

The exemption was **conditional on criterion (a) still being true**, and it fired on 2026-08-06 with
the countdown ticker. What now governs is the re-check trigger on the *replacement* row in
[`ARCHITECTURE.md`](./ARCHITECTURE.md) `## Documented deviations`: the wiring gets wired, not
re-argued, if the ticker stops being window-bounded, if a second repeating timer appears, or if any
repeating work starts running with the popup closed. That last clause was **broken between
2026-08-06 and this page's regeneration** — `applyTeleportNote` armed the ticker before `ShowFrame`
had shown the frame, and the popup's `OnHide` fires only on a transition, so a ticker armed against
a frame that was never shown had no cancel site at all. The arm is now behind `f:IsShown()` with
`OnShow` as its single site, which is what makes the sentence true rather than aspirational. The row
is amended, not retired: the deviation always rested on the invariant, and the repair restores the
invariant. Adding an `OnUpdate` handler, a second ticker,
or an event handler doing more than occasional work in combat means regenerating the sweep above
first.

## What this page does not excuse

- The `perf` suite in a run bundle reads **`skip`**, and a skip is **never a pass**. At the release
  gate it is **not evaluated** rather than passed (`automated-tests-§3`), and the release notes say
  so — see [`testing.md`](./testing.md) and
  [`automated-tests/README.md`](./automated-tests/README.md).
- `docs/complexity.md` is retired; complexity is measured by the runner's `complexity` suite and
  its trend line is [`automated-tests/RESULTS.md`](./automated-tests/RESULTS.md) (`performance-§10`).
