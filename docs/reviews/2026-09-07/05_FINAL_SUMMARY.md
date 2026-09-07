# WhatGroup — Final Summary (2026-09-07)

> **Written ahead of implementation.** This is the artifact to paste into the PR once
> `04_EXECUTION_PLAN.md` has been executed and every check in `03_SMOKE_TESTS.md` has passed. It
> assumes that outcome. Numbers marked *(to confirm)* are filled in from the sign-off table and the
> post-change suite run; do not ship this file with them unfilled.

---

## Headline

This cycle fixed a settings control that did not do what its own label promised, and restored a
factual claim that three documents were resting on. `General visibility` — the collection's canonical
"when may this window be on screen" dropdown — was only ever consulted when the popup was drawn or
when the dropdown itself moved, so `Only in combat` almost never showed anything and
`Only out of combat` never hid anything once combat started. It now reacts to combat transitions like
its counterpart in the rest of the collection. Alongside that, the teleport cooldown countdown could
be armed against a popup that was never on screen, which quietly contradicted the one sentence the
addon's decision *not* to wire the performance harness is built on; the ticker is now bounded by the
window it belongs to, and the record says so. The rest is smaller: one gratuitous taint source
removed, two hand-copies of values the library already publishes replaced by reads, the capture
pipeline taught to pair an application with the group it was actually made against, the test runner's
suite list finally pinned, and ~880 KB of project-page screenshots stopped shipping to players.

---

## Counts

`Critical fixed: 0 · High fixed: 1 · Medium fixed: 6 · Low fixed: 6`

**Deferred:**
- `WHATGROUP-R-08` (`RESULTS.md` prose cites an older run than its own newest row) — deferred **by
  design**, not by omission. That file is written by `/wow-addon:automated-tests`; re-pointing the
  paragraph belongs to the next recorded run, and a hand-edit would read as measured.
- `WHATGROUP-R-06` (`C_SpellBook.IsSpellKnown` rung) — *(to confirm)*. Shipped only if
  `03_SMOKE_TESTS.md` T-06 showed the two APIs present and agreeing. If it did not, this is closed as
  not-applicable with the client's answer recorded at `core/Compat.lua:62`.

---

## Changes by theme

### Theme A — `visibility` is a state the addon maintains

**What changed.** The popup now appears and disappears on its own when you enter and leave combat,
under `Only in combat` and `Only out of combat`. Previously those two values were evaluated only when
something *else* asked the popup to open, which meant `Only in combat` effectively never fired (the
join notification always arrives out of combat) and `Only out of combat` left a popup on screen
through a whole pull.

**Why it mattered.** The row is `options-ui-§15`'s canonical one — the same control, with the same
label, in every addon in the collection — and a sibling implements it correctly. One addon behaving
differently under an identical control is exactly the drift that block exists to prevent, and both
`README.md` and `docs/frame.md` described the behaviour the code did not have.

**Findings covered:** `WHATGROUP-R-01`. **Changes implemented:** C-01.
**Files touched:**
- `modules/Frame.lua`
- `core/WhatGroup.lua`
- `docs/frame.md`, `docs/settings-panel.md`, `README.md`
- `tests/test_frame.lua`

### Theme B — the ticker cannot outlive its window, again

**What changed.** The teleport cooldown countdown is armed only when the popup is actually on screen.
Two paths could previously arm it against a hidden frame — a popup built but suppressed by the
visibility gate, and a combat-deferred reconfigure replaying onto a popup the player had already
closed — and neither had a cancel site, because `OnHide` fires on a transition and there was none.

**Why it mattered.** Not for the runtime cost, which was one API call and one `SetText` per second
against an invisible label. It mattered because the ratified `performance-§12` deviation — the
argument for vendoring `LibKa0s-Perf-1.0` and deliberately not wiring it — rests on the claim that
this ticker *cannot outlive the window that armed it*. That claim is load-bearing across
`docs/ARCHITECTURE.md`, `docs/performance.md` and the code comment, and it was false. The fix makes
it true again; the deviation row was amended with the condition that enforces it rather than retired.

**Findings covered:** `WHATGROUP-R-02`. **Changes implemented:** C-02.
**Files touched:**
- `modules/Frame.lua`
- `docs/ARCHITECTURE.md`, `docs/performance.md`
- `tests/test_frame.lua`

### Theme C — read what the library publishes; pin what isn't pinned

**What changed.** The Master controls tab's closing button pair is keyed off the group name the
library publishes rather than a hand-typed copy of it; the settings composer is handed the addon's
folder name from the load vararg rather than a literal; the test runner's 17-entry suite list is now
pinned in both directions; and the L-trap source sweep asserts it actually read each file it claims
to check.

