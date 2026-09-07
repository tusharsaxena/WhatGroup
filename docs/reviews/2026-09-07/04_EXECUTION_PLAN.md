# WhatGroup — Execution Plan (2026-09-07)

Implements `02_PROPOSED_CHANGES.md`. Ordered so the two behavioural changes that share
`modules/Frame.lua` are settled before anything else touches it, and so the one change gated on an
in-client answer (C-06) cannot be merged blind.

**There is no upstream milestone.** No finding in this review lands under `libs/` or `tests/_kit/`;
the vendored payload is byte-identical to `../LibKa0s` v1.25.0. Nothing in this plan edits either
folder.

**Green gate applies to every task** (`testing`, `versioning-git`): `luacheck .` clean and
`lua5.1 tests/run.lua` green before any commit. Baseline today is **0 warnings / 528 passing**.

---

## Milestone M1 — the visibility contract

Both tasks touch `modules/Frame.lua`; they **must serialize**, in this order, because M1-T2's guard
depends on M1-T1's `ApplyFrameVisibility` shape.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| **M1-T1** | wow-event-wiring | C-01 / `WHATGROUP-R-01` | `modules/Frame.lua`, `core/WhatGroup.lua`, `tests/test_frame.lua` |
| **M1-T2** | lua-refactorer | C-02 / `WHATGROUP-R-02` | `modules/Frame.lua`, `tests/test_frame.lua` |
| **M1-T3** | docs-sync | C-01 + C-02 doc follow-on | `docs/frame.md`, `docs/settings-panel.md`, `docs/ARCHITECTURE.md`, `docs/performance.md`, `README.md` |

**M1-T1 notes.** Write the failing cases first (`testing`, TDD): a combat transition with the popup
built-but-hidden under `inCombat` shows it; the reverse hides it; `never` and `always` are unmoved by
either transition; a transition with no `pendingInfo` shows nothing. Then wire
`PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` in `OnEnable` — **never** `OnInitialize`. Handle the
lockdown-lag quirk (`02_PROPOSED_CHANGES.md` C-01 risk note) explicitly, with a case.

**M1-T2 notes.** This is a behaviour-preserving guard on a path with existing coverage
(`tests/test_frame.lua:376`, `:391`, `:403`, `:415`, `:425`), so those five cases are the
characterization test and must stay green untouched. Add two: a ticker is **not** armed when the
popup is built-but-not-shown, and **not** armed by the combat-deferred replay onto a closed popup.
Both need a `-- red under:` note naming the mutation (drop the `f:IsShown()` guard).

**M1-T3 notes.** Amend the second `performance-§12` row in `docs/ARCHITECTURE.md` in place — one
clause naming the visible-only condition as how the invariant is enforced. **Do not retire the row,
do not wire Perf, do not delete the superseded first row.** Regenerate `docs/performance.md`'s sweep
with the command that file already documents.

**Done when:** the suite is green with the new cases; T-01 and T-02 in `03_SMOKE_TESTS.md` pass
in-client; `docs/ARCHITECTURE.md`'s deviation row again describes the code.

### CHECKPOINT 1 — human verification

Stop here. M1 changes when a window appears on screen and adds the addon's first combat-entry event
handler. Run `03_SMOKE_TESTS.md` T-01, T-02, X-1 and X-4 before proceeding. Nothing downstream
depends on M1, so a failure here does not block M2–M4.

---

## Milestone M2 — taint and coupling

All three tasks touch **disjoint** files. **Parallelizable.**

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| **M2-T1** | taint-auditor | C-03 / `WHATGROUP-R-03` | `settings/Schema.lua` |
| **M2-T2** | lua-refactorer | C-04 + C-11 / `WHATGROUP-R-04`, `WHATGROUP-R-12` | `settings/Panel.lua` |
| **M2-T3** | lua-refactorer | C-12 / `WHATGROUP-R-14` | `core/WhatGroup.lua` |

