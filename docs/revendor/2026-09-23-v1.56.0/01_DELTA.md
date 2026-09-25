Delta: LibKa0s v1.55.0 -> v1.56.0

Written 2026-09-24 for plan item `RV-WG` of the 2026-09-23 review and standards-audit remediation,
following `../wow-addon/commands/revendor-libka0s.md` as amended by WA-01 (the local checkout; the
installed plugin predates WA-01). Scope: Steps 0 to 4 only (pre-flight, resolve, delta, copy).
Candidates, decisions and adoption (Steps 5 to 7) are **not** taken here: each surface this release
offers WhatGroup is already a named M3 plan item (WG-02 to WG-29), so this bundle carries no
`02_CANDIDATES.md`, `03_DECISIONS.md` or `04_EXECUTION_PLAN.md`.

## Step 0: pre-flight on the newest bundle's base

```sh
# Step 0's walk, restricted to this addon
b=docs/revendor/2026-09-23-v1.55.0   # newest single-tag bundle
head -1 $b/01_DELTA.md               # "# Re-vendor delta: LibKa0s v1.54.2 -> v1.55.0"
```

`WhatGroup  2026-09-23-v1.55.0  base v1.54.2  vendored-before v1.54.2@a60a3d6  ok`

The v1.55.0 bundle's base agrees with the provenance line before its re-vendor commit `a60a3d6`.
No base correction is owed.

## Step 2: the tag

```sh
git -C ../LibKa0s tag --sort=-v:refname | head -1      # v1.56.0 (local tag, not pushed)
git -C ../LibKa0s archive v1.56.0 LibKa0s testkit | tar -x -C <scratch>/tag/
```

Extracted from the tag, never from the library's working tree or a checkout of it.

## 3a. Claimed version, and the base

```sh
grep -n '[Bb]undles' CLAUDE.md
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)                 # a60a3d6
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+'
```

- `CLAUDE.md:79`: `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).`
- The last payload commit `a60a3d6` left the line at v1.55.0. Both walks agree.

```sh
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C <scratch>/old/
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit && echo payload-matches
```

`payload-matches`: the vendored payload is byte-identical to v1.55.0. **Base: v1.55.0.** Every
range below is `v1.55.0..v1.56.0` (48 library commits, `ab6404d`..`514fc0a`).

```sh
git -C ../LibKa0s log --oneline v1.55.0..v1.56.0
git -C ../LibKa0s diff --stat v1.55.0 v1.56.0 -- LibKa0s testkit
```

`LibKa0s/`: 15 files changed (every shipped `.lua` except `Env`, `Compat`, `Pool`,
`WidgetsDragHandle`, `OptionsCompose`, `PerfPanel`; `LibKa0s.xml` unchanged).
`testkit/`: `README.md`, `framework.lua`, `mock_base.lua`, `mock_record.lua`,
`run-automated-tests.sh`, `test_eol.lua`, `test_layout_cap.lua`, `test_prose.lua` changed;
`asserts.lua` (+330), `mock_events.lua` (+148), `prose_lists.lua` (+106) new.
26 files, +2349 / -844.

## 3b. Actual version

```sh
grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua
```

Every vendored minor equals v1.55.0's (the 3c "v1.55.0" column). Claim and fact agree; no skew
before the copy.

## 3c. Per-file minor delta

File list read from the tag's `LibKa0s/LibKa0s.xml` (21 `<Script>` rows, unchanged from v1.55.0),
constants from the grep in the spec's 3c loop.

