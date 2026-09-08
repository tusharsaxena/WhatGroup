# 05 — Execution plan (2026-09-08)

Ordered, checkable steps for the seven roots and one dependent in `02_DEVIATIONS.md`, keyed to their
IDs. Read as one document with `02` and `04`: every count here is the one those carry — **7 roots,
8 including dependents; 5 Low, 2 Info; 5 MUST failures among the roots**.

**This bundle changes nothing.** It is the hand-off to a separate remediation engagement.

**Gate on every commit** (`versioning-git`, `testing`): `luacheck .` clean and `lua tests/run.lua`
green. Both are green at `58bc280` today — 0/0 over 41 files, 559/559 — so any red is the step's own.

---

## Sprint 1 — the register and its gate (WG-61, WG-63)

One commit, because splitting it puts the suite red in between.

- [ ] **1.1 (WG-61)** In `docs/ARCHITECTURE.md:369`, replace the `Why` cell's trailing `` `WG-R-06`. ``
      with `` `F-006` (`docs/reviews/2026-08-05/`). ``
      *Check:* `grep -n 'F-006' docs/ARCHITECTURE.md` → one hit;
      `grep -n '### F-006' docs/reviews/2026-08-05/01_FINDINGS.md` → `172:`.
- [ ] **1.2 (WG-61)** In `docs/ARCHITECTURE.md:370`, replace `` `WG-A-08`. `` with
      `` `WG-37` (`docs/audits/2026-08-05/`). ``
      *Check:* `grep -n '### WG-37' docs/audits/2026-08-05/02_DEVIATIONS.md` → `113:`.
- [ ] **1.3 (WG-61)** Rewrite the key at `docs/ARCHITECTURE.md:360-364` to name the three id schemes
      the repo's history actually uses — `WG-NN` under `docs/audits/`, `F-NNN` for the 2026-05 and
      2026-08 reviews, `WHATGROUP-R-NN` for 2026-09-07 onward — and drop the `WG-R-NN` / `WG-A-NN`
      shorthands, which have no assignment site anywhere.
      *Check:* `grep -c 'WG-R-\|WG-A-' docs/ARCHITECTURE.md` → `0`.
- [ ] **1.4 (WG-63)** In `tests/test_register.lua:94`, stop excluding `%-R%-` ids and resolve them
      against a second corpus, `docs/reviews/*/*.md`.
- [ ] **1.5 (WG-63)** In `tests/test_register.lua:59-77`, narrow `isAssigned` so an id counts only
      where it heads a `### ` heading — the form every bundle actually uses to assign one — rather
      than any table cell. This is what stops a bundle's *Recorded deviations* echo from
      "assigning" the id it is merely quoting.
- [ ] **1.6 (WG-63) — the falsifiability proof, and it is not optional** (`testing-§12`). Put
      `WG-A-08` back into the register by hand, run `lua tests/run.lua`, and confirm the case goes
      **red**. Then revert. A gate for this MUST that cannot fail is the failure the MUST exists to
      catch, one level up. Record the mutation and the failure in the commit body.
- [ ] **1.7** `luacheck .` clean, `lua tests/run.lua` green, `docs/test-cases.md` regenerated if
      any case name changed, and the README `[tests]` badge moved with it.

**Done when:** every id the register cites resolves to a `### ` heading in a bundle under
`docs/audits/` or `docs/reviews/`, and re-introducing either dead id turns the suite red.

## Sprint 2 — the citations and the two words (WG-62, WG-54)

Two commits. They touch the same file (`core/WhatGroup.lua`) and are kept apart because one is a
spelling sweep and the other is a reference sweep, and a mixed diff is unreviewable.

### 2a — WG-62, ten unresolvable citations

- [ ] **2a.1** `lint-§1` → `lint` at eight sites: `.luacheckrc:13`, `:19`, `:73`;
      `docs/testing.md:299`; `tests/test_lintconfig.lua:1`, `:131`, `:151`, `:262`. Two of those
      are inside assertion message strings and one is a file header; none is matched on, so no case
      result changes.
