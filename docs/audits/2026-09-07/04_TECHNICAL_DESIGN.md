# 04 — Technical design (2026-09-07)

Remediation design for the 14 root deviations in `02_DEVIATIONS.md`, keyed to their IDs. Nothing here
is executed by this audit; this is the hand-off.

**Shape of the whole job.** Nothing on this list touches a code path a player reaches. Twelve of the
fourteen are a doc, a config file, a record or a comment; two are upstream in `LibKa0s`. There is no
behavioral change to design, no migration to write, and no risk of regression in the addon's runtime
— which is why the ordering in `05_EXECUTION_PLAN.md` is driven by *cheapness and blast radius*
rather than by severity.

---

## D-1 — Renormalize the working tree (WG-46)

**Touch:** the index and six checked-out files. No source edit.

```sh
git add --renormalize .
git status                       # review: expect exactly the six paths
git commit -m "chore: renormalize the working tree against the CRLF pin"
# then bring the WORKING TREE into line — --renormalize rewrites the index only
rm <path> && git checkout -- <path>       # per straggler
```

**Verification:** re-run the `AUDIT.md` (e) one-liner; it must print `0`.

**Risk:** low, but not zero in one direction — `git add --renormalize` stages every file it
reclassifies, so the commit must be reviewed rather than `-a`-ed. `tests/_kit/run-automated-tests.sh`
is `text eol=lf` by the `*.sh` carve-out and must **stay** LF; the one-liner already exempts it
correctly, and the mode (`100755`) is a separate index property that renormalization does not touch.
Confirm `git ls-files -s tests/_kit/run-automated-tests.sh` still reads `100755` afterwards.

**Ordering:** do this **first and alone**. Every later step edits text files, and doing it after them
mixes a whitespace-only diff into a content diff nobody can then review.

---

## D-2 — Annotate the TOC (WG-47)

**Touch:** `WhatGroup.toc` only. Comments, not lines moved. *No line may be reordered by this change*
— the current order is dependency-correct and `layout-§1` explicitly does not mandate a sequence.

Four comments to add, each naming **what resolves**, in the shape `WhatGroup.toc:33-34` already uses:

| Line | Comment to add |
|---|---|
| above `core\DebugLogSetup.lua` (`:44`) | LOAD-BEARING: `lib:New` runs at file scope and reads `NS.FONT_MONO`, which `core\WhatGroup.lua` assigns at load; above it the descriptor's `font` is nil and the library's `:New` validation rejects it. |
| above `defaults\Profile.lua` (`:47`) | LOAD-BEARING: publishes `NS.C`, which `settings\Schema.lua` takes as a file-scope upvalue and every `add{}` dereferences at load. |
| above `settings\OptionsSetup.lua` (`:55`) | LOAD-BEARING: publishes `Helpers.MasterControls` onto the LibKa0s instance; `settings\Panel.lua` calls it at file scope. |
| above `settings\Schema.lua` (`:54`) | LOAD-BEARING: creates `Settings.Schema`, which `settings\Panel.lua` splices the composed Master controls block into at file scope. |

Note `:54` and `:55` are adjacent and both load-bearing relative to `:56`; write them as **one**
block comment above `settings\Schema.lua` covering the section's internal order, rather than two
near-identical stanzas.

Then one *conventional* note per remaining group — `# Defaults` (`defaults\TeleportSpells.lua`) and
`# Modules` — matching the vocabulary at `:40`.

**Risk:** none at runtime. The only hazard is writing a comment that is **wrong**, which is worse
than none; each claim above was verified against a file-scope read in `03_EVIDENCE.md` §2.2 and the
implementer should re-verify rather than copy.

---

## D-3 — Refresh the automated-test record (WG-48, WG-49)

**Touch:** `docs/automated-tests/` — a new bundle directory, `RESULTS.md`, and two `ANALYSIS.md`
files.

1. Run the vendored runner: `tests/_kit/run-automated-tests.sh`. Do **not** hand-write a bundle and
   do **not** edit the vendored script (`testing-§1`).
2. The runner prepends the new row and rewrites nothing else. The four **standing sections** are
   prose and must be rolled forward by hand to name the new run: test suite (528, and *why* it moved
   — the settings revamp, not a refactor), lint (16 files now, not 14, and the same scope caveat),
   perf (unchanged: permanent `skip`, with the `performance-§12` note it already carries), and the
   complexity watch list (still empty; the ceiling function is unchanged at CCN 15 but has moved to
   `core/WhatGroup.lua:675-738`).
