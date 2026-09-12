# 05 — Summary: LibKa0s v1.31.0 → v1.32.0

| | |
|---|---|
| From | v1.31.0 (re-cut, `e7e1962`), kit revision 17 |
| To | **v1.32.0** (tag at `e18dd12`), kit revision **17** |
| Run | non-interactive, bulk-logging rollout, 2026-09-12. No issue filed, nothing pushed |
| Rule | `debug-logging-§10`, standard v2.44.0 (WowAddonStandards `7883278`) |

## Per-file minors

| File | v1.31.0 | v1.32.0 |
|---|---|---|
| `Options.lua` (`MINOR`) | 15 | **16** |
| `Slash.lua` (`MINOR`) | 7 | **8** |
| Core 7, Env 1, Pool 3, Item 1, Media 3, Widgets 9, DebugLog 12, Perf 11, `WIDGETS_MINOR` 15, `COMPOSE_MINOR` 4, `SCROLL_MINOR` 3, `PANEL_MINOR` 5 | unchanged | unchanged |

Both payloads were copied whole from `git archive v1.32.0`, and the `CLAUDE.md` provenance line and
`docs/testing.md`'s sibling-state note moved in the same commit. After the copy, both diffs were empty
in both directions, content and bytes, against the tag and against the sibling's working tree. There
were no `Only in` lines.

## What each act now logs

| Act | Line |
|---|---|
| `/wg resetall` → Yes, the Master controls *Reset all settings* button, the Defaults button (all `Helpers.RestoreAllDefaults`) | `[Set] reset profile '<name>' to defaults (N rows)`, once, from `OnProfileReset`. N = profile rows whose stored value differed from the default just before the reset. No per-row `[Set]`, no `[Reset]`. |
| A reset straight at the db (`db:ResetProfile()` from AceDBOptions or a `/run`) | `[Set] reset profile '<name>' to defaults`, once, with no count. |
| The library's `RestoreDefaults(pageKey, ctx)` (unreached today, bracketed defensively) | `[Set] reset <pageKey>: N rows`, N = rows whose stored value changed (`: 0 rows` when all were at default). |
| The library's `RestoreAllDefaults` (overwritten on the instance, unreachable) | Bracketed the same way; with no `resetProfile` it would log `[Set] reset all: N rows`. |
| `/wg reset <path>` | `[Set] <path> = <value>`, unchanged. |
| `/wg set <path> <value>`, a panel widget | `[Set] <path> = <value>`, unchanged. |

## Adopted

| Candidate | Commit |
|---|---|
| Re-vendor (payload + provenance + `01_DELTA.md`) | `1a2d0e1` Re-vendor LibKa0s v1.32.0 (Options minor 16, Slash minor 8) |
| B-1 reset line + B-2 defensive bracket | `bdd5891` Log a profile reset as one [Set] line counting the rows it changed; bracket the library's resets (debug-logging-§10) |

## Declined, skipped, unreached

- `resetProfile` on the descriptor: declined, it would break `test_settings.lua`'s refresh-once case.
- Slash 8 bracket: unreached (`/wg resetall` is host-owned), not wired.
- `OnProfileCopied` / `OnProfileChanged` lines: not added. WhatGroup ships no profile UI and the
  rollout's scope for it is the reset. Recorded in `03_DECISIONS.md`.
- Filing was skipped by instruction.

## Gates

| Point | `lua tests/run.lua` | `luacheck .` | `lizard -C 15` |
|---|---|---|---|
| Baseline, before the copy | 589 / 0 / 589 | 0 / 0, 41 files | — |
| After the copy (`1a2d0e1`) | 589 / 0 / 589, `test_vendor_sync` green against v1.32.0 | 0 / 0 | — |
| Red step (first draft of the cases) | 588 / 5 failed / 593 | — | — |
| After the adoption (`bdd5891`) | 597 / 0 / 597 | 0 / 0, 41 files | clean (runner form `-x ./libs/* -x ./tests/_kit/*`, and `core modules settings defaults locales`) |

lizard 1.24.0 crashed with a `TypeError` in `with_namespace` on a first cut of `settings/Schema.lua`
that built `Settings.Bulk` as a table of anonymous functions; the committed form declares them as
named `function Bulk.begin` / `Bulk.finish` and the crash is gone. HEAD's `Schema.lua` was clean
before the change. CR count equals LF count in every file both commits touched. `docs/test-cases.md`
is regenerated and in sync (597), and the README badge reads 597/597.
