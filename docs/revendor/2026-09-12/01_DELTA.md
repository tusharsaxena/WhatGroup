# 01 — Delta: LibKa0s v1.29.0 → v1.30.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.30.0 LibKa0s testkit`. The tag is annotated, at `e369e0f`, and sits
on the library's `fix/kit-27-30` branch rather than on `master`. That does not matter here:
`tests/test_vendor_sync.lua` resolves the **tag** its provenance line names, not a branch.

Written before anything was copied. This run is non-interactive: the owner answered the adoption
interview in advance (2026-09-12). The answers are recorded in `03_DECISIONS.md`.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.29.0 (MIT). That line is the
```

The line sits mid-paragraph under `## Bundled LibKa0s`. Only the version moves.

## 3b — Actual version, before this run

```
grep -hoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, Perf 10, Pool 3, Slash 7, Widgets 9,
`WIDGETS_MINOR` 14, `SCROLL_MINOR` 3, `PANEL_MINOR` 5, plus `COMPOSE_MINOR` 3 in `OptionsCompose.lua`.
These match v1.29.0's release block. The line and the bytes **agreed**.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml`: Core, Env, Pool, Item, Media, Widgets,
DebugLog, Slash, Options, OptionsWidgets, OptionsCompose, OptionsScroll, Perf, PerfPanel.

| File | Constant | v1.29.0 | v1.30.0 |
|---|---|---|---|
| every shipped file | as above | unchanged | unchanged |

`diff old-minors new-minors` is empty. The v1.30.0 CHANGELOG says the same: *"No file in `LibKa0s/`
moved, so every minor above is the one v1.29.0 shipped."* **No cross-major skew is possible.**

## 3d — Both diffs, both directions

```
diff -r --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # empty
diff -rq                    <tag>/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr <tag>/testkit tests/_kit     # 4 files
diff -rq                    <tag>/testkit tests/_kit     # the same 4 files
```

Four kit files differ in content: `README.md`, `framework.lua`, `mock_base.lua` and `vendor_sync.lua`.
That is the whole of the release, kit revision 16. There are **no `Only in` lines**, so nothing was
removed upstream and no deletion inside either payload is warranted.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Core (`core/CoreSetup.lua`), Env (`core/EnvSetup.lua`), Media (`core/MediaSetup.lua`), DebugLog
(`core/DebugLogSetup.lua`), Options (`settings/OptionsSetup.lua`), Slash (`settings/Slash.lua`).
These are the same six seams `CLAUDE.md` names. Perf is declined on structural grounds
(LIBKA0S-15, WhatGroup#7). That is settled, and this release does not touch Perf, so the premise is
unchanged.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
<tag>/testkit/framework.lua:20:Kit.VERSION = 16
tests/_kit/framework.lua:20:Kit.VERSION = 15
```

Kit revision **15 → 16**. Both payloads are copied whole, in the same commit as the provenance line.
The pairing rule (LibKa0s ≥ v1.9.0 takes kit ≥ 11 in the same commit) is met by construction. The
two payloads move together so the addon can never hold a kit that cannot compare the library it
ships.

## Runner mode, for the new #28 case

```
git ls-files -s tests/_kit/run-automated-tests.sh
100755 f6cd8b0a86aaf87d394e9ebaf0decf9e13c4e10c 0	tests/_kit/run-automated-tests.sh
```

The index already records the runner as `100755`, so the case revision 16 adds should pass as-is.

## Baseline gate, before the copy

`lua tests/run.lua`: 568 passed, 0 failed, 0 skipped, 568 total. `luacheck .`: 0 warnings / 0 errors
in 41 files.
