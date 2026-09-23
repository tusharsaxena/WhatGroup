# Candidates: LibKa0s v1.54.2 -> v1.55.0

Written 2026-09-23 (`revendor-libka0s.md` Step 5). The owner delegated the interview (CP-6), so
the decision rules in the Phase 6 brief replace Step 6's questions. Each decision is recorded in
`03_DECISIONS.md` as it lands.

## Sources read

In the order Step 5 prescribes, never from memory:

1. `git -C ../LibKa0s log --oneline v1.54.2..v1.55.0`, and the `CHANGELOG.md` block `## v1.55.0`
   (`git -C ../LibKa0s show v1.55.0:CHANGELOG.md`). That block names three new majors (Compat 1,
   Bus 1, Schema 1) and kit revision 25, and says: "No existing `.lua` file in the library
   changes -- every existing major's version key and every existing file's LibStub minor are
   exactly v1.54.2's."
2. `Since` markers: none apply. `01_DELTA.md` 3c shows no minor moved under any major this addon
   looks up, so no existing API document has a newer version to diff.
3. The three design specs' per-consumer deltas, which name this repo by `file:line`:
   `Ka0sAddonsCommonTasks/docs/2026-09-22-SUITE_STANDARDS_AND_LIBKA0S_SWEEP/3b-specs/compat.md`
   section 8.6 (and 8.0, the common block), `bus.md` section 12, `schema.md` section 11
   (WhatGroup, and the common block).
4. The API documents: `LibKa0s/docs/api/{Compat,Bus,Schema}/version-1-docs.md`.
5. This repo's own recorded declines: `gh issue list --search "LibKa0s" --state all` (#7, #9 to #14)
   and `docs/ARCHITECTURE.md`. None covers Compat, Bus or Schema.

## Class A: delivered by the re-vendor alone (recorded, not offered)

- **Kit revision 25**: the (basename, directory) suite key, the layout-1 cap census gate
  (`tests/_kit/test_layout_cap.lua`), the `.gitattributes` body case in `test_eol`, and the
  commit SHA in the automated-test record. Wired in Phase 5 (`a60a3d6`).
- Nothing else. No existing file's minor moved, so no fix reached an existing seam.

## Class B: host change under a major already consumed

None. The eight majors this addon looks up (Core, Env, Lifecycle, Media, DebugLog, Launcher,
Options, Slash) carry v1.54.2's minors unchanged, so they have no new descriptor field, member or
row type.

## Class C: whole-module adoption

### C-1 `LibKa0s-Compat-1.0`: four spell readers onto the library

- **What.** `NS.Compat.GetSpellName` and `GetSpellTexture` become the library's members. The two
  cooldown shims keep their names and bodies' policy but read `startTime, duration, isEnabled`
  from the library's `GetSpellCooldown`.
- **Evidence.** `compat.md` 8.6. Library: `libs/LibKa0s/Compat.lua` (`lib.GetSpellName`,
  `lib.GetSpellTexture`, `lib.GetSpellCooldown`). API document `docs/api/Compat/version-1-docs.md`
  "How a host wires it" (reader arm) and "Adopting it" (the table-map row for WhatGroup).
- **Touches.** `core/Compat.lua:25-51` (`GetSpellName`, `GetSpellTexture`), `:94-111`
  (`GetSpellCooldownRemaining`), `:116-127` (`GetSpellCooldownTimes`); `tests/run.lua:66` (the
  surface-source map gains the Compat row); `tests/test_compat.lua`,
  `tests/test_surface_parity.lua`; docs.
- **Stays host.** `GetSpellLink`, `IsSpellKnown`, `GetActivityInfoTable`, `AddOnLinkType`
  (single-consumer or a correctness disagreement, `compat.md` 5.1 and 5.3), and the GCD floor in
  `GetSpellCooldownRemaining` (5.1).
