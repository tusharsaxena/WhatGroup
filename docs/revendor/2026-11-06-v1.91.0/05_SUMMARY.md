# Summary, LibKa0s v1.90.0 -> v1.91.0

Item `FU-RV-WG` of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/`.

- **Tag:** v1.90.0 -> v1.91.0 (commit `55bfbb4`). The tag is **local**. It is pushed only at the
  finalize, on the owner's go-ahead. The base came from the `CLAUDE.md` provenance line and agrees
  with the last payload commit (`16b2610`, the v1.90.0 refresh). Step 0 was skipped because the
  installed roster regex matches nothing. Its one comparison for this addon, run by hand, reads `ok`,
  so no base correction is owed.
- **Per-file minors:** `Core.lua` 16 -> 17, `SkinPaintExtras.lua` 18 -> 19, `Widgets.lua` 25 -> 26 and
  `WidgetsLineChart.lua` 6 -> 7. There are four new files, `CorePixel.lua` 1, `SkinPaintHud.lua` 1,
  `SkinAceConfirm.lua` 1 and `WidgetsDropdown.lua` 1. Every other file is unchanged. Both sides carry
  kit revision 51 and the kit payload is byte-identical. There is no cross-major skew, and no file was
  removed upstream.
- **The copy:** both payloads were copied whole from a fresh `git archive v1.91.0` extract. All four
  diffs (content and bytes for each payload) were empty before the prune. After it, the only
  difference is the `Only in <scratch>/LibKa0s/media/icons` lines for the undeclared icons.
- **Span bundle:** none, because 3h printed nothing.
- **Delivered for free (class A):** the line chart's lines in physical pixels (WidgetsLineChart 7),
  and the four pure-move peels. This addon draws no line chart, so it shows nothing different on
  screen.
- **Contract blockers:** none (01_DELTA 3g). The addon hands the library no `__Attach*` members, and
  no stub mirrors a moved member.
- **Harness blockers, fixed in the re-vendor commit:** `tests/loader.lua` lists the four new files in
  the tag's `LibKa0s.xml` order, and the MODULES case in `tests/test_libka0s.lua` names `CorePixel`,
  `SkinPaintHud` and `SkinAceConfirm`. No test pinned an exact minor.
- **Icons:** the `LibKa0s icons:` line was kept unchanged (12 names, all Open Iconic). It still sits
  directly under the provenance line. The prune printed `12 icon(s) declared; kept 13 file(s),
  removed 5827`, the same subset as at v1.90.0. No provenance split was needed.
- **README credits:** unchanged, since Open Iconic is still the only set shipped.
- **Dead stub mirrors:** none.
- **Adopted:** nothing.
- **Declined:** nothing, and no issue was filed.
- **Unreached or undecided:** none.
- **Gate** (through `~/.claude/dev-copilot/bin/ka0s-bounded`): `luacheck .` reports 0 warnings / 0
  errors in 77 files. `.luacheckrc` excludes `libs/` and `tests/_kit/`, and the changed seam,
  `tests/loader.lua`, is inside the checked set. `lua tests/run.lua` reports 1100 passed, 0 failed, 1
  skipped (the standing diagnostics opt-out case), 1101 total. No Lua file of the addon's own is above
  the 1500-line cap (`tests/test_libka0s.lua` 1073). No function changed, so complexity is unchanged.
