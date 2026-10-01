Delta: LibKa0s v1.65.0 -> v1.66.0

# 01 — Delta (WhatGroup)

Plan item GI-WG-RV of the 2026-10-01 GitHub issue pass
(`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`, spec S4). Payload taken from the
**local tag** v1.66.0 (`e4c5ef7`):

```sh
git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>/new
```

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md          # :79  Bundles [LibKa0s](...) v1.65.0 (MIT)
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)       # fff8fb8 (DG-WG-01)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # v1.65.0
git -C ../LibKa0s archive v1.65.0 LibKa0s testkit | tar -x -C <scratch>/claimed
diff -rq <scratch>/claimed/LibKa0s libs/LibKa0s && diff -rq <scratch>/claimed/testkit tests/_kit   # payload-matches
```

Base **v1.65.0**; claim and payload agree. `git -C ../LibKa0s log --oneline v1.65.0..v1.66.0`: 24 commits;
`git -C ../LibKa0s diff --stat v1.65.0 v1.66.0 -- LibKa0s testkit`: 20 files changed, 2693 insertions,
1651 deletions. Step 0 for this addon: newest single-tag bundle `2026-09-29-v1.63.0` states base
v1.62.0, the provenance before `1329218` was v1.62.0: ok.

## 3b / 3c. Minors (only the files that moved; every other file unchanged)

```sh
for f in $(git -C ../LibKa0s show v1.66.0:LibKa0s/LibKa0s.xml | grep -oE 'file="[^"]+\.lua"' | cut -d'"' -f2); do ... done
```

| File | Old | New |
|---|---|---|
| `Widgets.lua` | MINOR 11 | MINOR 12 |
| `WidgetsReorder.lua` | (new) | REORDER_MINOR 1 |
| `DebugLog.lua` | MINOR 18 | MINOR 19 |
| `Slash.lua` | MINOR 18 | MINOR 19 |
| `SlashParse.lua` | (new) | PARSE_MINOR 1 |
| `OptionsWidgets.lua` | WIDGETS_MINOR 33 | WIDGETS_MINOR 34 |
| `OptionsTabs.lua` | TABS_MINOR 7 | TABS_MINOR 8 |
| `Perf.lua` | MINOR 13 | MINOR 14 |
| `PerfSampler.lua` | (new) | SAMPLER_MINOR 1 |
| `PerfCommands.lua` | (new) | COMMANDS_MINOR 1 |

No consumer file was behind its claim: no cross-major skew.

## 3d. Diffs

Before the copy (`diff -rq --strip-trailing-cr <scratch>/new/LibKa0s libs/LibKa0s`, and for the kit):
the ten files above differ or are `Only in <scratch>/new` (the four new library files,
`lizard_sighted.lua`, `test_lizard_sighted.lua`); kit `README.md`, `asserts.lua`, `framework.lua`,
`inventory.lua`, `mock_base.lua`, `run-automated-tests.sh`, `test_eol.lua` differ. No
`Only in libs/LibKa0s` or `Only in tests/_kit`: nothing to delete. After the copy, `diff -r` (bytes) and
`diff -r --strip-trailing-cr` are empty for both payloads.

## 3e. Consumption

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

Ten majors through the ten seam files (Compat, Core, DebugLog, Env, Launcher, Lifecycle, Media,
Options, Schema, Slash), unchanged. Perf is declined (#7). The moved majors this addon consumes:
DebugLog, Slash, Options (OptionsWidgets, OptionsTabs); Widgets is reached through DebugLog.

## 3f. Kit

`Kit.VERSION` 34 -> **35** (`tests/_kit/framework.lua:20`). Both payloads move together, as always.
Kit 35 adds `test_lizard_sighted.lua`, which `tests/run.lua` must declare (`Kit.assertSuiteInventory`).

## 3g. Contract delta

- **Slash 19** (`docs/api/Slash/version-19.1-docs.md:54-59`, `:759`, `:914`): a host `parse` is now
  handed `Sl:Text` as a third argument. `settings/Slash.lua:224` `parseValue(row, text)` declares two
  parameters and uses no third, so nothing it receives changes meaning. It still calls
  `lib.ParseValue(row, text)` with two arguments (`:232`), which answers `lib.STRINGS.ERR_BOOL` as before,
  and `:237-238` maps it to the descriptor's own wording: unchanged behavior.
- **SlashParse 1**: `lib.ParseValue` now lives in `SlashParse.lua`. The client loads it through
  `LibKa0s.xml`; the headless loader names every library file, so `tests/loader.lua` gains it (and
  the other three new files) in XML order.
- **OptionsWidgets 34 / OptionsTabs 8**: every new field is opt-in; WhatGroup calls neither
  `RenderGrid` nor `RenderTabbedSchema` itself.
- **DebugLog 19**: `lib:New`'s refusals and defaults hoisted to file-level helpers; no member, field,
  default or string moves.

**Blockers:** none.
