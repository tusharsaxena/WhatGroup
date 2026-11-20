# 04 Execution plan

Nothing adopted from the tag. The re-vendor is one commit, SD-RV-WG:

1. Copy both payloads whole from the v1.108.0 extract; both diffs empty before the prune.
2. Roll the provenance line to v1.108.0; keep the `LibKa0s icons:` line.
3. Prune icons and sounds with the tag's `tools/prune-icons.lua`.
4. Fix the 3g blocker: the degraded `NS.ApplySkin` (core/CoreSetup.lua) reads `NS.SKIN_FALLBACK` in place of its own typed table; the case in `tests/test_frame_skin.lua` first.
5. Refresh the standard reference to v2.116.0, read from the local WowAddonStandards checkout on `feat/2026-11-20-libka0s-94-97-99-100`: the vendored quirks block in `docs/midnight-quirks.md` restamped v2.116.0 (`client-quirks.md` is unchanged since v2.115.0, so its text is byte-identical). The TOC `X-Standard`, the README badge and the CLAUDE.md compliance block carry no version and are current; the `§N.M` sweep finds 0 hits.
6. `docs/test-cases.md` regenerated and the README Tests badge rolled to the new count; `docs/ARCHITECTURE.md`'s degraded-path sentence names `NS.SKIN_FALLBACK`.
7. Gate (Retail-only addon, one client): `ka0s-bounded lua tests/run.lua` and `ka0s-bounded luacheck .` (0/0), every authored file under 1500 lines.