- [ ] **2a.2** `code-quality-§3` → `performance-§10` at two sites: `core/WhatGroup.lua:744` and
      `docs/module-map.md:17`. The latter is one very long table cell — edit the token in place, do
      not reflow the row.
- [ ] **2a.3** Add the range-check to `tests/test_doc_structure.lua`, in `04`'s **option 2** form:
      assert that no `filename-§N` in the repo names one of `documentation-§6`'s eleven
      bare-filename sections, and that every cited `filename` is in the 26-name Sections list.
      Hard-code both name lists with a comment saying they are copied from `documentation-§6`.
- [ ] **2a.4** *Check, and it is the same command `03` §F used:* extract every `filename-§N` over
      the 66 tracked non-vendored non-frozen files and range-check it against
      `grep -c '^### [0-9]'`. Expect **0** offending sites, down from 10.
- [ ] **2a.5** *Check the SHOULD half has not regressed:*
      `grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits --exclude-dir=reviews --exclude-dir=automated-tests --exclude-dir=.git | wc -l` → `0`.

### 2b — WG-54, two British spellings

- [ ] **2b.1** `core/WhatGroup.lua:60` `travelled` → `traveled`.
- [ ] **2b.2** `core/WhatGroup.lua:779` `behaviour` → `behavior`.
- [ ] **2b.3 — do not touch `cancelled`.** `core/WhatGroup.lua:740`, `docs/data-flow.md:56` and
      `tests/test_capture.lua:433` carry `C_LFGList`'s own application-status token, which
      `localization-§5`'s Blizzard-symbol exception requires verbatim. Renaming
      `APPLICATION_ENDED.cancelled` breaks the dispatch at `core/WhatGroup.lua:776` and the suite
      will say so — but a reviewer who does not know why the word is there will ask, so say it in
      the commit body.
- [ ] **2b.4** Add `tests/test_prose.lua` carrying `localization-§5`'s `BRITISH` and `ALLOWED`
      lists **whole** (the section MUSTs both or neither), removing `ALLOWED` as delimited whole
      words before the substring scan, naming the four exclusions file-by-file in the test, and
      excluding its own file.
- [ ] **2b.5** *Check:* the new case is green, and adding `colour` to any source comment turns it
      red. Without that second half the case is green against nothing.

**Why this sprint matters more than its grade suggests:** both of its findings were **written by
this cycle**, hours after the pass that swept the previous instances. Neither had a gate. The gates
in 2a.3 and 2b.4 are the actual deliverable; the ten renames and two words are the easy part.

## Sprint 3 — one config line (WG-58)

- [ ] **3.1** Add `  - .superpowers  # dev-only agent tooling; named by packaging's ignore list
      whether or not it exists` to `.pkgmeta`, beside `.claude` at `:19`.
- [ ] **3.2** *Check, and it is `AUDIT.md`'s own (a):*
      `for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; do grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done`
      → **no output**. And (b) still prints only `UNACCOUNTED — .git`.

**Or, instead of 3.1:** take the unconditional-weak-form question upstream, and if it is declined
there, write the row in `docs/ARCHITECTURE.md` → `## Documented deviations` citing `packaging` with
a Decided date and a re-check trigger (*"a tool creates `.superpowers/` in this repo"*). Do **not**
leave the decline in a cycle bundle — `documentation-§3` is explicit that a deviation not in the
register is not ratified, and this audit would re-file it next cycle.

## Sprint 4 — upstream, not here (WG-51, WG-56)

Neither is fixable in this repository. Both are filed so the next audit does not re-derive them.

- [ ] **4.1 (WG-51)** Open an issue on `LibKa0s` for `testkit/vendor_sync.lua`: assert
      `git ls-files -s tests/_kit/run-automated-tests.sh` reports `100755`, per `automated-tests-§2`.
      `04` carries the assertion. Note that `M1-LK-07` closed this item's sibling (the manifest
      `skipped` key, now visible at `docs/automated-tests/20260908-181437/manifest.json`) and not
      this half, and that `LibKa0s` HEAD still has no such assertion.
