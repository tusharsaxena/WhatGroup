# 01 — Delta: LibKa0s v1.30.0 → v1.31.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.31.0 LibKa0s testkit`. The tag resolves to `30db4ed` ("The v1.31.0
release record"). `git -C ../LibKa0s tag --sort=-v:refname | head -1` answers `v1.31.0`, and the
sibling's working tree was clean.

Written before anything was copied. This is a non-interactive run (triage wave B2, 2026-09-12): the
owner decided in advance that WhatGroup migrates its harness onto the kit (#19, option 1), so the
decisions are recorded in `03_DECISIONS.md` without an interview.

This is the second re-vendor dated 2026-09-12. The first, v1.29.0 → v1.30.0, is the frozen bundle at
`docs/revendor/2026-09-12/`; this one takes the `-v1.31.0` suffix so that bundle stays untouched.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.30.0 (MIT). That line is the
```

The line sits mid-paragraph under `## Bundled LibKa0s`. Only the version moves.

## 3b — Actual version, before this run

```
grep -HoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, Perf 10, Pool 3, Slash 7, Widgets 9,
`WIDGETS_MINOR` 14, `COMPOSE_MINOR` 3, `SCROLL_MINOR` 3, `PANEL_MINOR` 5. These match v1.30.0's
release block, so the line and the bytes **agreed**.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml`: Core, Env, Pool, Item, Media, Widgets,
DebugLog, Slash, Options, OptionsWidgets, OptionsCompose, OptionsScroll, Perf, PerfPanel.

| File | Constant | v1.30.0 | v1.31.0 |
|---|---|---|---|
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 14 | **15** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 3 | **4** |
| every other shipped file | as above | unchanged | unchanged |

Two secondary files of the Options major move. No file is behind the tag after the copy, so
**no cross-major skew is possible**.

## 3d — Both diffs, both directions

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # OptionsCompose.lua, OptionsWidgets.lua
diff -rq                    <tag>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # README.md, framework.lua, mock_base.lua
diff -rq                    <tag>/testkit tests/_kit     # the same three
```

Five files differ in content, and the byte diff names the same five, so there is no line-ending
drift on either side. There are **no `Only in` lines**, so nothing was removed upstream and no
deletion inside either payload is warranted.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Core (`core/CoreSetup.lua:39`), Env (`core/EnvSetup.lua:41`), Media (`core/MediaSetup.lua:49`),
DebugLog (`core/DebugLogSetup.lua:20`), Options (`settings/OptionsSetup.lua:17`), Slash
(`settings/Slash.lua:64`). These are the six seams `CLAUDE.md` names; no seventh lookup site. Perf is
declined on structural grounds (LIBKA0S-15, WhatGroup#7). This release does not touch Perf, so that
premise is unchanged.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
<tag>/testkit/framework.lua:20:Kit.VERSION = 17
tests/_kit/framework.lua:20:Kit.VERSION = 16
```

Kit revision **16 → 17**. Both payloads are copied whole, in the same commit as the provenance line.
The pairing rule (LibKa0s ≥ v1.9.0 takes kit ≥ 11 in the same commit) is met by construction.

## Baseline gate, before the copy

`lua tests/run.lua`: 573 passed, 0 failed, 0 skipped, 573 total. `luacheck .`: 0 warnings / 0 errors
in 41 files. The runner is recorded `100755` in the index.

## Addendum, 2026-09-12: the v1.31.0 tag was re-cut before release

This bundle was written against the first cut of the `v1.31.0` tag (commit `30db4ed`). Before anything
was pushed, a review of that release found defects in the kit-17 fakes, and LibKa0s re-cut the tag on the
fixed tree: **`v1.31.0` now points at `e7e1962`**. Commit `fa2fdc1` ("Re-vendor LibKa0s v1.31.0 from the
re-cut tag (e7e1962)") copied both payloads whole from the re-cut tag, and the vendor-sync cases pass
against it. The provenance line in `CLAUDE.md` already named v1.31.0, so it did not move.

What the re-cut changed, relative to the tables above:

| File | First cut | Re-cut |
|---|---|---|
| `Perf.lua` | minor 10 (unchanged) | **minor 11**: `P.Save` traces the ring trim once past its cap (debug-logging-§8) |
| `OptionsWidgets.lua` | minor 15 | minor 15 (review fixes land inside the unreleased minor: `pairWith` keyed by `row.path or row.field`; a bound row's `disabledIf` reads through `row.get`) |
| `OptionsCompose.lua` | minor 4 | minor 4 (unchanged surface) |
| kit (`tests/_kit/`) | revision 17 | revision 17 (review fixes: repeating-timer delay no longer drifts; the nameless `NewAddon` path is exactly one table argument; the timer handle field is AceTimer's own `cancelled`, and `NewTimer` handles answer `IsCancelled()`; dispatch survives a handler error; `ADDON_LOADED` after login enables a load-on-demand addon; the AceEvent library object carries the message API) |

So three files in `LibKa0s/` move in this release, not two, and any "the ring trim is not traced" finding
recorded above is resolved upstream by Perf minor 11.

The re-cut needed one consumer follow-up. The reviewed kit records a canceled timer handle under
AceTimer's own field name, `cancelled`, where the first cut used `canceled`. The supersede case in
`tests/test_notify.lua` read the old name, and it was the one failure `fa2fdc1` left. Commit `0fd5493`
("Tests: read the canceled timer handle as AceTimer's `cancelled`") ported that read from `.canceled` to
`.cancelled`. No other addon code reads the renamed field.

The gate, re-run on the re-cut payload:

| Point | `lua tests/run.lua` | `luacheck .` |
|---|---|---|
| After the re-cut copy (`fa2fdc1`) | one failure: the `test_notify.lua` supersede case reading `.canceled` | — |
| After the port (`0fd5493`) | 579 / 0 / 579, `test_vendor_sync` green against `e7e1962` | — |
| After the chat-link fix (`fcf8197`) | 589 / 0 / 589 | 0 / 0, 41 files |

The ten cases between the last two rows come from `fcf8197`'s chat-link tests, not from the re-cut.
