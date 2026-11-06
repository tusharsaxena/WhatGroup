Delta: LibKa0s v1.90.0 -> v1.91.0

Item `FU-RV-WG` of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/` (`00_PLAN.md`, items 1
and 2: the line chart's lines in physical pixels, and the four band files peeled). The tag is
**local** to `../LibKa0s` and not pushed (`git -C ../LibKa0s ls-remote --tags origin v1.91.0` prints
nothing; commit `55bfbb4`), so this is a new tag, not a refresh. Extracted with
`git -C ../LibKa0s archive v1.91.0 LibKa0s testkit tools | tar -x -C <scratch>`. The reads below were
taken before the copy.

**Step 0 was skipped** for this run. The installed skill's roster regex expects markdown links, and
ADDONS.md writes `` `../../<Folder>/` ``, so it matches nothing (dev-copilot `FU-DC1` fixes it). The
one comparison it would make for this addon was run by hand with a named-variable `tag_at`: the
newest single-tag bundle `2026-11-06-v1.90.0` states base v1.89.0, and the provenance at `1cc2a40^`
(SF1-RV-WG, the commit that vendored v1.90.0) is v1.89.0. Result `ok`, so no base correction is owed.

## 3a. Claimed version, and the base

`grep -n '[Bb]undles' CLAUDE.md`:

    48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.90.0 (MIT).

`git log -1 --format=%H -- libs/LibKa0s tests/_kit` returns `16b2610` (SF2-RV-WG, the v1.90.0
refresh), and its CLAUDE.md names v1.90.0. `git log --format='%h %s' 16b2610..HEAD -- CLAUDE.md`
lists nothing. A `git archive v1.90.0 LibKa0s testkit` extract matches the vendored payload apart from
the undeclared icons (`diff -rq`), and the kit matches byte for byte. The base is **v1.90.0**.

`git -C ../LibKa0s log --oneline v1.90.0..v1.91.0` lists 9 commits. Seven are this release: `55d3b0f`
FU-L1 (line chart), `d72dc4a`, `c1ed261`, `acc9640` and `3f7be30` FU-L2 (the four peels), and
`1938837` and `55bfbb4` FU-L3 (the release). The other two are the v1.90.0 merge (`f4be157`) and its
sync-docs (`06d97b0`). `git -C ../LibKa0s diff --stat v1.90.0 v1.91.0 -- LibKa0s testkit` shows 9
files under `LibKa0s/` and none under `testkit/`.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reads every file
at its v1.90.0 minor (Core 16, SkinPaintExtras 18, Widgets 25, WidgetsLineChart 6). The line and the
bytes agree.

## 3c. Per-file minor delta (the loop over the tag's `LibKa0s/LibKa0s.xml`)

| File | Old | New |
|---|---|---|
| `Core.lua` | 16 | **17** |
| `CorePixel.lua` | (new) | **1** (`PIXEL_MINOR`) |
| `SkinPaintExtras.lua` | 18 | **19** |
| `SkinPaintHud.lua` | (new) | **1** (`HUD_MINOR`) |
| `SkinAceConfirm.lua` | (new) | **1** (`CONFIRM_MINOR`) |
| `Widgets.lua` | 25 | **26** |
| `WidgetsDropdown.lua` | (new) | **1** (`DROPDOWN_MINOR`) |
| `WidgetsLineChart.lua` | 6 | **7** |

Every other file is unchanged. Four files are new (each loads right after the file it was peeled
from), and none was removed. There is no cross-major skew.

## 3d. Diffs before the copy

`diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` (content) lists `Core.lua`,
`LibKa0s.xml`, `SkinPaintExtras.lua`, `Widgets.lua` and `WidgetsLineChart.lua` as differing, the four
new files as `Only in <scratch>/LibKa0s`, and `Only in <scratch>/LibKa0s/media/icons` for the
undeclared icons (that is the declaration working). There is no `Only in libs/LibKa0s` line and no
`differ` under `media/icons`. The byte diff lists the same paths, so there is no line-ending drift.

`diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit` and the byte diff are both empty.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Core (`core/CoreSetup.lua:46`), Launcher (`core/LauncherSetup.lua:42`), DebugLog
(`core/DebugLogSetup.lua:20`), Env (`core/EnvSetup.lua:41`), Skin (`core/SkinSetup.lua:79`),
Lifecycle (`core/LifecycleSetup.lua:38`), Compat (`core/Compat.lua:36`), Media
(`core/MediaSetup.lua:50`), Schema (`settings/SchemaSetup.lua:236`), Slash (`settings/Slash.lua:134`)
and Options (`settings/OptionsSetup.lua:17`). This is unchanged from v1.90.0, and there is still no
Widgets lookup.

## 3f. Kit revision

`grep -n 'Kit.VERSION'` reads 51 in both the tag's `testkit/framework.lua:20` and
`tests/_kit/framework.lua:20`. The kit does not move in this range. Both payloads are still copied
whole, so the pairing rule (kit 11+ with v1.9.0+) holds by construction.

## 3g. Contract delta

The majors that moved are Core (17.1), Skin (SkinPaintExtras 19, plus SkinPaintHud 1 and
SkinAceConfirm 1) and Widgets (26, WidgetsDropdown 1, WidgetsLineChart 7). This addon looks up Core
and Skin. It does not look up Widgets.

`diff <(git show v1.90.0:docs/api/<M>/<old>) <(git show v1.91.0:docs/api/<M>/<new>)` for each:

- **Core** (`docs/api/Core/version-16-docs.md` -> `version-17.1-docs.md`): "A pure move ... no public
  or internal member and no behavior changes, so `members-17.1.json` lists the same names as version
  16." The moved members (`__PixelSize`, `__OnPixelScale`, `__WatchPixels`, `__PixelBackdrop`,
  `__RefreshPixelBackdrops`) are internal, and this addon's library-absent Core stub mirrors none of
  them (`grep -rn '__PixelSize\|__WatchPixels\|__OnPixelScale\|__PixelBackdrop' . --include='*.lua'
  --exclude-dir=libs --exclude-dir=_kit` prints nothing).
- **Skin** (`version-17.1.27.8.19.18.17.4.9-docs.md` -> `version-17.1.27.8.19.19.1.1.17.4.9-docs.md`):
  "A pure move ... no member of the major or of a facade and no behavior changes". `S.BarGloss` and
  `S.HudFont` move to `SkinPaintHud.lua`, and the AceConfigDialog confirmation box moves to
  `SkinAceConfirm.lua`.
- **Widgets** (`version-25.6.13.6.8.5-docs.md` -> `version-26.1.6.13.7.8.5-docs.md`): the dropdown
  peel is "a pure move ... no public member, option or behavior changes". The line chart's lines become
  physical pixels: "What a host owes: nothing." The one changed sentence under an existing surface is
  the `series[i].thickness` row, which now reads physical pixels. This addon draws no line chart.

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit`
finds no site.

