# Ka0s WhatGroup — Execution Plan (2026-08-03)

Implements `02_PROPOSED_CHANGES.md` (C-01 … C-10), verified by `03_SMOKE_TESTS.md`.

**Ground rules for every task**

- Trunk-based: work directly on `master`. **Do not create a branch** unless the human explicitly
  asks (versioning-git, anti-patterns #21).
- TDD: the test lands with (or before) the code (testing, anti-patterns #24).
- Commit only on green — `lua tests/run.lua` passing **and** `luacheck .` clean (versioning-git,
  anti-patterns #23).
- **No task in this plan edits anything under `libs/` or `tests/_kit/`.** There is no upstream
  milestone in this plan because this review raised no `[upstream]` findings — the vendored copies
  are byte-identical to their source repo. If a task ever finds itself wanting to edit one, stop:
  that is a library-repo change plus a minor bump plus a re-vendor commit, and it is its own
  milestone.

---

## Milestone M1 — Correctness (the bug and the data-safety seam)

**Done when:** C-01, C-02, C-03, C-06 are implemented with covering tests, the suite is green, lint
is clean, and smoke tests C-01-a/b/c, C-02 and C-06-a/b pass in-client.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M1-T1 | lua-refactorer | C-01 (F-001) | `core/WhatGroup.lua`, `modules/Frame.lua`, `tests/test_frame.lua` |
| M1-T2 | lua-refactorer | C-02 (F-006), C-03 (F-009) | `core/WhatGroup.lua`, `tests/test_capture.lua` |
| M1-T3 | savedvariables-migrator | C-06 (F-004) | `core/Database.lua`, `tests/test_database.lua` |

**Serialization:** M1-T1 and M1-T2 both edit `core/WhatGroup.lua` → **must serialize** (T1 then T2).
M1-T3 touches a disjoint file set → **parallelizable** with either.

**Test additions required**

- `tests/test_frame.lua`: keep the existing "restores a pendingInfo cleared during the wait" case
  (it must still pass, unwiped path); add "a WipeCapture during the wait is NOT undone", and
  "after a wiped deferral, an in-group roster transition fires no notify". The second is the one
  that would have caught F-001.
- `tests/test_capture.lua`: "a declined/cancelled status drops the queued application"; "the
  captured table always carries a string `shortName`, even with no activity info".
- `tests/test_database.lua`: "a future schemaVersion is left untouched"; "a current DB emits no
  `[Migrate]` line".

---

## Milestone M2 — Convergence and hardening

**Done when:** C-04, C-05, C-07, C-08 are implemented, the suite is green, lint is clean, and smoke
tests C-03/C-04, C-05, C-07 and C-08 pass in-client.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M2-T1 | lua-refactorer | C-04 (F-002) | `modules/Frame.lua`, `tests/test_frame.lua` |
| M2-T2 | wow-api-migrator | C-05 (F-003) | `core/Compat.lua`, `settings/Panel.lua`, `settings/Slash.lua`, `tests/test_compat.lua`, `docs/file-index.md` |
| M2-T3 | lua-refactorer | C-07 (F-005) | `modules/Frame.lua` |
| M2-T4 | options-panel-wiring | C-08 (F-013) | `settings/OptionsSetup.lua`, `tests/test_panel.lua` |

**Serialization:** M2-T1, M2-T3 (and M1-T1) all edit `modules/Frame.lua` → **must serialize**;
run M2-T1 then M2-T3 after M1-T1 has landed. M2-T2 and M2-T4 have disjoint file sets from those and
from each other → **parallelizable**.

**Test additions required**

- `tests/test_frame.lua`: assert the popup's Playstyle text equals
  `NS.addon.Labels.GetPlaystyleLabel(info)` for both the string and enum inputs (so a future
  divergence goes red rather than unnoticed).
- `tests/test_compat.lua`: `Compat.GetAddOnMetadata` prefers `C_AddOns`, falls back to the global,
  and returns nil when neither exists — the same three-case shape the other shims already use.
- `tests/test_panel.lua`: the Defaults-button scheduling flag is cleared after the deferred hop.

---

## Milestone M3 — Housekeeping

**Done when:** C-09 is implemented, the suite is green, lint is clean, smoke test C-09 and
regression R-14 pass.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M3-T1 | ux-cleanup | C-09 items 1 & 4 (F-008, F-012) | `locales/enUS.lua`, `settings/Panel.lua`, `settings/Slash.lua` |
| M3-T2 | lua-refactorer | C-09 items 2 & 3 (F-010, F-011) | `core/WhatGroup.lua`, `tests/test_capture.lua`, `.luacheckrc` |

**Serialization:** M3-T1 touches `settings/Panel.lua` and `settings/Slash.lua`, which M2-T2 also
touches → **must run after M2-T2**. M3-T2's `core/WhatGroup.lua` overlaps M1-T1/M1-T2 → **must run
after M1**. M3-T1 and M3-T2 are **parallelizable with each other**.

---

## Milestone M4 — Release hygiene (run last, at release time)

**Done when:** C-10 is implemented and smoke test C-10 passes — the in-game version, the TOC, the
code constant, `## What's new` and the top `## Version History` row all name the same version.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| M4-T1 | release-manager | C-10 (F-007) | `WhatGroup.toc`, `core/WhatGroup.lua`, `README.md` |

**Serialization:** strictly last — it names the version that the preceding milestones' work ships
under, and it touches `core/WhatGroup.lua`, which M1 and M3 also touch.

**Note:** the `## Interface:` line is a **different** axis (toc-file-§3) driven by
`wow-addon:bump-interface`, and is out of scope for M4 unless a retail patch has landed.

---

## Critical path

```
M1-T1 ──► M1-T2 ──────────────► M3-T2 ──┐
                                        ├──► M4-T1
M1-T3 (parallel) ───────────────────────┤
                                        │
M2-T1 ──► M2-T3 ────────────────────────┤
M2-T2 ──────────────► M3-T1 ────────────┘
M2-T4 (parallel, no overlap) ───────────┘
```

**File-overlap map (the "must serialize" reasons in one place)**

| File | Tasks touching it |
|---|---|
| `core/WhatGroup.lua` | M1-T1, M1-T2, M3-T2, M4-T1 |
| `modules/Frame.lua` | M1-T1, M2-T1, M2-T3 |
| `settings/Panel.lua` | M2-T2, M3-T1 |
| `settings/Slash.lua` | M2-T2, M3-T1 |
| `tests/test_frame.lua` | M1-T1, M2-T1 |
| `tests/test_capture.lua` | M1-T2, M3-T2 |
| Disjoint (fully parallel) | M1-T3 (`core/Database.lua`), M2-T4 (`settings/OptionsSetup.lua`) |

---

## Checkpoints

- **CP-1 — after M1, before M2.** Human verifies C-01-c in-client (the actual F-001 repro). This is
  the only finding with user-visible wrong output; do not stack refactors on top of an unverified
  fix.
- **CP-2 — after M2-T2, before M3-T1.** Human confirms `/wg version` and the landing page's Notes
  line still render correctly — the metadata seam feeds two visible surfaces and the two call sites
  previously degraded differently.
- **CP-3 — after M3, before M4.** Full run of `03_SMOKE_TESTS.md` including the regression suite and
  the taint tests, plus regression R-14 (library-absent load) — M3 touches the degraded-path strings.
- **CP-4 — before M4-T1 is committed.** Human decides the semver level for the `/wg reset`
  re-specification (breaking user-facing command surface) and states the reasoning in the commit
  message.

---

## Incremental commit strategy

One commit per task, each green. Suggested messages (imperative, finding IDs in the body):

| Task | Commit message |
|---|---|
| M1-T1 | `Gate the combat-deferred popup restore on a wipe generation (F-001)` |
| M1-T2 | `Reclaim dead LFG applications; seed shortName in the capture shape (F-006, F-009)` |
| M1-T3 | `Let the migration loop own the schemaVersion advance (F-004)` |
| M2-T1 | `Popup reads the shared playstyle label instead of re-deriving it (F-002)` |
| M2-T2 | `Route addon-metadata reads through Compat (F-003)` |
| M2-T3 | `Fall back to layout constants when the teleport anchor rect is unresolved (F-005)` |
| M2-T4 | `Clear the deferred Defaults-button latch after the hop (F-013)` |
| M3-T1 | `Drop orphaned locale keys; match the addon's chat voice (F-008, F-012)` |
| M3-T2 | `Remove the unread playstyle alias and stale lint globals (F-010, F-011)` |
| M4-T1 | `Release <X.Y.Z>: roll What's new and Version History forward (F-007)` |

Each body should carry a `Review: docs/reviews/2026-08-03/` line so the artifacts are findable from
`git log`.
</content>
