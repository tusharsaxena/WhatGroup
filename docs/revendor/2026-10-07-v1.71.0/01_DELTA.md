Delta: LibKa0s v1.70.0 -> v1.71.0

# LibKa0s v1.70.0 -> v1.71.0: the delta (WhatGroup)

Item RV-WG of the 2026-10-07 review and standards-audit remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/`), run mechanically
per `/dev-copilot:wow-revendor-libka0s` with no interview and no issue filing (the plan's
`OWNER_SCOPE.md` §5). Copied from the annotated tag `v1.71.0` (LibKa0s commit `cb274a4`, tag object
`3bf1b97`) by `git -C ../LibKa0s archive v1.71.0 LibKa0s testkit | tar -x`. The tag is **local
only**: it sits on LibKa0s's `feat/2026-10-07-review-audit-remediation` and is not on origin until
the owner's go-ahead.

## 3a. The base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# 3fd8a2f chore: re-vendor LibKa0s v1.70.0
diff -rq <v1.70.0>/LibKa0s libs/LibKa0s && diff -rq <v1.70.0>/testkit tests/_kit && echo payload-matches
# payload-matches
```

The provenance line, the last payload commit and the payload agree: the base is **v1.70.0**.
`git -C ../LibKa0s log --oneline v1.70.0..v1.71.0` lists 20 commits; the payload ones are `LK-01`
to `LK-06`.

## 3c. Per-file minors (the tag's `LibKa0s.xml`)

| File | Major | old | new |
|---|---|---|---|
| `Env.lua` | `LibKa0s-Env-1.0` | 1 | 2 |
| `Slash.lua` | `LibKa0s-Slash-1.0` | 19 | 20 |
| `SlashParse.lua` | `LibKa0s-Slash-1.0` | 1 | 2 |
| `OptionsIdList.lua` | `LibKa0s-Options-1.0` | 3 | 4 |
| `WidgetsLineChart.lua` | `LibKa0s-Widgets-1.0` | 2 | 3 |
| `WidgetsAutocomplete.lua` | `LibKa0s-Widgets-1.0` | 1 | 2 |
| every other file (28) | | as v1.70.0 | unchanged |

Thirty-four library files on both sides; no file added or removed, no `NEEDS_*` floor rises
(the tag's `CHANGELOG.md` v1.71.0 block).

## 3d. Both diffs, before the copy

`diff -rq <tag>/LibKa0s libs/LibKa0s` names exactly the six files above. `diff -rq <tag>/testkit
tests/_kit` names `README.md`, `framework.lua` and `inventory.lua`, and `secrets.lua` is only in the
tag. Nothing is only in the addon, so the whole-folder copy deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

Core, Env, Compat, Lifecycle, Media, DebugLog, Launcher, Schema, Options and Slash, unchanged from
v1.70.0. Widgets is not consumed (declined, [#12](https://github.com/tusharsaxena/WhatGroup/issues/12)).

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION =' <tag>/testkit/framework.lua tests/_kit/framework.lua
# <tag>/testkit/framework.lua:20:Kit.VERSION = 38
# tests/_kit/framework.lua:20:Kit.VERSION = 37
```

Kit revision **37 -> 38**: the `--list` renderer moves to `inventory.lua` and its `## Totals` table
counts only the cases that run (a `Skipped` row before Total), and the new `secrets.lua` adds the
opt-in `Kit.secret` family. Both payloads come from the one tag in this commit, so the
revision-11 pairing rule holds by construction.

## 3g. Contract delta

Moved majors (Env, Slash, Options, Widgets) intersected with consumed majors: **Env, Slash and
Options**.

- **Env 2**: `Env.GetAddOnMetadata` no longer falls back to the bare `GetAddOnMetadata` global.
  `NS.Meta` and `NS.Version` (`core/EnvSetup.lua`) call it only when the library is present, and every
  supported client has `C_AddOns`, so no host behavior moves.
- **Slash 20.2**: `ParseValue` refuses `nan` and the infinities on a number row. No host test
  pinned their acceptance; the suite is green after the copy.
- **OptionsIdList 4**: the id-list help-art guard asks `C_AddOns.IsAddOnLoaded` only. WhatGroup's
  panel builds no id list (`settings/OptionsSetup.lua` stubs `H.IdList`).

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` is empty.

**Blockers:** none.

## 3h. Tags vendored and never recorded

Before this run the listing printed `v1.69.0` and `v1.70.0`. They are recorded by the span bundle
`docs/revendor/2026-10-07-v1.69.0-v1.70.0/`, written in the same commit, and the listing now prints
nothing.