**Blockers:** none in the contract sense. The four new payload files are a test-harness blocker. Each
one was fixed in the re-vendor commit:

- `tests/loader.lua`'s `LIBKA0S` list (the XML-order list that `tests/test_harness.lua:51` checks
  against `LibKa0s.xml`) adds `CorePixel.lua` after `Core.lua`, `SkinPaintHud.lua` and
  `SkinAceConfirm.lua` after `SkinPaintExtras.lua`, and `WidgetsDropdown.lua` after `Widgets.lua`, in
  the tag's XML order. `tests/test_surface_parity.lua` derives its skip list from the loader, so it
  follows automatically.
- `tests/test_libka0s.lua`'s MODULES case names `CorePixel` under Core and `SkinPaintHud` and
  `SkinAceConfirm` under Skin, so the per-file list keeps matching what the client loads.

The hand-written degraded skip lists (`tests/test_libka0s.lua:554`, `tests/test_envsetup.lua:19`,
`tests/test_mediasetup.lua:41`) skip `Core.lua`. Every new file returns before attaching when its shell
is absent (`CorePixel.lua:16-17`, `SkinPaintHud.lua:16-18`, `SkinAceConfirm.lua:15-17`,
`WidgetsDropdown.lua:22-27`), as `WidgetsReorder.lua` and the other secondary files already omitted
there do. No change is owed there. Test pins: no test pins an exact LibKa0s minor, so no pin moves.

## 3h. Span check

This uses the audit walk plus the provenance-roll walk from the store's horizon (2026-08-25), run with
a named-variable `tag_at` (the installed text's `"$1"` arrives substituted). The output of
`grep -vxF -f recorded.txt vendored.txt` is empty, so no span bundle is owed.

## 3i. The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md`:

    49:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.

It is the next non-blank line after the provenance line, so no split is owed. **Kept as is**, decided
by the run with no re-ask: v1.91.0 adds no library-drawn icon name (CHANGELOG v1.91.0). Hand lists
have drifted before (KickCD `tests/test_mediasetup.lua:28`, this addon's own
`tests/test_mediasetup.lua:19`), so the owner's in-client smoke is the backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'` finds
`tests/test_mediasetup.lua:128,141,167-176,189,261`. These were narrowed to the declaration at the
v1.75.0 re-vendor, and neither the declaration nor the catalog changes in this range, so there is no
blocker.

Dead stub mirrors: `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
prints nothing.
