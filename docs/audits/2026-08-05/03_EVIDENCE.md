# Ka0s WhatGroup — Evidence (2026-08-05)

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` is sourced here: a `file:line` citation
or a command with its real output. Nothing below is inferred from code looking reasonable.

Repo: `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup` @ `b31c90d` (2026-08-05), working tree
clean apart from `docs/reviews/2026-08-05/` (untracked) and this bundle.

---

## A. Mechanical checks — RUN

### A1. Lint

```
$ luacheck .
Checking core/Compat.lua ... OK
... (14 files)
Total: 0 warnings / 0 errors in 14 files
exit=0
```

Config scope: `.luacheckrc:8` — `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "tests/" }`.
Declared globals: `.luacheckrc:18-21` (`WhatGroupDB`, `StaticPopupDialogs`) — **no `WhatGroupPerfDB`**;
`read_globals` `.luacheckrc:25-39` — **no `debugprofilestop`** (evidence for `WG-35`).

### A2. Headless harness

```
$ lua5.1 tests/run.lua
...
422 passed, 0 failed, 422 total
exit=0
```

### A3. Generated test-case inventory (testing-§5)

```
$ lua5.1 tests/run.lua --list > /tmp/.../tc.md
$ diff /tmp/.../tc.md docs/test-cases.md
(no output)  -> test-cases: IN SYNC
```

README `[tests]` badge (`README.md:7`) reads `Tests-422%2F422_passing` — matches the 422/422 above.

### A4. Complexity — the standard's exact invocation, and its drift

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
...
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
      5573       6.3     1.7       45.6      808            0      0.00    0.00
exit=0
```

Top functions by CCN (none warned):

| CCN | Function |
|---|---|
| 13 | `WhatGroup@533-573@./core/WhatGroup.lua` (`_TryFireJoinNotify`) |
| 12 | `ConfigureTeleportButton@184-261@./modules/Frame.lua` |
| 12 | `WhatGroup@619-673@./core/WhatGroup.lua` (`LFG_LIST_APPLICATION_STATUS_UPDATED`) |
| 12 | `WhatGroup@445-477@./core/WhatGroup.lua` (`ShowNotification`) |
| 12 | `WhatGroup@174-189@./core/WhatGroup.lua` (`InitSummary`) |
| 11 | `Helpers.ValidateSchema@285-318@./settings/Schema.lua` |

**Drift vs the newest committed bundle: NONE.** `docs/automated-tests/20260804-233335/complexity.txt`
(tail) carries the identical footer — `5573 / 6.3 / 1.7 / 45.6 / 808 / 0 / 0.00 / 0.00` — and the same
"No thresholds exceeded" line. `docs/automated-tests/20260804-233335/manifest.json` records
`"complexity": { "status": "pass", "warnings": 0, "maxCcn": 13, "nloc": 5573, "functions": 808,
"bandFiles": 0, "overCapFiles": 0, "gating": false }`. No function crossed a `lizard` threshold and
no file entered layout-§1's 1000–1500 band since that run.

**Staleness of the record.** The newest bundle is stamped `20260804-233335`, i.e. **hours** old, and
its manifest records `"git": { "sha": "2111c54…", "branch": "feat/fix-ccn", "dirty": true }` while
`HEAD` is `b31c90d` — two docs-only commits ahead (`433f160`, `b31c90d`). The numbers still reproduce
exactly, so the record is current in substance; the `dirty: true` stamp means the run cannot be tied
to a commit, which is worth knowing when this bundle is read later. The checkpoint is **release**
(automated-tests-§6), and no release has been cut since, so this is not a finding against commit
gating.

**Watch list read as a decision record** (`docs/automated-tests/RESULTS.md`, "Complexity watch list"):
both required tables are present and both read **"None."**, written as a result rather than dropped
(automated-tests-§4). Zero entries carry an "accepted" disposition, so anti-pattern #53's
three-consecutive-runs shelf life is not engaged. The three entries carried at the
`20260804-182231` baseline (CCN 22, 22, 17) were split into named units and retired, not renewed.

