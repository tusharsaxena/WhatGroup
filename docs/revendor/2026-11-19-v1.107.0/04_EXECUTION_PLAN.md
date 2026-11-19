# 04 Execution plan

Nothing adopted from the tag. The re-vendor is one commit, AF-RV-WG:

1. Copy both payloads whole from the v1.107.0 extract; both diffs empty before the prune.
2. Roll the provenance line to v1.107.0; keep the `LibKa0s icons:` line.
3. Prune icons and sounds with the tag's `tools/prune-icons.lua`.
4. Refresh the standard reference to v2.115.0 in the same item: the vendored quirks block in `docs/midnight-quirks.md` replaced whole (it was v2.103.1), and the one live DPS Race mention, smoke check SKIN-38 in `docs/smoke-tests.md`, names Combat Trail's race HUD. The TOC `X-Standard`, the README badge and the CLAUDE.md compliance block carry no version and were already current.
5. `docs/test-cases.md` checked in lockstep (unchanged, 1127 passing); the README Tests badge already reads 1127.
6. Gate (Retail-only addon, one client): `ka0s-bounded lua tests/run.lua` and `ka0s-bounded luacheck .` (0/0), every authored file under 1500 lines.
