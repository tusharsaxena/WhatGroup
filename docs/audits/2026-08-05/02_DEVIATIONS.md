# Ka0s WhatGroup — Deviations (2026-08-05)

**Audited against:** Ka0s WoW Addon Standard **v2.21.0 (2026-08-04)**, fetched over the network
(`AUDIT.md`, `standards/STANDARDS.md`, all 25 section files discovered by following the Sections
list).

**ID prefix:** `WG-` (stable since the 2026-07-12 run). Recurring deviations keep their IDs; new IDs
this run begin at `WG-44`.

---

## Summary

| Severity | Count | IDs |
|---|---|---|
| **MUST** | 9 | WG-30 · WG-31 · WG-32 · WG-33 · WG-34 · WG-35 · WG-36 · WG-37 · WG-44 |
| **SHOULD** | 5 | WG-38 · WG-39 · WG-40 · WG-42 · WG-45 |
| **MAY / advisory** | 1 | WG-43 |

**Verdict: minor deviations.** Six of the nine MUSTs (`WG-30`–`WG-35`) are one decision — the
declined `LibKa0s-Perf-1.0` wiring — surfacing in six sections, and it is a recorded user decision
(`docs/pending/LEDGER.md`, `LIBKA0S-15`). The addon's library adoption, layout, TOC, settings,
slash, debug, localization, test and complexity surfaces all measure clean, and every mechanical
check that could be run this session came back green.

**Closed since 2026-08-04:** `WG-41` (no `docs/complexity.md`) — the standard **retired** that file
in v2.19.0, so its absence is now the compliant state, not a gap. Nothing else closed; `WG-30`
through `WG-40`, `WG-42` and `WG-43` all recur unchanged.

**Standing accepted deviations, recorded in-repo and deliberately not re-litigated:** the vendored
JetBrains Mono console font (`WG-20`) and the landing-page logo (`WG-21`) are sanctioned by
debug-logging-§2 and options-ui-§5. The `settings/OptionsSetup.lua` load-completing stub is the one
**documented** options-ui-§1 exception and is **not** a finding. The `or` chains in `buildCapture`
are over API capture data, not stored settings, and are **not** anti-pattern #54.

**Not a deviation, but unverified:** the two Ka0s-owned vendor diffs could not be run under this
run's single-repo constraint. See `03_EVIDENCE.md` § "Checks NOT RUN".

---

## MUST

### WG-30 — `LibKa0s-Perf-1.0` is vendored but not wired: no `core/PerfSetup.lua`, no `NS.Perf`, no buckets
**Section:** `performance-§1`, `performance-§3`, `performance-§6` ·
**Where:** repo has no `core/PerfSetup.lua`; `WhatGroup.toc:26-33` (`# Core` block) · *recurs from 2026-08-04*

performance's adoption-strength paragraph makes the **wiring** a MUST for every addon (coverage is
only a SHOULD): one instance created at load from a descriptor, in its own `core/PerfSetup.lua`,
positioned before any consumer, degrading to a member-answering stub. None of it exists. The library
half is correct — `libs/LibKa0s/Perf.lua` and `PerfPanel.lua` are both vendored as part of the whole
ship folder, which is what library-stack-§7 demands.