| File | Constant | v1.55.0 (vendored) | v1.56.0 (tag) |
|---|---|---|---|
| `Core.lua` | `MINOR` | 7 | **8** |
| `Env.lua` | `MINOR` | 1 | 1 |
| `Compat.lua` | `MINOR` | 1 | 1 |
| `Lifecycle.lua` | `MINOR` | 1 | **2** |
| `Bus.lua` | `MINOR` | 1 | **2** |
| `Schema.lua` | `MINOR` | 1 | **2** |
| `Pool.lua` | `MINOR` | 3 | 3 |
| `Item.lua` | `MINOR` | 1 | **2** |
| `Media.lua` | `MINOR` | 3 | **4** |
| `Widgets.lua` | `MINOR` | 9 | **10** |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` | 2 | 2 |
| `DebugLog.lua` | `MINOR` | 12 | **13** |
| `Slash.lua` | `MINOR` | 14 | **15** |
| `Launcher.lua` | `MINOR` | 1 | **2** |
| `Options.lua` | `MINOR` | 23 | **24** |
| `OptionsWidgets.lua` | `WIDGETS_MINOR` | 30 | **31** |
| `OptionsTabs.lua` | `TABS_MINOR` | 3 | **4** |
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 7 | 7 |
| `OptionsScroll.lua` | `SCROLL_MINOR` | 3 | **4** |
| `Perf.lua` | `MINOR` | 12 | **13** |
| `PerfPanel.lua` | `PANEL_MINOR` | 5 | 5 |

No file is new and none is removed. Every moved minor moves forward, and the copy carries all of
them at once. **No cross-major skew**, before or after. No `NEEDS_*` floor rises (CHANGELOG
v1.56.0, first paragraph).

## 3d. Both diffs

Before the copy:

```sh
diff -rq --strip-trailing-cr <scratch>/tag/LibKa0s libs/LibKa0s
diff -rq                     <scratch>/tag/LibKa0s libs/LibKa0s
diff -rq --strip-trailing-cr <scratch>/tag/testkit tests/_kit
diff -rq                     <scratch>/tag/testkit tests/_kit
```

- Library, content and bytes read the same: the 15 files whose minor moved in 3c differ, and
  every other file is identical.
- Kit, content and bytes read the same: the eight changed files differ, and
  `Only in <tag>/testkit: asserts.lua, mock_events.lua, prose_lists.lua`.
- No `Only in libs/LibKa0s` or `Only in tests/_kit` line: nothing was removed upstream, so the
  copy deletes nothing by name.

After the copy (`rm -rf` both folders, then `cp -r <scratch>/tag/LibKa0s/. libs/LibKa0s/` and
`cp -r <scratch>/tag/testkit/. tests/_kit/`, with `run-automated-tests.sh` kept executable), all
four diffs are **empty**.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

| Major | Lookup site | Minor moved in this range |
|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:39` | 7 -> 8 |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua:41` | no |
| `LibKa0s-Compat-1.0` | `core/Compat.lua:34` | no |
| `LibKa0s-Lifecycle-1.0` | `core/LifecycleSetup.lua:38` | 1 -> 2 |
| `LibKa0s-Launcher-1.0` | `core/LauncherSetup.lua:42` | 1 -> 2 |
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua:49` | 3 -> 4 |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:20` | 12 -> 13 |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua:17` | key 23.30.3.7.3 -> 24.31.4.7.4 |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:113` | 14 -> 15 |

Nine majors consumed, one lookup site each (Compat joined at v1.55.0's C-1, `8c89b31`). Bus and
Schema have no lookup: Bus was declined (#21, `state:will-not-do`), and Schema is WhatGroup#22,
now plan item WG-12. Perf, Widgets, Pool and Item are reached only through the library's own
internal lookups.

## 3f. Kit revision, and the pairing rule

```sh
grep -n 'Kit.VERSION' <scratch>/tag/testkit/framework.lua tests/_kit/framework.lua
```

Tag: `Kit.VERSION = 26` (`framework.lua:20`). Vendored: `25`. **25 -> 26.** Revision 26 is the kit
that ships with v1.56.0 (`docs/api/testkit/version-26-docs.md`), and both payloads move in this one
commit. The revision-11 floor for LibKa0s v1.9.0 and newer is satisfied by construction.

## 3g. Contract delta

The read is the majors whose minor moved (3c) intersected with the majors this addon looks up
(3e): Core, Lifecycle, Launcher, Media, DebugLog, Options and Slash. Each pair of documents was
read at the tag (`git -C ../LibKa0s show v1.56.0:docs/api/<Major>/version-<key>-docs.md`), together
with the v1.56.0 block of the library's `CHANGELOG.md` and its *What a consumer owes on
re-vendoring v1.56.0* section.

```sh
grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit
```

No hits: WhatGroup hands the library no host-supplied member through an `__Attach*` seam, so no
moved call site can reach a member it supplies.

| Major | Old -> new document | What moved under an unchanged surface | Reaches WhatGroup? |
|---|---|---|---|
| Options | `Options/version-23.30.3.7.3-docs.md` -> `Options/version-24.31.4.7.4-docs.md:39-65` | `CreateOptionsPanel` under `InCombatLockdown()` **parks** and replays once at `PLAYER_REGEN_ENABLED`; `OpenOptionsPanel` answers `true`/`false`/`nil` | **Yes: 3 reds**, below |
| Launcher | `Launcher/version-1-docs.md` -> `Launcher/version-2-docs.md:36`, `:154`, `:223` | `lib.STRINGS` drop the `[LibKa0s] ` prefix; `NO_BROKER`/`NO_ICON`/`NO_MINIMAP` print once per instance | No host test asserts the prefix; green |
| Slash | `Slash/version-14-docs.md` -> `Slash/version-15-docs.md` | `CliSet` prints a `false, reason[, why]` refusal instead of echoing; `CliReset` prints `NO_DEFAULT` on exactly `false` | Class A: `settings/Slash.lua:63` passes through to `CliSet`; green |
| Core | `Core/version-7-docs.md` -> `Core/version-8-docs.md` | `printer.Format` pcalls; three new `SafeRegister*` lib-level members | The Core parity pin (`tests/test_surface_parity.lua:66`) compares the live and degraded addon namespaces, not the lib; green |
| DebugLog | `DebugLog/version-12-docs.md` -> `DebugLog/version-13-docs.md` | `#buffer` may read up to 1564 between compactions | No host case writes past 1500; green |
| Lifecycle | `Lifecycle/version-1-docs.md` -> `Lifecycle/version-2-docs.md` | Documentation only (nested-edge order) | No |
| Media | `Media/version-3-docs.md` -> `Media/version-4-docs.md` | `RegisterLSM` passes a langmask and counts what LSM holds | No |

