# 02 — Candidates: LibKa0s v1.30.0 → v1.31.0

Sources, in order: `git -C ../LibKa0s log --oneline v1.30.0..v1.31.0` (seven commits, of which
`3162e53` "Options 15.15.4.3: a record-backed bind arm" and `f355fdc` "Kit 17: the Ace surfaces six
consumer harnesses migrate onto" carry the payload), the `## v1.31.0` block of the tag's
`CHANGELOG.md`, `docs/api/Options/version-15.15.4.3-docs.md`, and `docs/api/testkit/version-17-docs.md`
(read against `version-16-docs.md`).

Two things moved: two secondary files of the Options major, and the kit.

## Class A — reached the addon on the re-vendor alone

| Item | Evidence | Why it needs no host change |
|---|---|---|
| `OptionsWidgets.lua` minor 15: a row with no `path` reads and writes through its own `get` / `set` | CHANGELOG `### OptionsWidgets.lua minor 15` | The gate is `path == nil`. Every WhatGroup row is path-keyed (`docs/ARCHITECTURE.md` → Settings Schema: "Every path is absolute"), so every row still reads and writes through the descriptor exactly as before. Measured upstream: WhatGroup 571 / 2 / 573 identical with and without the new `libs/`. |
| `OptionsCompose.lua` minor 4: `spec.bind`, the record-backed arm | CHANGELOG `### OptionsCompose.lua minor 4`; "Path-keyed callers are byte-for-byte unaffected", pinned by the library's `fixture_compose_golden.lua` | WhatGroup composes one block, `MasterControls`, path-keyed, from `settings/Panel.lua`. It holds no registry records (`docs/ARCHITECTURE.md` → "No structural registry"), so there is nothing for a bind to address. Delivered, inert. |
| Kit 17: `M.__fireTimers()` skips a canceled entry; `C_Timer.NewTimer`'s `Cancel` is honored | testkit v17 `### M.__fireTimers() honors cancellation` | WhatGroup's `C_Timer.After` pushes onto its own `mock.timers`, and the mock has no `NewTimer`. Reaches the harness only through the #19 migration below. |
| Kit 17: AceGUI `WidgetVersions`, `RegisterLayout` / `GetLayout` | testkit v17 `### AceGUI` | The mock wraps the kit's `aceGUI.Create` and nothing reads the new members. Available, unused. |

## Class B — host change required

**B-1. Migrate the harness onto the kit's Ace fakes (WhatGroup#19, option 1).**

- What: stop replacing the kit's AceAddon in `tests/wow_mock.lua`, so the addon's own
  `NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")` reaches the kit's
  named path: the validated event half with `M.__fireEvent`, AceTimer on `M.__timers`, AceConsole's
  `commands` and `__slash`, `GetAddon`, and the real `Enable` / `Disable`.
- Evidence: testkit v17 `### AceAddon: NewAddon honors its mixin list`, `### AceEvent: firing a game
  event`, `### AceTimer, on the kit's one queue`, `### AceConsole`, and the per-consumer entry
  `**WhatGroup (#19).**` under `## For the six migrations: what stays local`. The divergence that kept
  WhatGroup on revision 16's behavior (`NewAddon(target)` with no name) "retires when those two
  wrappers forward the name and the list".
- Touches: `tests/wow_mock.lua`, `tests/test_harness.lua`, `tests/test_lifecycle.lua`,
  `tests/test_frame.lua`, `tests/test_notify.lua`, `docs/testing.md`. No production code.
- Recommendation: **adopt** (owner decision, triage 2026-09-12: harness declines migrate onto the kit).
  It closes a real fidelity gap: the local recorder did not validate, and the kit's
  `UnregisterAllEvents` on the same object could not see the local table.
- Blast radius: **replaces** harness code the repo owned (the AceAddon copy, `fireAddonEvent`, the
  AceTimer queue, `chatCommands`). Test-only; the suites' assertions port one-for-one to the kit's
  shapes, plus five new harness cases that pin the new contract.

**B-2. `C_SpellBook` in the mock (orchestrator reading 7, tied to #15 and #19).**

- What: model `C_SpellBook.IsSpellKnown` beside the `IsSpellKnown` global, both reading
  `mock.knownSpells`; make the two older Compat cases that cleared only the global clear
  `C_SpellBook` too.
- Evidence: `core/Compat.lua:68-76` asks `C_SpellBook.IsSpellKnown` first (commit `3887767`, #15).
- Touches: `tests/wow_mock.lua`, `tests/test_compat.lua`.
- Recommendation: **adopt**. Without it every learned/unlearned case measured the fallback rung.
- Blast radius: additive in the mock; two existing cases tightened.

## Class C — whole-module adoption

None new. The payload's majors are the same as v1.30.0's. Perf stays declined on structural grounds
(LIBKA0S-15, WhatGroup#7); v1.31.0 does not touch Perf, so the premise has not moved.
