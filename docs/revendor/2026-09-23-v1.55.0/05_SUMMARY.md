# Summary: LibKa0s v1.54.2 -> v1.55.0

## The tag, and the minors

- **Tag:** v1.54.2 -> v1.55.0, taken from the sibling checkout's local tag with `git archive`.
- **Kit revision:** 24 -> 25.
- **Per-file minors:** every existing file's minor is unchanged. The payload gains three majors at
  minor 1: `Compat.lua`, `Bus.lua` and `Schema.lua`. `LibKa0s.xml` gains their three rows (21
  files). The full table is in `01_DELTA.md` 3c.
- **Re-vendor commit:** `a60a3d6` (Phase 5), with the provenance line in `CLAUDE.md`.

## Delivered free (class A)

Kit revision 25:

- the suite declaration is keyed by (basename, directory);
- the layout-1 cap census gate `test_layout_cap`, 13 cases;
- the `.gitattributes` body case in `test_eol`;
- the commit SHA in the automated-test record.

No library behavior reached an existing seam, because no existing minor moved.

## Contract blockers (3g)

None. No minor moved under a major this addon looks up, and it has no `__Attach*` sites
(`01_DELTA.md` 3g).

## Adopted

- **C-1 `LibKa0s-Compat-1.0`**, `8c89b31` *Read the spell name, icon and cooldown through
  LibKa0s-Compat-1.0*.
  - `NS.Compat.GetSpellName` and `GetSpellTexture` are now the library's members.
  - `GetSpellCooldownRemaining` and `GetSpellCooldownTimes` are built on the library's
    `GetSpellCooldown`. They keep the GCD floor and the two-value truncation.
  - With the library absent, these four take the reader arm.
  - Tests: 12 added (`test_compat` 31 -> 42, `test_surface_parity` 4 -> 5). Five of them are
    characterization cases, written first and green before the move.
  - The runner's surface-source map gains the Compat row.

## Declined

- **C-2 `LibKa0s-Bus-1.0`: never.** Issue #21 (`state:will-not-do`, `severity:low`). The addon has
  no bus (`docs/ARCHITECTURE.md:121-128`, `:457`), and the spec's delta does not name this repo.
- **C-3 `LibKa0s-Schema-1.0`: not now.** Issue #22 (`state:triaged`, `severity:medium`). It was
  attempted once and rolled back. On a library-absent load, the library's `Set` and the prescribed
  stub refuse the rowless `enabled` and `state.testMode` paths, so `/wg enable`, `/wg disable` and
  `/wg test` stop working there. The spec does not name that change. The two characterization
  cases that caught it are kept: `f07743f` *Pin the degraded enable and test-mode verbs' writes*,
  2 tests added.

## Skipped or unreached

None. All three candidates were decided.

## Gates

Every count below is from `ka0s-bounded lua tests/run.lua`, and every lint result from
`ka0s-bounded luacheck .`.

| Point | Tests | Lint |
|---|---|---|
| Start (after `a60a3d6`) | 713 passed, 0 failed, 0 skipped | 0 / 0 in 48 files |
| C-1 characterization written, before the code | 718 passed, 0 failed | not run |
| After C-1 (`8c89b31`) | 725 passed, 0 failed, 0 skipped | 0 / 0 in 48 files |
| C-3 characterization written (`f07743f`) | 727 passed, 0 failed, 0 skipped | 0 / 0 in 48 files |
| C-3 attempt, before rollback | 717 passed, 10 failed, 727 total | not run |
| After rollback, and at the bundle commit | 727 passed, 0 failed, 0 skipped | 0 / 0 in 48 files |

No tool was skipped. `docs/test-cases.md` was regenerated from `lua tests/run.lua --list` at each
commit that changed the inventory.
