# Ka0s WhatGroup — Deviations (2026-08-04)

**Audited against:** Ka0s WoW Addon Standard **v2.17.1 (2026-08-03)**.

**Standard provenance:** `AUDIT.md`, `standards/STANDARDS.md` and **all 24** section files linked
from the Sections list were fetched over the network with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`, then verified
**byte-identical** (`diff -r`, exit 0) against the clean local checkout at
`2141229 v2.17.1`. No section was unassessed and no rule here is reconstructed from memory.

**ID prefix:** `WG-` (stable since the 2026-07-12 run). New IDs this run begin at `WG-30`.

---

## Summary

| Severity | Count | IDs |
|---|---|---|
| **MUST** | 8 | WG-30 · WG-31 · WG-32 · WG-33 · WG-34 · WG-35 · WG-36 · WG-37 |
| **SHOULD** | 5 | WG-38 · WG-39 · WG-40 · WG-41 · WG-42 |
| **MAY / advisory** | 1 | WG-43 |

**Verdict: minor deviations.** Six of the eight MUSTs are one decision — the declined
`LibKa0s-Perf-1.0` wiring — surfacing in six sections. Everything the standard's other
twenty-odd sections require is met, including the whole shared-library adoption, the vendor-sync
gate, the green gate and the doc set.

**Closed since 2026-07-18:** `WG-09` (relaxed by standard v2.8.0 — `X-Wago-ID` is now MAY),
`WG-14`, `WG-17`, `WG-19`, `WG-22`, `WG-23`, `WG-24`, `WG-25`, `WG-26`, `WG-27`, `WG-28`, `WG-29`.
No prior deviation recurs.

**Standing accepted deviations, recorded in-repo and not re-litigated here:** the vendored JetBrains
Mono console font (`WG-20`) and the landing-page logo (`WG-21`) are both **sanctioned** by
debug-logging-§2 and options-ui-§5 and an audit **MUST NOT** flag them. `LIBKA0S-05` (the console no
longer persists its position) is a **library** contract gap, not the addon's — `debug-logging`'s
guarantee list does not include position persistence, and the window is the library's to draw.

---

## MUST

### WG-30 — `LibKa0s-Perf-1.0` is not wired: no `core/PerfSetup.lua`, no `NS.Perf`, no buckets
**Section:** `performance-§1`, `performance-§3`, `performance-§6` · **Where:** repo has no
`core/PerfSetup.lua`; `WhatGroup.toc:30-37` (`# Core` block) · *new*

performance-§1 makes the **wiring** a MUST for every addon: create one instance at load from a
descriptor in its own `core/PerfSetup.lua`, positioned before any consumer, and degrade to a stub.
performance-§3 requires declared buckets; performance-§6 requires the suspend/resume host contract.
None of it exists. The library files themselves **are** vendored (`libs/LibKa0s/Perf.lua`,
`PerfPanel.lua`) — that half is correct and is what library-stack-§7's whole-folder rule demands.

The decline is a **recorded, user-taken decision** — `docs/pending/LEDGER.md:63` (`LIBKA0S-15`,
2026-08-02) — on two structural grounds: the addon has no hot path (a whole-repo sweep finds zero
`OnUpdate`, zero tickers, zero repeating timers, so every declared bucket would read `0.000`, which
performance-§3 itself calls *a lie in every report*), and `suspend` on a **capture** addon would
silently drop the applies and invites the addon exists to record, costing the user the feature
rather than pausing a display. Four of the eight adopters have declined Perf on the same reasoning.

It is nonetheless a MUST in the current standard, so it is on the register. **Fix direction:** two
mutually exclusive routes, and the choice is the user's — (a) wire the harness anyway, with buckets
on the roster handler and the capture path and a suspend implementation that refuses to make capture
inert; or (b) take it upstream, as a `performance` amendment carving out addons whose suspend
contract would destroy user data. Route (b) is the one the collection's evidence points at, and it
would close `WG-30` through `WG-35` at once.