Kit revision 26's behavioral flips (frames start shown, the AceDB fake raises, recorded
`EventRegistry` callbacks, lone-CR counting, store-root prose, `§` in kit case names) produced no
red in this suite. The `§` rename makes `docs/test-cases.md` stale; it is regenerated by a later
item (WG-DOCS), never by this commit.

## Blockers

**One contract change reaches WhatGroup: Options minor 24's combat park.**
`tests/test_panel.lua:106` ("registering during combat still registers"), `:114` ("a login taken
in combat needs no second registration") and `tests/test_lifecycle.lua:413` ("a login taken in
combat still registers the panel") pin the old behavior, that a registration in combat registers at
once. Under minor 24 it parks until combat ends, which the standard permits at v2.65.0
(`options-ui-§5`, `options-ui-§9`: the library MAY park and MUST replay once; the host MUST NOT add
its own park). The library's CHANGELOG names this repo's `tests/test_panel.lua` as a host suite that
must fire the end of combat first.

It is resolved **outside** this commit, by plan decision rather than by the spec's default of fixing
the host beside the payload: the plan fixes every `RV-*` commit as copy-only and assigns this red
to **WG-02** (*Re-pin settings registration in combat to LibKa0s Options' park-and-replay (LK-25)*,
`PLAN_REVIEW_RESOLUTIONS.md`: "WG-02 is not folded into RV-WG"). Nothing needs a decision: the
host's behavior is the library's to own, and only the three test expectations move.

## 3h. Tags vendored and never recorded

```sh
# the spec's 3h listing, run before this commit
grep -vxF -f <scratch>/recorded.txt <scratch>/vendored.txt
```

28 tags: v1.16.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0
v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0
v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2.

The consolidated span bundle is **not** written here. It is plan item **WG-29**, which owns its
tag list and writes it in the WS-01 shape. This listing is the input it starts from.
