# WhatGroup — final summary (2026-10-07 review)

*Written assuming every check in `03_SMOKE_TESTS.md` has passed. Fill in the commit range when the work
lands.*

## Headline

This cycle stops WhatGroup from comparing cooldown numbers that the game hides from addons during
combat. Before the fix, a popup left open into a fight raised an error and froze its countdown, and a
join notice that arrived mid-fight could stop before its details link and its popup.

The cycle also makes the one-shot **Test** (the settings-panel button and `/wg test notify`) preview
through a record of its own. It no longer replaces the group the player actually joined, and it no
longer leaves behind a popup that appears when the addon is re-enabled. Three stale statements (a
tooltip, a perf write-up and a comment) were corrected.

## Counts

Critical fixed: 0, High fixed: 1, Medium fixed: 3, Low fixed: 3.

The two Low upstream findings are deferred to their owning repos as cross-repo handoffs:
- F-008 goes to WowAddonStandards.
- F-009 goes to LibKa0s, and lands here only as a later re-vendor.

## Changes by theme

### T1 — Check for secret values before comparing a cooldown

- **What changed:** `NS.Compat` gained the library's `IsSecret` guard, with a documented fallback for
  when the library is absent. The teleport-cooldown reader now also reports whether it could read the
  value. The popup countdown skips ticks it cannot read and resumes when combat ends. The chat summary
  leaves the *(on cooldown)* tag off when it cannot tell.
- **Why it mattered:** comparing a secret value raises an error. On a repeating timer, that error
  silently ends the timer.
- **Findings:** F-001, F-002. **Changes:** C-001, C-002.
- **Files:** `core/Compat.lua`, `modules/Frame.lua`, `core/WhatGroup.lua`, `tests/wow_mock.lua`,
  `tests/test_compat.lua`, `tests/test_frame.lua`, `tests/test_notify.lua`, `docs/compat-layer.md`,
  `docs/module-map.md`.

### T2 — The one-shot test gets its own record

- **What changed:** `RunTest` renders the sample through the popup's preview record and passes it to
  `ShowNotification`. `pendingInfo` is never written. While the addon is disabled, the button prints
  the chat preview and builds nothing.
- **Why it mattered:** clicking **Test** inside a real group replaced that group's details for the rest
  of the session. Clicking it while disabled left a sample popup that appeared on re-enable.
- **Findings:** F-003, F-004. **Changes:** C-003.
- **Files:** `core/WhatGroup.lua`, `modules/Frame.lua`, `tests/test_lifecycle.lua`,
  `tests/test_testmode.lua`, `docs/slash-dispatch.md`, `docs/scope.md`, `docs/frame.md`,
  `docs/module-map.md`.

### T3 — Stale text

- **What changed:** the Height tooltip now says 280. `docs/performance.md` was re-measured. The
  `reloadProfile` comment now matches the account-wide migration stamp.
- **Findings:** F-005, F-006, F-007. **Changes:** C-004, C-005, C-006.
- **Files:** `settings/Schema.lua`, `modules/Frame.lua`, `docs/performance.md`, `core/WhatGroup.lua`.

## API / behavior changes

- `NS.Compat.IsSecret(v)` is new, and is internal to the addon's namespace.
- `NS.Compat.GetSpellCooldownRemaining` now returns a second value, `readable`.
- `WhatGroup:ShowNotification(info)` takes an optional capture. Called with no argument it behaves as
  before.
- `/wg test notify` and the panel **Test** button no longer change `pendingInfo`. After a test, `/wg
  show` and the details link still open the real group, or say none is held.
- No slash verb, schema row, SavedVariables key or default changed.

## SavedVariables / migration

None. `NS.SCHEMA_VERSION` stays at 1.

## Deprecated-API migrations

None.

## Performance impact

The figures come from `tests/perf.lua` runs. Fill these in from the post-change run:

| Scenario | Before (2026-10-07) | After |
|---|---|---|
| `cooldownTick` | 2.0 api/iter, 240.4 bytes/iter | _from the post-M2 run_ |
| `showFrameRepeat` | 19.0 api/iter, 1744.1 bytes/iter | _from the post-M2 run_ |
| `combatGateFlipping` | 7.0 api/iter, 960.0 bytes/iter | _from the post-M2 run_ |

## Test and complexity movement

- Passes go from **914 to 918**: +3 for C-002, and C-003's one rewritten case plus one new case.
- `docs/test-cases.md` and the README `Tests` badge moved in the M1 and M2 commits.
- No watch-list entry should cross CCN 15. The next release's regeneration of `docs/automated-tests/`
  will confirm it (the committed record is from `20260927-031637`).

## Known follow-ups

- **F-008 (WowAddonStandards):** name `C_Spell.GetSpellCooldown` in the §8 trigger set, so audits grade
  this class as a MUST.
- **F-009 (LibKa0s testkit):** add a shared secret simulator. When it ships, re-vendor `tests/_kit/` and
  delete WhatGroup's local helper from C-002.
- **S-001's answer:** if the client does not mark teleport cooldowns secret, record F-001 as defensive
  rather than live in the consolidated record.

## Verification evidence

- `03_SMOKE_TESTS.md`, with its sign-off table filled in.
- Commit range: `<first>..<last>` on `feat/2026-10-07-review-audit-remediation` (fill in).

## Suggested PR description

```
WhatGroup: secret-safe teleport cooldown; one-shot Test no longer replaces the real capture

- Ask IsSecret before comparing a spell cooldown (F-001). A popup open into combat no longer
  raises and freezes its countdown, and an in-combat join notice prints every row.
- Mock a secret cooldown and pin the combat ticker and Teleport row (F-002).
- /wg test notify and the panel Test button preview through their own record (F-003, F-004).
  The real group's details survive a test, and a disabled-addon test leaves no popup behind.
- Height tooltip says 280; docs/performance.md re-measured; reloadProfile comment corrected
  (F-005, F-006, F-007).

Tests: 914 -> 918 passed; luacheck 0/0. Upstream handoffs: F-008 (WowAddonStandards),
F-009 (LibKa0s testkit).
```
