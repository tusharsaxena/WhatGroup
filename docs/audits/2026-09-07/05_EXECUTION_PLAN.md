# 05 — Execution plan (2026-09-07)

Ordered, checkable remediation steps for the **14 root** deviations (**15 including the one
dependent**) catalogued in `02_DEVIATIONS.md`. Every step names its deviation ID and its own
verification. Designs are in `04_TECHNICAL_DESIGN.md`.

**Gate on every commit** (`testing-§4`): `luacheck .` clean **and** `lua tests/run.lua` green.
Baseline to hold against, measured today: `0 warnings / 0 errors in 16 files` and
`528 passed, 0 failed, 0 skipped, 528 total`.

**Read-only reminder:** this audit changed nothing. The tree at hand-off is HEAD `ce572a3`, clean.

---

## Sprint 0 — Whitespace, alone (WG-46)

Done first and in its own commit, so no later content diff is buried under a renormalization.

- [ ] **0.1** `git add --renormalize .`; `git status` and confirm the staged set is **six paths** and
      that every one of them is a text file the pin covers. Commit. (The six are not enumerated here
      on purpose — the fix is one action, and a per-file list invites treating it as six.) — **WG-46**
- [ ] **0.2** For each straggler, `rm <path> && git checkout -- <path>` so the working tree matches
      the index. — **WG-46**
- [ ] **0.3** Re-run the `AUDIT.md` (e) one-liner (`03_EVIDENCE.md` §1.5). **Must print `0`.**
- [ ] **0.4** `git ls-files -s tests/_kit/run-automated-tests.sh` still reads **`100755`**, and
      `tests/_kit/run-automated-tests.sh` still has **no** CR bytes (`tr -dc '\r' < … | wc -c` → 0).
- [ ] **0.5** Green gate.

**Exit:** stragglers `0`; suite and lint unchanged.

---

## Sprint 1 — Upstream first, so nothing here waits on it (WG-50, WG-51, and the two standard questions)

Two `gh issue create` calls on `LibKa0s`, two on `WowAddonStandards`, one tracker here. No code.

- [ ] **1.1** File on `tusharsaxena/LibKa0s`: *runner emits no `skipped` figure* — `RESULTS.md` tests
      column and `manifest.json` `tests` object. Labels `state:triaged`, `severity:low`. Cite
      `automated-tests-§4` and this bundle. — **WG-50**
- [ ] **1.2** File on `tusharsaxena/LibKa0s`: *consumer-side vendored-payload gate does not assert
      `run-automated-tests.sh` is recorded `100755`*. Labels `state:triaged`, `severity:low`. Cite
      `automated-tests-§2`. — **WG-51**
- [ ] **1.3** File on `tusharsaxena/WowAddonStandards`: `documentation-§3`'s *three tables* vs the
      five verification-and-record docs it places outside the tier model; and whether
      `ARCHITECTURE.md` registers itself. — **WG-60**
- [ ] **1.4** File on `tusharsaxena/WowAddonStandards`: `documentation-§1` item 7's `Tab | Covers`
      header vs its page-granularity requirement. — **WG-56** *(blocks step 3.4 — decide there
      before editing the README)*
- [ ] **1.5** File one tracking issue on this repo referencing 1.1 and 1.2, labels `state:triaged`,
      `severity:low`, so the next audit sees them owned. Add a *known kit gaps* line to
      `docs/testing.md` naming both. — **WG-50, WG-51**

**Throttle:** space the `gh` write calls out; five creates is comfortably under any limit but the
collection's habit is to go slowly.

**Exit:** five issue URLs recorded; `docs/testing.md` names the two kit gaps.

---

## Sprint 2 — The two substantive docs (WG-53, WG-57, WG-52)

The only sprint with real writing in it.

- [ ] **2.1** Write `docs/compat-layer.md` per `04_TECHNICAL_DESIGN.md` D-6: why the layer exists,
      one row per shim (seven, at `core/Compat.lua:24,40,52,62,83,105,125`), the degrade-to-nil
      contract, and a **link** to `docs/frame.md:95-97` rather than a second copy of the cooldown
      narrative. — **WG-53**
