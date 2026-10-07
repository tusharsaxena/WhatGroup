# WhatGroup — execution plan (2026-10-07 review)

This plan is for the branch `feat/2026-10-07-review-audit-remediation`, the cross-repo exercise's shared
branch name. Each commit must pass the green gate: `lua tests/run.lua` and `luacheck .` at 0/0. Nothing
here edits `libs/` or `tests/_kit/`.

## Milestones

### M1 — Secret-safe cooldown reader (F-001, F-002)

Done when C-001 and C-002 are in and the suite is green at **917 passed**, with `docs/test-cases.md` and
the README badge moved in the same commit.

| Task | Role | Implements | Files |
|---|---|---|---|
| WG-M1-1 | test-author | C-002 (F-002): secret helper in the mock, and 3 red-first cases | `tests/wow_mock.lua`, `tests/test_compat.lua`, `tests/test_frame.lua`, `tests/test_notify.lua` |
| WG-M1-2 | lua-refactorer | C-001 (F-001): `Compat.IsSecret` guard arm, the two-return reader, the ticker and the `teleportValue` call sites | `core/Compat.lua`, `modules/Frame.lua`, `core/WhatGroup.lua` |
| WG-M1-3 | docs | C-001 docs, plus the inventory and badge | `docs/compat-layer.md`, `docs/module-map.md`, `docs/test-cases.md`, `README.md` |

Order: write WG-M1-1's cases first and watch them go **red** against today's code (the
`red under:` comments must be true). Then do WG-M1-2, then WG-M1-3.

### M2 — The one-shot test stops overwriting the real capture (F-003, F-004)

Done when C-003 is in, the suite is green at **918 passed**, and the inventory and badge have moved.

| Task | Role | Implements | Files |
|---|---|---|---|
| WG-M2-1 | test-author | C-003 tests: rewrite `test_lifecycle.lua:485-493`, add a test-mode case, retarget the two `pendingInfo.mapID == 2805` assertions | `tests/test_lifecycle.lua`, `tests/test_testmode.lua` |
| WG-M2-2 | lua-refactorer | C-003: `NS.FramePreviewOnce`, `ShowNotification(info)`, `RunTest` | `modules/Frame.lua`, `core/WhatGroup.lua` |
| WG-M2-3 | docs | the C-003 doc edits, plus the inventory and badge | `docs/slash-dispatch.md`, `docs/scope.md`, `docs/frame.md`, `docs/module-map.md`, `docs/test-cases.md`, `README.md` |

### M3 — Correct stale text (F-005, F-006, F-007)

Done when C-004, C-005 and C-006 are in. C-005's figures come from a `tests/perf.lua` run taken
**after** M1 and M2.

| Task | Role | Implements | Files |
|---|---|---|---|
| WG-M3-1 | ux-cleanup | C-004 (F-005) | `settings/Schema.lua`, `modules/Frame.lua` (comment only) |
| WG-M3-2 | docs | C-005 (F-006): bisect the 18 → 19 API-count move, then re-measure | `docs/performance.md` |
| WG-M3-3 | docs | C-006 (F-007) | `core/WhatGroup.lua` (comment only) |

### M4 — Upstream handoffs (F-008, F-009). These are separate repos, not tasks in WhatGroup

| Task | Repo | Implements | Exit |
|---|---|---|---|
| WG-M4-1 | WowAddonStandards | U-1 (F-008): extend the `events-frames-taint-§8` named-API list | A standard version bump commit in WowAddonStandards. WhatGroup needs no commit beyond M1 |
| WG-M4-2 | LibKa0s | U-2 (F-009): additive `testkit` secret simulator, `Kit.VERSION` 38 | **Re-vendor commit** in WhatGroup: `tests/_kit/` replaced whole from the new tag, then a follow-up that switches C-002's local helper to the kit's and deletes the local copy |

Both are cross-repo. Hand them to the consolidated plan in `Ka0sAddonsCommonTasks`, because other
addons (MultiMeters for U-2, every consumer for U-1) are in scope too.

## Critical path and what can run in parallel

- **`modules/Frame.lua`:** WG-M1-2, WG-M2-2 and WG-M3-1. These must run in that order.
- **`core/WhatGroup.lua`:** WG-M1-2, WG-M2-2 and WG-M3-3. These must run in that order.
- **`docs/test-cases.md` and `README.md`:** WG-M1-3 and WG-M2-3. These must run in order, because each
  regenerates from its own milestone's count.
- **`docs/module-map.md`:** WG-M1-3 and WG-M2-3, in order.
- **Can run in parallel:** WG-M1-1 with any docs-only task. WG-M3-2 is independent in files but must
  wait for M1 and M2 to finish (it measures them). WG-M4-1 and WG-M4-2 can run alongside everything,
  in other repos.

## Checkpoints

1. **Before M1:** the owner runs **S-001** on the current build. If the cooldown is *not* secret on
   12.1.0, M1 still lands as a defensive fix, but F-001 is downgraded to Medium in the consolidated
   record.
2. **After M1:** run the green gate, then smoke C-001 in client.
3. **After M2:** run the green gate, then smoke TEST-1 to TEST-4. The test-mode state machine is the
   riskiest code in the addon.
4. **After M3:** run the green gate. Release regeneration of `docs/automated-tests/` is **not** part
   of this plan (`/dev-copilot:bump-version` owns it).

## Commits

One commit per task, with the task id as the subject prefix (the collection's checkpointed-plan
convention):

- `WG-M1-1: mock a secret cooldown; red cases for the combat ticker and teleport row (F-002)`
- `WG-M1-2: ask IsSecret before comparing a spell cooldown (F-001)`
- `WG-M1-3: document the cooldown reader's readable flag; inventory 917`
- `WG-M2-1: pin that the one-shot test leaves the real capture alone (F-003, F-004)`
- `WG-M2-2: preview /wg test notify through its own record, never pendingInfo (F-003, F-004)`
- `WG-M2-3: test-notify docs; inventory 918`
- `WG-M3-1: Height tooltip states the shipped 280 (F-005)`
- `WG-M3-2: re-measure docs/performance.md (F-006)`
- `WG-M3-3: correct reloadProfile's migration comment (F-007)`
- Later, in WhatGroup: `chore: re-vendor LibKa0s testkit (kit 38)` and
  `WG-M4-2: use the kit's secret simulator`

No version bump, tag or merge without the owner's explicit go-ahead.