**Why it mattered.** Every one of these was a value or a list that exists authoritatively somewhere
else and was restated by hand where the restatement drifts silently. `settings/OptionsSetup.lua`
already argues this position at length and refuses to copy the same constant into its degraded stub —
the live path had simply not caught up. The suite-list pin closes a stated `testing-§9` MUST whose
two failure modes (a new suite that never runs; a renamed suite reported as a skip) are invisible to
a green gate by construction.

**Findings covered:** `WHATGROUP-R-04`, `WHATGROUP-R-05`, `WHATGROUP-R-11`, `WHATGROUP-R-12`.
**Changes implemented:** C-04, C-05, C-10, C-11.
**Files touched:**
- `settings/Panel.lua`
- `tests/run.lua`, `tests/test_harness.lua`, `tests/test_libka0s.lua`
- `docs/test-cases.md`, `README.md` (badge)

### Theme D — correctness and hygiene

**What changed.** The reset-confirmation registration no longer assigns the Blizzard
`StaticPopupDialogs` global (it still writes its own key, lazily, as before). Captured group
information is now keyed by the search-result id it came from rather than popped off a FIFO, so two
sign-ups whose status events arrive out of order no longer pair with each other's applications, and
declined applications no longer leak. The notification's `Open Automatically` flag is read when the
timer fires rather than when it is scheduled. Screenshots and dev-only docs stopped shipping.

**Why it mattered.** The global assignment was a stronger taint act than the indexed write the
surrounding comment carefully defers — it marked the variable Blizzard's own `StaticPopup_Show`
reads, for no behavioural gain, on a path three UI controls reach. The FIFO pairing could put the
wrong dungeon's name in the popup and the chat summary for a player doing the ordinary thing of
signing up to several groups at once; it was masked most of the time by the invite-time re-fetch,
which is exactly why it would have been hard to catch from a bug report.

**Findings covered:** `WHATGROUP-R-03`, `WHATGROUP-R-07`, `WHATGROUP-R-09`, `WHATGROUP-R-10`,
`WHATGROUP-R-14`. **Changes implemented:** C-03, C-07, C-08, C-09, C-12.
**Files touched:**
- `settings/Schema.lua`
- `core/WhatGroup.lua`
- `.pkgmeta`
- `tests/test_capture.lua`, `tests/test_mediasetup.lua`

### Theme E — the record

**What changed.** The `performance-§12` deviation row states the condition that now enforces its
invariant; `docs/performance.md`'s sweep was regenerated; `docs/frame.md` → *Visibility* and
`docs/settings-panel.md`'s `visibility` row describe the combat-transition behaviour; six paths whose
working tree disagreed with the `.gitattributes` CRLF pin were re-checked-out.

**Findings covered:** `WHATGROUP-R-13`, plus the doc follow-on from Themes A and B.
**Changes implemented:** C-13.

---

## API / behaviour changes

| Kind | Change |
|---|---|
| Behaviour | `General visibility = Only in combat` / `Only out of combat` now show and hide the popup on combat transitions. Previously they were evaluated only at popup-open and at dropdown-change |
| Behaviour | The teleport cooldown countdown ticks only while the popup is on screen. A cooldown that expires while the popup is closed is picked up on the next open, as before |
| Behaviour | `Open Automatically` is honoured as of the moment the notification fires, not as of the moment it was scheduled. Only observable with `notify.delay > 0` |
| Internal | Captures are keyed by `searchResultID` rather than queued FIFO. No user-visible surface, no saved shape |
| Events | Two new registrations in `OnEnable`: `PLAYER_REGEN_DISABLED`, `PLAYER_REGEN_ENABLED` |
| Packaging | `media/screenshots/`, `CLAUDE.md` and `DEPENDENCIES.md` no longer ship |
| **Unchanged** | No slash verb added, renamed or removed — the 11 in `WhatGroup.COMMANDS` are exactly as before. No locale key added or renamed. No new default, no removed default |

## Saved-variable / migration notes

**No schema bump.** `NS.SCHEMA_VERSION` stays at `1`; no stored key changed shape, name or default.
Existing profiles carry forward untouched and no `/wg reset` is needed. The `RunMigrations` seam
(`core/Database.lua`) was not exercised by this work.

## Deprecated-API migrations

*(to confirm — this table ships only if `03_SMOKE_TESTS.md` T-06 passed)*

| Old API | New API | Files |
|---|---|---|
| `IsSpellKnown(spellID)` (global) | `C_SpellBook.IsSpellKnown(spellID)`, global retained as the second rung | `core/Compat.lua` |

If T-06 showed `C_SpellBook.IsSpellKnown` absent or disagreeing, this section is replaced by one
line: *no deprecated-API migration was made; see the comment at `core/Compat.lua:62` for the client's
measured answer.*

## Performance impact

