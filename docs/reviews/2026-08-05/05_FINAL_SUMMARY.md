# 05 — Final summary

> **Written ahead of implementation.** This document describes the cycle **as it will read once
> `04_EXECUTION_PLAN.md` has been executed and every check in `03_SMOKE_TESTS.md` has passed.** It is
> the PR description and the "what shipped" record. Until the sign-off table in `03_SMOKE_TESTS.md`
> is filled in, treat the claims below as planned rather than delivered.

---

## Headline

This cycle fixed a defect that made the addon's own on/off switch a suggestion: with **Enable**
turned off, WhatGroup was still capturing group data, printing the full join summary to chat and
opening the popup — because only one of the two paths into the capture pipeline was gated. The more
uncomfortable half of the finding is that a test named *"master switch off means nothing is queued"*
had been green over that bug the whole time; it nilled the search result before asserting, so it
would have passed with the gate deleted. Both were fixed, and the test was proven to go red before
it was trusted again. Alongside that: a settings **read** that was quietly writing empty tables into
your SavedVariables now reads without writing; the popup stopped keeping a second private copy of the
playstyle-label rule; the secure teleport button stopped dispatching its `/cast` on both the down and
the up edge of a single click; and five locale rows that no code has referenced in some time were
removed.

---

## Counts

**Critical fixed: 0 · High fixed: 2 · Medium fixed: 3 · Low fixed: 3**

- High: F-001 (master switch), F-002 (unfalsifiable test).
- Medium: F-003 (read-path write), F-004 (duplicated label rule), F-005 (double click edge).
- Low: F-006 (dead locale rows), F-007 (unguarded rect arithmetic), F-008 (uncovered fallback).
- **Deferred / routed elsewhere:** F-U01 and F-U02 are upstream (LibKa0s) and land in this repo only
  as a re-vendor commit — see *Known follow-ups*.

No Critical findings were raised. The review found no taint propagation, no protected-API secret-value
leakage, no deprecated-API usage and no saved-variable data loss.

---

## Changes by theme

### Theme A — The master switch means what it says

**What changed.** `LFG_LIST_APPLICATION_STATUS_UPDATED` now checks `db.profile.enabled` at the top of
the handler, so both the queued capture and the re-fetched one are suppressed while the addon is off.
The two `tests/test_capture.lua` cases that covered this stopped removing the search result before
asserting, so the master switch is now the only thing that can make them pass, and each carries a
`-- red under:` comment naming the mutation that reddens it.

**Why it mattered.** The Enable tooltip promises *"WhatGroup ignores group applications entirely — no
capture, no notification, no popup"* and the addon did none of that. Worse, the covering test would
never have caught the regression, so the bug was invisible to the gate that exists to catch exactly
this.

**Findings:** F-001, F-002 · **Changes:** C-01, C-02
**Files:** `core/WhatGroup.lua`, `tests/test_capture.lua`, `docs/capture-pipeline.md`,
`docs/test-cases.md`, `README.md`

### Theme B — Reads stop writing; one rule lives in one place

**What changed.** `Helpers.Get` resolves a settings path read-only; only the write path materializes
missing parent tables. The popup's playstyle row now calls the shared `Labels.GetPlaystyleLabel`
instead of re-deriving the same rule inline.

**Why it mattered.** A `Get` of an unmaterialized nested path left empty tables in the AceDB profile,
which then got serialized into `WhatGroupDB` — keys the user never set, accumulating after every
`resetall`. And the popup carried a second copy of a rule whose own file comment claimed it lived in
exactly one place, so a new playstyle enum would have shipped half-applied.

**Findings:** F-003, F-004 · **Changes:** C-03, C-04
**Files:** `settings/Schema.lua`, `modules/Frame.lua`, `tests/test_settings.lua`

### Theme C — Frame hardening

**What changed.** The secure teleport button registers a single click edge (`AnyUp`) instead of both,
so one press runs the macro once; the `PreClick` trace no longer needs a down-edge filter to avoid
logging twice. The derived anchor offsets for that button are guarded against an unresolved widget
rect, falling back to the same position the anchor constants already imply.

**Why it mattered.** `SecureActionButtonTemplate` dispatches on every registered edge, so a single
click was attempting the teleport twice — the second attempt rejected with a red client error. The
addon's own `PreClick` filter was documenting the double dispatch rather than fixing it. Separately,
`GetLeft()`/`GetTop()` arithmetic inside a one-shot builder is a raise that would leave the popup
permanently unbuildable.

