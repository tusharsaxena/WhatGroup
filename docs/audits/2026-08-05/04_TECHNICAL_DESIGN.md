# Ka0s WhatGroup — Remediation Design (2026-08-05)

Keyed to the IDs in `02_DEVIATIONS.md`. This is design only; nothing here was applied.

---

## 0. The one decision that shapes everything else

`WG-30`–`WG-35` are six sections reporting one unresolved question: **does WhatGroup wire
`LibKa0s-Perf-1.0`, or does the collection amend `performance` to carve out addons whose
suspend contract would destroy user data?** That question is the user's, not the remediation
engineer's, and nothing in that cluster should be touched until it is answered — a half-wired
harness (a declared `WhatGroupPerfDB` nobody writes, a `perf` verb that reports nothing) is worse
than the current honest absence, which at least records itself as a `skip` with a reason.

Everything outside that cluster — `WG-36`, `WG-37`, `WG-38`, `WG-39`, `WG-40`, `WG-42`, `WG-43`,
`WG-44`, `WG-45` — is independent of it and can be closed in any order.

### Route A — wire the harness

New file `core/PerfSetup.lua`, TOC-inserted in `# Core` **after** `core/CoreSetup.lua` (it needs the
secret-safe stringifier) and **before** `core/WhatGroup.lua` and `modules/Frame.lua` (which would take
`local Perf = NS.Perf` as a load-time upvalue). Shape, per performance-§1/§2:

```lua
local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
if not lib then NS.Perf = { on = false, Note = function() end, ... } return end
NS.Perf = lib:New({ ... })
```

The stub must answer **every** member the addon reaches — the `on` gate field, `Note`, and whatever
the `perf` verb and the show-decision ladder touch — because a stub with a hole is a crash moved to a
rarer path.

Buckets (`WG-30`, coverage is only a SHOULD): the honest candidates are the capture path
(`CaptureGroupInfo` / `CaptureGroupInfoFromApplication`), the `GROUP_ROSTER_UPDATE` handler and the
notify build. None is per-frame, so expect near-zero readings — which is the finding, not a failure.

Suspend/resume (`performance-§6`) is where the design has to be deliberate: suspend **MUST NOT**
make capture inert, or the A/B arm silently costs the user the applies the addon exists to record.
The implementation is "suspend the *display* — notify scheduling and popup — while the capture
pipeline keeps recording", and that intent belongs in a comment at the implementation, not in a
ledger.

Then `WG-31` (TOC second SV global), `WG-32` (one `COMMANDS` row dispatching into the library's
command entry point, printing through `NS.Print`), `WG-35` (two `.luacheckrc` lines), `WG-34`
(`tests/perf.lua` with, at minimum, the zero-overhead scenario performance-§2 names as required
evidence) and `WG-33` (`docs/performance.md`, `docs/perf-runs/README.md`) all follow mechanically.

### Route B — take the carve-out upstream

A `performance` amendment in `WowAddonStandards` carving out addons with no hot path **and** a
capture-style suspend contract. If accepted, `WG-30`, `WG-31`, `WG-32`, `WG-34`, `WG-35` close as
"not applicable", and `WG-33` shrinks to a single one-screen `docs/performance.md` stating that this
addon brackets nothing and why — which still has a job, because the next reader would otherwise go
looking for a harness. `docs/perf-runs/README.md` closes with it.

Route B is the one the collection's own evidence points at (four of the adopters have declined Perf
on the same reasoning), but it is a standards change and therefore belongs upstream, not here.

---

## 1. `WG-44` — make the master-switch cases falsifiable (and fix what they then catch)

**This is the only MUST on the list that is a correctness problem rather than a wiring gap, and it
must be done as one change**, because the corrected test goes red against today's implementation.

Two edits, in this order:

1. **`tests/test_capture.lua:63-76`** — remove the `mock.searchResults[100] = nil` line at `:71` so
   the accept path has real data to capture, keep `assertNil(addon.pendingInfo)`, and add the
   testing-§12 comment naming the mutation that reddens it, e.g.
   `-- red under: drop the profile.enabled guard in the "inviteaccepted" branch`.
   Do the same at `:261-275` (`:271`).
   Run the suite and **watch it fail** — that failing run is the evidence the test now tests
   something.
2. **`core/WhatGroup.lua:619-673`** — gate the `"inviteaccepted"` branch on the master switch, the
   same predicate `OnApplyToGroup` already uses at `:488`. Put the guard at the **top of the
   branch**, before `CaptureGroupInfoFromApplication` at `:639`, so nothing is fetched, no
   `pendingInfo` is assigned (`:650`) and `_TryFireJoinNotify` (`:671`) is never reached. Extracting
   the predicate into a small named helper (`local function captureEnabled(self)`) keeps the two
   call sites from drifting apart again and does not move the CCN in a direction anyone has to argue
   about (`_TryFireJoinNotify` is 13; this branch is 12).

**Risk.** The guard changes behavior for a user who disables the addon mid-application: the accept
no longer produces a popup. That is the documented contract (`settings/Schema.lua:92`) and the
`enabled.onChange` handler already wipes in-flight capture state, so the two agree afterwards. Pin
the interaction with a case that flips `enabled` **between** apply and accept.

