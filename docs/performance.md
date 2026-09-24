# Performance

**Ka0s WhatGroup brackets nothing, and this page is why.**

This addon claimed the **no-combat-path exemption** (`performance-§12`) until **2026-08-06**, when
the teleport cooldown countdown ticker ended criterion (a). The wiring is **still declined** — now
as a ratified deviation in its own right, on criteria (b) and (c), which the ticker does not touch.
Either way the outcome on disk is the same: it vendors `libs/LibKa0s/` whole — Perf.lua included,
because the folder is copied whole or not at all (library-stack-§7, anti-patterns #48) — and does
**not** wire it: there is no `core/PerfSetup.lua`, no `WhatGroupPerfDB`, no `perf` verb
registration, no suspend/resume contract and no `docs/perf-analysis/`. **`tests/perf.lua` is the one
piece that is now built** — see [Offline scenarios](#offline-scenarios-what-the-addon-actually-costs)
below; none of the argument against the in-game wiring touches it. The `perf`
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

The sweep returns **twenty lines across four files** today. Seven of them are prose: the pattern
names appear inside comments at `core/WhatGroup.lua:16`, `:26`, `:96`, `:299`, `:773` and `:855`
and `core/LifecycleSetup.lua:42`, which describe the hook and timer discipline rather than doing
anything. The other **thirteen are call sites**, and they are the twelve rows below — the two
`C_Timer.After(0, …)` hops share a row. The rows are in the order
the grep prints them, so the two can be read side by side. A hit that maps onto neither list is the
end of this page's claim.

One subscription the pattern does **not** match is covered in the `:122` row: the chat link's
`EventRegistry:RegisterCallback("SetItemRef", …)` at `core/WhatGroup.lua:113`, which `NS.StandDown` unregisters (`:349`) and `NS.StandUp` re-registers.

Every call site, with the per-hit work:

| Site | What it is | Work while the player is in combat |
|---|---|---|
| `core/WhatGroup.lua:63` | `hooksecurefunc(C_LFGList, "ApplyToGroup", …)` | Fires only when the **player clicks Apply** in the LFG browser, which is not a combat action. Stashes one table. |
| `core/WhatGroup.lua:122` | `hooksecurefunc("SetItemRef", …)` | **Installed only on a degraded client** (`NS.Compat.AddOnLinkType()` nil). There it fires on every **chat-link click**: one type check and one prefix compare, then a return for every link that is not ours. On a current client the line does not run; `EventRegistry:RegisterCallback` at `:113` runs in its place, with the same per-click work, and only for `addon:` link clicks, and it is unregistered while the addon is disabled. |
| `core/WhatGroup.lua:305` | `RegisterEvent("GROUP_ROSTER_UPDATE")` | The one handler that can fire mid-combat. `IsInGroup()` plus three comparisons; the debug line is suppressed unless the in-group state actually transitioned. On most pulls it fires **zero** times. |
| `core/WhatGroup.lua:306` | `RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")` | Fires on an LFG application status change — a state the player reaches out of combat. |
| `core/WhatGroup.lua:312` | `RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChanged")` | Fires **once per pull**, on the edge into the lockdown. It first asks whether test mode is on: one boolean read when it is off, and when it is on one `hidePopup()`, one chat line and a panel refresh, once. Until the first popup is built `f` is `nil` and the whole handler is one comparison. With a popup built: `visibilityAllows` — one profile read and up to three string compares — and then at most one `Show`, which needs `visibility = inCombat` and a capture still pending. **No `Hide` runs on this edge, and none can.** `f` parents a `SecureActionButtonTemplate` child, so the client refuses `Hide` on it under lockdown; the one `hidePopup()` seam returns `false` rather than calling into that refusal, and the `outOfCombat` gate's hide is honored one edge late, on the row below (`M2-28`). Nothing walks, nothing allocates. |
| `core/WhatGroup.lua:313` | `RegisterEvent("PLAYER_REGEN_ENABLED", "OnCombatStateChanged")` | The same handler on the other edge, running strictly *after* combat, where both directions are legal — so this is where every deferred hide lands: a `Close` the player pressed during the fight, which outranks the gate, or the `outOfCombat` gate's own hide. The same one gate evaluation, then at most one `Hide` **or** one `Show`, the `Show` only when a capture is still pending. Still nothing that walks or allocates. |
| `core/WhatGroup.lua:362` | `RegisterEvent("PLAYER_REGEN_ENABLED", "OnDisabledCombatEnded")` | Registered **only** by `StandDown`, and only when the addon is disabled in combat while the popup still owes a protected `Hide` — the one registration `slash-commands-§7` lets a disabled addon keep. `OnDisabledCombatEnded` unregisters it first thing on the one fire, then finishes the stand-down. Fires at most once, strictly *after* combat. |
| `core/WhatGroup.lua:858` | `self:ScheduleTimer(…)` | **One-shot** AceTimer, armed once per group join, for the notify delay. Not repeating. |
| `modules/Frame.lua:491` | `WhatGroup:ScheduleRepeatingTimer(…, 1)` | **The one repeating timer in the addon**, and the reason criterion (a) no longer holds. Armed only when the popup is **on screen** *and* the dungeon's teleport is on cooldown — the arm sits behind an `f:IsShown()` check and is re-run from the popup's `OnShow`, so it cannot exist against a hidden frame. Canceled from the popup's `OnHide`, from the top of every `ConfigureTeleportButton` run, and by the tick that sees the cooldown reach zero. Per tick: one `C_Spell.GetSpellCooldown` call, one `NS.FormatDuration` string build, and one `SetText`. It can fire during combat — the popup can be open then — so this is the addon's first in-combat repeating work, however small. |
| `modules/Frame.lua:534` | `f:RegisterEvent("PLAYER_REGEN_ENABLED")` | Registered **only** when a secure-attribute write was blocked by `InCombatLockdown()`, and the handler **unregisters itself** on the first fire. It exists to do its work strictly *after* combat. |
| `modules/Frame.lua:1038` | `waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")` | Same shape: a transient frame that defers the popup build to combat-end and then `UnregisterAllEvents()`. |
| `settings/OptionsSetup.lua:265`, `:273` | `C_Timer.After(0, …)` | Two **next-frame** secure-defer hops in the settings panel build. One-shot, and only ever reached from a settings-panel `OnShow`. |

**Zero `OnUpdate` handlers. One repeating timer** — the cooldown countdown at
`modules/Frame.lua:491`, added 2026-08-06. Everything else above is one-shot or self-unregistering.
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

**(c) is an argument about a MEASUREMENT window, not about whether this addon can be made inert.**
Since the stand-down landed (`slash-commands-§7`, `ARCHITECTURE.md` → `## The stand-down`) it very
much can: `core/LifecycleSetup.lua` builds the `LibKa0s-Lifecycle-1.0` latch and `NS.StandDown`
unregisters every event, cancels every timer and takes the popup off screen. The difference is who
asked. A player who unticks *Enable WhatGroup* has asked to stop capturing and is entitled to have
that mean it; a perf harness suspending the addon for thirty seconds has not, and the player loses
the group info they joined for with nothing on screen to explain it. The **`perf` hold is wired on
the same latch anyway** — it is the library's key and the latch is the same latch — so if the
exemption is ever re-examined there is no second teardown path to reconcile, which is the whole
reason `slash-commands-§7` insists the stand-down be built on this seam rather than beside it.

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


## Offline scenarios: what the addon actually costs

`tests/perf.lua` (`performance-§9`) measures the paths this page makes claims about. It is
**outside the green gate** — `lua tests/run.lua` never runs it and no commit depends on it — and it
asserts only deterministic quantities: API calls on the addon's own frames, and bytes allocated per
iteration, each isolated by a full collect either side. Timings are printed for orientation and
asserted on nothing.

```sh
lua tests/perf.lua
```

**Measured 2026-09-16, at v1.4.0.** Three consecutive runs produced identical figures in every
column but `ms/iter`.

| Scenario | iters | api/iter | bytes/iter | What it is |
|---|---|---|---|---|
| `cooldownTick` | 2000 | 2.0 | 240.4 | The repeating ticker's own body, armed through the addon and called as the client would call it |
| `formatDurationLong` | 2000 | 0.0 | 34.5 | `NS.FormatDuration` on the `h > 0` branch — what a real teleport cooldown takes |
| `formatDurationShort` | 2000 | 0.0 | 0.8 | The same on the seconds-only branch |
| `combatGateSteady` | 2000 | **0.0** | **0.0** | A combat transition that changes nothing. Asserted at zero |
| `combatGateFlipping` | 2000 | 7.0 | 1064.1 | A transition that genuinely flips the popup, on `visibility = inCombat` |
| `showFrameRepeat` | 500 | 18.0 | 1872.5 | A group capture arriving: repopulate and show |
| `applyScale` | 500 | 1.0 | 0.0 | Dragging the scale slider |
| `applyAlpha` | 500 | 1.0 | 0.0 | Dragging the alpha slider |

**What the numbers say.**

- **The ticker is as cheap as this page has been claiming.** Two API calls — one `SetText`, one
  `Show` — and 240 bytes, once per second, only while a popup the player opened is on screen with a
  live cooldown. That was an argument until now; it is a measurement from here on, and a regression
  on it reddens `tests/perf.lua` instead of reaching a player.
- **The combat path costs nothing when nothing changes**, which is the case a player is in for every
  pull where `visibility` is `always`. Zero calls and zero bytes, and that one is **asserted**, not
  merely recorded — the run fails if it ever allocates.
- **A flipping transition is seven calls and does not grow.** The first draft of the harness asserted
  "at most one Show or Hide" and was wrong about the design: a hide edge is `Hide, Hide, SetAlpha`
  (the popup, its secure child, and the alpha restore that settles a lockdown-deferred hide), and a
  show edge re-anchors and repopulates. Seven is the real figure; what is asserted is that it stays
  constant, because a player crosses two edges per pull and a constant cost does not accumulate.
- **The slider paths allocate nothing**, which is what makes a drag cheap: they call one setter and
  build no strings.

**Ceilings.** Each scenario's byte ceiling is its measured figure plus 24 — deliberately smaller
than the cheapest regression it exists to catch, since one extra table per iteration costs 64 bytes
under this interpreter. Raise one only by re-measuring and saying why. **A rise is the finding.**

**A note on measurement honesty.** Bytes are measured with the API-counting shim **switched off**.
The shim's wrapper takes varargs, and a vararg call allocates under Lua 5.1, so a byte figure taken
with it installed is partly the shim's — it inflated one scenario from 492 to 1080 bytes/iter before
this was fixed. Each scenario therefore runs twice: once counting calls, once measuring allocation.

## What this page does not excuse

- **The `perf` suite no longer reads `skip`.** It did until 2026-09-16, and the wording here used to
  explain why that skip was not a pass. It now runs eight offline scenarios and reads **`pass`**, so
  the release gate evaluates it like any other suite (`automated-tests-§3`). What is still absent is
  the **in-game** capture: there is no `perf` verb and no `docs/perf-analysis/`, so no bundle here
  will ever carry a dungeon run. See [`testing.md`](./testing.md) and
  [`automated-tests/README.md`](./automated-tests/README.md).
- `docs/complexity.md` is retired; complexity is measured by the runner's `complexity` suite and
  its trend line is [`automated-tests/RESULTS.md`](./automated-tests/RESULTS.md) (`performance-§10`).
