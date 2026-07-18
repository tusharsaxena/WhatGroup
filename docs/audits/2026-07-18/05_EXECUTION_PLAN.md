# 05 — Execution Plan

**Addon:** Ka0s WhatGroup · **Standard:** v2.7.0 (2026-07-17) · **Date:** 2026-07-18

Ordered, checkable remediation for `02_DEVIATIONS.md`, grouped into sprints and keyed to
deviation IDs and the `04_TECHNICAL_DESIGN.md` themes. This is the hand-off to the separate
remediation engagement — **this audit changes no code.**

**Gate for every step:** test-first where logic exists → `lua tests/run.lua` green →
`luacheck .` clean before commit. Trunk-based, no version bump, no auto-commit (repo hard rules).

Baseline verified this audit: **48 tests pass**, **luacheck 0/0**.

---

## Sprint 1 — Secret-safe printer seam (blocks other work)

Do this first: WG-23 and WG-29 route through the seam it creates.

- [ ] **WG-22a** Add `core/Util.lua` with `NS.IsConcatSafe` + `NS.SafeToString` (probe
      `table.concat`, not `..`). List it first among the addon files in the TOC.
- [ ] **WG-22b** Rework `NS.Print` to prepend `NS.PREFIX` and stringify each arg via
      `NS.SafeToString`; reclaim it after `NewAddon` (or adopt `NS.Util.print`) per architecture-§2.
- [ ] **WG-22c** Route `NS.Debug`'s `...` through `NS.SafeToString` before `string.format`; keep
      the zero-alloc gate first.
- [ ] **WG-23** Rewrite `WhatGroup:ShowNotification` (and any other hand-built line) to call
      `NS.Print(label, value)` with pieces as separate args — remove every
      `print(CHAT_PREFIX .. …)` / `tostring` / `..` pre-concatenation. Sweep all 16 `print(` sites.
- [ ] **Tests:** new `test_util.lua` (nil/bool/string/table + a raises-in-concat "secret" →
      `<secret>`); extend `test_debuglog.lua` to prove the sink survives an unsafe arg.
- [ ] **Smoke:** `/wg test` — chat notification renders identically (labels, gold, em-dash).

## Sprint 2 — Slash surface

- [ ] **WG-29** Add a `version` verb to `COMMANDS` printing `[WG] v<version>` from
      `GetAddOnMetadata` (fallback `WhatGroup.VERSION`), through `NS.Print`.
- [ ] **WG-19** Drop the trailing `:` from the `printHelp` header string.
- [ ] **Tests:** assert `version` output and a colon-free help header.
- [ ] **Docs:** the landing page + README slash table regenerate from `COMMANDS` — confirm the new
      verb appears (run `wow-addon:sync-docs` if used).

## Sprint 3 — TOC & metadata

- [ ] **WG-14** Reorder `WhatGroup.toc` file-listing blocks to
      `Libraries → Locales → Core → Defaults → Modules → Settings`.
- [ ] **WG-09** Add `## X-Wago-ID: <id>` (last metadata line) **if** a Wago listing exists;
      otherwise record an accepted deviation (Curse-only) with a TOC comment + audit note.
- [ ] **Smoke:** in-game `/reload` + `/wg` + `/wg config` to confirm load order + panel intact.

## Sprint 4 — Settings & window polish

- [ ] **WG-25** Replace the runConfig combat branch with the grey canonical notice
      *"cannot open settings during combat — Blizzard's category-switch is protected"* (tagged,
      `|cff888888…|r`); keep refuse-and-return.
- [ ] **WG-24** *(user decision)* Either create `defaults/Profile.lua` (`NS.C` value table) and
      point each schema `default =` at it, **or** record an accepted deviation (schema is the
      single source) with an in-code comment. If splitting: assert `BuildDefaults` shape unchanged.
- [ ] **WG-26** Add `db.global.windows`; persist the popup and debug-console point on `OnDragStop`,
      restore on show (guard on `db` ready). *(Or persist only the console + accept the transient
      popup — user decision.)*
- [ ] **WG-28** Promote the console's `BACKDROP`/`applySkin` to shared `NS.SKIN` + `NS.ApplySkin`;
      apply from both windows.
- [ ] **Tests:** window geometry round-trip (store→restore) against the mock; `BuildDefaults` shape
      if WG-24 is split.
- [ ] **Smoke:** move + `/reload` → popup and console reopen at the saved spot.

## Sprint 5 — Docs

- [ ] **WG-27** Rename the `CLAUDE.md` section to `## Standards compliance (read first)` (keep
      substance); point the `docs/agent-context.md` first hard rule at it by name; replace the
      stale `§0` cross-ref. Pure docs.

## Sprint 6 — Accepted / no-action register

- [ ] **WG-17** *(accepted, documented)* AceTimer-3.0 not used — raw `C_Timer` with an in-code
      justification. No action unless the team elects to conform; kept on the register for
      visibility. Re-confirm the justification comment still reads true.

---

## Sequencing rationale

1. **Sprint 1 is the keystone** — the secret-safe seam is a prerequisite for WG-23 (call-site
   migration) and desirable before WG-29 (the new verb prints through it).
2. **Sprints 2–5 are independent** of each other and can be reordered or parallelised; each is a
   small, contained change with its own green gate.
3. **WG-24 and WG-26 carry the most judgement** (a defaults-file split; a new SavedVariables
   sub-tree with a transient-popup question) — surface the two "user decision" points before
   implementing, per the repo's stop-and-flag deviation rule.

## Definition of done

- Every MUST (WG-09, WG-14, WG-19, WG-22, WG-23, WG-24, WG-25, WG-26, WG-29) is closed **or** an
  explicit accepted-deviation note is recorded in-code and in the audit trail.
- SHOULDs (WG-17, WG-27, WG-28) closed or consciously accepted with an in-code comment.
- `lua tests/run.lua` green, `luacheck .` clean, `docs/test-cases.md` + README `[tests]` badge
  regenerated in lockstep with any suite change.
- No version bump and no commit/push unless the user asks in the working turn.
