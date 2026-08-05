# 04 — Execution plan

Implements `02_PROPOSED_CHANGES.md`. Five milestones. M1 is the only one with user-visible risk;
M4 is upstream and does not edit this repo's source at all.

---

## M1 — The master switch (blocking)

**Done when:** a disabled WhatGroup produces no capture, no chat line and no popup on a real join
(T-01), the two master-switch cases in `tests/test_capture.lua` have been **proven red** by deleting
the C-01 gate and reverting from a `cp` backup, and `docs/test-cases.md` + the README `[tests]` badge
have moved to the new count in the same commit.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T1.1** | wow-api-behavior | C-01 | `core/WhatGroup.lua` |
| **T1.2** | test-engineer | C-02 | `tests/test_capture.lua` |
| **T1.3** | test-engineer | C-02 (falsification) | *none* — mutate `core/WhatGroup.lua`, observe red, restore from `cp` backup |
| **T1.4** | docs | C-02 | `docs/test-cases.md` (regenerated), `README.md` (badge), `docs/capture-pipeline.md` (the flow diagram at `:38-92` must show the new gate) |

**Ordering:** T1.2 before T1.1 (testing-§4: write the failing test first — with the fixture fixed,
the case goes red against today's code, which is the proof F-002 asks for). T1.3 after T1.1. T1.4
last, because the count is only final once T1.2 is settled.

**Serialize:** T1.1 and T1.3 both touch `core/WhatGroup.lua` — the same file, and T1.3 deliberately
mutates and restores it. **Never run T1.3 concurrently with anything.**

---

## M2 — Read purity and the shared label helper

**Done when:** `Helpers.Get` of an absent nested path leaves `db.profile` untouched (new case, plus
T-03 in client), and the popup's playstyle row comes from `Labels.GetPlaystyleLabel`.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T2.1** | lua-refactorer | C-03 | `settings/Schema.lua` |
| **T2.2** | test-engineer | C-03 | `tests/test_settings.lua` |
| **T2.3** | lua-refactorer | C-04 | `modules/Frame.lua` |

**Parallelizable:** T2.1+T2.2 (settings) and T2.3 (frame) have **disjoint** file sets — run them
concurrently. T2.1 and T2.2 serialize against each other only by dependency order (test first).

**Against M1:** T2.3 touches `modules/Frame.lua`, which M3 also touches — see the map below.

---

## M3 — Frame hardening

**Done when:** one click yields exactly one cast and one console line in client (T-05), and the
popup builds with its teleport icon aligned from a cold profile (T-06).

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T3.1** | wow-api-behavior | C-05 | `modules/Frame.lua` |
| **T3.2** | lua-refactorer | C-07 | `modules/Frame.lua` |

**Serialize:** T3.1, T3.2 **and M2's T2.3** all touch `modules/Frame.lua`. Run them in the order
T2.3 → T3.1 → T3.2, or fold all three into one agent's pass over the file. They must not run
concurrently.

**Note:** neither C-05 nor C-07 is verifiable headlessly. The suite will stay green through both;
their evidence is T-05 and T-06.

---

## M4 — Upstream (cross-repo — does NOT edit this addon's source)

**Done when:** the LibKa0s repo carries the US-spelling fix with each touched file's LibStub minor
bumped, the vendor `diff -r` is clean, and this repo has a **re-vendor commit** whose diff contains
nothing but `libs/LibKa0s/**` (and `tests/_kit/**` if it moved).

| Task | Role | Implements | Repo | Files touched |
|---|---|---|---|---|
| **T4.1** | library-maintainer | U-01 | **LibKa0s** | `Core.lua`, `DebugLog.lua`, `Slash.lua`, `OptionsWidgets.lua`, `Perf.lua` — 29 comment words |
| **T4.2** | library-maintainer | U-01 | **LibKa0s** | bump each touched file's LibStub minor + the library's own changelog |
| **T4.3** | release-engineer | U-02 | **both** | run `diff -r libs/LibKa0s/ ../LibKa0s/<ship>/` and `diff -r tests/_kit/ ../LibKa0s/testkit/` from an unconstrained checkout |
| **T4.4** | release-engineer | U-01, U-02 | **WhatGroup** | re-vendor the whole `libs/LibKa0s/` folder — **one commit, nothing else in it** |

**Hard rule:** no task in this milestone may edit a file under `libs/` or `tests/_kit/` **in this
repo** by hand. T4.4 is a folder copy, not an edit. A local patch is reverted by the next
re-vendor and reappears as a regression with no cause in this repo's history (anti-patterns #45/#47).

**Ordering:** T4.1 → T4.2 → T4.3 → T4.4, strictly serial and strictly after M1–M3 (a re-vendor
landing mid-refactor makes a bisect over this cycle useless).

---

## M5 — Cleanups

**Done when:** the five dead locale rows are gone with no visible string change (T-07), and
`NS.Util.format`'s degraded path is either covered or removed.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T5.1** | ux-cleanup | C-06 | `locales/enUS.lua` |
| **T5.2** | test-engineer | C-08 | `tests/test_libka0s.lua` (or `core/CoreSetup.lua` if the delete option is chosen) |
| **T5.3** | docs | all | `docs/test-cases.md` (final regeneration), `README.md` (final badge), `docs/file-index.md` if any line count moved materially |

**Parallelizable:** T5.1 and T5.2 have disjoint file sets. T5.3 is last, alone.

---

## Critical-path / concurrency map

```
M1  T1.2 ─► T1.1 ─► T1.3 ─► T1.4          [core/WhatGroup.lua, tests/test_capture.lua]  SERIAL
                 │
                 ▼
M2  T2.1 ─► T2.2                          [settings/Schema.lua, tests/test_settings.lua]  ┐ parallel
    T2.3                                  [modules/Frame.lua]                             ┘
                 │
                 ▼
M3  T3.1 ─► T3.2                          [modules/Frame.lua]                            SERIAL with T2.3
                 │
                 ▼
M4  T4.1 ─► T4.2 ─► T4.3 ─► T4.4          [LibKa0s repo; then libs/LibKa0s/ as a copy]    SERIAL, cross-repo
                 │
                 ▼
M5  T5.1  ║  T5.2 ─► T5.3                 [locales/, tests/, docs/]                       T5.1 ∥ T5.2
```

**File-collision callouts:**
- `modules/Frame.lua` — **T2.3, T3.1, T3.2**. Three tasks, one file → must serialize (or merge).
- `core/WhatGroup.lua` — **T1.1, T1.3**. T1.3 mutates and restores it; nothing else may touch the
  working tree while it runs.
- `docs/test-cases.md` + `README.md` badge — **T1.4, T5.3**. Both regenerate the inventory; T5.3
  is the authoritative final run. Regenerate, never hand-edit.
- Everything else is disjoint.

---

## Checkpoints

| # | After | Human verifies |
|---|---|---|
| **CP-1** | T1.3 | The mutation genuinely reddened both master-switch cases and the tree was restored from the `cp` backup, not `git checkout`. This is the checkpoint that proves the whole review's central finding. |
| **CP-2** | M1 complete | `lua tests/run.lua` green at the new count; `docs/test-cases.md` byte-identical to a fresh `--list`; README badge matches. T-01 and T-02 run in client before M2 starts. |
| **CP-3** | M3 complete | T-05 and T-06 run in client. C-05 changes a secure frame; do not proceed to the re-vendor with an unverified secure-button change in the tree. |
| **CP-4** | Before T4.4 | The `diff -r` output is reviewed by a human. A re-vendor that silently pulls in unrelated library changes is how a consumer inherits a defect it never reviewed. |
| **CP-5** | M5 complete | Full `03_SMOKE_TESTS.md` sign-off table filled in. |

---

## Incremental commit strategy

One commit per task where the task stands alone; the inventory/badge always rides with the change
that moved the count (testing-§5).

| Commit | Tasks | Message |
|---|---|---|
| 1 | T1.2 | `tests: make the master-switch cases falsifiable (they passed with the gate deleted)` |
| 2 | T1.1 + T1.3 | `fix: honor the master switch on the inviteaccepted path (F-001)` |
| 3 | T1.4 | `docs: regenerate the test inventory and badge for the master-switch cases` |
| 4 | T2.1 + T2.2 | `fix: Helpers.Get no longer materializes profile keys on a read (F-003)` |
| 5 | T2.3 | `refactor: the popup uses Labels.GetPlaystyleLabel instead of a second copy (F-004)` |
| 6 | T3.1 | `fix: the secure teleport button registers one click edge, not two (F-005)` |
| 7 | T3.2 | `fix: guard the derived secure-button offsets against an unresolved rect (F-007)` |
| 8 | T4.4 | `vendor: re-vendor LibKa0s <version> (US-spelling sweep, upstream F-U01)` — **this commit contains nothing but `libs/LibKa0s/**`** |
| 9 | T5.1 + T5.2 | `cleanup: drop five dead locale rows; cover the degraded Util.format path` |
| 10 | T5.3 | `docs: final test inventory and badge regeneration for this cycle` |

Do **not** squash commit 8 into any other. Its whole value is being identifiable as a folder copy
when someone later bisects a library-sourced behavior change.