The addon ships no `tests/perf.lua` and wires no `LibKa0s-Perf-1.0`, both by ratified
`performance-§12` deviation, so there are no bucket figures or offline scenario counts to report and
none are invented here.

The one measurable change is negative work removed: the cooldown ticker no longer runs while the
popup is off screen. The evidence for it is `03_SMOKE_TESTS.md` steps 2–3 of the performance
spot-check (`collectgarbage("count")` before/after a 60 s window with the popup closed) — record the
two readings here rather than describing the change.

*Complexity, for the next release to confirm:* `LFG_LIST_APPLICATION_STATUS_UPDATED` was the tree's
max-CCN function at **15** (`WhatGroup@675-738@./core/WhatGroup.lua`, `lizard` run of 2026-09-07,
0 warnings across 1004 functions / 7047 NLOC). C-07 extracts the search-result-id resolution into a
named local and is expected to move it **down**. This is a note for `/wow-addon:bump-version`'s
regeneration, not a task to run `lizard` now.

## Test and complexity movement

| | Before | After |
|---|---|---|
| Passing cases | 528 | 530 + *(new cases from M1-T1, M1-T2, M2-T2, M3-T1 — to confirm)* |
| Failing / skipped | 0 / 0 | 0 / 0 |
| `luacheck` | 0 warnings, 0 errors, 16 files | *(to confirm)* |
| `lizard` max CCN | 15, 0 warnings | *(to confirm; expected ≤ 15)* |

`docs/test-cases.md` and the README `[tests]` badge moved **in the same commit** as the change that
moved the count (M4-T1 and each behavioural task), regenerated with `lua5.1 tests/run.lua --list`.
Neither was hand-edited. `docs/automated-tests/RESULTS.md` was **not** written by this work — its
next row comes from the next recorded run.

## Known follow-ups

- **`WHATGROUP-R-08`** — `RESULTS.md`'s `## Test suite` prose still cites run `20260807-121935` and
  462 cases. Left to the next `/wow-addon:automated-tests` run, which is the only sanctioned writer
  of that file.
- **`WHATGROUP-R-06`**, if T-06 came back negative — re-check whenever the interface version moves;
  the shim's `false`-on-absence default means the failure mode is silent and total.
- **Upstream `performance-§12` amendment.** The second deviation row already proposes that §12's
  re-check trigger should exempt a ticker gated on an addon's own transient window. C-02 makes this
  addon's ticker unambiguously window-bounded, which strengthens the case. Not raised by this review;
  noted so it is not lost.
- **`visibility` across the collection.** WhatGroup was the outlier here, but the canonical row is in
  all nine addons. Worth one grep per repo for a `visibility` value that is read only at draw time.

## Verification evidence

- `03_SMOKE_TESTS.md` in this bundle, with its sign-off table completed.
- Measurement baseline: `01_FINDINGS.md` → *Measurement run*, 2026-09-07 (528/528, 0 lint, max CCN
  15, vendor sync clean against `../LibKa0s` v1.25.0).
- Commit range: *(to fill in)*. PR: *(to fill in)*.

---

## Suggested PR description

```
fix: make General visibility react to combat, and bound the cooldown ticker to its window

General visibility's two combat-dependent values were only ever evaluated when the popup
was drawn or when the dropdown moved, so "Only in combat" almost never showed anything and
"Only out of combat" never hid anything once a pull started. Both now react to
PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED, matching the same canonical options-ui-§15 row
elsewhere in the collection and matching what README.md and docs/frame.md already promised.

The teleport cooldown ticker could be armed against a popup that never reached the screen —
via the visibility gate, and via a combat-deferred reconfigure replaying onto a closed popup —
with no cancel site, because OnHide fires on a transition. It is now armed only against a
visible popup. That restores the invariant the ratified performance-§12 deviation is built on;
the row is amended with the condition that enforces it rather than retired, and Perf stays
declined on its unchanged criteria (b) and (c).

Also: dropped a gratuitous assignment of the StaticPopupDialogs global from the lazy reset-popup
registration; keyed captures by searchResultID instead of FIFO order so interleaved LFG sign-ups
pair with the right group; read MASTER_GROUP and addonName from their sources instead of
hand-typed copies; pinned the runner's suite list in both directions (testing-§9); widened the
private-art test; and stopped shipping media/screenshots and dev docs.

Findings: WHATGROUP-R-01 … -07, -09 … -14 (docs/reviews/2026-09-07/01_FINDINGS.md).
Deferred: WHATGROUP-R-08 (belongs to the next recorded automated-tests run).
No change under libs/ or tests/_kit/ — no upstream findings in this review.

Tests: 528 -> <N> passing, 0 failing, 0 skipped. luacheck clean. lizard 0 warnings.
docs/test-cases.md and the README badge moved with the count.
```