3. Re-anchor the stale citation at `RESULTS.md:109`: `modules/Frame.lua:146` → `:275`.
4. Write `ANALYSIS.md` for the new bundle. For the two historical bundles (WG-49), either backfill
   them or — the cheaper and equally honest option — add one line to `RESULTS.md` stating that
   exploratory (non-release) runs do not get a write-up, which is what `automated-tests-§5`'s SHOULD
   permits. **Pick one and say which**; leaving two silent gaps is the thing that reads as an
   oversight.

**Risk:** the runner overwrites `RESULTS.md` in place. Confirm the column set has not changed before
running (`automated-tests-§4` forbids silently recreating the file when it has) — the vendored kit is
at LibKa0s v1.25.0 and the last run was produced by the same kit, so this should be a clean prepend.

**Ordering:** after D-1, so the new bundle is written into a normalized tree; and after **every other
content change on this list**, so the record it produces describes the tree the remediation leaves
behind rather than the one it started from. This is the natural last step.

---

## D-4 — Two upstream items (WG-50, WG-51)

**Touch:** nothing in this repo. Both are `LibKa0s` kit defects and `testing-§1` forbids patching the
vendored copy — doing so here would convert two Low findings into an anti-pattern #47 fork.

- **WG-50** — `run-automated-tests.sh` must emit `passed/skipped/total` in the `RESULTS.md` tests
  column and a `skipped` key in `manifest.json`'s `tests` object. It matters concretely for this
  repo: `tests/test_vendor_sync.lua` skips when `../LibKa0s` is absent, and today's format would
  report that run as full coverage.
- **WG-51** — the consumer-side gate (`tests/_kit/vendor_sync.lua`) must assert
  `git ls-files -s tests/_kit/run-automated-tests.sh` reports `100755`.

**Design:** file one issue on `tusharsaxena/LibKa0s` per item, labeled `state:triaged` +
`severity:low`, each citing `automated-tests-§4` / `automated-tests-§2` and this bundle. Then file a
tracking issue **here** so the next audit can see the item is owned rather than re-filing it, and add
a line to `docs/testing.md` naming both as known kit gaps. Adoption lands with the next re-vendor;
`docs/revendor/` is where that is recorded.

**Ordering:** independent of everything else. Do it early — it is two `gh issue create` calls and it
stops the two findings recurring unattributed.

---

## D-5 — The deviation register (WG-52)

**Touch:** `docs/ARCHITECTURE.md:352`, one table cell plus a clause.

Change the Rule cell from `` `standalone-windows-§33` `` to `` `standalone-windows` `` — the bare
filename, which is the form `documentation-§5/§6` prescribes for a section with no numbered
subsections. Because the bare name no longer points at a specific rule, add the rule's own words to
*What differs*, e.g. *"§'s wide-action-button SHOULD — 'A wide action button keeps its label and gains
a mark beside it' — is not met on the popup's footer Close."*

**Risk:** none. The decision itself is untouched and stays ratified with its 2026-08-25 date.

**Ordering:** trivially independent.

---

## D-6 — Write `docs/compat-layer.md` (WG-53)

**Touch:** one new file, plus one row in `docs/ARCHITECTURE.md:316`.

The page is short and the material already exists. Cover:

- **Why the layer exists** — `core/Compat.lua:7-9` already says it: Compat is the **sole** caller of
  the variant APIs, so a patch rename changes one file.
- **The seven shims**, one row each: `GetSpellName`, `GetSpellTexture`, `GetSpellLink`,
  `IsSpellKnown`, `GetSpellCooldownRemaining`, `GetSpellCooldownTimes`, `GetActivityInfoTable` —
  each with the modern API it prefers, the legacy global it falls back to, and its degraded return.
- **The contract** — every shim degrades to `nil`/`false` rather than raising, which is what lets
  `modules/Frame.lua`'s teleport path treat an unknown spell as *not learned* instead of erroring.