The decline is a recorded, user-taken decision (`docs/pending/LEDGER.md`, `LIBKA0S-15`) on two
structural grounds: the addon has no hot path (no `OnUpdate`, no ticker, no repeating timer), so
every declared bucket would read `0.000`; and `suspend` on a **capture** addon would drop the applies
and invites the addon exists to record. **Fix direction (user's choice, unchanged):** (a) wire the
harness anyway with a suspend that refuses to make capture inert, or (b) take the carve-out upstream
as a `performance` amendment. Route (b) closes `WG-30`–`WG-35` at once.

### WG-31 — TOC declares one SavedVariables global; the standard requires exactly two
**Section:** `toc-file-§1`, `toc-file-§2`, `savedvariables-§4`, `performance-§5` ·
**Where:** `WhatGroup.toc:7` · *recurs*

`## SavedVariables: WhatGroupDB`. toc-file-§2 requires **exactly two**, in order: `<Addon>DB` then
`<Addon>PerfDB`. **Fix:** `## SavedVariables: WhatGroupDB, WhatGroupPerfDB`, but only alongside
`WG-30` — a declared-but-never-written SV global is worse than an absent one. Blocked on `WG-30`.

### WG-32 — the reserved `perf` verb is missing from `NS.COMMANDS`
**Section:** `slash-commands-§2`, `performance-§4` · **Where:** `settings/Slash.lua:43-67` · *recurs*

The table carries eleven verbs (`help`, `show`, `test`, `config`, `version`, `list`, `get`, `set`,
`reset`, `resetall`, `debug`); `perf` is not among them, so `/wg perf` answers
`unknown command 'perf'`. **Fix:** one positional-triple row dispatching into the library's command
entry point. Blocked on `WG-30`.

### WG-33 — `docs/performance.md` and `docs/perf-runs/README.md` are absent
**Section:** `documentation-§3`, `performance-§8` · **Where:** `docs/` (neither path exists) · *recurs*

documentation-§3 names **five** required topic-detail docs. Three are present and correct
(`test-cases.md`, `automated-tests/README.md`, `automated-tests/RESULTS.md`); these two are not.
performance-§8 additionally makes `docs/perf-runs/` the standing **in-game** capture store, which
automated-tests-§7 explicitly did **not** fold into the run bundles. **Fix:** write both when
`WG-30` resolves; if the decline is ratified upstream, `docs/performance.md` still has a job — a
one-screen page saying this addon brackets nothing and why. Blocked on `WG-30`.

### WG-34 — no `tests/perf.lua` offline scenario runner, and so no zero-overhead evidence
**Section:** `performance-§9`, `performance-§2` · **Where:** `tests/` (no `perf.lua`) · *recurs*

performance-§9 requires the runner at that exact path; performance-§2 names its zero-overhead
scenario as the **required evidence** that instrumentation is free when off. The manifest correctly
records `perf` as a **skip** with its reason rather than a pass
(`docs/automated-tests/20260804-233335/manifest.json`), which is the honest handling of the absence —
but the absence is still the deviation, and under automated-tests-§3's release gate a `perf` skip is
a gate that did not pass (the narrow "ships no `tests/perf.lua`" exception applies, and **MUST** then
be stated in the release notes). Blocked on `WG-30`.

### WG-35 — `.luacheckrc` omits `debugprofilestop` and `WhatGroupPerfDB`
**Section:** `lint`, `performance-§2`, `performance-§5` · **Where:** `.luacheckrc:18-39` · *recurs*

`debugprofilestop` belongs in `read_globals` (bracket call sites are addon code and **are** linted)
and `WhatGroupPerfDB` in `globals` beside `WhatGroupDB`. Neither is declared. Costs nothing today
because there are no call sites — which is exactly why it will be missed on the day there are.
**Fix:** two lines. Pointless before `WG-30`.

### WG-36 — `.pkgmeta` ignore list omits `_dev` and lockfiles
**Section:** `packaging` · **Where:** `.pkgmeta:6-11` · *recurs*

The file ignores `.luacheckrc`, `.gitignore`, `.gitattributes`, `docs`, `tests`. `_dev` and
lockfiles are missing. The directory does not exist today; the rule exists so that the day someone
creates one it is already excluded rather than shipped to players in a release nobody re-read the
packaging config for. **Fix:** add `- _dev` and `- "*.bak"`. Independent, one line, no risk.

### WG-37 — two settings-layer call sites fall back to the global `print()`
**Section:** `events-frames-taint-§8`, `slash-commands-§4` ·
**Where:** `settings/Panel.lua:22-25`, `settings/Schema.lua:48-51` · *recurs*

Both files define `local function pout(...)` that calls `WhatGroup._print` when present and the raw
global `print(...)` otherwise. events-frames-taint-§8 names exactly **one** sanctioned second output
path — the library-absent branch of `core/CoreSetup.lua` — and this is not it: the global carries no
`[WG]` tag and is not secret-safe. In practice the branch is unreachable (`core/WhatGroup.lua` sets
`WhatGroup._print` and loads first), which makes it low-impact, not a non-deviation: a TOC reorder
would silently activate a second untagged chat path. **Fix:** delete the fallback arm and call
`NS.Print`; if a guard is still wanted, make it a no-op rather than a second printer. Independent,
and the cheapest MUST here to close.

### WG-44 — the master-switch capture tests cannot fail: they neutralize the input before asserting
**Section:** `testing-§12` · **Where:** `tests/test_capture.lua:63-76`, `tests/test_capture.lua:261-275` · *new*

`test("capture: master switch off means nothing is queued", …)` sets `enabled = false`, drives
`OnApplyToGroup` and the `applied` event, then **nils `mock.searchResults[100]`** (`:71`) before
firing `inviteaccepted` and asserting `assertNil(addon.pendingInfo)`. With the search result gone
there is nothing for the accept path to capture, so the assertion holds no matter what the master
switch does — the case reads as coverage of the gate and provides none. The sibling case at
`:261-275` has the same shape (`mock.searchResults[10] = nil` at `:271`).

This is not a theoretical falsifiability concern: the implementation it claims to cover **does not
have the gate**. `WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED`'s `"inviteaccepted"` branch calls
`CaptureGroupInfoFromApplication` unconditionally (`core/WhatGroup.lua:639`), assigns
`self.pendingInfo` (`:650`) and fires `_TryFireJoinNotify` (`:671`) with no
`db.profile.enabled` check — only `OnApplyToGroup` is gated (`:488`). The suite is green anyway.
testing-§12 is explicit that a test which cannot fail is worse than no test, because it still prints
`PASS`, still counts in the `--list` inventory and still moves the README badge.

Note the audit boundary: testing-§12 says an audit **MUST NOT** record the mere *absence* of a
mutation check as a deviation. This is not that — the falsification was demonstrated, and the
underlying behavior gap is separately tracked as `F-001` in `docs/reviews/2026-08-05/01_FINDINGS.md`.

**Fix:** leave the search result in place so the accept path has real data to capture, assert
`pendingInfo` stays nil, and add the `-- red under:` comment testing-§12 SHOULDs, naming the
mutation. Fix the implementation gate in the same change or the corrected test goes red — which is
the point.

---

## SHOULD

### WG-38 — README carries a non-canonical `## Bundled libraries` section
**Section:** `documentation-§1`, `anti-patterns` #28 · **Where:** `README.md:81-83` · *recurs*

documentation-§1 fixes the README's twelve sections in exact order. A thirteenth sits between
`## How it works` (item 8) and `## FAQ` (item 9), and its content is contributor-facing — which
documentation-§1 says belongs under `docs/`. All canonical sections are present and in the correct
relative order, so this is an insertion rather than a reordering. **Fix:** move it into
`docs/ARCHITECTURE.md`'s external-dependencies section (which already carries the same material),
keeping at most the MIT attribution line if it must stay user-visible.

### WG-39 — `docs/ARCHITECTURE.md` omits four of the section headings the standard names
**Section:** `documentation-§3` · **Where:** `docs/ARCHITECTURE.md:1,5,11,57,85,91,108` · *recurs*

The standard's shape is Overview, Module Map, Settings Schema, Message Bus, Slash Commands (table
from `NS.COMMANDS`), Event Subscriptions, Taint Notes, Known Limitations. The file is strong but
uses its own headings — `What it does`, `Subsystems at a glance`, `Invariants worth not breaking`,
`Working environment`, `External dependencies`, `Load order` — leaving four topics with no home:
**Settings Schema** and **Slash Commands** (delegated to `docs/settings-system.md` /
`docs/slash-dispatch.md`, with no table here), **Message Bus** (absent — correctly, since the addon
has none, but the shape wants that said) and **Known Limitations** (absent). **Fix:** add the four
headings; three are a few lines each, and Known Limitations has real content available (the locale
scope decision, the declined Perf wiring, the console's position persistence).

### WG-40 — settings-category registration is refused under combat, so a login in combat leaves the addon absent from the options list
**Section:** `options-ui-§5`, `options-ui-§9` · **Where:** `settings/Panel.lua:266-272` · *recurs*

`Settings.Register()` calls `Helpers.CreateOptionsPanel()` at `OnEnable` — correct — but returns
early first if `InCombatLockdown()`. options-ui-§9 states plainly that the category registration
itself never taints, and the addon's own comment (`settings/Panel.lua:255-259`,
`core/WhatGroup.lua:148-159`) already identifies its real taint sources as the secure teleport button
and the `UISpecialFrames` insert, both correctly deferred in `modules/Frame.lua`. The guard defends
against a failure the standard says does not exist. User-visible consequence: log in during combat
and the **Ka0s WhatGroup** entry is missing from Settings → AddOns until `/wg config` runs. **Fix:**
drop the combat guard from `Settings.Register()` and keep the panel-**open** gate the library already
enforces; or, if the guard stays, replace the early `return` with a one-shot re-registration on
`PLAYER_REGEN_ENABLED` and record it as an accepted deviation in-code.

