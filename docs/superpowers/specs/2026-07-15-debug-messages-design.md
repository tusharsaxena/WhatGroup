# Design — Better WhatGroup debug messages (standard §8/§9/§10)

**Date:** 2026-07-15
**Status:** Approved (brainstorming) — implementing
**Scope:** Content of the debug log only. The console, line format, sink, and
session-only on/off flag are unchanged.

## Goal

Make the debug console tell the story of what the addon did: (1) trace the main
functional flows, (2) log every settings change, (3) kill spam by coalescing and
trimming, (4) keep the already-standardized `<HH:MM:SS> | [Tag] <content>`
format. Apply the Ka0s WoW Addon Standard's `debug-logging` §8 (Coverage, MUST),
§9 (Coalescing, MUST NOT), §10 (Settings changes, MUST) — codified by the
LootHistory reference; WhatGroup only needs to conform.

## Already in place (no change)

- Line format `<ts> | [Tag] <content>` via `NS.Debug(tag, fmt, …)` →
  `DebugLog.FormatColored`/`FormatPlain` (debug-logging §3). Every call site
  routes through `NS.Debug`; no site bypasses it, so "always this format" is
  structural.
- Zero-alloc gate (`NS.State.debug`), session-only flag, the console window.
- Verbosity stays a flat on/off — no log levels.

## Decisions

- **`[Init]` visibility:** debug is session-only (off at login), so a boot-time
  `[Init]` line is emitted while debug is off and never seen. Resolution: emit
  `[Init]` at `OnEnable` (satisfies §8 literally, zero-alloc when off) **and**
  re-emit a one-line state snapshot the moment debug is switched on, via
  `WhatGroup:LogState(reason)` called from `runDebug`'s `on` path after
  `SetEnabled(true)`. Every debug session then opens with current context.
- **Settings logging:** one canonical line at the single write seam
  (`Helpers.Set`); no downstream re-echo (§10).
- **Reset coalescing:** `RestoreDefaults` sets N rows via `Helpers.Set`; suppress
  the per-row `[Set]` with a new `skipLog` opt and emit one `[Reset]` summary
  (§9).

## Code changes

### A. Coalesce & trim (§9)

- **`WhatGroup_Settings.lua` `Helpers.Set`** — gains `opts.skipLog`. When not set,
  logs `[Set] <path> = <value>` once (value via a small local formatter:
  bool/number → string). `RawSet` stays silent (side-effect-free write).
- **`WhatGroup_Settings.lua` `Helpers.RestoreDefaults`** — passes
  `{ skipRefresh = true, skipLog = true }` per row, then emits one
  `[Reset] restored N settings to defaults` (N counted from schema rows with a
  path). String/count built behind the debug gate.
- **`WhatGroup.lua` `OnApplyToGroup` + `CaptureGroupInfo`** — merge the two lines
  into one at apply: `[Apply] id=N captured "<title>" (activity=A map=M m+=B)`.
  Keep `[Capture] GetSearchResultInfo returned nil for id=N` for the no-op path.
  `CaptureGroupInfo` no longer emits its own success line (the `[Apply]` summary
  carries it); it returns the captured table as today.
- **Trim tag-echoing prefixes** across every message (`LFG_STATUS`,
  `ApplyToGroup`, `ConfigureTeleportButton:`, `ShowFrame:`, `inviteaccepted:`).

### B. New flow coverage (§8) — one gated line each

| Tag | File / site | Example line |
|-----|-------------|--------------|
| `Init` | `WhatGroup.lua` `OnEnable` + `WhatGroup:LogState` | `ready schemaVersion=1 enabled=true notify.delay=1.5s autoShow=true inGroup=false hasPending=false` |
| `Migrate` | `Database.lua` `RunMigrations` (only if version changes) | `v1 -> v2` |
| `Invite` | `WhatGroup.lua` inviteaccepted merge | `accepted appID=N → "<title>" map=M (source=fresh)` |
| `Notify` | `WhatGroup.lua` `_TryFireJoinNotify` + timer | `scheduling in 1.5s (ROSTER transition)`; `fired`; `cancelled (superseded)` |
| `Frame` | `WhatGroup_Frame.lua` ShowFrame / teleport | `popup shown "<title>"`; `teleport spellID=445269 known=true` |
| `Reset` | `WhatGroup_Settings.lua` RestoreDefaults | `restored 10 settings to defaults` |
| `Test` | `WhatGroup.lua` `RunTest` | `synthetic capture injected "<title>"` |

`WhatGroup:LogState(reason)` builds the `[Init]` snapshot from `db.profile` +
`IsInGroup()` + `pendingInfo`, gated on debug-on.

### C. Settings changes (§10)

- `Helpers.Set` → `[Set] <path> = <value>` (see A).
- `enabled` `onChange` reactor: when disabling actually wipes an in-flight
  capture, log **one material-effect** line `[Capture] wiped (addon disabled)` —
  only when `pendingInfo` or a queued/pending application existed. Never restates
  the `enabled = false` value.

### D. Tag inventory after

Kept: `Capture` `Apply` `LFG` `Invite` `Roster` `Notify` `Frame` `ChatLink`
`Debug`. Added: `Init` `Migrate` `Set` `Reset` `Test`. Renamed: internal
`[Settings] Helpers.Get: no path` → `[Schema]` (disambiguates from `[Set]`).

## Out of scope (YAGNI)

Log levels/tiers, console/format/font changes, standard edits (already done),
window-geometry logging, version bump, git commit.

## Verify

- `lua tests/run.lua` + `luacheck .` green.
- Extend `tests/test_debuglog.lua`: `[Set]` fires once at the seam; `RestoreDefaults`
  emits one `[Reset]` and zero `[Set]`; `LogState` emits `[Init]`; the merged
  `[Apply]` summary; all when debug on, nothing when off.
- Sync `docs/debug-console.md`, `docs/common-tasks.md`, `docs/smoke-tests.md`.
- No auto-commit (repo hard rule) — working tree only.
