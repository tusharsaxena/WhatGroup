# Pending-item ledger

The record of what has been decided about every pending item found in this
addon — TODO/FIXME markers, unexecuted audit and review plan steps, doc open
questions, open GitHub issues, and recorded-but-unacted Claude memory.

Maintained by **`/wow-addon:pending-audit`**. Each run sweeps the repo afresh,
matches what it finds against the rows below on **ID + evidence hash**, and uses
the match to decide whether to ask about an item again:

- a `done` or `wont-do` row with a matching hash → the item is closed and is not
  raised again
- a `deferred` row → the item stays on the books but is not re-interviewed; it
  shows up as a collapsed count
- a row whose ID matches but whose **hash differs** → the evidence changed since
  the decision, so the item is raised again with its history attached

The evidence hash is the first 8 characters of `sha1` over the item's verbatim
evidence text. That is what makes a reworded TODO or an edited plan row
correctly re-surface instead of hiding behind a stale decision.

## Legend

| Marker | Value | Meaning | Re-surfaces? |
|---|---|---|---|
| 🟢 | `done` | Implemented this run | No — closed |
| 🔵 | `wont-do` | Decided it will never be done | No — closed |
| 🟡 | `deferred` | Not now; still on the books | Yes, as a collapsed count |

Both the marker and the word are always written: the word is the data (and what
`grep wont-do` finds), the marker is the affordance. There is deliberately no
red — nothing in this file is an error state.

## Decisions

| ID | Evidence hash | Source | Decision | Date | Rationale |
|---|---|---|---|---|---|
| PLAN-01 | `03f76c5e` | audit 2026-07-18 · WG-09 (`WhatGroup.toc`) | 🔵 wont-do | 2026-07-31 | Declined both adding an `X-Wago-ID` and recording a Curse-only accepted deviation. The TOC keeps no note, so the MUST stays visible only in the frozen audit bundle. *(Reason inferred — no explanation given.)* |
| ISS-01 | `2921308d` | GitHub issue #3 | 🟢 done | 2026-07-31 | Fixed by the move to eager `Settings.Register()` at `OnEnable` + lazy widget build; the issue's own text had gone stale. Commented and closed on GitHub. |
| CODE-01 | `61950cbc` | `core/WhatGroup.lua:537` · review 2026-05-02 F-004 | 🟢 done | 2026-07-31 | Migration implemented now rather than left as a TODO. `CaptureGroupInfoFromApplication` routes appID → searchResultID through the documented `C_LFGList.GetApplicationInfo`, keeping the old appID path as a logged fallback. |
| PLAN-02 | `9f608077` | audit 2026-07-18 · WG-28 | 🟢 done | 2026-07-31 | Shared the colours only, not the backdrop table: the audit's design assumed both windows had the same border, but the popup uses a 1px hairline and the console a 12px tooltip border, so one shared table would have restyled a window. `NS.SKIN` + `NS.ApplySkin(frame, backdrop)` in `core/Util.lua`, with the divergence justified in-code. |
| ISS-02 | `adb8df35` | GitHub issue #2 | 🟡 deferred | 2026-07-31 | Validating mapIDs/spellIDs and handling mega dungeons needs in-game data that can't be verified from the repo; not worth guessing at IDs. Stays open on GitHub. |
| CODE-02 | `71717ee7` | `defaults/TeleportSpells.lua:113,119-121` | 🟢 done | 2026-07-31 | Kept the four raid placeholders as a checklist but rewrote the comments to state the real constraint ("no teleport spell exists; slot reserved") so they stop reading as unfinished work. Blocked on Blizzard, not on us. |
| CODE-03 | `f4d850e3` | `defaults/TeleportSpells.lua:98` | 🟡 deferred | 2026-07-31 | Same work as ISS-02 — the Uldaman mapID can't be sourced from here. Resolve both together when game data is available. |
| ISS-03 | `b16fc5b1` | GitHub issue #1 | 🟡 deferred | 2026-07-31 | "Add role to the pop" is a one-line spec for real feature work (capture the role, add a popup row, add a schema toggle); needs scoping before it can be built. Stays open on GitHub. |
| MEM-01 | `5012941c` | `memory/feedback_standards_adherence.md` | 🟢 done | 2026-07-31 | The rule was correct but its pointers had drifted. Updated to `standards/STANDARDS.md`, dropped the dead `§0` cross-ref, repointed at `docs/audits/2026-07-18/`, and fixed the `CLAUDE.md` section name to "Standards compliance (read first)". |