### WG-42 — `NS.FONT_MONO` has no Blizzard fetch-failure fallback
**Section:** `debug-logging-§2` · **Where:** `core/WhatGroup.lua:96`, consumed at `core/DebugLogSetup.lua:95` · *recurs*

debug-logging-§2 asks for the vendored path exposed as a constant with a Blizzard font (e.g.
`Fonts\ARIALN.TTF`) as the fetch-failure fallback. The constant is a bare path handed straight to the
descriptor, which the library validates at `:New` time. The vendored TTF and its `OFL.txt` are both
present, so this only bites if the file fails to load in-client. **Fix:** resolve the constant
through a small guard falling back to `Fonts\ARIALN.TTF`, or record the omission as deliberate with a
comment saying why a vendored file is treated as always present.

### WG-45 — the docs state the commit gate but never the v2.21.0 release gate
**Section:** `automated-tests-§3` (*The release gate*), `automated-tests-§6`, `documentation-§5` ·
**Where:** `docs/testing.md:214-229`, `docs/automated-tests/README.md:19-33`,
`docs/automated-tests/RESULTS.md:9-11`, `DEPENDENCIES.md:92` · *new*

Standard v2.21.0 added a second, different checkpoint: **commits** are gated on `lint` + `tests`
only, and the **tag** is gated on all four suites at `pass` **plus**
`suites.complexity.warnings == 0` (zero functions above CCN 15), evaluated by the release command
from the run's `manifest.json`, with a `skip` blocking as NOT EVALUATED rather than reading as a
pass. Every place this addon describes gating stops at the commit half:

