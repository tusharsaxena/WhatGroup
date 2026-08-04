# Ka0s WhatGroup — Execution Plan (2026-08-04)

Ordered, checkable remediation steps for the deviations in `02_DEVIATIONS.md`, designed in
`04_TECHNICAL_DESIGN.md`. This is the hand-off to a separate remediation engagement — the audit
itself changed nothing.

**Green gate on every commit:** `lua tests/run.lua` (415+ passed, 0 failed) **and** `luacheck .`
(0/0), plus the vendor gate — `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and
`diff -r ../LibKa0s/testkit tests/_kit`, both empty.

**Working rules:** trunk-based on `master`, no branch unless asked; commit only on green; never
push unless asked; never edit `libs/` or `tests/_kit/`.

---

## Sprint 1 — the free-standing fixes (no decision needed)

Six deviations, all independent, all small. Nothing here waits on anything.

### S1.1 — Remove the two global `print()` fallbacks · **WG-37** (MUST)

- [ ] `settings/Panel.lua:22-25` — replace `pout`'s second arm with a no-op guard on `NS.Print`.
- [ ] `settings/Schema.lua:48-51` — same edit; update the comment, which currently *describes* the
      fallback ("keeps the panel from going dark") and would otherwise contradict the code.
- [ ] Grep the repo for any remaining bare `print(` outside `core/CoreSetup.lua` — expect none.
- [ ] Add/adjust a case asserting a settings-layer chat line lands through `NS.Print` with the cyan
      tag, not through the global.
- [ ] Green gate. **Commit:** *"settings: the panel and schema chat-outs stop falling back to global print (WG-37)"*

### S1.2 — `.pkgmeta` ignore list and both retired citations · **WG-36** (MUST) + **WG-43** (advisory)

- [ ] `.pkgmeta` — add `- _dev` and `- "*.bak"` under `ignore:`.
- [ ] `.pkgmeta:4` — `(§3.3, §13)` → `(library-stack-§3, packaging)`.
- [ ] `.luacheckrc:1` — `(§14)` → `(lint)`.
- [ ] Green gate. **Commit:** *"packaging+lint: ignore _dev, and repoint two retired §N.M citations (WG-36, WG-43)"*

### S1.3 — Un-gate the settings-category registration · **WG-40** (SHOULD)

- [ ] `settings/Panel.lua:245-251` — delete the `InCombatLockdown()` early return and its `pout`
      line. Leave every other combat guard alone: the panel-**open** gate is the library's, and
      `modules/Frame.lua`'s three secure-write guards are the addon's real taint defense.
- [ ] Update the comment block above `Settings.Register` so it no longer claims registration taints
      the GameMenu chain — cite options-ui-§9's finding instead.
- [ ] `settings/Slash.lua:208-214` — the `runConfig` re-registration comment names "a login in
      combat, where OnEnable's registration bailed on its own guard"; that scenario is gone, so the
      comment needs rewording (the call stays: it is still a correct idempotent fallback).
- [ ] New case: drive `OnEnable` with the mock reporting `InCombatLockdown() == true`, assert the
      category registers anyway.
- [ ] `docs/ARCHITECTURE.md:66` and `:72(c)` both describe the guard — update both.
- [ ] Green gate. **Commit:** *"settings: register the canvas category at login even in combat (WG-40)"*
- [ ] **Smoke test before release** — `docs/smoke-tests.md`: (a) `/reload` while in combat, confirm
      **Ka0s WhatGroup** appears in Settings → AddOns without `/wg config`; (b) open the GameMenu and
      click **Logout** in the same session — no `ADDON_ACTION_FORBIDDEN`.

### S1.4 — Mono-font fetch-failure fallback · **WG-42** (SHOULD)

- [ ] `core/WhatGroup.lua:96-100` — either add the `Fonts\ARIALN.TTF` fallback at the point the
      descriptor reads the constant, **or** write the omission down as a deliberate decision (a
      vendored file is treated as always present) in the existing WG-20 comment block.
- [ ] If the fallback is added, a case pinning that a missing vendored path still yields a usable
      `font` value for `:New`.
- [ ] Green gate. **Commit:** *"debug console: state the mono-font fallback decision (WG-42)"*

### S1.5 — `docs/complexity.md` · **WG-41** (SHOULD)

- [ ] `lizard core defaults locales modules settings > docs/complexity.md` (never `libs/`, never
      `tests/`); prepend a two-line header naming the command and stating it is generated.
- [ ] Confirm nothing gates on it — performance-§10 is explicit that it is a report, not a gate.
- [ ] **Commit:** *"docs: add the generated complexity report (WG-41)"*

**Sprint 1 exit:** two MUSTs and three SHOULDs closed; `luacheck` and the suite green; the vendor
diffs still empty.

---

## Sprint 2 — documentation shape

### S2.1 — Relocate `## Bundled libraries` · **WG-38** (SHOULD)

- [ ] Delete `README.md:81-83`; verify the remaining sections are exactly documentation-§1's twelve,
      in order: H1 → badges → logo → description → What's new → Screenshots → Usage → How it works →
      FAQ → Troubleshooting → Issues → Version History.
- [ ] Fold the content into `docs/ARCHITECTURE.md`'s `## External dependencies`, which already lists
      the same libraries — keep the LibKa0s version and the `libs/LibKa0s/LICENSE` path.
- [ ] If the MIT attribution should stay player-visible, one sentence in the description or
      `## How it works` — not a section.
- [ ] Re-check for angle-bracket placeholders in shipped README content (expect only the deliberate
      `<br>` in Version-History cells, which documentation-§1 protects).
- [ ] **Commit:** *"README: drop the non-canonical Bundled libraries section (WG-38)"*

### S2.2 — Four missing `docs/ARCHITECTURE.md` headings · **WG-39** (SHOULD)

- [ ] `## Settings Schema` — `Path | Type | Default | Widget | Section` table from
      `settings/Schema.lua`, keeping the `docs/settings-system.md` pointer.
- [ ] `## Message Bus` — one paragraph stating the addon has none, why (one feature module, direct
      methods on the AceAddon object), and that a second module must adopt architecture-§4's
      per-receiver targets rather than registering on a shared object.
- [ ] `## Slash Commands` — the `Command | What it does` table from `NS.COMMANDS`, matching the
      README's.
- [ ] `## Known Limitations` — gather the four already-recorded items: English-only locale scope
      (`docs/scope.md`), the declined Perf wiring (`LIBKA0S-15`), the console's lost position
      persistence (`LIBKA0S-05`), and the `ParseValue` string gap (`LIBKA0S-12`). **Write this
      section last** — Sprint 3's outcome changes the Perf entry.
- [ ] Run `wow-addon:sync-docs` so the slash table stays in lockstep.
- [ ] **Commit:** *"docs(architecture): add the four sections documentation-§3 names (WG-39)"*

**Sprint 2 exit:** the doc set matches documentation-§1 and documentation-§3 in shape, not only in
content.

---

## Sprint 3 — the Perf decision · **WG-30 … WG-35** (6 MUSTs)

**This sprint starts with a conversation, not an edit.** Nothing in it should be attempted before the
user picks a route.

### S3.0 — Decide (blocking)

- [ ] Present both routes from `04_TECHNICAL_DESIGN.md` with the evidence: no hot path (zero
      `OnUpdate`/tickers/repeating timers), and `suspend` costing a **capture** addon the captures it
      exists for. Note that four of eight adopters declined on the same reasoning.
- [ ] Record the outcome as a new `docs/pending/LEDGER.md` row, whichever way it goes. A decision
      taken twice and recorded once is a decision that gets re-litigated.

### Route A1 — wire the harness (if that is the call)

Ordered, because each step depends on the one before.

- [ ] **S3.1** `core/PerfSetup.lua` — silent guarded `LibStub("LibKa0s-Perf-1.0", true)`, `:New` from
      a descriptor, stub carrying every member the addon calls. TOC slot in `# Core`, before
      `modules/Frame.lua`. · WG-30
- [ ] **S3.2** Declare buckets (`rosterUpdate`, `captureApply`) in the descriptor, in report order,
      and bracket both with the exact gated idiom — `local t0 = Perf.on and debugprofilestop()` …
      `if t0 then Perf.Note(key, debugprofilestop() - t0) end`. No allocation, no formatting, no `NS`
      lookup inside a dormant bracket. · WG-30
- [ ] **S3.3** Cases pinning that **every declared bucket is reached by a real bracket** (testing-§8,
      performance-§3), driving each bucket's genuine entry point. · WG-30
- [ ] **S3.4** Implement `suspend`/`resume` — and **raise the reading upstream first**: keeping the
      two `hooksecurefunc` capture hooks live while suspending the announcement is a deliberate
      interpretation of performance-§6, and shipping it silently is exactly what `CLAUDE.md`'s
      deviation rule forbids. Restore from **current** state; never persist the flag; resume **before**
      saving or reporting. · WG-30
- [ ] **S3.5** `WhatGroup.toc:7` → `## SavedVariables: WhatGroupDB, WhatGroupPerfDB`; hand the name
      to the descriptor; keep the ring outside the AceDB tree. · WG-31
- [ ] **S3.6** `.luacheckrc` — `debugprofilestop` into `read_globals`, `WhatGroupPerfDB` into
      `globals` with a comment. · WG-35
- [ ] **S3.7** `perf` row in `settings/Slash.lua`'s `COMMANDS`, dispatching to the library's entry
      point and printing the returned lines through `NS.Print`. Bare `/wg perf` opens the guided step
      panel. The library registers no chat command. · WG-32
- [ ] **S3.8** `tests/perf.lua` — offline scenarios including the **zero-overhead** one; assert only
      deterministic quantities (call counts, bytes allocated), never wall clock; keep it **out** of
      `tests/run.lua`'s suite list and out of the `--list` inventory. · WG-34
- [ ] **S3.9** `docs/performance.md` and `docs/perf-runs/README.md`. · WG-33
- [ ] **S3.10** Regenerate `docs/test-cases.md` and update the README `[tests]` badge in the **same**
      change as any case count movement (testing-§5).
- [ ] Green gate at every step. Suggested commits: one per numbered step.
- [ ] **Smoke test:** run a real two-arm capture, confirm the suspended arm still records an LFG
      apply, confirm `/wg perf` opens the panel, confirm resume happens before persistence.

### Route A2 — amend the standard (the recommended call)

- [ ] **S3.1'** Open the change against `WowAddonStandards`: a carve-out in `performance-§1`/`§6` for
      an addon whose suspended arm would **lose user-visible work** rather than pause a display,
      conditioned on the decline being recorded and a `docs/performance.md` stating it; `toc-file-§2`
      and `lint` relaxing `<Addon>PerfDB` to *"when the harness is wired"*; `slash-commands-§2`
      keeping `perf` **reserved** regardless. Cite the four independent declines as evidence.
- [ ] **S3.2'** On adoption, write `docs/performance.md` — one screen: this addon has no bracketed
      hot path, here is why, here is where the decision lives (`LIBKA0S-15`), and here is what would
      change that. This is worth writing either way; it is what stops the next reader hunting for a
      harness that was never meant to exist. · WG-33
- [ ] **S3.3'** Close `WG-30`, `WG-31`, `WG-32`, `WG-34`, `WG-35` as compliant-under-the-amended-rule
      in the **next** audit run — never by editing this frozen bundle.
- [ ] `libs/LibKa0s/Perf.lua` and `PerfPanel.lua` **stay vendored** either way (anti-pattern #48).

**Sprint 3 exit:** either the harness is wired and its six MUSTs are genuinely closed, or the
standard says what the collection actually does and the addon is compliant against it. What must not
happen is the middle: a TOC declaring a SV global nothing writes, or a `perf` verb that answers
nothing.

---

## Closing checklist

- [ ] `lua tests/run.lua` green; `luacheck .` 0/0.
- [ ] `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` empty; `diff -r ../LibKa0s/testkit tests/_kit` empty.
- [ ] `docs/test-cases.md` regenerated and the README `[tests]` badge matching it.
- [ ] `docs/smoke-tests.md` extended with the WG-40 login-in-combat check and, under route A1, the
      capture-protocol checks.
- [ ] `docs/pending/LEDGER.md` carries the Sprint 3 decision row.
- [ ] No version bump unless explicitly asked (`CLAUDE.md` hard rule). If one is taken, `README.md`'s
      `## What's new` and the top Version History row move in the **same** change
      (documentation-§1 item 5).
- [ ] This bundle is **frozen**. The next audit is a new dated folder under `docs/audits/`; nothing
      here is edited to record what was fixed.