## LibKa0s adoption

One row per decision taken while adopting `LibKa0s` (`docs/adoption-prompt.md` in
that repo), written **when the call was made** rather than at the end. The rows
that get lost are the decisions that felt obvious at the time — and an unrecorded
decision is indistinguishable from a mistake to whoever finds it next.

`Kind` says what the row is: **took** (adopted a library surface), **declined**
(the surface exists and this addon deliberately kept its own), **gap** (the
contract cannot express what this addon needs), or **change** (a library change
this adoption drove).

| ID | Kind | Module | Decision |
|---|---|---|---|
| LIBKA0S-01 | took | testkit | The harness moved onto the shared kit: `tests/run.lua` is `Kit.expose` + `Kit.run` over this repo's three lifecycle factories, `tests/loader.lua` became the isolated-instance factory over `Loader.makeEnv` / `Loader.tocFiles`, and `tests/wow_mock.lua` became an **extender** over `mock_base` rather than a swap. Taken FIRST, before any module: `mock_base` is the only source of a `LibStub` with a real `NewLibrary`, and without it every seam would have silently taken its degraded path while the suite stayed green. |
| LIBKA0S-06 | change | DebugLog | **This adoption drove a library change.** `D.Debug` routed every vararg through `safeToString` and handed the results to `string.format` — safe for a `%s` slot, but a WoW combat secret is a NUMBER, so a host logging one through `"%d"` passed `"<secret>"` to `%d` and `string.format` raised, *inside the gated sink*, which is the one place debug-logging-§4 exists to keep safe. WhatGroup's own sink had `pcall`'d this since WG-22, so its suite went red on the first load of the library's. Not host-shaped and not adapter-able: the sink is bound bare (`NS.Debug = D.Debug`, a MUST), so wrapping it would re-implement the gate — anti-patterns #47. Fixed upstream at **DebugLog minor 7** (LibKa0s v1.5.0): the format is `pcall`'d and the line still lands, format string first then the stringified args. A satisfiable format is byte-identical to minor 6, so no consumer's output moved; all seven other consumers' suites are unchanged. |
| LIBKA0S-05 | gap | DebugLog | **The console no longer remembers where you put it.** `core/DebugLog.lua` persisted the window's anchor through `NS.Windows.Save`/`Restore` on its drag bar (WG-26). The library builds and owns that drag bar, exposes neither it nor a geometry hook, and its `OnDragStop` is a bare `StopMovingOrSizing()` — so there is no adapter, only a fork. Accepted rather than worked around: debug-logging-§1's "what the library guarantees" list does not include position persistence, no other adopter has it, and the popup — the window a player actually positions — keeps its own. Recorded as a gap rather than a decline because the contract genuinely cannot express it; if a second host wants it, it is an additive descriptor field upstream. |
| LIBKA0S-04 | declined | DebugLog | No `skin`, no `applySkin`, no `makeCloseButton`. Core minor 3 made the library's own default the normative Ka0s window edge (standalone-windows), which is what the popup now wears too, and the × on a window the LIBRARY draws is the library's — a host must not push its own onto it. The console therefore looks slightly different from the one this addon shipped (a 1px black edge with a grey inner highlight in place of the 12px tooltip border), and that is the point. |
| LIBKA0S-03 | took | DebugLog | `core/DebugLog.lua` (405 lines) deleted outright; `core/DebugLogSetup.lua` (139) is the whole replacement. Both formatters were already byte-identical to the library's and the frame globals the descriptor generates from `name` match the old hardcoded ones exactly, so `/framestack` and Esc-close behave as before. The seam MOVED in the TOC — after `core/WhatGroup.lua` rather than before it — because the library validates `font` at `:New` time where the hand-written console read `NS.FONT_MONO` lazily inside its frame builder. Nothing calls `NS.Debug` at file load, so the move costs nothing. |
| LIBKA0S-02 | declined | testkit | `mock_base`'s frame stub is not a drop-in and the host mock keeps ten overrides over it, each documented in `tests/wow_mock.lua`'s header. The load-bearing four are the kit's own documented divergence (`CreateFontString`/`CreateTexture` answer the frame itself — the popup collapses into one `SetText` sink), a `Hide` that fires `OnHide`, numeric `GetLeft/Right/Top/Bottom` (the secure teleport button's offsets are arithmetic over them), and an AceTimer queue **separate** from `C_Timer`'s, because the notify delay and the panel's secure-defer hop have to be fireable independently. |
