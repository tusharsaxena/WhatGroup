# Decisions: LibKa0s v1.55.0 candidates

The owner delegated the interview to the Phase 6 agent (CP-6). The rules applied:

1. **Adopt** what the spec prescribes for this repo, one major per commit, characterization test
   first, the degraded case added, the surface-source map and parity case updated where the spec
   says.
2. **Not now** (`state:triaged`) where the spec says the repo MAY defer, or where the adoption
   cannot land green without changing behavior a test pins or a player would see, after one honest
   attempt rolled back to its commit boundary. **Never** (`state:will-not-do`) only for a
   structural misfit the spec or this repo's docs record.
3. Each decline is a GitHub issue in this repo with one `state:` and one `severity:` label.

Written as each decision landed, in the order of `02_CANDIDATES.md`.

## C-2 `LibKa0s-Bus-1.0`: never

- **Decision:** never (`state:will-not-do`, `severity:low`).
- **Reason.** A structural misfit this repo's own docs record. There is no message bus to put a
  record under: `docs/ARCHITECTURE.md:121-128` ("There is none, because WhatGroup is a single-addon
  capture pipeline"), `:457` (`message-bus.md` not applicable), and
  `grep -rn "SendMessage\|RegisterMessage" core modules settings defaults` returns nothing. The
  spec's per-consumer delta (`bus.md` section 12) does not name this repo.
- **Issue:** https://github.com/tusharsaxena/WhatGroup/issues/21
- **Reopen when:** a second consumer of join data appears and the addon starts publishing
  messages (`docs/ARCHITECTURE.md:127-128`).

## C-1 `LibKa0s-Compat-1.0`: adopt

- **Decision:** adopt.
- **Reason.** The spec prescribes it for this repo (`compat.md` 8.6) and does not mark it optional.
  It lands green with every live-path answer the addon renders unchanged: the characterization
  cases (the two-value cooldown pair on every rung, the legacy `isEnabled` readings, a missing
  `isEnabled`, a table with no start or duration, the teleport ids the popup passes) were written
  first and passed against the host's own ladders, then passed unchanged after the move. The
  behavior that did change is what the spec names (a plain `""` falls through, the middle rung, one
  texture value, no client call for a non-spell id, the reader arm on a library-absent load), and
  none of it reaches a number id from `defaults/TeleportSpells.lua` on a loaded library.
- **Commit:** `8c89b31` Read the spell name, icon and cooldown through LibKa0s-Compat-1.0.

## C-3 `LibKa0s-Schema-1.0`: not now

- **Decision:** not now (`state:triaged`, `severity:medium`, a deferred duplication).
- **Reason.** One honest attempt was made and rolled back to its commit boundary. The adoption
  cannot land green without changing behavior a player would see, and the spec does not name
  that change. On a library-absent load the Master controls rows are not composed (the hollow
  composer, `options-ui-§1`), so `enabled` and `state.testMode` have no row. The host verbs write
  them through `Helpers.Set` (`settings/Slash.lua:286`, `:288`, `:354`). The library's `Set` and
  the prescribed runtime-completing stub both refuse a path with no row (JC-2). So after adoption,
  `/wg disable` and `/wg test` do nothing on a degraded install, which `slash-commands-§1` forbids.
  Every fix is a decision rather than an edit, and each is a deviation or an upstream change (see
  the issue). The standard does not require adoption (`library-stack-§7`, v2.64.0), so deferring
  it is compliant.
- **Evidence.** Two characterization cases were written first and passed against the current seam
  (`tests/test_libka0s.lua`, "degraded: `/wg disable` and `/wg enable` still write the stored
  switch" and "degraded: `/wg test on` and `off` still move test mode"), committed in `f07743f`.
  The attempt replaced `settings/Schema.lua:276-754` with a `lib:New{ rows, resolveRoot,
  announce, debug, print }` instance, the reference runtime-completing stub, stamped `get`/`set`
  on the session and global rows, and put `S.AddRows(MASTER_ROWS, 1)` at `settings/Panel.lua:295`.
  Under it, `ka0s-bounded lua tests/run.lua` gave 717 passed, 10 failed, 727 total. Two of the
  failures are the unsanctioned ones above. The other eight are re-pins the spec sanctions:
  `RawSet` deleted, `opts.skipOnChange` and `skipRefresh` gone, JC-2 (two cases), JC-3, and the
  reset sweep's two extra refreshes.
- **Issue:** https://github.com/tusharsaxena/WhatGroup/issues/22
- **Reopen when:** the Schema API document's stub (and `options-ui-§1`) permit storing a write to a
  path with no row, or the owner ratifies one of the other two routes the issue lists.