**Concurrency note.** M2-T3 touches `core/WhatGroup.lua`, which **M1-T1 also touches**. If M1 has not
merged, serialize M2-T3 after it. M2-T1 and M2-T2 are safe to run alongside M1.

**M2-T2 notes.** Two one-line changes in one file, both the same class of defect (a host copy of a
value that exists authoritatively elsewhere). One commit. The `MASTER_GROUP` change needs a case in
`tests/test_panel.lua` that asserts the tail hook fires under whatever `Helpers.MASTER_GROUP` says —
**not** under the literal, or the test carries the same copy the fix removed.

**Done when:** suite green; `03_SMOKE_TESTS.md` T-03, T-04 and X-1/X-2 pass.

---

## Milestone M3 — the capture pipeline

Single task, and the highest-risk change in the set. **Serialize after M2-T3** — same file.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| **M3-T1** | lua-refactorer | C-07 / `WHATGROUP-R-07` | `core/WhatGroup.lua`, `tests/test_capture.lua` |

**Notes.** `LFG_LIST_APPLICATION_STATUS_UPDATED` is today's max-CCN function (**15**, at the release
gate's cap, `WhatGroup@675-738@./core/WhatGroup.lua` in the fresh `lizard` run). Extracting the
search-result-id resolution into a named local should move it **down**; the four-branch
source-preference ladder is the bulk of the count. Confirm at the **next release's** regeneration —
do not run `lizard` into the repo as part of this task, and do not gate the commit on it.

Characterization first: `tests/test_capture.lua` already covers the single-application path
extensively. Pin the current behaviour of `WipeCapture` and of the fresh-vs-queued preference ladder
**before** touching the queue, then add the interleaving and declined-leak cases.

**Done when:** suite green with the new cases; `03_SMOKE_TESTS.md` T-07 passes three times in-client.

### CHECKPOINT 2 — human verification

Stop. M3 rewrites the addon's core capture path. T-07 must pass on a live realm with three real
sign-ups before M4 begins.

---

## Milestone M4 — harness, packaging and the record

All disjoint. **Fully parallelizable**, and independent of M1–M3.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| **M4-T1** | test-harness | C-05 / `WHATGROUP-R-05` | `tests/run.lua`, `tests/test_harness.lua`, `docs/test-cases.md`, `README.md` |
| **M4-T2** | test-harness | C-09 + C-10 / `WHATGROUP-R-10`, `WHATGROUP-R-11` | `tests/test_mediasetup.lua`, `tests/test_libka0s.lua` |
| **M4-T3** | packaging | C-08 / `WHATGROUP-R-09` | `.pkgmeta` |
| **M4-T4** | repo-hygiene | `WHATGROUP-R-13` | working-tree re-checkout only — **no file content changes** |

**M4-T1 notes.** This is the only task that moves the pass count: **528 → 530**.
`docs/test-cases.md` and the README `[tests]` badge **must** move in the same commit
(`testing`), regenerated with `lua5.1 tests/run.lua --list` — never hand-edited. Copy the two cases
from the reference implementations `testing-§9` names (BankLedger `tests/test_harness.lua:22-32`,
PanelMaster `tests/test_harness.lua:19-32`) rather than writing new ones.

**M4-T4 notes.** Six paths, listed in `WHATGROUP-R-13`. `git add --renormalize .` fixes the **index**
and not the working tree (`line-endings-§2`); a re-checkout of those paths is what actually moves
them. Verify with `git ls-files --eol` afterwards. Do not touch file content.

**`WHATGROUP-R-08` is deliberately not a task here.** The `RESULTS.md` prose is re-pointed by the
**next recorded run** (`/wow-addon:automated-tests`), which is where that file is written from. A
hand-edit would read as measured.

**Done when:** 530 green, `docs/test-cases.md` and the badge agree, `git ls-files --eol` shows no
stragglers, T-08 passes against a real packaged zip.

---