- [ ] **2.2** Flip `docs/ARCHITECTURE.md:316` from `Not applicable` to `Present`, with the trigger
      restated as *seven addon-specific shims; LibKa0s supplies no Compat major*. — **WG-53**
- [ ] **2.3** Add the new file to `## Documentation map` — it belongs in the **Conditional (Tier 2)**
      table, which already has its row; only the Status and Trigger cells change. Confirm no `.md`
      under `docs/` is now uncovered or double-covered. — **WG-53**
- [ ] **2.4** Extend `docs/ARCHITECTURE.md`'s `## Message Bus` paragraph to name
      `modules/Frame.lua:318` and `:635` and state why a transient, self-unregistering `CreateFrame`
      registration is not the second party `architecture-§4`'s clobber rationale is about — plus the
      threshold that *would* bind. — **WG-57**
- [ ] **2.5** Correct the register's Rule cell at `docs/ARCHITECTURE.md:352`:
      `standalone-windows-§33` → `standalone-windows`, and quote the SHOULD's own words in
      *What differs* so the row stays checkable. Leave *Decided* at 2026-08-25. — **WG-52**
- [ ] **2.6** Green gate. (Docs only — the suite should not move.)

**Exit:** `docs/compat-layer.md` exists and is mapped; no Tier 2 row asserts a false *Not
applicable*; the register carries no unresolvable `filename-§N`.

---

## Sprint 3 — Text and config one-liners (WG-54, WG-55, WG-56, WG-58, WG-59)

- [ ] **3.1** Spelling sweep over the **three named scopes only** — shipped source
      (`core/ defaults/ locales/ modules/ settings/`), live `docs/*.md`, and `tests/` **excluding**
      `tests/_kit/`. The 20 sites are listed in `03_EVIDENCE.md` §2.7. **Do not touch** `libs/`,
      `tests/_kit/`, `docs/audits/`, `docs/reviews/`, `docs/superpowers/`,
      `docs/automated-tests/`, `docs/revendor/`. — **WG-54**
- [ ] **3.2** Regenerate the inventory: `lua tests/run.lua --list > docs/test-cases.md`. The case
      **name** at `tests/test_settings.lua:676` changed, so the file changes; the **count** does not,
      so `README.md:7`'s `528%2F528` badge stays. Confirm both. — **WG-54**
- [ ] **3.3** `README.md:121`: `Notify` → `Chat`, so the top Version History row agrees with
      `## What's new` at `:21` and with `settings/Schema.lua:149`'s `group = "Chat"`. — **WG-55**
- [ ] **3.4** *Gated on 1.4.* If the upstream question is declined, collapse `README.md:69-73` to one
      row per **page** and link `docs/settings-panel.md`; keep the three prose paragraphs. If the
      standard is amended instead, close **WG-56** citing the amendment. — **WG-56**
- [ ] **3.5** `.pkgmeta`: add the `.superpowers` ignore row beside `.claude` (`:14`), and either a
      `.pkgmeta` row or a comment saying the packager consumes and drops it. Re-run both dot-entry
      sweeps from `03_EVIDENCE.md` §1.6 — the first must print nothing, the second only `.git`. — **WG-58**
- [ ] **3.6** `.luacheckrc:9`: add `"_dev/"` to `exclude_files`, agreeing with `.pkgmeta:12`.
      `luacheck .` must still read `0 warnings / 0 errors in 16 files`. — **WG-59**
- [ ] **3.7** Green gate.

**Exit:** zero British-spelling hits in the three swept scopes; README internally consistent; both
config files account for the same dev-only paths.

---

## Sprint 4 — Annotate the TOC (WG-47)

Deliberately after the doc work and before the record refresh: it is the one step that touches the
shipped `.toc`, and it wants a quiet diff.

- [ ] **4.1** Add the four load-bearing comments per `04_TECHNICAL_DESIGN.md` D-2, each **naming what
      resolves** — not merely *"order matters"*. Write `settings\Schema.lua` and
      `settings\OptionsSetup.lua` as one block above the `# Settings` group rather than two
      near-identical stanzas. — **WG-47**
