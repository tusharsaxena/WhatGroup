# 01 — Current state (2026-09-07)

**Audited against:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)** — index
`standards/STANDARDS.md` plus **all 26** section files its *Sections* list links, fetched verbatim
with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`.
Playbook: `AUDIT.md` at the same ref.

**Rule set used:** the **addon** rule set. `WhatGroup.toc` exists, so this is not a Ka0s-owned
library repo and `library-stack-§7`'s applicability list does not substitute.

**Repo state at audit time:** branch `main`, clean tree, HEAD `ce572a3`
(*Merge branch 'feat/settings-revamp-v2'*). TOC `## Version: 1.3.0`.

---

## Layout (`layout`)

`core/ defaults/ locales/ modules/ settings/` with `libs/` and `tests/` beside them — the single
modular layout, no flat root. Folder casing is lowercase throughout.

`media/` holds only typed subfolders — `media/logos/` and `media/screenshots/` — and **no** private
copy of anything the shared payload ships: there is no `media/fonts/`, no `media/icons/`, no
`media/textures/`. The JetBrains Mono face and the icon catalog come from
`libs/LibKa0s/media/` (`core/MediaSetup.lua:92` calls `Media.RegisterLSM(addonName)` once).

File sizes: largest addon file is `core/WhatGroup.lua` at **787** lines, then `modules/Frame.lua`
at **672** and `settings/Schema.lua` at **593** — all well below `layout-§1`'s 1000-line on-notice
band.

## TOC (`toc-file`)

