Delta: LibKa0s v1.89.0 -> v1.90.0

Item `SF1-RV-WG` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (the owner's first
smoke feedback, `SF1_SMOKE_FEEDBACK.md`). The tag is **local** to `../LibKa0s` and not pushed (commit
`4485b8f`), so `git ls-remote` shows nothing; this is a new tag, not a refresh. Extracted with
`git -C ../LibKa0s archive v1.90.0 LibKa0s testkit tools | tar -x -C <scratch>`. Written before the copy.

## 3a. Claimed version, and the base

`grep -n '[Bb]undles' CLAUDE.md`:

    48:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.89.0 (MIT).

The last commit touching either payload, `git log -1 --format=%H -- libs/LibKa0s tests/_kit`, is
`af671b3` (V89-WG: Re-vendor LibKa0s v1.89.0), and its CLAUDE.md names v1.89.0. No `CLAUDE.md` commit
since. The base is **v1.89.0**.

Step 0 for this addon: the newest single-tag bundle `2026-11-06-v1.89.0` states base v1.85.0, and the
provenance at `af671b3^` is v1.85.0: `ok`. No base correction.

`git -C ../LibKa0s log --oneline v1.89.0..v1.90.0`: 7 commits, of which four are this release
(`7d42f4e` SF1-L1 pixel edges, `b9f7651` SF1-L2 keepScope, `4ac9f3c` and `4485b8f` SF1-L3 release) and
three are the v1.89.0 merge and its harvest/sync-docs. `git -C ../LibKa0s diff --stat v1.89.0 v1.90.0 --
LibKa0s testkit`: 7 files under `LibKa0s/`, none under `testkit/`.

## 3b. Actual version

`grep -hoE 'local (MAJOR, )?[A-Z_]*MINOR *= *("[^"]+", *)?[0-9]+' libs/LibKa0s/*.lua` reads every file at
its v1.89.0 minor (Core 15, Skin 16, SkinPaint 18, SkinPaintExtras 17, Widgets 23, WidgetsAutocomplete
7, OptionsAppearance 6). Line and bytes agree.

## 3c. Per-file minor delta (the tag's `LibKa0s/LibKa0s.xml` loop)

| File | Old | New |
|---|---|---|
| `Core.lua` | 15 | **16** |
| `Skin.lua` | 16 | **17** |
| `SkinPaint.lua` | 18 | **19** |
| `SkinPaintExtras.lua` | 17 | **18** |
| `Widgets.lua` | 23 | **24** |
| `WidgetsAutocomplete.lua` | 7 | **8** |
| `OptionsAppearance.lua` | 6 | **7** |

Every other file is unchanged, and no file is new or removed (`LibKa0s.xml` itself is byte-identical).
No cross-major skew.

## 3d. Diffs before the copy

`diff -rq --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s` (content): the seven files above differ;
`Only in <scratch>/LibKa0s/media/icons` for the undeclared icons (the declaration working). No
`Only in libs/LibKa0s`, no `differ` under `media/icons`. The byte diff lists the same paths and nothing
else, so no line-ending drift.

`diff -rq --strip-trailing-cr <scratch>/testkit tests/_kit` and the byte diff: empty.

## 3e. Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Launcher (`core/LauncherSetup.lua:42`), Core (`core/CoreSetup.lua:46`), Env (`core/EnvSetup.lua:41`),
Media (`core/MediaSetup.lua:50`), Compat (`core/Compat.lua:36`), Skin (`core/SkinSetup.lua:79`),
Lifecycle (`core/LifecycleSetup.lua:38`), DebugLog (`core/DebugLogSetup.lua:20`), Options
(`settings/OptionsSetup.lua:17`), Slash (`settings/Slash.lua:134`), Schema (`settings/SchemaSetup.lua:236`).
Unchanged from v1.89.0. No Widgets lookup.

## 3f. Kit revision

`grep -n 'Kit.VERSION'`: tag `testkit/framework.lua:20` and `tests/_kit/framework.lua:20` both read 51.
The kit does not move in this range; both payloads are still copied whole, which keeps the pairing rule
(kit 11+ with v1.9.0+) by construction.

## 3g. Contract delta

Moved majors intersected with consumed ones: Core (16), Skin (17, with SkinPaint 19 and SkinPaintExtras
18) and Options (OptionsAppearance 7). Widgets 24 is not looked up by the host.

- **Core 16** (tag `CHANGELOG.md`, v1.90.0, "Core minor 16"; `docs/api/Core/version-16-docs.md`): the new
  pixel-edge members are all internal (`__PixelSize`, `__WatchPixels`, `__OnPixelScale`,
  `__PixelBackdrop`), "so no member manifest moves". The host's library-absent Core stub owes nothing.
- **Skin 17** (`docs/api/Skin/version-17.1.27.8.19.18.17.4.9-docs.md`): `RegisterOwner(owner, { keepScope
  = true })` is an optional field; an owner that omits it registers as before. This addon's registration
  (`core/SkinSetup.lua:550`) omits it, and the run assigns `keepScope` to the Skin Tester alone (`SF1-ST`).
- **OptionsAppearance 7**: `lib.__copySkinTo` skips Scope only for a `keepScope` target; every other
  target, this addon included, takes the Scope as before.

The tag's `docs/releasing.md:267-269` states that v1.90.0 adds no Skin facade, major or instance member,
and its CHANGELOG release block says "No host owes a facade or stub member".

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=Libs --exclude-dir=_kit`:
no site.

**Blockers:** none found by this read.

## 3h. Span check

The audit walk plus the provenance-roll walk from the store's horizon (2026-08-25): 64 tags vendored,
64 recorded, `grep -vxF -f recorded.txt vendored.txt` prints nothing. No span bundle.

## 3i. The icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md`:

    49:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, info, move, reset, settings, volume-high.

The next non-blank line after the provenance line; no split owed. **Kept as is (decided by the run, no
re-ask).** v1.90.0 adds no library-drawn icon name. Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, this addon's own `tests/test_mediasetup.lua:19`); the owner's in-client
smoke is the backstop.

## 3j. Tests that assume the whole icon folder

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`:
`tests/test_mediasetup.lua:128,141,167-176,189,261`. Narrowed to the declaration at the v1.75.0
re-vendor; the declaration and the catalog are unchanged in this range, so no blocker.

Dead stub mirrors: `grep -rn '__releaseChrome' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
prints nothing.
