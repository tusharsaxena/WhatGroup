Delta: LibKa0s v1.76.0 -> v1.77.0

# LibKa0s v1.76.0 to v1.77.0: the delta (WhatGroup)

Item WG-RV of the 2026-10-24 run "keybindings (015), settings layout (020), frame strata (030)"
(`Ka0sAddonsCommonTasks/docs/2026-10-24-KEYBINDS_LAYOUT_STRATA/`). It was run per the installed
`/dev-copilot:wow-revendor-libka0s` (2.4.0) with no interview and no issue filing, because the item
spec rules that the adoptions this run needs are WG-KB and WG-ZS and that every other candidate is
recorded as deferred. Copied from the annotated tag `v1.77.0` (tag object `7380d36`, LibKa0s commit
`78240f7`) with `git -C ../LibKa0s archive v1.77.0 LibKa0s testkit tools | tar -x`. The tag is
**local only** (`git -C ../LibKa0s ls-remote --tags origin v1.77.0` prints nothing). It sits on
LibKa0s's `feat/2026-10-24-keybinds-layout-strata` and stays off origin until the owner gives the
go-ahead.

## 3a. The base

```sh
grep -n '[Bb]undles' CLAUDE.md
# 46:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.76.0 (MIT).
git log -1 --format='%h %s' -- libs/LibKa0s tests/_kit
# ec996a4 WG-RV2: re-vendor LibKa0s from the moved v1.76.0 tag (LK-91)
diff -rq <v1.76.0>/LibKa0s libs/LibKa0s     # only the undeclared media/icons entries
diff -rq <v1.76.0>/testkit tests/_kit && echo kit-match
# kit-match
```

The provenance line, the last payload commit and the payload all agree, so the base is **v1.76.0**.
`git -C ../LibKa0s log --oneline v1.76.0..v1.77.0` lists 15 commits (LK-00, LK-01 to LK-04, LK-10
to LK-13, LK-20 and the three LK-90 release commits, plus the v1.76.0 merge). Step 0 for this
addon: the newest earlier single-tag bundle, `2026-10-23-v1.76.0/`, states base v1.75.2, which
matches the provenance line before its re-vendor (`addbbfe`), so there is nothing to correct.

## 3b / 3c. Per-file minors (the tag's `LibKa0s.xml`, 41 files)

| File | old (v1.76.0) | new (v1.77.0) | What moved |
|---|---|---|---|
| `Core.lua` | 11 | 12 | `Core.RaiseStaticPopups()` |
| `DebugLog.lua` | 20 | 21 | the console is toplevel and raises a shown StaticPopup on show |
| `PerfPanel.lua` | `PANEL_MINOR` 8 | 9 | the perf panel is toplevel, same raise |
| `SimPanel.lua` | `SIM_PANEL_MINOR` 5 | 6 | the sim panel is toplevel, same raise |
| `Widgets.lua` | 14 | 15 | the dropdown menu is clamped to the screen |
| `WidgetsDragHandle.lua` | `DRAG_MINOR` 4 | 5 | `spec.level`, `handle:ApplyLevel()`, `spec.ignoreParentAlpha` |
| `WidgetsAutocomplete.lua` | `AUTOCOMPLETE_MINOR` 2 | 3 | the suggestion list is clamped to the screen |
| `Options.lua` | 29 | 30 | attaches OptionsKeybinds at the end of `lib:New` |
| `OptionsIds.lua` | `IDS_MINOR` 2 | 3 | `O.__closeOwnedSuggest` |
| `OptionsCombat.lua` | `COMBAT_MINOR` 1 | 2 | combat start closes the suggestion list too |
| `OptionsCompose.lua` | `COMPOSE_MINOR` 7 | 8 | `O.StrataTooltip` |
| `OptionsKeybinds.lua` | (new) | `KEYBINDS_MINOR` 3 | the key binding model and the Keybindings tab |
| every other file (29) | | unchanged | |

Command: the 3c loop over `git -C ../LibKa0s show v1.77.0:LibKa0s/LibKa0s.xml`, printing only the
rows that differ. The XML lists 41 files, one more than v1.76.0: `OptionsKeybinds.lua` is new, last
in the XML. No consumer file was behind, so there is no cross-major skew.

## 3d. Both diffs

Before the copy, `diff -rq --strip-trailing-cr <tag>/LibKa0s libs/LibKa0s` named the twelve changed
files above and `Only in <tag>/LibKa0s: OptionsKeybinds.lua`, plus the expected
`Only in <tag>/LibKa0s/media/icons` entries (everything this addon does not declare).
`diff -rq <tag>/testkit tests/_kit` named `README.md` and `framework.lua` and three new files,
`bindings_xml.lua`, `mock_bindings.lua` and `mock_layers.lua`. **Nothing was only in the addon**,
so the copy deletes nothing outside the prune.

After `cp -r` of both payloads, and **before the prune**, both content diffs and both byte diffs
were empty (`CONTENT-AND-BYTES-CLEAN`). After the prune, the only remaining difference is the
expected `Only in <tag>/LibKa0s/media/icons` set.