**Findings:** F-005, F-007 · **Changes:** C-05, C-07
**Files:** `modules/Frame.lua`

### Theme D — Cleanups

**What changed.** Five locale rows with no call site were removed (`Ka0s WhatGroup`, `General`,
`Slash Commands`, `Defaults`, and the retired combat-refusal sentence now owned by
LibKa0s-Options). The degraded `NS.Util.format` fallback got its first covering case, exercised by
loading with `libs/LibKa0s/Core.lua` genuinely absent rather than by hand-stubbing the member.

**Why it mattered.** A translator editing those five rows would have seen nothing change in game —
they read as coverage while providing none. And the fallback would have been first executed, in a
broken install, by whichever caller was added months later.

**Findings:** F-006, F-008 · **Changes:** C-06, C-08
**Files:** `locales/enUS.lua`, `tests/test_libka0s.lua`

---

## API / behavior changes

- **Behavior:** with `enabled = false`, `LFG_LIST_APPLICATION_STATUS_UPDATED` returns early. No
  capture, no `pendingInfo`, no notification, no popup. `/wg test` and `/wg show` are unaffected —
  they bypass the capture pipeline by design.
- **Behavior:** the teleport button casts on mouse-**up** rather than on mouse-down. Same single
  click, one dispatch instead of two.
- **Behavior:** `Helpers.Get` on a path whose parent table does not exist returns `nil` without
  creating it. Externally observable only in the SavedVariables file.
- **No slash-command changes.** The `COMMANDS` table and `README.md:49-60` are untouched and still
  agree.
- **Locale keys removed:** `"Ka0s WhatGroup"`, `"General"`, `"Slash Commands"`, `"Defaults"`,
  `"cannot open settings during combat — Blizzard's category-switch is protected"`. All five had zero
  call sites; the strings they named continue to render identically (T-07).
- **No new defaults, no removed defaults, no new locale keys.**

## Saved-variable / migration notes

**No schema bump.** `NS.SCHEMA_VERSION` stays at `1` and `core/Database.lua`'s migration ladder is
untouched. C-03 changes only whether *new* empty keys are created going forward; it does not remove
keys an existing profile already carries. A user who wants a genuinely pristine profile can run
`/wg resetall`, which wipes `db.profile` before re-threading the defaults — but no user is required
to. Existing profiles load unchanged.

## Deprecated-API migrations

**None.** The review found no deprecated or removed API in this addon's own source. The
version-variant surface is already firewalled behind `core/Compat.lua`, which is the sole caller of
`C_Spell.*`, the legacy `GetSpell*` globals, `IsSpellKnown` and
`C_LFGList.GetActivityInfoTable`, each with a modern-first / legacy-fallback chain.

## Performance impact

**Section omitted deliberately — no perf-tagged change was made and no perf evidence exists to
cite.** This addon ships no `tests/perf.lua`, no `docs/performance.md` and no `docs/perf-runs/`; it
wires no `LibKa0s-Perf-1.0` bucket and brackets no path, which is why
`docs/automated-tests/RESULTS.md` records `perf: skip` for every run. None of C-01…C-08 touches an
`OnUpdate` or per-frame path. Any number here would be an estimate, and an estimate in this section
reads as a measurement.

## Test and complexity movement

| | Before | After |
|---|---|---|
| Test cases | **422 / 422** | **425 / 425** (+1 master-switch output assertion, +1 read-purity, +1 degraded `Util.format`) |
| `docs/test-cases.md` | in sync with a fresh `--list` | regenerated in the same commits that moved the count |
| README `[tests]` badge | `422/422` | `425/425`, moved with the inventory |
| luacheck | 0 warnings / 0 errors, 14 files | unchanged |
| lizard | 808 functions, avg CCN 1.7, **0 above CCN 15**; max 13 (`WhatGroup@533-573@./core/WhatGroup.lua`) | unchanged in shape |

**Complexity watch:** C-01 adds one guard clause to
`LFG_LIST_APPLICATION_STATUS_UPDATED` and C-03 adds one to `Resolve`, so each of those functions
gains roughly +1 CCN. Neither is near the threshold (the tree's current maximum is 13, in a different
function), and the release gate — `suites.complexity.warnings == 0`, i.e. zero functions above CCN 15
(automated-tests-§3) — is expected to stay satisfied. **To be confirmed by the next release's
regeneration via `/wow-addon:bump-version`, not regenerated as part of this work.**