Metadata block in the mandated field order, 13 fields, no blank lines inside it. `X-License: MIT`,
`X-Standard:` points at the standards repo, `X-Curse-Project-ID: 1489907` (the addon **is**
published; the id matches the README's CurseForge badge at `README.md:4`).

`## SavedVariables: WhatGroupDB` — **one** global, which is the compliant count for an addon
holding a recorded `performance-§12` decline (`toc-file-§2`). Single `## Interface: 120007`, no
multi-flavor list.

File listing is `#`-sectioned in the mandated order **Libraries → Locales → Core → Defaults →
Modules → Settings**, ends with a single trailing newline (verified byte-wise). `libs\LibKa0s\LibKa0s.xml`
is listed **once**, after Ace3 and LibSharedMedia (`WhatGroup.toc:25`) — no individual `LibKa0s`
`.lua` line anywhere.

Three positions carry annotations (`WhatGroup.toc:30-31`, `:33-34`, `:38-40`); several other
load-bearing ones do not — see **WG-47**.

## Libraries (`library-stack`)

Vendored whole and committed; `.pkgmeta` declares **no** `externals:` block. `libs/` holds LibStub,
CallbackHandler-1.0, AceAddon/AceEvent/AceConsole/AceTimer/AceDB/AceGUI-3.0, LibSharedMedia-3.0 and
`LibKa0s/`.

`CLAUDE.md:69` carries the provenance line — *Bundles [LibKa0s](…) v1.25.0 (MIT).* — and
`README.md` carries **none** (correct since testkit revision 9; anti-patterns #58/#59).

Both vendored payloads are **byte-identical** to the sibling repo at that tag:
`diff -r` over `LibKa0s/` and over `testkit/` → `tests/_kit/` both returned empty (see
`03_EVIDENCE.md`). Six of the ten majors are wired, one setup file each; `Perf` is vendored and
deliberately unwired under a ratified register row.

## Shared subsystems — descriptors and stubs

The addon owns **no** console window, widget maker, flow engine, dispatcher, parser or test
framework. What it owns per module is a descriptor plus a degradation stub:

| Module | Seam file | Descriptor / lookup | Stub |
|---|---|---|---|
| `LibKa0s-Core-1.0` |  `core/CoreSetup.lua:39` | `lib:New{ prefix, sink }` at `:147` | `:41-101`, member-answering |
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua:49` | `NS.Icon` / `NS.MediaFont` / `RegisterLSM` | nil-answering, documented |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua` | conventional slot | present |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:20` | `lib:New{…}` at `:120`, `addonName` at `:133` | `:54-118` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | descriptor + page registry | load-completing (the documented exception) |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:64` | `commands = COMMANDS` at `:150` | `:69-118` |

Stub coverage was checked by grepping the call sites: every `Sl.*` member the addon reaches
(`OnSlash`, `PrintHelp`, `HelpRows`, `LandingRows`, `Text`, `CliList/Get/Set/Reset/Version`) is
answered by the degraded table, and `core/CoreSetup.lua`'s degraded branch publishes the same key
set as its library branch (including `Util.format`, which has no production caller and says so).

`MakeCloseButton` — one wrapper at `core/CoreSetup.lua:136` supplying `addonName`, its degraded twin
at `:100`, and no other addon-side call site. The `grep -rn 'MakeCloseButton('` sweep returns
nothing outside `libs/` and `tests/` beyond those two lines.

## Settings panel (`options-ui`)

One subcategory page, `general`, registered at `settings/Panel.lua:340`, plus the host-drawn landing
page (`buildMain`, exempt per `options-ui-§5`).

The page is **tabbed**. `RenderTabbedSchema` partitions by `group` in declaration order and draws
three tabs: **Master controls** (first, the literal §15 name), **Chat**, **Popup**. The first tab is
**composed, not written** — `Helpers.MasterControls{…}` at `settings/Panel.lua:204` emits the
canonical block and `settings/Panel.lua:262-264` splices it at the head of the array. Its eight
canonical rows are all present and all wired: `visibility` → `ApplyFrameVisibility`, `scale` →
`ApplyFrameScale`, `alpha` → `ApplyFrameAlpha`, `locked` read at `modules/Frame.lua:378`, reset
position and reset all on the tail pair. The addon **is** positionable (`modules/Frame.lua:339`
`SetMovable(true)`), so none of the four frame rows is legitimately omissible and none is omitted.

No new stored **type** was introduced: `visibility`, `scale`, `alpha`, `locked` are all new keys
added at `127baa1` (`git show 127baa1~1:defaults/Profile.lua` has none of them), so `options-ui-§15`'s
`true → inCombat` migration does not apply and `NS.SCHEMA_VERSION = 1` correctly did not move.

Content checks (c)–(i): the schema declares **no** color row, **no** `disabledIf`, **no**
`LSM30_Font/Border/Statusbar` control, and **no** reorder list or paired scroll-arrow art — all
greps empty. Two tabs mix control kinds and both carry `subgroup` headings. The library's own
wrapped-strip pitch is measured once from the inactive cap atlas
(`libs/LibKa0s/OptionsWidgets.lua:399-401`), so anti-pattern #70 is closed upstream; this addon has
no page that wraps.

Global reset is `options-ui-§12`-shaped: `Helpers.RestoreAllDefaults` (`settings/Schema.lua:511`) is
a single `db:ResetProfile()` plus a session-only sweep, never a second walk of the schema; the
confirmation string at `settings/Schema.lua:582` is the mandated wording **verbatim**; there is no
`afterRestoreAll` hook and no surviving `ResetPositions` seam.

## Slash (`slash-commands`)

`/wg`, `/whatgroup`, dispatched by `LibKa0s-Slash-1.0` over an 11-row `COMMANDS` table
(`settings/Slash.lua:35-58`). `perf` is a reserved verb and deliberately unregistered.

## Debug (`debug-logging`)

`LibKa0s-DebugLog-1.0` with a descriptor carrying `addonName`, `title`, `font` resolved from
`NS.FONT_MONO` with a `Fonts\ARIALN.TTF` fetch-failure fallback (`core/DebugLogSetup.lua:40,42,139`),
`isEnabled`/`setEnabled` bound to session-only `NS.State.debug`. Nothing about debug reaches
`db.profile`.

## SavedVariables (`savedvariables`)

AceDB, `defaults/Profile.lua` holds every default value, `core/Database.lua` carries
`NS.SCHEMA_VERSION = 1` and an idempotent, deliberately empty migration runner. No
`t.k = stored.k or D.k` defaulting anywhere in `core/ defaults/ modules/ settings/` (grep empty), so
anti-pattern #54 does not arise.

## Tests, lint, complexity

`luacheck .` — **0 warnings / 0 errors over 16 files**.
`lua tests/run.lua` — **528 passed, 0 failed, 0 skipped, 528 total**.
`lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — **0 warnings, no thresholds exceeded**;
7047 NLOC across 1004 functions, avg CCN 1.8.

`tests/_kit/` is the vendored kit under `tests/`, never `libs/`;
`git ls-files -s tests/_kit/run-automated-tests.sh` reports **100755**.
`docs/automated-tests/` holds nine frozen bundles plus `README.md` and `RESULTS.md`. There is **no**
retired `docs/complexity.md` and **no** retired `docs/perf-runs/`.

## `.gitattributes` (`line-endings`)

Present at the root and byte-comparable to the collection's client-bound canonical body. Pin verbatim:

```
* text=auto eol=crlf
```

plus `*.sh text eol=lf` at line 34 and 20 ` binary` lines. Six tracked files disagree with the pin —
see **WG-46**.

## Packaging (`packaging`)

`.pkgmeta` — `package-as: WhatGroup`, no `externals:`, ignoring `.luacheckrc`, `.gitignore`,
`.gitattributes`, `docs`, `tests`, `_dev`, `*.bak`, `.claude` and the non-loadable logo masters.
`.superpowers` and `.pkgmeta` itself are unlisted — see **WG-58**.

## Root doc set (`documentation-§1/§2/§7`)

`README.md` — H1, the five canonical badges in order with the **bare** `![Standard](…)` form
(`README.md:6`), logo, description, `## What's new in 1.3.0`, `## Screenshots`, `## Usage`
(`### Slash commands` + `### Settings panel`), `## How it works`, `## FAQ`, `## Troubleshooting`,
`## Issues and feature requests`, `## Version History`. No `## Credits`, no bundled-library
inventory, no `## Testing`, no angle-bracket placeholders (only `<br>` in table cells). The
`[tests]` badge reads `528%2F528` and agrees with `docs/test-cases.md`'s Totals table.

`CLAUDE.md` — a stub: H1, adherence line, `## Standards compliance (read first)`, the docs pointer
list, the green-gate line, `## Bundled LibKa0s` carrying the provenance line.

`DEPENDENCIES.md` — present at root (10.2 KB).

## `docs/` (`documentation-§3`)

**Trio:** `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md` — all three present.

**Hub shape:** `docs/ARCHITECTURE.md` is **352** lines, under the ~400 SHOULD; all **ten** mandated
sections are present (Overview, Module Map, Settings Schema, Message Bus, Slash Commands, Event
Subscriptions, Taint Notes, Known Limitations, `## Documentation map`, `## Documented deviations`)
and no mandated section exceeds ~60 lines — the largest is *Module Map* at 48.

**Tier 1:** all six present under the canonical names — `scope.md`, `module-map.md`, `schema.md`,
`settings-panel.md`, `data-flow.md`, `common-tasks.md`.

**Tier 2:** `slash-dispatch.md` (11 verbs — trigger fired), `midnight-quirks.md`, `debug.md`
present; `message-bus.md`, `profiles.md`, `perf-analysis/README.md` carry correct *Not applicable*
rows; `compat-layer.md` carries a *Not applicable* row whose trigger **has** fired — **WG-53**.

**Tier 3:** `frame.md`, mapped.

**Non-canonical filenames:** none. There is no `data-model.md`, `saved-variables.md`, `pipeline.md`,
`settings-system.md`, `wow-quirks.md`, `slash-commands.md`, `debug-console.md`, `file-index.md`,
`conventions.md`, `complexity.md` or `agent-context.md`. This closes the whole class the 2026-08-05
run tracked.

**Documentation map:** present, covering every `.md` under `docs/` with no dangling row — but in
**four** tables rather than the specified three, and not covering `ARCHITECTURE.md` itself
(**WG-60**).

## Deviation register and the issue store

`docs/ARCHITECTURE.md:337-352` — `## Documented deviations`, five rows, correct column shape, every
row carrying a Rule, a Why, a Decided date and a Re-check trigger. Two `performance-§12` rows (the
second recording that the first's trigger **fired** on 2026-08-06 and the wiring is still declined),
one `localization-§3`, one `events-frames-taint-§8`, one `standalone-windows-§33`.

GitHub issue store read with `gh issue list --state all --limit 200`: 14 issues, every one carrying
a `state:` and a `severity:` label, **no** `[status]` title prefix (anti-pattern #62 clear). Eight
`state:will-not-do`; of those, seven decline an **optional** LibKa0s module or an **optional** TOC
field (`X-Wago-ID` is a MAY) and therefore owe no register row, and the eighth (#7, Perf) **is** in
the register. There is no `docs/pending/LEDGER.md` and no `docs/pending/` directory
(anti-pattern #60 clear).

## What has closed since the 2026-08-05 run

`WG-36` (`.pkgmeta` `_dev`/lockfiles), `WG-38` (README `## Bundled libraries`), `WG-39`
(`ARCHITECTURE.md` headings), `WG-40` (combat-refused category registration — the guard is gone from
`Settings.Register()` at `settings/Panel.lua:358`), `WG-42` (`FONT_MONO` fallback), `WG-43` (retired
`§N.M` notation — a live-tree sweep returns **zero**), `WG-44` (the non-falsifiable capture cases —
the gate now exists at `core/WhatGroup.lua:691` and `tests/test_capture.lua:83` pins it), `WG-45`
(release gate documented). `WG-30`–`WG-35` and `WG-37` are **recorded deviations**, ratified in the
register, and are not re-filed.
