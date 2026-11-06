# Summary, LibKa0s v1.89.0 -> v1.90.0

Item `SF1-RV-WG` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (from
`SF1_SMOKE_FEEDBACK.md`).

- **Tag:** v1.89.0 -> v1.90.0 (commit `4485b8f`). The tag is **local** and gets pushed only when the
  owner gives the go-ahead. The base came from the `CLAUDE.md` provenance line and agrees with the
  last payload commit (`af671b3`). Step 0 reads `ok`, so no base correction is owed.
- **Per-file minors:** `Core.lua` 15 -> 16, `Skin.lua` 16 -> 17, `SkinPaint.lua` 18 -> 19,
  `SkinPaintExtras.lua` 17 -> 18, `Widgets.lua` 23 -> 24, `WidgetsAutocomplete.lua` 7 -> 8,
  `OptionsAppearance.lua` 6 -> 7. Every other file is unchanged. Both sides carry kit revision 51
  and the kit payload is byte-identical. There is no cross-major skew and no file was removed
  upstream.
- **The copy:** both payloads were copied whole from a fresh `git archive v1.90.0` extract. All four
  diffs (content and bytes for each payload) were empty before the prune. After it, the only
  difference is the `Only in <scratch>/LibKa0s/media/icons` lines for the undeclared icons.
- **Span bundle:** none, because 3h printed nothing.
- **Delivered for free (class A):** library edges are one physical pixel at any UI scale (Core 16),
  and a skin copy from this addon leaves a `keepScope` owner's Scope alone (Skin 17,
  OptionsAppearance 7).
- **Contract blockers:** none (01_DELTA 3g). The addon hands the library no `__Attach*` members.
- **Icons:** the `LibKa0s icons:` line was kept unchanged (12 names, all Open Iconic) and still sits
  directly under the provenance line. The prune printed `12 icon(s) declared; kept 13 file(s),
  removed 5827`, which is 212 Open Iconic files, the whole Phosphor set (1435 files) and the whole
  Game-icons set (4180 files): the same subset as at v1.89.0. No provenance split was needed.
- **README credits:** unchanged, since Open Iconic is still the only set shipped.
- **Dead stub mirrors:** none.
- **Adopted:** nothing. `keepScope` is for the Skin Tester alone (`SF1-ST`).
- **Declined:** nothing, and no issue was filed.
- **Unreached or undecided:** none.
- **Column-header check (SF1 item 5):** WhatGroup draws no column-header row, so there is no divider
  line to remove (02_CANDIDATES, `modules/FrameLayout.lua:31-33`, `:73-83`; `core/SkinSetup.lua:456`,
  `:458`). No `SF1-WG-HDR` change is owed.
- **Gate:** `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` printed `0 warnings / 0 errors in 77
  files`. `.luacheckrc` excludes `libs/` and `tests/_kit/`, and the addon's own seams are inside the
  checked set. `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` printed `1100 passed,
  0 failed, 1 skipped, 1101 total`, with the vendor-sync cases passing at v1.90.0. The largest file
  the addon owns is `modules/Frame.lua` at 1256 lines, under the 1500-line cap. The commit changes
  none of the addon's own Lua.