- `docs/testing.md:216-219` — the gates table marks `perf` and `complexity` "no — recorded only",
  and `:221` says they "**never fail a run**", with no mention of the tag.
- `docs/testing.md:228-229` — "**At release, not at commit.**" describes only that a *bundle is
  produced* at release; it then says "Commits are gated on lint + tests only" and stops, where the
  release gate is exactly what belongs next.
- `docs/automated-tests/README.md:21-30` — the same table and the same "never used to fail a run"
  sentence, again with no release-gate row.
- `docs/automated-tests/RESULTS.md:9-11` — "`perf` and `complexity` are recorded and never fail a
  run" without naming the checkpoint that qualifies it.
- `DEPENDENCIES.md:92` — `lizard` is listed as "**optional**", which was true when complexity only
  reported; under the release gate an absent `lizard` makes the tag's zero-CCN claim unmeasured.

None of this is wrong about commits — it is incomplete about releases, and the incompleteness reads
as a decision ("complexity never gates") rather than as staleness. **Fix:** in each of the four docs,
follow the "never fails a run" sentence with the release-gate sentence naming both conditions and the
actor; add a release-gate row or a short subsection to both gates tables; and in `DEPENDENCIES.md`
mark `lizard` "optional for day-to-day work, **required to cut a release**". No code changes.

---

## MAY / advisory

### WG-43 — two config files cite the retired global `§N.M` section numbering
**Section:** `STANDARDS.md` cross-reference scheme (`filename-§N` is the only form) ·
**Where:** `.luacheckrc:1` (`§14`), `.pkgmeta:4` (`§3.3, §13`) · *recurs*

Every other file in the repo already uses `filename-§N`; these two headers point at nothing.
Advisory: no normative rule binds an addon's comments to the citation scheme, but a dead
cross-reference costs the next reader a lookup that resolves to nothing. **Fix:** `§14` → `lint`;
`§3.3, §13` → `library-stack-§3, packaging`.

---

## Sections measured and found compliant

Recorded as results, not omissions: `layout`, `toc-file` (§1 apart from `WG-31`, §3, §4, §5),
`library-stack` (including the whole-folder LibKa0s payload and the single aggregate TOC line),
`architecture`, `savedvariables` (§1–§3, §5 — the `or` chains are over API data and documented as
such), `options-ui` (§1–§8, §10, §11, including the sanctioned load-completing stub),
`standalone-windows`, `preview-mode`, `slash-commands` (§1, §3–§6), `localization` (all five —
zero British-spelled tokens in addon-owned source or docs), `events-frames-taint` (§1–§7, and §8
apart from `WG-37`), `public-api` (not engaged), `compat`, `debug-logging` (§1, §3–§12), `lint`
(the run is 0/0; only the two missing globals of `WG-35`), `packaging` (apart from `WG-36`),
`testing` (§1–§11, §13; §12 fails as `WG-44`; §10 not applicable — the addon publishes no LibStub
major), `automated-tests` (§1, §2, §4, §5, §7 — bundles frozen and unpruned, runner vendored and
executable, `*.sh text eol=lf` present, `RESULTS.md` a single overwritten path with two watch-list
tables both correctly reading "None.", **no retired `docs/complexity.md`**), `performance-§10`/`§11`
(the complexity report is measured, matches, and the CCN-elimination refactor used named units
rather than metric-gaming shapes), `documentation` (§1 apart from `WG-38`, §2, §3 apart from
`WG-33`/`WG-39`, §4, §6 — **all three standards-reference places present**, §7),
`audit-review-history`, `versioning-git`, `naming-cheatsheet`.

**Anti-patterns:** none of #1–#55 is exhibited by the addon. In particular **#47 is clear** (no
hand-rolled console, options toolkit, dispatcher or harness anywhere in the repo), **#48 is clear**
(`libs/LibKa0s/` is the entire ship folder, including the two Perf files the addon does not wire, and
the TOC lists `LibKa0s.xml` once), **#49 is clear**, **#51/#53 are clear** (the watch list is a
result, not a backlog), **#54 is clear**, and **#45 is UNVERIFIED rather than clear** — see
`03_EVIDENCE.md`.
</content>