### WG-31 — TOC declares one SavedVariables global; the standard requires exactly two
**Section:** `toc-file-§1`, `toc-file-§2`, `savedvariables-§4`, `performance-§5` ·
**Where:** `WhatGroup.toc:7` · *new*

`## SavedVariables: WhatGroupDB`. toc-file-§2 is explicit: **exactly two** globals in order,
`<Addon>DB` then `<Addon>PerfDB`, the latter being the standard's one sanctioned non-AceDB SV.
**Fix:** `## SavedVariables: WhatGroupDB, WhatGroupPerfDB` — but only alongside `WG-30`, since a
declared-but-never-written SV global is worse than an absent one. Blocked on the `WG-30` decision.

### WG-32 — the reserved `perf` verb is missing from `NS.COMMANDS`
**Section:** `slash-commands-§2`, `performance-§4` · **Where:** `settings/Slash.lua:44-67` · *new*

slash-commands-§2 reserves `perf` collection-wide and requires it to be registered **by the addon**
through its own `COMMANDS` table. The table carries eleven verbs; `perf` is not among them, so
`/wg perf` answers `unknown command 'perf'`. **Fix:** one positional-triple row dispatching to the
library's command entry point, printing the returned lines through `NS.Print`. Blocked on `WG-30`.

### WG-33 — `docs/performance.md` and `docs/perf-runs/README.md` are absent
**Section:** `documentation-§3`, `performance-§8` · **Where:** `docs/` (neither file exists) · *new*

documentation-§3 names **three** required topic-detail docs. `docs/test-cases.md` is present and
generated; the other two are not. performance-§8 additionally makes `docs/perf-runs/` a **standing,
cumulative** capture store rather than a per-investigation folder. **Fix:** write both when `WG-30`
resolves; if the decline is ratified upstream, `docs/performance.md` still has a job — a one-screen
page stating that this addon has no bracketed hot path and why, so the next reader does not go
looking for a harness. Blocked on `WG-30`.

### WG-34 — no `tests/perf.lua` offline scenario runner, and so no zero-overhead evidence
**Section:** `performance-§9`, `performance-§2` · **Where:** `tests/` (no `perf.lua`) · *new*

performance-§9 requires the offline runner at that exact path, outside the green gate, asserting only
deterministic quantities, and shipping a **zero-overhead scenario** — which performance-§2 names as
the *required evidence* that instrumentation is free when off, explicitly not a comment claiming it.
With no brackets there is nothing to measure, so this is downstream of `WG-30` in the strictest
sense. **Fix:** ships with the harness or dies with the carve-out. Blocked on `WG-30`.

### WG-35 — `.luacheckrc` omits `debugprofilestop` and `WhatGroupPerfDB`
**Section:** `lint`, `performance-§2`, `performance-§5` · **Where:** `.luacheckrc:18-39` · *new*

`lint`'s template puts `debugprofilestop` in `read_globals` (because bracket call sites are addon
code and **are** linted, even though `libs/` is not) and `<Addon>PerfDB` in `globals` beside the
settings global. Neither is declared. Today this costs nothing — there are no call sites — which is
exactly why it will be missed on the day there are. **Fix:** add both, with the comments the template
carries. Two lines, mechanical, but pointless before `WG-30`.

### WG-36 — `.pkgmeta` ignore list omits `_dev` (and lockfiles)
**Section:** `packaging` · **Where:** `.pkgmeta:6-11` · *new*

packaging states the addon **MUST** ignore `docs/`, `_dev/`, `tests/`, and lockfiles. The file
ignores `.luacheckrc`, `.gitignore`, `.gitattributes`, `docs` and `tests` — `_dev` is missing. The
directory does not exist today, so nothing currently ships that should not; the rule exists so that
the day someone creates one, it is already excluded rather than shipped to players in a release
nobody re-read the packaging config for. **Fix:** add `- _dev` and `- "*.bak"` to the ignore list.
Independent of every other item here — one line, no risk.