- [ ] **4.2 (WG-51)** Mirror it here as a `state:triaged` issue with `severity:low`, so the item has
      a home in this repo's own store (`audit-review-history`). No register row: this is an open
      defect, not a ratified deviation.
- [ ] **4.3 (WG-56)** Open a `WowAddonStandards` issue for `documentation-§1` item 7: the column
      header it names (`Tab | Covers`) contradicts the granularity the same sentence mandates.
      Proposed edit is one word. Note that WhatGroup, PrettyChat and any addon that adopted the
      strip and then updated its README will have landed on the same contradiction.
- [ ] **4.4 (WG-56)** Until it lands, **do not "correct"** `README.md:69` back to `Tab` — that
      re-opens WG-56's original form and turns `tests/test_doc_structure.lua`'s page-granularity
      case red.

## Sprint 5 — the release, not a commit (WG-48)

- [ ] **5.1** At the **next tag**, run `tests/_kit/run-automated-tests.sh` from HEAD as part of
      cutting it — after the last commit, not before. That is the checkpoint `automated-tests`
      names, and it is the whole of this item.
- [ ] **5.2** *Check:* the new bundle's `manifest.json` `git.sha` equals the tagged commit, and
      `docs/automated-tests/RESULTS.md`'s top row matches a fresh
      `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — run **verbatim**, no extra flag, no
      narrowed path, or the number cannot be compared with any earlier row.
- [ ] **5.3** Write that run's `ANALYSIS.md` into its own bundle. **Do not** backfill
      `20260807-110421` or `20260825-103505`; `automated-tests-§5` now **MUST NOT**, and
      `20260908-181437/ANALYSIS.md` has already noted the gap once, forward, which is the whole of
      what is owed.
- [ ] **5.4** If `tests/test_frame.lua` has passed **1250** lines by then, its watch-list
      disposition's own re-check trigger has fired and it needs a fresh judgment, not a carried-forward
      *Accepted*. It is 1063 today.

---

## Not scheduled, and why

| Item | Why there is no step |
|---|---|
| `architecture-§4` Message Bus rationale (former WG-57) | Rejected in this cycle's triage as `WHATGROUP-A-12`; re-measured today and the rejection holds. A rejected finding is not a ratified deviation, so it needs neither an edit nor a register row. |
| `# Locales` TOC annotation | Position already fixed by `toc-file-§5`'s section-header-order MUST, and §5's own reference block shows it uncommented. |
| `ARCHITECTURE.md`'s self-row in the doc map | A **MAY** in v2.39.0, and an audit **MUST NOT** file either state. |
| The two older bundles with no `ANALYSIS.md` (former WG-49) | Closed fix-forward, and v2.39.0 now forbids backfilling them. |
| Anything under `libs/` or `tests/_kit/` | Both `diff -r` checks against v1.27.0 are empty, and both trees are `MUST NOT` edit. |

## Closing check for the remediation engagement

Re-run these five and expect these five numbers, which are the ones `02` and `03` are built on:

| Command | Today | After |
|---|---|---|
| `luacheck .` | `0 warnings / 0 errors in 41 files` | unchanged, or +1 file per new test |
| `lua tests/run.lua` | `559 passed, 0 failed, 0 skipped` | ≥ 559, still 0 failed |
| `AUDIT.md` (e) line-ending one-liner | `0` | `0` |
| citation range-check over 66 tracked files | `10` offending sites | `0` |
| `lua brit.lua` over 65 tracked files | `5` raw / **2** real | `3` raw / **0** real |

The `brit.lua` row is stated as *raw and real* on purpose: three of the five hits are the
`C_LFGList` `cancelled` token and are supposed to survive. An engagement that drives the raw count
to zero has broken the addon.