- [ ] **4.2** Add one *conventional* note to `# Defaults` and one to `# Modules`, in the vocabulary
      already at `WhatGroup.toc:40`. — **WG-47**
- [ ] **4.3** **Reorder nothing.** Confirm `git diff --stat WhatGroup.toc` shows insertions only, and
      that `git diff -w` on the non-comment lines is empty.
- [ ] **4.4** Re-verify each claim before committing it: `core/DebugLogSetup.lua:120,139`,
      `core/WhatGroup.lua:115`, `settings/Schema.lua:27`, `settings/Panel.lua:204,262-264`. A comment
      that is *wrong* is worse than none (anti-pattern #66).
- [ ] **4.5** Green gate — `tests/test_harness.lua` derives its load list **from the TOC**, so a
      malformed comment line would surface here rather than in the client.
- [ ] **4.6** Confirm the file still ends in a single trailing newline (`toc-file-§5`).

**Exit:** every file-scope-resolving position annotated; every group labelled; load order byte-identical.

---

## Sprint 5 — Refresh the record, last (WG-48, WG-49)

Last on purpose: the bundle this produces should describe the tree the remediation leaves behind.

- [ ] **5.1** Run `tests/_kit/run-automated-tests.sh`. Do not edit the vendored script. — **WG-48**
- [ ] **5.2** Roll `RESULTS.md`'s four standing sections forward to the new run — test suite (say
      *why* the count moved: the settings revamp, plus one renamed case from 3.1), lint (16 files
      now, same scope caveat), perf (unchanged permanent `skip`, keep the `performance-§12` note),
      and the watch list (still empty; ceiling function unchanged at CCN 15, now at
      `core/WhatGroup.lua:675-738`). — **WG-48**
- [ ] **5.3** Re-anchor `RESULTS.md:109`: `modules/Frame.lua:146` → `:275`. — **WG-48**
- [ ] **5.4** Write the new bundle's `ANALYSIS.md`, per the root `AUTOMATED_TESTS.md` prompt. — **WG-48**
- [ ] **5.5** Decide the two historical bundles: backfill `ANALYSIS.md`, **or** add one line to
      `RESULTS.md` stating that non-release runs do not get a write-up. State which; do not leave two
      silent gaps. — **WG-49**
- [ ] **5.6** Re-run the whole `03_EVIDENCE.md` Part 1 sweep and confirm the record now matches the
      tree: `luacheck` files, suite total, `lizard` NLOC/functions/warnings.

**Exit:** the newest bundle's numbers reproduce today's measurement; no standing section names an
older run than the table's top row; no stale `file:line` in `RESULTS.md`.

---

## Not in scope for this engagement

- **The five ratified register rows** (`performance-§12` ×2, `localization-§3`,
  `events-frames-taint-§8`, `standalone-windows`). Confirmed, not reopened; only WG-52's citation is
  touched, and it changes no decision.
- **Wiring `LibKa0s-Perf-1.0`.** The re-check row's two triggers have not fired
  (`03_EVIDENCE.md` §1.8, §2.6). Re-arming it is a decision, not remediation.
- **Adopting a message bus.** WG-57's fix is a paragraph; the bus itself would be a change out of
  proportion to a Low finding on a single-module addon.
- **Any version bump.** Nothing here is user-visible.

## Definition of done

- [ ] All 14 root IDs are closed, or carry a filed upstream issue number (WG-50, WG-51, WG-60, and
      WG-56 if declined upstream).
- [ ] The `AUDIT.md` (e) one-liner prints `0`.
- [ ] Both dot-entry sweeps are clean but for `.git`.
- [ ] `docs/compat-layer.md` exists, is mapped, and duplicates no Tier 1/2 content.
- [ ] Every `filename-§N` in `docs/ARCHITECTURE.md`'s register resolves against v2.38.0.
- [ ] `luacheck .` `0/0`; `lua tests/run.lua` green with the count `docs/test-cases.md` and
      `README.md:7` both state.
- [ ] The newest `docs/automated-tests/` bundle reproduces on re-run.