### WG-37 — two settings-layer call sites fall back to the global `print()`
**Section:** `events-frames-taint-§8`, `slash-commands-§4` ·
**Where:** `settings/Panel.lua:22-25`, `settings/Schema.lua:48-51` · *new*

Both files define `local function pout(...)` that calls `WhatGroup._print` when present and the raw
global `print(...)` otherwise. events-frames-taint-§8 is unambiguous that call sites **MUST NOT**
call the global `print()` — it neither carries the `NS.PREFIX` tag nor secret-stringifies its args —
and it names exactly **one** sanctioned place for a second output path: the library-absent branch of
`core/CoreSetup.lua`, which this is not. The section adds that such a call site is *non-compliant
even if it is never handed a secret today*.

In practice the branch is unreachable: `core/WhatGroup.lua:83` sets `WhatGroup._print` and the TOC
loads `# Core` before `# Settings`, so `pout` always takes the first arm. That makes this a
low-impact deviation, not a non-deviation — the fallback is a second, untagged, non-secret-safe chat
path that a future TOC reorder would silently activate. **Fix:** delete the fallback arm and call
`NS.Print` directly; if a guard is still wanted, make it a no-op rather than a second printer.
Independent, and the cheapest MUST on this list to close.

---

## SHOULD

### WG-38 — README carries a non-canonical `## Bundled libraries` section
**Section:** `documentation-§1`, `anti-patterns` #28 · **Where:** `README.md:81-83` · *new*

documentation-§1 fixes the README's twelve sections *in this exact order* so every addon reads
identically. A thirteenth section sits between `## How it works` (item 8) and `## FAQ` (item 9),
describing the vendored library stack and its license. The canonical sections are all present and
all in the right relative order, so this is an insertion rather than a reordering — but it is a
departure from the canonical structure, and its content is contributor-facing (which
documentation-§1 says belongs under `docs/`), with the one genuinely player-relevant part being the
MIT attribution. **Fix:** move the paragraph to `docs/ARCHITECTURE.md`'s external-dependencies
section, which already carries the same material, and keep at most the LibKa0s license line if
attribution needs to remain user-visible.

### WG-39 — `docs/ARCHITECTURE.md` omits four of the section headings the standard names
**Section:** `documentation-§3` · **Where:** `docs/ARCHITECTURE.md:1-138` · *new*