**Refactor shapes (performance-§11 / anti-pattern #52).** The CCN-elimination work is visible in
`core/WhatGroup.lua:210-241` (`buildCapture`) and `:246-…` (`applyActivityInfo`) — named units that
describe a thing a reader recognizes, not `part2`/`doTheRest`. The literal table is built inside a
per-capture builder, which is a per-capture allocation deliberately (documented at `:226-228`: a
shared fallback would alias every id-less capture together), not a per-frame path. The `or`-chain
decision is documented at `:203-209` with the `false`-vs-`nil` reasoning spelled out — the opposite
of a silent #54.

### A5. `.gitattributes` and the vendored runner (automated-tests-§2)

- `.gitattributes` last stanza: `*.sh   text eol=lf`, with the `bash\r` rationale written above it.
- `ls -l tests/_kit/run-automated-tests.sh` → `-rwxrwxrwx … 23340 …` — vendored and executable.
- Kit contents: `tests/_kit/{README.md, framework.lua, loader.lua, mock_base.lua, run-automated-tests.sh}`
  — under `tests/`, never `libs/`.

### A6. Retired `docs/complexity.md`

```
$ ls docs/complexity.md
(absent)
```

Correct as of standard v2.19.0 / automated-tests-§7. `docs/testing.md:236-237` records the retirement
explicitly. This closes the prior run's `WG-41`.

### A7. British-spelling sweep (anti-pattern #46, localization-§5)

`grep -rniE "(colour|grey|behaviour|centre|cancelled|initialis|organis|recognis|customis|normalis|serialis)"`
over `core/ defaults/ locales/ modules/ settings/ tests/ README.md CLAUDE.md DEPENDENCIES.md` and the
`docs/` trio + five topic docs → **no hits** (the three matches returned were `analysis` / `ANALYSIS.md`,
US-spelled). The addon's own surface is clean.

The vendored library carries British spellings in authored comments —
`libs/LibKa0s/{Core.lua:5, DebugLog.lua:5, Options.lua:1, OptionsWidgets.lua:5, Slash.lua:5}` hits —
but `libs/LibKa0s/` is **not this addon's code** and is audited in its own repo. Recorded here as
context only; it is not a WhatGroup deviation. It is tracked as `F-U01` in
`docs/reviews/2026-08-05/01_FINDINGS.md`.

---

## B. Checks NOT RUN (unverifiable this session — never read as a pass)

### B1. Ka0s-owned vendored library drift (`diff -r`, anti-patterns #45 / #48)

Both diffs the playbook mandates were **NOT RUN**:

```
diff -r ../LibKa0s/LibKa0s  ./libs/LibKa0s     -- NOT RUN
diff -r ../LibKa0s/testkit  ./tests/_kit       -- NOT RUN
```

Reason: this engagement is constrained to the single repository
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup`; no sibling repo may be read. `../LibKa0s`
exists on this machine (its presence was observed via `ls -d`, nothing inside it was opened), so the
check is **runnable but not run**, not impossible.

Consequence, stated plainly: **vendor drift is unverified.** Both suites staying green says nothing
about it — that is the exact silence anti-pattern #45 describes. What *can* be said from inside this
repo is that the vendoring is **whole** rather than partial: `libs/LibKa0s/` carries `Core.lua`,
`DebugLog.lua`, `Slash.lua`, `Options.lua`, `OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`,
`PerfPanel.lua`, `LICENSE` and `LibKa0s.xml`, and `libs/LibKa0s/LibKa0s.xml:2-9` lists all eight
`.lua` files — no shell without its attach file, no dependent module without `Core.lua`
(anti-pattern #48 clear on the evidence available). Module minors, for the next diff:
Core 4, DebugLog 7, Slash 6, Options 6, Perf 6.

### B2. `make test`

No `Makefile` in the repo — not applicable.

---

## C. Evidence per deviation

### WG-30 — Perf not wired
- No `core/PerfSetup.lua` anywhere in the tree (full `find` listing taken this run).
- `WhatGroup.toc:26-33` — the `# Core` block lists `CoreSetup`, `Util`, `Compat`, `Database`,
  `WhatGroup`, `DebugLogSetup`; no `PerfSetup.lua` slot (toc-file-§5's template puts it before any
  `NS.Perf` consumer).
- `grep -rn "NS.Perf\|LibKa0s-Perf-1.0" core defaults modules settings` → no addon-side hits.
- The library half is present: `libs/LibKa0s/Perf.lua:25` — `local MAJOR, MINOR = "LibKa0s-Perf-1.0", 6`;
  `libs/LibKa0s/PerfPanel.lua` present; both listed in `libs/LibKa0s/LibKa0s.xml:8-9`.
- Decision record: `docs/pending/LEDGER.md` (`LIBKA0S-15`); restated at `CLAUDE.md:58-61` —
  "**Perf is declined** on structural grounds".

### WG-31 — one SavedVariables global
- `WhatGroup.toc:7` — `## SavedVariables: WhatGroupDB`.
- toc-file-§1's template and toc-file-§2 require `<Addon>DB, <Addon>PerfDB`.

### WG-32 — no `perf` verb
- `settings/Slash.lua:43-67` — the `COMMANDS` literal, eleven positional triples: `help`, `show`,
  `test`, `config`, `version`, `list`, `get`, `set`, `reset`, `resetall`, `debug`.
- `grep -n "perf" settings/Slash.lua` → no matches.
- `README.md:47-61` — the published command table carries the same eleven, so the docs are
  consistent with the code and both are missing the reserved verb.

### WG-33 — two required topic-detail docs absent
- `docs/performance.md` — absent. `docs/perf-runs/` — absent (no directory).
- Present and correct: `docs/test-cases.md`, `docs/automated-tests/README.md`,
  `docs/automated-tests/RESULTS.md`.

### WG-34 — no offline scenario runner
- `tests/` contains `run.lua`, `loader.lua`, `wow_mock.lua`, 14 `test_*.lua`, `_kit/` — no `perf.lua`.
- `docs/automated-tests/20260804-233335/manifest.json` — `"perf": { "status": "skip", "skipReason":
  "no tests/perf.lua — this addon ships no offline scenarios", "scenarios": 0, "gating": false }` —
  the honest recording automated-tests-§3 requires.

### WG-35 — `.luacheckrc` globals
- `.luacheckrc:18-21` `globals = { "WhatGroupDB", "StaticPopupDialogs" }`.
- `.luacheckrc:25-39` `read_globals` — `debugprofilestop` absent.

### WG-36 — `.pkgmeta` ignore list
- `.pkgmeta:6-11` — `ignore:` lists `.luacheckrc`, `.gitignore`, `.gitattributes`, `docs`, `tests`;
  no `_dev`, no lockfile pattern. `.pkgmeta:1` `package-as: WhatGroup`; `:3-4` records that there is
  deliberately **no `externals:`** block (packaging, anti-pattern #7 clear).

### WG-37 — global `print()` fallback
- `settings/Panel.lua:22-25`:
  ```lua
  local function pout(...)
      if WhatGroup._print then return WhatGroup._print(...) end
      print(...)
  ```
- `settings/Schema.lua:48-51` — the same shape.
- Reachability: `core/WhatGroup.lua` publishes `WhatGroup._print`, and `WhatGroup.toc:26-49` loads
  `# Core` before `# Settings`, so the first arm always wins today.
- The one sanctioned second printer, for contrast: `core/CoreSetup.lua:62-71` (library-absent branch).

### WG-44 — unfalsifiable master-switch tests
- `tests/test_capture.lua:63-76`:
  ```lua
  test("capture: master switch off means nothing is queued", function()
      ...
      addon.db.profile.enabled = false
      mock.searchResults[100] = baseInfo({ activityIDs = { 500 } })
      addon:OnApplyToGroup(100)  -- returns early, nothing enqueued
      addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")
      mock.searchResults[100] = nil  -- fresh fetch nil -> no data anywhere   <-- :71
      addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")
      assertNil(addon.pendingInfo)
  end)
  ```
  With `searchResults[100]` nil, the accept path has nothing to capture, so the assertion is true
  independently of the master switch.
- `tests/test_capture.lua:261-275` — same shape, `mock.searchResults[10] = nil` at `:271`.
- The gate the tests claim to cover exists only on the apply path: `core/WhatGroup.lua:483-490`
  (`OnApplyToGroup`'s `if not (self.db and self.db.profile and self.db.profile.enabled) then return end`).
- The accept path has no such check: `core/WhatGroup.lua:619-673` — `:639`
  `local fresh = self:CaptureGroupInfoFromApplication(appID)`, `:650` `self.pendingInfo = final`,
  `:671` `self:_TryFireJoinNotify("inviteaccepted")`, none of them gated on `profile.enabled`.
- The suite is nonetheless green (A2), which is the falsification: the covering case passes against
  an implementation that lacks the gate.
- The user-facing contract it contradicts: the master-switch tooltip at `settings/Schema.lua:92`.
- Cross-reference: `docs/reviews/2026-08-05/01_FINDINGS.md` `F-001` / `F-002`, where the behavior was
  reproduced headlessly.

### WG-38 — README extra section
- `README.md` headings in order: `# Ka0s WhatGroup` (:1), `## What's new in 1.3.0` (:18),
  `## Screenshots` (:27), `## Usage` (:41) with `### Slash commands` (:43) / `### Settings panel` (:63),
  `## How it works` (:75), **`## Bundled libraries` (:81)**, `## FAQ` (:85),
  `## Troubleshooting` (:98), `## Issues and feature requests` (:110), `## Version History` (:114).
- Badge row `README.md:3-7` is canonical: `[wow]` `Midnight_12.0.7` (matching `WhatGroup.toc:1`
  `120007`), CurseForge live endpoint `1489907` (matching `WhatGroup.toc:13`), MIT, the standard badge
  with **underscore** spacing (`Ka0s-WoW_Addon_Standard-yellow`, not `%20`), and `[tests]` 422/422.
- Logo at `README.md:9`; no angle-bracket placeholders anywhere in the README (the command table at
  `:55-57` writes `/wg get name`, `/wg set name value` bare).

### WG-39 — `docs/ARCHITECTURE.md` headings
- Actual headings: `# Architecture` (:1), `## What it does` (:5), `## Subsystems at a glance` (:11),
  `## Invariants worth not breaking` (:57), `## Working environment` (:85),
  `## External dependencies` (:91), `## Load order` (:108).
- Absent by name and by content-home: Settings Schema, Slash Commands (table from `NS.COMMANDS`),
  Message Bus, Known Limitations.

### WG-40 — combat-gated category registration
- `settings/Panel.lua:266-272`:
  ```lua
      -- Defense in depth: `runConfig` already refuses under combat, but registering Settings
      -- categories during combat taints the GameMenu callback chain. ...
      if InCombatLockdown() then
          pout("Cannot register settings panel during combat.")
          return
      end
  ```
- Eager registration is otherwise correct: `core/WhatGroup.lua:160-161` calls
  `self.Settings.Register()` at `OnEnable` — anti-pattern #22 is **clear**.
- The addon's own comment naming its real taint sources: `settings/Panel.lua:255-259`,
  `core/WhatGroup.lua:148-159`. Those sources are deferred in `modules/Frame.lua:189-196`, `:306-318`.
- No `PLAYER_REGEN_ENABLED` re-registration exists for the settings category
  (`grep -n "PLAYER_REGEN_ENABLED" settings/` → no hits).

### WG-42 — `NS.FONT_MONO`
- `core/WhatGroup.lua:96` —
  `NS.FONT_MONO = "Interface\\AddOns\\WhatGroup\\media\\fonts\\JetBrainsMono-Regular.ttf"` — a bare
  path, no fallback resolution.
- Consumed at `core/DebugLogSetup.lua:95` (`font = NS.FONT_MONO`), which the library validates at
  `:New` time (`core/DebugLogSetup.lua:9-13` says so).
- The asset is present: `media/fonts/JetBrainsMono-Regular.ttf`, `media/fonts/OFL.txt`.

### WG-45 — release gate absent from the docs
- `docs/testing.md:214-219` — the gates table: `perf` / `complexity` → "no — recorded only".
- `docs/testing.md:221-223` — "**`perf` and `complexity` never fail a run.**" … "They contribute
  `amber`, which is a signal rather than a stop." No release-gate sentence follows.
- `docs/testing.md:228-229` — "**At release, not at commit.** A full bundle is produced as part of
  every version bump, before the tag, with an `ANALYSIS.md` write-up. Commits are gated on lint +
  tests only." — the bundle is described; the gate on it is not.
- `docs/automated-tests/README.md:21-30` — the same table, and "`perf` and `complexity` are
  **measured, recorded and diffed — never used to fail a run.**"
- `docs/automated-tests/RESULTS.md:9-11` — "**`lint` and `tests` gate. `perf` and `complexity` are
  recorded and never fail a run**".
- `DEPENDENCIES.md:92` — "### 2.3 lizard — **optional**, for the complexity report".
- The rule they predate: automated-tests-§3, *The release gate* — a release **MUST NOT** be cut
  unless the release run's `manifest.json` shows all four suites at `pass` and
  `suites.complexity.warnings == 0`, a `skip` counting as not-passed, evaluated by the release
  command rather than by the runner (whose exit code is deliberately unchanged).

### WG-43 — retired `§N.M` citations
- `.luacheckrc:1` — `-- .luacheckrc — lint config for the Ka0s WhatGroup addon (§14).`
- `.pkgmeta:3-4` — `declares NO externals: block (§3.3, §13)`.

---

## D. Compliance claims, sourced

| Claim | Evidence |
|---|---|
| Three-place standards reference complete | `WhatGroup.toc:12`; `README.md:6`; `CLAUDE.md:6-25` |
| Root doc set is exactly three + LICENSE | root listing: `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE` |
| `CLAUDE.md` is a stub, not an agent brief | `CLAUDE.md:69` "This root file is a **stub** (documentation-§2)"; pointer list `:71-80`; green gate `:82-88` |
| No scaffolding pack (#49) | no `docs/agent-context.md`; `CLAUDE.md:33-38` forbids its return |
| No `TODO.md` (documentation-§4) | absent at root and under `docs/` |
| `docs/` trio present | `docs/ARCHITECTURE.md`, `docs/testing.md`, `docs/smoke-tests.md` |
| DebugLog consumed, not hand-rolled | `core/DebugLogSetup.lua:20` lookup, `:88-136` descriptor, `:22-86` stub |
| DebugLog stub covers every member called | stub answers `Add, Debug, Clear, Show, Hide, Toggle, IsShown, IsEnabled, RefreshHeader, ShowCopy, UpdateScrollBar, UpdateStatus, BufferSize, LastLine, FindLine, CopyText, MakeCloseButton, Text, SetEnabled, ConsoleCheckbox` (`core/DebugLogSetup.lua:47-83`) plus `NS.Debug` (`:84`); the deliberate omission of the formatters is reasoned at `:44-46` — a decision, not a gap |
| Core stub covers every member called | `core/CoreSetup.lua:50-98` publishes `IsConcatSafe`, `SafeToString`, `Util.print`, `Util.format`, `SKIN`, `ApplySkin`, `MakeCloseButton`; `Util.format` is published on both paths deliberately (`:73-75`) |
| Options stub is the documented load-completing exception | `settings/OptionsSetup.lua:19-34` states the rule and the addon's **measured** empty load-time set, pinned by `tests/test_libka0s.lua`; `:78-82` refuses to copy the library's layout constants |
| Slash consumed, `COMMANDS` stays the host's | `settings/Slash.lua:43-67` (data), `:71` lookup, `:78-…` stub that re-implements no formatter/parser |
| Whole-folder LibKa0s vendoring, one TOC line | `libs/LibKa0s/` listing; `libs/LibKa0s/LibKa0s.xml:2-9`; `WhatGroup.toc:24` |
| Schema version + migration runner | `core/Database.lua:23-40` |
| Bundles frozen and unpruned | `docs/automated-tests/{20260804-182231,20260804-215056,20260804-233335}/`, each with `manifest.json` + `ANALYSIS.md` + four suite artifacts |
| `RESULTS.md` is one overwritten path with all four standing sections | `docs/automated-tests/RESULTS.md` — trend table, "Test suite", "Lint", "Perf", "Complexity watch list" (two tables, both "None.") |
</content>