## Milestone M5 — the gated change

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| **M5-T1** | wow-api-migrator | C-06 / `WHATGROUP-R-06` | `core/Compat.lua`, `tests/test_compat.lua` |

**This task does not start until `03_SMOKE_TESTS.md` T-06 has been run and its two `/run` readings
recorded.** The finding is filed **unverified**; T-06 is what verifies it. If the client reports
`C_SpellBook.IsSpellKnown` absent, or the two APIs disagree on any spell, the compliant outcome is to
**abandon C-06** and record the client's answer as a comment at `core/Compat.lua:62` — not to ship a
ladder nobody checked.

**Done when:** T-06's readings are recorded in the sign-off table, and either the rung is in with two
new `tests/test_compat.lua` cases (one per rung), or the finding is closed as not-applicable with the
comment in place.

---

## Critical path / concurrency map

```
M1-T1 ──► M1-T2 ──► M1-T3 ──► CHECKPOINT 1
   │
   └────────────────────────► M2-T3 ──► M3-T1 ──► CHECKPOINT 2
                                 (core/WhatGroup.lua: serialize)

M2-T1  ┐
M2-T2  ├─ parallel with everything (disjoint files)
M4-T1  │
M4-T2  │
M4-T3  │
M4-T4  ┘

M5-T1 ──► requires T-06 in-client first
```

**Files touched by more than one task — must serialize:**
- `modules/Frame.lua` — M1-T1, M1-T2.
- `core/WhatGroup.lua` — M1-T1, M2-T3, M3-T1.
- `tests/test_frame.lua` — M1-T1, M1-T2.

**Everything else is disjoint** and safe to run concurrently:
`settings/Schema.lua` (M2-T1), `settings/Panel.lua` (M2-T2), `tests/run.lua` +
`tests/test_harness.lua` (M4-T1), `tests/test_mediasetup.lua` + `tests/test_libka0s.lua` (M4-T2),
`.pkgmeta` (M4-T3), `core/Compat.lua` (M5-T1). Note M4-T1 and M4-T2 both touch `docs/test-cases.md`
only through regeneration — regenerate once, after both land.

---

## Commit strategy

One commit per task, each green before it lands (`versioning-git`). Suggested messages:

| Task | Message |
|---|---|
| M1-T1 | `fix(frame): re-evaluate General visibility on combat transitions (WHATGROUP-R-01)` |
| M1-T2 | `fix(frame): arm the cooldown ticker only against a visible popup (WHATGROUP-R-02)` |
| M1-T3 | `docs: restate the performance-§12 ticker invariant now that the code holds it` |
| M2-T1 | `fix(taint): stop assigning the StaticPopupDialogs global (WHATGROUP-R-03)` |
| M2-T2 | `fix(panel): read MASTER_GROUP and addonName rather than restating them (WHATGROUP-R-04, -12)` |
| M2-T3 | `fix(notify): read autoShow when the timer fires, not when it is scheduled (WHATGROUP-R-14)` |
| M3-T1 | `fix(capture): key applications by search-result id, not FIFO order (WHATGROUP-R-07)` |
| M4-T1 | `test(harness): pin the suite list in both directions (testing-§9, WHATGROUP-R-05)` |
| M4-T2 | `test: widen the private-art sweep and assert the L-trap read its files (WHATGROUP-R-10, -11)` |
| M4-T3 | `chore(packaging): stop shipping screenshots and dev docs (WHATGROUP-R-09)` |
| M4-T4 | `chore: renormalize six paths against the CRLF pin (WHATGROUP-R-13)` |
| M5-T1 | `fix(compat): prefer C_SpellBook.IsSpellKnown (WHATGROUP-R-06)` — only after T-06 |

A **version bump is not part of this plan.** `WhatGroup.VERSION` / the TOC are moved by
`/wow-addon:bump-version` at release, which is also where `docs/automated-tests/` is regenerated and
`WHATGROUP-R-08`'s prose is re-pointed.