documentation-§3 specifies the doc's sections: Overview, Module Map, Settings Schema, Message Bus,
Slash Commands (table from `NS.COMMANDS`), Event Subscriptions, Taint Notes, Known Limitations. The
file is genuinely excellent and covers most of that content, but under its own headings and with
four topics having no home: **Settings Schema** and **Slash Commands** are delegated to
`docs/settings-system.md` / `docs/slash-dispatch.md` with no table here; **Message Bus** is absent
(correctly — the addon has none, but the standard's shape wants that said); **Known Limitations** is
absent entirely. **Fix:** add the four headings. Three are short — a schema table, the `COMMANDS`
table, and a one-line "no message bus: single feature module, direct method calls on the AceAddon
object". Known Limitations has real content available already (the enGB/locale scope decision, the
declined Perf wiring, the console's lost position persistence).

### WG-40 — settings-category registration is refused under combat, so a login in combat leaves the addon absent from the options list
**Section:** `options-ui-§5`, `options-ui-§9` · **Where:** `settings/Panel.lua:248-251` · *new*

options-ui-§5 makes eager registration at load a MUST, and options-ui-§9 states plainly that **the
category registration itself never taints** — naming, as its worked example, an addon that deferred
registration to dodge a *misdiagnosed* boot-time GameMenu taint which actually came from AceHook
closures and a secure button. `Settings.Register()` calls `Helpers.CreateOptionsPanel()` at
`OnEnable`, correctly — but returns early first if `InCombatLockdown()`. The addon's own comment
already identifies its real taint sources as the secure teleport button and the `UISpecialFrames`
insert (both correctly deferred in `modules/Frame.lua`), so this guard is defending against the
failure options-ui-§9 says does not exist. The user-visible consequence is narrow but real: log in
during combat and the **Ka0s WhatGroup** entry is missing from Settings → AddOns until `/wg config`
is run — the exact defect options-ui-§9 exists to prevent, reached by a different route.

**Fix:** drop the combat guard from `Settings.Register()` and keep the panel-**open** gate, which
already lives inside the library's `OpenOptionsPanel` where every caller meets it. If the guard is
kept, replace the early `return` with a one-shot re-registration on `PLAYER_REGEN_ENABLED` so the
category still arrives, and record it as an accepted deviation with that reasoning in-code.

### WG-41 — no `docs/complexity.md`
**Section:** `performance-§10` · **Where:** `docs/` (absent) · *new*

performance-§10 SHOULDs a committed, **report-only** `lizard` run over the addon's own source
excluding `libs/`. It explicitly must not gate commits, and absent tooling means the report is stale
rather than the addon non-compliant. **Fix:** run `lizard` excluding `libs/`, commit the output as
`docs/complexity.md` with a header stating it is generated and how. Independent of `WG-30` — this
half of `performance` needs no harness.

### WG-42 — `NS.FONT_MONO` has no Blizzard fetch-failure fallback
**Section:** `debug-logging-§2` · **Where:** `core/WhatGroup.lua:96-100` · *new*

debug-logging-§2 asks for the vendored path exposed as a constant *"with a Blizzard font (e.g.
`Fonts\ARIALN.TTF`) as the fetch-failure fallback"*. The constant is a bare path string, and it is
handed straight to the library's descriptor, which validates it at `:New` time. The vendored TTF and
its `OFL.txt` are both present and correct, so this only bites if the file fails to load in-client.
**Fix:** resolve the constant through a small guard that falls back to `Fonts\ARIALN.TTF`, or record
the omission as deliberate with a comment saying why a vendored file is treated as always present.

---

## MAY / advisory

### WG-43 — two config files cite the retired global `§N.M` section numbering
**Section:** `STANDARDS.md` cross-reference scheme (`filename-§N` is the only form) ·
**Where:** `.luacheckrc:1` (`§14`), `.pkgmeta:4` (`§3.3, §13`) · *new*

The standard retired global `§N.M` numbering at v1.5.0; every reference is now `filename-§N`. Both
config headers still cite the old form, so the numbers point at nothing. Every other file in the
repo — source, docs, `CLAUDE.md` — already uses the current scheme, which is what makes these two
stand out. Advisory only: no normative rule binds an addon's comments to the citation scheme, but a
dead cross-reference costs the next reader a lookup that resolves to nothing. **Fix:** `§14` → `lint`,
`§3.3, §13` → `library-stack-§3, packaging`.

---

## Sections measured and found compliant

Recorded as results, not omissions: `layout`, `library-stack` (including the whole-folder LibKa0s
payload and both empty vendor diffs), `architecture`, `savedvariables-§1/§2`,
`options-ui` (§1–§8, §10, §11), `standalone-windows` (including the §2 window edge and the close-control
rule), `preview-mode`, `slash-commands` (§1, §3–§6), `localization` (all five subsections),
`events-frames-taint` (§1–§7, and §8 apart from `WG-37`), `public-api` (not engaged),
`compat`, `debug-logging` (§1, §3–§12), `testing` (all twelve subsections; §10 not applicable —
the addon publishes no LibStub major), `audit-review-history`, `versioning-git`,
`naming-cheatsheet`, and the whole `anti-patterns` list — no anti-pattern #1–#49 is exhibited. In
particular **#45 and #48 are clear**: both `diff -r` runs are empty and `libs/LibKa0s/` is the entire
ship folder including the two Perf files the addon does not wire; **#47 is clear**: there is no
hand-rolled console, options toolkit, dispatcher or harness anywhere in the repo; **#49 is clear**:
no `docs/agent-context.md`, and `CLAUDE.md` states it must never return.
