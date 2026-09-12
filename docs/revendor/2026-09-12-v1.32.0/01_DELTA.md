# 01 — Delta: LibKa0s v1.31.0 → v1.32.0

Taken **from the tag**, never from the sibling working tree:
`git -C ../LibKa0s archive v1.32.0 LibKa0s testkit`. The tag resolves to `e18dd12` ("The v1.32.0
release record, re-taken on the final tree"). `git -C ../LibKa0s tag --sort=-v:refname | head -1`
answers `v1.32.0`, and the sibling's working tree was clean, checked out at `e18dd12`.

Written before the adoption work. This is a non-interactive run (bulk-logging rollout, 2026-09-12):
the owner ruled `debug-logging-§10` in advance (standard v2.44.0, WowAddonStandards `7883278`), so
the decisions are recorded in `03_DECISIONS.md` without an interview. Filing and pushing are skipped
by instruction.

This is the third re-vendor dated 2026-09-12. The first two are the frozen bundles at
`docs/revendor/2026-09-12/` (v1.29.0 → v1.30.0) and `docs/revendor/2026-09-12-v1.31.0/`; this one
takes the `-v1.32.0` suffix so both stay untouched.

## 3a — Claimed version, before this run

```
grep -n '[Bb]undles' CLAUDE.md
71:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.31.0 (MIT). That line is the
```

The line sits mid-paragraph under `## Bundled LibKa0s`. Only the version moves. The one other live
reference, `docs/testing.md:250`'s sibling-state note, moves with it.

## 3b — Actual version, before this run

```
grep -HoE 'local (MAJOR, )?(MINOR|WIDGETS_MINOR|SCROLL_MINOR|PANEL_MINOR|COMPOSE_MINOR) *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Core 7, DebugLog 12, Env 1, Item 1, Media 3, Options 15, Perf 11, Pool 3, Slash 7, Widgets 9,
`WIDGETS_MINOR` 15, `COMPOSE_MINOR` 4, `SCROLL_MINOR` 3, `PANEL_MINOR` 5. These match v1.31.0's
release block (the re-cut, `e7e1962`), so the line and the bytes **agreed**.

## 3c — Per-file minor delta

The file list comes from the tag's `LibKa0s/LibKa0s.xml`: Core, Env, Pool, Item, Media, Widgets,
DebugLog, Slash, Options, OptionsWidgets, OptionsCompose, OptionsScroll, Perf, PerfPanel.

| File | Constant | v1.31.0 | v1.32.0 |
|---|---|---|---|
| `Options.lua` | `MINOR` | 15 | **16** |
| `Slash.lua` | `MINOR` | 7 | **8** |
| every other shipped file | as above | unchanged | unchanged |

Two primary files move, each the head of its own major. No file is behind the tag after the copy, so
**no cross-major skew is possible**.

## 3d — Both diffs, both directions

```
diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # Options.lua, Slash.lua
diff -rq                    <tag>/LibKa0s libs/LibKa0s   # the same two
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit     # empty
diff -rq                    <tag>/testkit tests/_kit     # empty
```

Two files differ in content, and the byte diff names the same two, so there is no line-ending drift
on either side. There are **no `Only in` lines**, so nothing was removed upstream and no deletion
inside either payload is warranted. After the copy all four are empty, and so are the same four
against the sibling's working tree.

## 3e — Consumption map

```
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v /libs/ | grep -v /tests/
```

Core, Env, Media, DebugLog, Options (`settings/OptionsSetup.lua`) and Slash (`settings/Slash.lua`):
the six seams `CLAUDE.md` names. Both moving majors are consumed. Perf stays declined on structural
grounds (LIBKA0S-15, WhatGroup#7); this release does not touch Perf.

What each move reaches here:

- **Options 16** adds the optional `bulkBegin` / `bulkEnd` descriptor pair around `RestoreDefaults`
  and `RestoreAllDefaults`. WhatGroup's descriptor supplies neither, so the walk is minor 15's
  exactly. More to the point, neither walk is on the live path: the host's `Helpers.RestoreAllDefaults`
  overrides the library's on the instance (LIBKA0S-08, WhatGroup#10), and nothing calls the per-page
  `RestoreDefaults` because the Defaults button is confirmation-gated through the popup.
- **Slash 8** adds the same pair around `CliResetAll`. WhatGroup's `/wg resetall` is host-owned
  (`runResetAll`, behind the popup) and never reaches `CliResetAll`, so the bracket is unreached.

## 3f — Kit revision, and the pairing rule

```
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
<tag>/testkit/framework.lua:20:Kit.VERSION = 17
tests/_kit/framework.lua:20:Kit.VERSION = 17
```

Kit revision **17 → 17**; `testkit/` does not move in this release. Both payloads are still copied
whole, in the same commit as the provenance line. The pairing rule (LibKa0s ≥ v1.9.0 takes kit ≥ 11
in the same commit) is met by construction. The runner `tests/_kit/run-automated-tests.sh` stays
`100755` in the index.

## Baseline gate, before the copy

`lua tests/run.lua`: 589 passed, 0 failed, 0 skipped, 589 total. `luacheck .`: 0 warnings / 0 errors
in 41 files.