- **What is not here** — no `WOW_PROJECT_ID` branching (anti-pattern #9); `compat` is Retail-patch
  variance only.
- **Link, do not duplicate** — the cooldown states belong to `docs/frame.md:95-97`; link them.

Then change `docs/ARCHITECTURE.md:316` from `Not applicable | …` to
`Present | core/Compat.lua carries seven addon-specific shims LibKa0s supplies no major for`.

**Risk:** the trap here is writing a second copy of `frame.md`'s cooldown narrative. Tier 3/Tier 2
docs **MUST NOT** duplicate each other; link.

**Ordering:** independent. Sizeable enough (an hour) that it should not be bundled with the one-line
fixes.

---

## D-7 — Answer `architecture-§4`'s second trigger (WG-57)

**Touch:** `docs/ARCHITECTURE.md:105-112`, one paragraph.

The current text argues the module-count half. Extend it to name the event-registration half
explicitly: that `modules/Frame.lua:318` and `:635` each register `PLAYER_REGEN_ENABLED` on a
**transient, self-unregistering `CreateFrame` frame** rather than on an AceEvent-embedded module
target, so there is no second registrant and CallbackHandler's `(message, target)` clobber — §4's
entire stated rationale — cannot arise. State the threshold that *would* bind: the second feature
module, or the first receiver registering on a shared bus object.

**If that reading is judged wrong**, the alternative design is the bus itself: `NS.NewBusTarget()`
per receiver, one `Ka0s_WhatGroup_*` message for the join-capture handoff, and a
`docs/message-bus.md`. That is a real change to `core/WhatGroup.lua`'s
`_TryFireJoinNotify` seam and is **out of proportion** to a Low finding on a single-module addon —
which is why the recommended route is the paragraph, with the third route being an upstream wording
question on whether a raw frame's `RegisterEvent` is what §4 means by *"a module that registers game
events"*.

**Risk:** none in the recommended route.

---

## D-8 — Three README/config one-liners (WG-54, WG-55, WG-56, WG-58, WG-59)

All small, all independent, grouped only because they share a review.

- **WG-54 (spellings).** One sweep over the three scopes named in `03_EVIDENCE.md` §2.7:
  `grey → gray`, `behaviour → behavior`, `colour → color`, `cancelled → canceled`. Two follow-ons:
  renaming the test case at `tests/test_settings.lua:676` changes the generated inventory, so
  regenerate `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) in the same
  change; and the case **count** does not move, so the README `[tests]` badge does not.
  **Do not** sweep `libs/`, `tests/_kit/` or any frozen `docs/` bundle.
- **WG-55 (Version History).** `README.md:121`: `Notify` → `Chat`. One word. The `## What's new`
  bullet at `:21` is already correct, so nothing else moves.
- **WG-56 (settings table).** Collapse `README.md:69-73` to one row —
  `| General | Everything the addon exposes, across three tabs |` — and keep the three prose
  paragraphs, which are player-facing and legitimate. The per-tab table already exists at
  `docs/settings-panel.md:319-329`; add the link. **Before doing this**, consider taking the
  ambiguity upstream instead (see WG-56's note): the mandated column header is literally
  `Tab | Covers`, which reads against the page-granularity sentence beside it, and this repo is
  unlikely to be the only one that landed here.
- **WG-58 (`.pkgmeta`).** Add `  - .superpowers   # dev-only: agent tooling; never shipped to
  players` beside the existing `.claude` row, and either add `.pkgmeta` or a comment saying the
  packager consumes and drops it. Two lines.
- **WG-59 (`.luacheckrc`).** Add `"_dev/"` to `exclude_files` so it agrees with `.pkgmeta:12`.
  One token. Re-run `luacheck .` — expect `0/0` over the same 16 files.

**Risk:** WG-54 is the only one with any: a careless `grep -rli … | xargs sed` would rewrite frozen
bundles and the vendored library. Scope the sweep to the 20 cited sites, or to the three explicit
path sets, and re-run the suite afterwards because one of the edits is inside a test-case name.

---

## D-9 — Two upstream questions for the standard (WG-56, WG-60)

Neither is remediable in this repo, and both should be raised on `WowAddonStandards` rather than
absorbed as local deviations:

- **WG-60** — `documentation-§3` says every `.md` under `docs/` sits in *"exactly one of its three
  tables"*, and separately mandates five **verification-and-record** docs that it explicitly places
  outside the tier model. There is no reading under which both hold. Proposal: name a fourth
  `### Verification and record` table in the specified map shape — which is what this repo already
  built — and say whether `ARCHITECTURE.md` registers itself.
- **WG-56** — `documentation-§1` item 7 mandates the header `Tab | Covers` while requiring page
  granularity. Proposal: rename the column to `Page | Covers`, or state that on a single-page addon
  the tab list is the acceptable form.

Raising these is cheap and stops every sibling repo re-deriving the same answer differently, which is
the drift `documentation-§3` was written to end.

---

## Cross-cutting notes

- **Nothing on this list requires a version bump.** No user-visible behavior changes, so `## What's
  new`, `## Version History` and the TOC `## Version:` stay at 1.3.0 — except that WG-55 *corrects* a
  Version History cell, which is a fix to an existing row, not a new one.
- **The green gate applies to every step**: `luacheck .` clean and `lua tests/run.lua` green before
  each commit (`testing-§4`). Only D-8's spelling sweep can move the suite, and only by renaming a
  case.
- **The deviation register is not touched** except by D-5. None of these findings is a candidate for
  ratification: every one has a cheap fix, and `documentation-§3` warns that a register which only
  grows stops being read.
