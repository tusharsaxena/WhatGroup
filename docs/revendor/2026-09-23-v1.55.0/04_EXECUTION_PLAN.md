# Execution plan: LibKa0s v1.55.0 adoption

Written before any addon Lua was touched (`revendor-libka0s.md` Step 7). The fences all hold:
`libs/` and `tests/_kit/` are read-only, setup files hold a descriptor or wiring plus a degradation
arm, no behavior change hides in a mechanical diff, and nothing here builds a close control.

Gate for every commit: `ka0s-bounded lua tests/run.lua` and `ka0s-bounded luacheck .` both green.
`.luacheckrc` excludes `libs/` and `tests/_kit/`, and every file an adoption touches is in the
checked set.

## C-1 `LibKa0s-Compat-1.0` (adopt)

- **Files.** `core/Compat.lua` (the four spell-reader bodies), `tests/run.lua` (the surface-source
  map's Compat row), `tests/test_compat.lua`, `tests/test_surface_parity.lua`, `tests/loader.lua`
  (a comment), and docs: `docs/ARCHITECTURE.md` (the module arrows, `## External dependencies`,
  load-order item 6, `## Known Limitations`), `docs/compat-layer.md`, `docs/module-map.md`,
  `docs/frame.md`, `docs/testing.md`, `CLAUDE.md`, `docs/test-cases.md`, the `README.md` badge.
- **Characterization, written first and green against the host's ladders.**
  - `GetSpellCooldownTimes` hands `SetCooldown` exactly two values on every rung: modern, nil
    table, legacy (with a four-value global), legacy nil, and no rung at all. **Arity is the
    assertion**, because `SetCooldown`'s third parameter is `modRate`.
  - A legacy `isEnabled` of `0` reads disabled, `1` and nil read enabled.
  - A modern table with no `isEnabled` reads enabled.
  - A table with no start or duration answers `0`.
  - The popup's numeric teleport ids get the same name and icon.
- **What proves the change.** The five cases above stay green after the move. New cases then pin
  what the library changed on purpose: identity with the library's members, a `""` falling
  through, the middle rung, one texture value, no client call for a non-spell id, and the
  degraded reader arm (the library's files skipped, never the member stubbed). A parity case
  holds `NS.Compat` to `LibKa0s-Compat-1.0`'s member set, ignoring the seven members this addon
  does not wire, each with its reason.
- **Mutation check.** The parity, arity, domain and degraded cases were each seen red against a
  wrong implementation (a three-value `GetSpellCooldownTimes`, and a reader arm missing
  `GetSpellTexture`).
- **Commit boundary.** One commit: code, tests, docs.

## C-3 `LibKa0s-Schema-1.0` (attempt, then decide)

- **Files the spec names.** `settings/Schema.lua:276-754` (the seam), `settings/Panel.lua:283-296`
  (stamp the session and global rows' `get`/`set`, and `S.AddRows(MASTER_ROWS, 1)` for the head
  splice), `settings/OptionsSetup.lua:194-219` and `settings/Slash.lua:232-236` (descriptor
  bindings).
- **Characterization, written first and green.** The spec does not name one path the adoption
  moves: the degraded host verbs `/wg enable`, `/wg disable` and `/wg test` write `enabled` and
  `state.testMode`, which have no row on a library-absent load. Two cases in
  `tests/test_libka0s.lua` pin that those writes land.
- **What would prove the change.** Those two cases, the existing `tests/test_settings.lua` seam
  cases (re-pinned where the spec sanctions a change), and the degraded suite.
- **Rollback boundary.** If the attempt goes red on anything the spec does not sanction, roll
  `settings/` back to `8c89b31` and keep the characterization cases as their own commit.
- **Outcome.** Red on exactly the two unsanctioned cases, so it was rolled back. See
  `03_DECISIONS.md`.

## C-2 `LibKa0s-Bus-1.0` (never)

No code. The decline is issue #21.