## 3e. Consumption map

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v 'libs/' | grep -v 'tests/'
```

Ten majors, one lookup site each, unchanged from v1.76.0: Core (`core/CoreSetup.lua:39`), Env
(`core/EnvSetup.lua:41`), Compat (`core/Compat.lua:36`), Lifecycle (`core/LifecycleSetup.lua:38`),
Media (`core/MediaSetup.lua:50`), DebugLog (`core/DebugLogSetup.lua:20`), Options
(`settings/OptionsSetup.lua:17`), Schema (`settings/SchemaSetup.lua:236`), Slash
(`settings/Slash.lua:129`) and Launcher (`core/LauncherSetup.lua:42`). Of the majors that moved,
it consumes Core, DebugLog and Options. It does not consume Widgets (declined, #12), Perf or Sim
(WhatGroup#24).

## 3f. Kit revision

```sh
grep -n 'Kit.VERSION =' <tag>/testkit/framework.lua tests/_kit/framework.lua
# <tag>/testkit/framework.lua:20:Kit.VERSION = 42
# tests/_kit/framework.lua:20:Kit.VERSION = 41
```

Kit revision **41 to 42**: the opt-in `mock_bindings.lua` and `mock_layers.lua`, and
`Kit.assertBindingsXml` and `Kit.keybindThroughTab` in `bindings_xml.lua`. Both payloads come from
the one tag in one commit, so the pairing rule holds by construction. Nothing in this addon calls
the new kit surfaces yet; WG-KB installs `mock_bindings.lua` and calls the two asserts, and WG-ZS
installs `mock_layers.lua`.

## 3g. Contract delta

Majors whose minor moved, intersected with the majors this addon consumes: **Core, DebugLog and
Options**. `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
is empty, so no host-supplied member has a moved call site.

### Blockers

One, and it is the one the tag's `CHANGELOG.md` names under *What a consumer owes* (v1.77.0 block,
"Every Options degradation stub gains four instance members"):

- **The Options degradation stub owes `KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED` and
  `StrataTooltip`.** The API document
  `docs/api/Options/version-30.2.34.3.5.9.2.8.4.2.1.3-docs.md` says so for the first three ("Every
  Options degradation stub owes the three members", the K2 paragraph) and for the fourth in the
  CHANGELOG's OptionsCompose minor 8 block. The earlier document,
  `version-29.2.34.2.5.9.1.7.4.2.1-docs.md` (v1.76.0), has none of the four. After the copy,
  `tests/test_surface_parity.lua` ("parity: the Options helpers stub carries the whole live
  surface") went red naming all four. **Fixed in this commit** in `settings/OptionsSetup.lua`'s
  library-absent stub: `KeybindingsTab` and `KeybindRows` answer nil, and `KEYBINDS_UNCHANGED` and
  `StrataTooltip` answer `""`. No panel renders on that path, so the stub carries no copy of the
  library's wording (anti-patterns #47).

One harness ripple, also in this commit:

- **`tests/loader.lua`'s LIBKA0S list gains `libs/LibKa0s/OptionsKeybinds.lua`**, last, where the
  XML has it. Before that, "harness: the explicit LibKa0s list matches LibKa0s.xml, in XML order"
  was red (expected 41 files, got 40). The list's Sim comment now names SimPanel minor 6 as of
  v1.77.0.

The Core and DebugLog changes (toplevel tool windows, `Core.RaiseStaticPopups`) owe a consumer
nothing; the Core stub's parity test stays green.

`Bindings.xml` still has the v2.87.0 shape (`header="WHATGROUP" category="ADDONS"`). Kit 42's
`Kit.assertBindingsXml` is opt-in and nothing here calls it, so no test went red and nothing was
marked pending. WG-KB moves the file to the launcher-§6 shape and adds the assert.

## 3h. Tags vendored and never recorded

```sh
# the standards audit's re-vendor walk (the command's step 3h), run before this copy
grep -vxF -f recorded.txt vendored.txt
# (empty)
```

Every tag this addon vendored has a bundle. No span bundle is written.

## 3i. The icon declaration

Unchanged and kept: `LibKa0s icons: close, copy, clear.`, the next non-blank line under the
provenance line. Its evidence is in `2026-10-22-v1.75.0/01_DELTA.md` 3i. v1.77.0 adds no
library-drawn name (the CHANGELOG's *What a consumer owes* list names none), and the toplevel and
clamp changes draw no new art. Hand lists have drifted before (KickCD `tests/test_mediasetup.lua:28`,
and this repo's own `tests/test_mediasetup.lua:19`), so the owner's in-client smoke stays the
backstop: a pruned icon still resolves to a path and draws blank.

## 3j. Tests that assume the whole icon folder

```sh
grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'
```

The hits are the declaration-driven cases written at v1.75.0. None opens a file for every catalog
name, so nothing is a blocker.