## Known follow-ups

- **F-U01 (upstream, LibKa0s):** 29 British-spelled words in authored comments across
  `Core.lua`, `DebugLog.lua`, `Slash.lua`, `OptionsWidgets.lua` and `Perf.lua`
  (anti-patterns #46, localization-§5). Deferred here because it is not this repo's code to edit — a
  local patch is reverted by the next whole-folder copy. Lands as a library commit plus a minor bump,
  then arrives here as a re-vendor commit.
- **F-U02 (upstream, LibKa0s):** the `diff -r` byte-identity check between `libs/LibKa0s/` /
  `tests/_kit/` and their source repo was **not run** — this review was scoped to a single repository
  and could not read a sibling. Vendor drift is therefore *unverified*, not clean. Run before the next
  release.
- **Panel localization:** every schema `label` and `tooltip` in `settings/Schema.lua` is raw English
  and does not route through `NS.L`. Out of scope for this cycle — the standard requires only that
  `enUS.lua` ship (localization-§3), and doing it properly is one deliberate change across the whole
  settings surface rather than the five orphan rows C-06 removed.
- **C-07's fallback branch is untestable headlessly.** The mock always returns numbers from
  `GetLeft`/`GetTop`, so the guard's else-branch has no covering case. Left uncovered rather than
  pinned with a test that would only assert the mock's behavior.

## Verification evidence

- **Completed checklist:** `docs/reviews/2026-08-05/03_SMOKE_TESTS.md`, sign-off table filled in —
  T-01…T-07, R-01…R-12, X-01…X-05 and the deDE locale pass.
- **Headless evidence at review time:** `luacheck .` 0/0 over 14 files; `lua5.1 tests/run.lua`
  422/422; `lua5.1 tests/run.lua --list` byte-identical to `docs/test-cases.md`;
  `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` 0 functions above CCN 15. Recorded in
  `01_FINDINGS.md`'s measurement block.
- **Commit range / PR:** _fill in once M1–M5 are merged._

---

## Suggested commit message / PR description

```
Review 2026-08-05: the master switch, a test that couldn't fail, and three smaller defects

The Enable toggle didn't disable the addon. OnApplyToGroup was gated on
db.profile.enabled, but the "inviteaccepted" branch of
LFG_LIST_APPLICATION_STATUS_UPDATED re-fetched the group from the LFG API
unconditionally, set pendingInfo and fired the notify path — so a disabled
WhatGroup still printed the full join summary and opened the popup. The gate now
sits at the handler's front door, where both capture paths pass through it.

The covering test would not have caught this. "capture: master switch off means
nothing is queued" nilled mock.searchResults before asserting pendingInfo was
nil, so it passed whether or not the gate existed — testing-§12's unfalsifiable
negative. Both master-switch cases now keep the search result live across the
accept and carry a `-- red under:` comment; each was proven red against the
pre-fix code before being trusted.

Also fixed:
- F-003 Helpers.Get materialized missing parent tables on a READ, leaving empty
  keys in db.profile that AceDB then serialized. Resolve() takes an opt-in
  `create` flag; the single write path is unchanged.
- F-004 the popup re-derived the playstyle label inline instead of calling
  Labels.GetPlaystyleLabel, contradicting that namespace's own comment.
- F-005 the secure teleport button registered AnyUp AND AnyDown, so one click
  dispatched /cast twice; the PreClick down-edge filter existed to work around
  it. One edge now, filter removed.
- F-006 five locale rows with zero call sites removed.
- F-007 the derived secure-button offsets are guarded against an unresolved rect.
- F-008 the degraded NS.Util.format fallback got its first covering case.

Tests 422 -> 425; docs/test-cases.md and the README badge moved with them.
luacheck clean (0/0, 14 files); lizard unchanged, still zero functions above
CCN 15.

Upstream, not in this commit: 29 British-spelled words in libs/LibKa0s comments
(F-U01) land in the LibKa0s repo with a minor bump and arrive here as their own
re-vendor commit. The libs/ and tests/_kit/ byte-identity diff (F-U02) was not
run this cycle and remains unverified.

Findings: F-001, F-002, F-003, F-004, F-005, F-006, F-007, F-008
Review bundle: docs/reviews/2026-08-05/
```