- **Behavior deltas the spec names.** A non-number, non-string id answers nil without calling the
  client (was: the client called with it); a plain `""` from `C_Spell.GetSpellName` falls through
  to the next rung; a middle rung (`C_Spell.GetSpellInfo(id).name`) is added; `GetSpellTexture`
  drops the client's second return. On a library-absent load the reader arm answers the
  documented absent values (nil, nil, `0, 0`, and so `0` remaining) where the host's own ladder
  answered from the client.
- **Recommendation: adopt.** The spec prescribes it for this repo, the host keeps every seam name,
  and every live-path answer the addon renders stays the same for every id it actually passes
  (a number from `defaults/TeleportSpells.lua`).
- **Blast radius: replaces host code.** Four function bodies are replaced by delegations; nothing
  is deleted from the call surface.

### C-2 `LibKa0s-Bus-1.0`: the stand-down record and message catalog

- **What.** `Bus:New{...}` tracked targets and `Bus.Catalog` for `NS.MSG`.
- **Evidence.** `bus.md` section 12 names nine repos and not this one (`grep -n WhatGroup bus.md`
  answers nothing). This repo's own record: `docs/ARCHITECTURE.md:121-128` ("There is none,
  because WhatGroup is a single-addon capture pipeline"; `grep -rn "SendMessage\|RegisterMessage"
  core modules settings defaults` returns nothing) and `:457` (`message-bus.md` not applicable).
- **Recommendation: never.** There is no bus, no receiver to track and no message to catalog, so
  the major has nothing to wrap. This is the structural misfit the repo's own docs record.
- **Blast radius:** none (no code).

### C-3 `LibKa0s-Schema-1.0`: the settings seam onto the library instance

- **What.** `settings/Schema.lua`'s `Resolve`, `SESSION` and `GLOBAL` registries, `Helpers.Get` /
  `RawSet` / `Set` / `FindSchema`, the bulk bracket, `ValidateSchema`, the reset count and
  `ApplyDefault` become a `lib:New{ rows = Schema, resolveRoot, announce, ... }` instance, with a
  write-completing, log-silent host stub for the library-absent load.
- **Evidence.** `schema.md` section 11 "WhatGroup -- seam adopter" (`settings/Schema.lua:288-305`,
  `:328-386`, `:388-419`, `:435-527`, `:544-577`, `:665-732`, `:751-754`;
  `settings/Panel.lua:283-296`; `settings/OptionsSetup.lua:194-219`; `settings/Slash.lua:232-236`).
  API document `docs/api/Schema/version-1-docs.md` "Adoption notes" and "The degradation stub".
- **Behavior deltas the spec names.** An unknown path is refused, not stored (JC-2); the `pcall`
  around `onChange` goes, so a raising reaction propagates (JC-3, pinned today by
  `tests/test_settings.lua:325-335`; JC-2 is pinned by `:337-341`); a table value is copied into the store (JC-6); the reset's
  session sweep runs the session rows' `onChange` and refresh it used to skip.
- **Recommendation: attempt, then decide.** The spec prescribes it and does not mark this repo as
  one that MAY defer. The risk the spec does not measure: on a library-absent load the Master
  controls rows are not composed (the hollow composer, `options-ui-§1`), so `enabled` and
  `state.testMode` have no row, and the host verbs `/wg enable`, `/wg disable` and `/wg test`
  write those paths through `Helpers.Set` (`settings/Slash.lua:286`, `:288`, `:354`). Under JC-2
  those writes are refused. That is a degraded-path behavior change a player would see
  (`slash-commands-§1` keeps host verbs working), and the spec does not list it.
- **Blast radius: replaces host code.** About 480 lines of `settings/Schema.lua` move onto the
  library or into a host stub, and three descriptor bindings move.

## Order (rule 4)

No candidate fixes a live defect or closes a recorded gap in this repo. All three are new
capability, so the order is smallest blast radius first: C-2 (no code), C-1 (four bodies), C-3
(the settings seam).