**Also check while in there:** the sibling test at `:255-259` ("accepting with no data anywhere
leaves pendingInfo nil") is genuinely testing the no-data path and should keep its `nil` setup — do
not "fix" it by symmetry.

---

## 2. Doc-only cluster — `WG-45`, `WG-38`, `WG-39`, `WG-33`(partial), `WG-43`

No code, no test impact, no release coupling. Can land as one docs commit.

- **`WG-45`** — add the release gate wherever the commit gate is described. Four loci, one sentence
  each plus a table row:
  - `docs/testing.md` after `:221-223` and after `:228-229`;
  - `docs/automated-tests/README.md` after `:28-30`;
  - `docs/automated-tests/RESULTS.md` `:9-11` — note this file is **generated**
    (documentation-§3: never hand-edited). The standing prose sections around the table are the
    addon's, but the gating blurb sits in the runner-written header region: **check first whether
    the sentence comes from the vendored `run-automated-tests.sh`.** If it does, this locus is a
    finding for `../LibKa0s`'s testkit, fixed upstream and re-vendored — not patched here, or the
    next re-vendor reverts it silently.
  - `DEPENDENCIES.md:92` — re-mark `lizard` "optional for day-to-day work, **required to cut a
    release**" (automated-tests-§3 makes an unmeasured zero-CCN claim a blocked release, not a pass).

  Canonical substance: *commits are gated on `lint` + `tests` only; the **tag** is gated on all four
  suites at `pass` plus `suites.complexity.warnings == 0`, evaluated by `/wow-addon:bump-version`
  from the run's `manifest.json`, where a `skip` blocks as NOT EVALUATED. The runner's exit code is
  deliberately unchanged, because the same script is the commit gate.* Say **which checkpoint** every
  time — a bare "perf and complexity never gate" is the sentence that is now half true.
- **`WG-38`** — move `README.md:81-83` into `docs/ARCHITECTURE.md`'s `## External dependencies`
  (`:91`), which already carries the same material; keep at most the LibKa0s MIT attribution line in
  the README if attribution must stay player-visible. Do not reorder any other README section.
- **`WG-39`** — add the four missing headings to `docs/ARCHITECTURE.md`. Three are short: a Settings
  Schema table (or a pointer plus the top-level key list), the `NS.COMMANDS` table (generated the
  same way the README's is, so the two move together), and a one-line Message Bus section saying the
  addon has none and why (single feature module, direct method calls on the AceAddon object). Known
  Limitations has real content available today: the locale scope decision, the declined Perf wiring
  (`WG-30`), and the console's lost position persistence.
- **`WG-43`** — `.luacheckrc:1` `§14` → `lint`; `.pkgmeta:4` `§3.3, §13` → `library-stack-§3,
  packaging`. Comment-only; zero behavior.

---

## 3. Small code cluster — `WG-36`, `WG-37`, `WG-42`, `WG-40`

- **`WG-36`** — `.pkgmeta` ignore list: add `- _dev` and `- "*.bak"`. One line each, no risk.
- **`WG-37`** — delete the `print(...)` arm from `pout` in `settings/Panel.lua:22-25` and
  `settings/Schema.lua:48-51`. The correct replacement is a direct `NS.Print` call; if a guard is
  still wanted for load-order safety, make the else-branch a **no-op**, never a second printer. Both
  files already have suite coverage that asserts on captured chat output
  (`tests/test_panel.lua`, `tests/test_settings.lua`), so the change is pinned.
- **`WG-42`** — resolve `NS.FONT_MONO` (`core/WhatGroup.lua:96`) through a guard that falls back to
  `Fonts\ARIALN.TTF`. Note the ordering constraint: `core/DebugLogSetup.lua:95` reads the constant at
  `:New` time and the library **validates** it, so the fallback must be resolved at definition time
  in `core/WhatGroup.lua`, not lazily at first console open. Alternatively, record the omission as a
  deliberate SHOULD-deviation with a comment saying why a vendored file is treated as always present
  — the standard permits that, and it is a defensible call for a file shipped in the same zip.
- **`WG-40`** — remove the `InCombatLockdown()` early return at `settings/Panel.lua:268-272`. The
  panel-**open** path keeps its combat gate inside the library's `OpenOptionsPanel`, where every
  caller meets it, and the addon's real taint sources stay deferred in `modules/Frame.lua`. If the
  guard is kept instead, it **MUST** become a one-shot re-registration on `PLAYER_REGEN_ENABLED` so
  the category still arrives, with the reasoning recorded in-code as an accepted deviation. Add a
  test that registers under a mocked combat state and asserts the category exists afterwards —
  `tests/test_panel.lua` already boots the panel and can carry it.

**Risk on `WG-40`:** this is the one item in the small cluster that touches taint behavior, and the
in-game verification (GameMenu → Logout after a combat login) cannot be done headlessly. It is a
`docs/smoke-tests.md` item, and it should be run before the change is released, not merely before it
is committed.

---

## 4. Ordering constraints

1. `WG-44`'s two edits are **one** change; the test edit alone leaves the suite red and the
   implementation edit alone leaves a test that still cannot fail.
2. `WG-45`'s `RESULTS.md` locus is blocked on determining whether that sentence is runner-generated;
   if it is, the fix is upstream in `../LibKa0s`'s `testkit/` plus a re-vendor commit here, and it
   **MUST NOT** be hand-patched in `tests/_kit/` or in the generated file.
3. `WG-31`/`WG-32`/`WG-33`/`WG-34`/`WG-35` are all downstream of the `WG-30` route decision.
4. Everything else is independent.
5. Every change lands on the green gate — `luacheck .` 0/0 and `lua5.1 tests/run.lua` 422/422 (or
   higher, as cases are added) — and the vendor diffs (`03_EVIDENCE.md` §B1) **MUST** be run and
   empty before any release that carries this work, since this audit could not run them.
</content>
