Delta: LibKa0s v1.68.0 -> v1.68.1

# LibKa0s v1.68.0 -> v1.68.1: the delta (WhatGroup)

Item DC-REV-01 of the 2026-10-04 LibKa0s re-vendor (`/dev-copilot:wow-revendor-libka0s WhatGroup
--tag v1.68.1`). Copied from the annotated tag `v1.68.1` (LibKa0s commit `9000cbd`, tag object
`9fb7956`, present on origin) by `git -C ../LibKa0s archive v1.68.1 LibKa0s testkit | tar -x`. The
sibling checkout's `HEAD` (`29e61d6`) is past the tag; `git -C ../LibKa0s diff --stat v1.68.1 HEAD
-- LibKa0s testkit` is empty, and the payload is taken from the tag either way.

v1.68.1 is a rename-only release: test kit revision 36, whose three changed files name the
`/dev-copilot:*` commands where revision 35 named `/wow-addon:*`. No LibStub minor moves.

## Step 0. Pre-flight

The step's table over the eleven in-scope addons (`../WowAddonStandards/standards/ADDONS.md`) prints
`ok` on every row; this addon's row:

```
WhatGroup  2026-10-02-v1.68.0  base v1.67.0  vendored-before v1.67.0@ea4bff6  ok
```

No base correction is owed.

## 3a. The base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.68.0 (MIT).
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)
# ea4bff6 TP-WG-01: re-vendor LibKa0s v1.68.0 (WidgetsDragHandle minor 4)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # ... v1.68.0
git log --format='%h %s' "$c..HEAD" -- CLAUDE.md
# 8c45687 SD-FIN-01: sync docs; CLAUDE.md back to the documentation-§2 stub   (line still v1.68.0)
diff -rq <v1.68.0>/LibKa0s libs/LibKa0s && diff -rq <v1.68.0>/testkit tests/_kit && echo payload-matches
# payload-matches
```

The provenance line, the last payload commit and the payload agree (`8c45687` touched `CLAUDE.md`
without moving the line): the base is **v1.68.0**.

```sh
git -C ../LibKa0s log --oneline v1.68.0..v1.68.1
# 9000cbd DC-REN-05  84cd24a DC-REN-04  060e2df DC-REN-03  fc805a2 DC-REN-02
# cfefa99 DC-REN-01: kit revision 36 and v1.68.1 - the kit and the live docs name the dev-copilot plugin's commands
# 0e9deee SD-FIN-01  c2c078d Merge branch 'feat/2026-10-02-drag-attach'
git -C ../LibKa0s diff --stat v1.68.0 v1.68.1 -- LibKa0s testkit
# testkit/framework.lua | 2 +-   testkit/run-automated-tests.sh | 8 +-   testkit/test_eol.lua | 2 +-
# (LibKa0s/: nothing)
```

## 3b. Claimed against actual

Before the copy, `diff -rq` of the addon's payload against the v1.68.0 tree is empty (3a), so every
vendored minor is v1.68.0's (32 constants by the step's grep). No skew.

## 3c. Per-file minors (the tag's `LibKa0s.xml`, in load order)

The step's loop over the tag's XML prints the same constant in both columns for all 32 files.

| File | old | new |
|---|---|---|
| every file (32) | as v1.68.0 | unchanged |

No file added or removed, no `NEEDS_*` floor rises (`CHANGELOG.md:13`-`:18` at v1.68.1: "Every
library file is unchanged from v1.68.0 ... No LibStub minor moves").

## 3d. Both diffs, before the copy

```sh
diff -r --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s   # empty
diff -r                     <tag>/LibKa0s libs/LibKa0s   # empty
diff -rq --strip-trailing-cr <tag>/testkit tests/_kit    # framework.lua, run-automated-tests.sh, test_eol.lua differ
diff -rq                     <tag>/testkit tests/_kit    # the same three
```

The library payload is already the tag's. The kit differs in exactly the three files the release
names; nothing is only in the tag and nothing only in the addon, so the copy deletes nothing.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

Core (`core/CoreSetup.lua:39`), Env (`core/EnvSetup.lua:41`), Compat (`core/Compat.lua:35`),
Lifecycle (`core/LifecycleSetup.lua:38`), Media (`core/MediaSetup.lua:50`), DebugLog
(`core/DebugLogSetup.lua:20`), Launcher (`core/LauncherSetup.lua:42`), Schema
(`settings/SchemaSetup.lua:236`), Options (`settings/OptionsSetup.lua:17`), Slash
(`settings/Slash.lua:129`). Unchanged from v1.68.0.

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION' <tag>/testkit/framework.lua tests/_kit/framework.lua
# <tag>/testkit/framework.lua:20:Kit.VERSION = 36
# tests/_kit/framework.lua:20:Kit.VERSION = 35
```

Kit revision **35 -> 36** (`docs/api/testkit/version-36-docs.md:10`, `:19`-`:23`: no member, case,
mock or manifest field changes). The revision-11 pairing rule holds by construction: both payloads
come from the one tag in this commit, which is why they move together.

## 3g. Contract delta

Moved majors (3c: none) intersected with consumed majors (3e) is **empty**, so no host contract can
have moved under this addon. `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs
--exclude-dir=Libs --exclude-dir=_kit` is empty: no host-supplied member exists to have had its call
site moved. The kit is not a LibStub major; its document states no surface change
(`version-36-docs.md:22`-`:23`).

**Blockers:** none.

## 3h. Tags vendored and never recorded

The step's listing (horizon 2026-08-25; 48 vendored tags, 48 recorded) prints nothing. No span
bundle is owed.
