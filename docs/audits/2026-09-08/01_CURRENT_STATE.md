# 01 — Current state (2026-09-08)

**Audited against:** Ka0s WoW Addon Standard **v2.39.0 (2026-09-07)** — `standards/STANDARDS.md`
line 1, fetched with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`. All **26** section files
listed under *Sections* were fetched from `standards/standards/` and read; the playbook is
`AUDIT.md` at the same ref.

**Rule set:** the **addon** sections. `WhatGroup.toc` exists, so this is not a Ka0s-owned library
repo and `library-stack-§7`'s applicability lists do not apply (`AUDIT.md` step 1).

**Repo:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup`, branch `master`, HEAD
`58bc280` (`Merge branch 'feat/2026-09-07-audit-review-remediation'`), working tree clean.

**Why this run exists.** It is work item **M5-06** of the 2026-09-07 collection remediation cycle:
the pass that measures whether the fifteen amended sections (`M1-STD-01`…`M1-STD-16`) describe the
repository they govern, rather than whether a keyword was typed into the standard. The immediately
preceding bundle is `docs/audits/2026-09-07/` (v2.38.0) and it is **frozen** — nothing in it was
edited by this run.

**A fetch hazard, recorded because it nearly corrupted this audit.** The session scratchpad already
held section files from an earlier, abandoned attempt against **v2.38.0**. A first fetch loop timed
out mid-pass and left fourteen of the twenty-six stale. They were caught by re-fetching every
section in parallel into a clean directory and comparing md5s — `audit-review-history`,
`automated-tests`, `documentation`, `layout`, `library-stack`, `line-endings`, `lint`,
`localization`, `open-evolutions`, `options-ui`, `packaging`, `slash-commands`,
`standalone-windows` and `toc-file` all differed. Every rule quoted below is from the verified
v2.39.0 copies.

---

## Layout (`layout`)

`core/ defaults/ locales/ modules/ settings/` plus `libs/`, `media/`, `docs/`, `tests/`. Folder
casing is lower-case throughout; `media/` has typed subfolders only (`media/logos/`,
`media/screenshots/` — `find media -type d`), and holds **no** `fonts/`, `icons/` or `textures/`
that would duplicate `libs/LibKa0s/media/`.

**The 1500-line cap, on v2.39.0's stated denominator** (every authored `.lua` the repo tracks,
`tests/` included; `libs/` and `tests/_kit/` are the carve-outs): largest authored file is
`tests/test_frame.lua` at **1063** lines, then `core/WhatGroup.lua` 889, `tests/test_libka0s.lua`
807, `modules/Frame.lua` 770. Nothing is over the cap. The one file in the 1000–1500 band is
carried in `docs/automated-tests/RESULTS.md:82` with a written **Accepted** disposition and a
re-check trigger, which is one of the three terminal states `layout-§1` now names.

## TOC (`toc-file`)

`WhatGroup.toc`, 15 metadata fields then `# Libraries → # Locales → # Core → # Defaults →
# Modules → # Settings`. `## Interface: 120007`, `## X-License: MIT`, `## X-Standard:` present,
`## X-Curse-Project-ID: 1489907` (real — the README's CurseForge badge resolves the same id).
`libs\LibKa0s\LibKa0s.xml` is listed **once**, after Ace3; no individual LibKa0s `.lua` appears.

**`toc-file-§5`'s annotation MUST, measured against its own denominator** (v2.39.0's amendment).
Reading the seam files rather than counting lines, the load-bearing positions are four, and all
four now carry a comment naming what resolves:

| Position | What resolves | Annotated at |
|---|---|---|
| `core\MediaSetup.lua` | `NS.FONT_MONO` from `NS.MediaFont` | `WhatGroup.toc:33-34` |
| `core\DebugLogSetup.lua` | `lib:New{}` reads `NS.FONT_MONO` at file scope | `WhatGroup.toc:44-46` |
| `defaults\Profile.lua` | `NS.C`, taken as `settings/Schema.lua:27`'s upvalue | `WhatGroup.toc:50-51` |
| `settings\Schema.lua` / `settings\OptionsSetup.lua` | `Settings.Schema` / `Settings.Helpers`, both spliced/called at `settings/Panel.lua` file scope | `WhatGroup.toc:62-63`, `:65-67` |

The **SHOULD** half is met too: `# Libraries` (`:15`), `core\EnvSetup.lua` (`:38-40`), `# Defaults`
(`:49`), `# Modules` (`:55-56`) and `# Settings` (`:59-61`) each carry an explicit *conventional*
note. `# Locales` carries none; that position is
already pinned by `toc-file-§5`'s own section-header-order MUST and by the standard's own reference
block, which shows `# Locales` uncommented, so it is recorded here rather than filed.

## Libraries (`library-stack`)

Vendored and committed: LibStub, CallbackHandler-1.0, AceAddon-3.0, AceEvent-3.0, AceConsole-3.0,
AceTimer-3.0, AceDB-3.0, AceGUI-3.0, LibSharedMedia-3.0, LibKa0s. No `externals:` block.

Measured against **§3's amended three-way reachability test** — every one is reached:
AceEvent/AceTimer/AceConsole by mixin **name string** at `core/WhatGroup.lua:31-33`, AceGUI by
`libs/LibKa0s/Options.lua` reaching it, CallbackHandler by Ace3's own files.

**Provenance:** `CLAUDE.md:69` — *"Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.27.0 (MIT)."* — and **not** in `README.md`. v1.27.0 is the newest tag in the sibling repo, so
there is no re-vendor backlog. Both `diff -r` checks are **empty** (03, §D).

**Shared subsystems are consumed, not hand-rolled.** No `modules/DebugLog.lua`, no widget makers,
no dispatcher, no test framework, no `core/LSMPatch.lua`. What the addon owns is five setup files
carrying a descriptor and a degradation stub: `core/CoreSetup.lua`, `core/MediaSetup.lua`,
`core/EnvSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, plus the slash
descriptor in `settings/Slash.lua:150` and `tests/_kit/` for the harness. `tests/_kit/` is under
`tests/`, never `libs/`.

**Shared media.** `core/MediaSetup.lua:92` — `if Media then Media.RegisterLSM(addonName) end` —
one call, fed the file's own first vararg, in the TOC slot that precedes every load-time consumer.
`NS.Icon` at `core/MediaSetup.lua:64`. The close-button grep returns the wrapper
(`core/CoreSetup.lua:136`), its degraded twin (`:100`) and nothing else outside `libs/` and
`tests/`.

## Patterns (`architecture`, `savedvariables`, `compat`, `events-frames-taint`)

Private `NS`, no `_G.WhatGroup`. AceAddon shell at `core/WhatGroup.lua:31`, with the AceConsole
`:Print` clobber reclaimed (anti-pattern #36). One feature module, `modules/Frame.lua`; no
`SendMessage`/`RegisterMessage` anywhere, and `docs/ARCHITECTURE.md:107-114` records that there is
no bus and why, which is what `architecture-§4`'s applicability clause asks of an addon below the
threshold.

`core/Database.lua:16` — `NS.SCHEMA_VERSION = 1`, with the migration runner seam at `:23`.
`defaults/Profile.lua` is the single home of every default value. The composed `visibility` row is
a **new** key (`git show 127baa1^:defaults/Profile.lua` carries no `visibility` and no
*show only in combat* boolean), so `options-ui-§15`'s stored-type-change migration does not arise.

`core/Compat.lua` publishes **seven** shims, counted with `documentation-§3`'s own published grep.
No `WOW_PROJECT_ID` branching. The `events-frames-taint-§8` protected-API sweep returns **zero**.

## Settings (`options-ui`)

One page, `Helpers.RegisterOptionsPage("general", "General", buildGeneralPage)`
(`settings/Panel.lua:367`), drawn through `Helpers.RenderTabbedSchema(c, "general", AFTER_GROUP)`
(`:356`). Three tabs in declaration order: **Master controls**, **Chat**, **Popup**. The first tab
is composed, not written — `Helpers.MasterControls{…}` at `settings/Panel.lua:204` — and the
`afterGroup` key is `Helpers.MASTER_GROUP` (`:323-324`), the library's published constant, not a
literal. No color row, no reorder list, no hand-written font/border/bar group, no `LSM30_*`
control, no `disabledIf`. The landing page is the host's own `buildMain` and is exempt; there is no
Profiles sub-page.

## Slash, debug, tests, performance

`settings/Slash.lua:35-58` — **11** verbs, published at `:62` and handed to the `LibKa0s-Slash-1.0`
descriptor's `commands` field at `:150`.
`core/DebugLogSetup.lua:133` carries `addonName` in the descriptor (`debug-logging-§13`).
`lua tests/run.lua` → **559 passed, 0 failed, 0 skipped**. `luacheck .` → **0/0 over 41 files**.
No `tests/perf.lua`; the `performance-§12` position is a register row, not silence.

## `.gitattributes` (`line-endings`)

Present at the root and **byte-identical** to `line-endings-§5`'s client-bound canonical body — 81
lines, `diff` empty. Pin `* text=auto eol=crlf` at `:26`, `*.sh text eol=lf` at `:34`, 20 ` binary`
marks. No `line-endings-§5 appendix` block, and none is owed. The working-tree check (e) returns
**0**. `line-endings-§7`'s new vendored gate `tests/_kit/test_eol.lua` is present (kit revision 15)
and green.

## Root docs

`README.md` — H1, the five canonical badges in order with the standard badge **bare** at `:6`,
logo, description, `## What's new in 1.3.0`, `## Screenshots`, `## Usage`, `## How it works`,
`## FAQ`, `## Troubleshooting`, `## Issues and feature requests`, `## Version History`. No
`## Credits`, no bundled-library inventory in a heading or in the intro prose, no angle-bracket
placeholders in the slash table. The `[tests]` badge reads `559/559`, matching
`docs/test-cases.md`'s Totals row and the live suite.

`CLAUDE.md` — a stub with `## Standards compliance (read first)` at `:6`, the `docs/` set note, hard
rules, `## Bundled LibKa0s` (the provenance line) and response style. `DEPENDENCIES.md` — four
numbered sections plus a keeping-it-honest section.

## `docs/` (`documentation-§3`)

Tier 1, all six present under canonical names. Tier 2, every trigger evaluated against the code:

| Doc | Trigger | Measured | State |
|---|---|---|---|
| `slash-dispatch.md` | ≥8 commands | 11 | Present |
| `midnight-quirks.md` | ≥1 own client workaround | yes | Present |
| `compat-layer.md` | **≥3** shims (v2.39.0's new count) | 7 | Present |
| `message-bus.md` | >10 messages | 0 | Not applicable, row present |
| `profiles.md` | profile control in the UI | none | Not applicable, row present |
| `debug.md` | surfaces beyond the default console | yes | Present |
| `perf-analysis/README.md` | harness wired | no | Not applicable, row in `### Conditional` |

`## Documentation map` at `docs/ARCHITECTURE.md:306` carries **four** tables in v2.39.0's mandated
order, the fourth being `### Verification and record` at `:334` with exactly its six rows;
`perf-analysis/README.md` registers in `### Conditional` at `:329`, which is what the amendment
settles. `ARCHITECTURE.md` does not register itself, which is a **MAY** and is filed neither way.
No orphans, no dangling rows, no non-canonical Tier 1/2 filename, no `file-index.md`,
`conventions.md`, `complexity.md`, `agent-context.md` or `docs/perf-runs/`. Hub is 386 lines with
every mandated section spilled.

`## Documented deviations` at `:351` carries four rows; all four re-check triggers were evaluated
against this tree and none has fired (03, §H).

## Issue store (`audit-review-history`)

18 issues, **every** one carrying a `state:` and a `severity:` label; no `[status]` title prefix
anywhere; no `docs/pending/LEDGER.md` and no `docs/pending/` directory. Six closed
`state:will-not-do` issues decline a `LibKa0s` module or an `X-Wago-ID` — none of them is a
declined **standard rule**, so none owes a register row.

## Packaging and lint

`.pkgmeta` — `package-as`, no `externals:`, and an ignore list that now names `_dev` (`:12`),
`.pkgmeta` itself (`:14`) and `.claude` (`:19`). The (b) enumeration over every root dot-entry
present reports only `.git`, which is the one exemption.

`.luacheckrc:17` — `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/",
"tests/_kit/" }`, exactly v2.39.0's amended template; the harness global sits in a
`files["tests/"]` stanza at `:61` and not in top-level `read_globals`; there is **no** top-level
`ignore`; and, correctly under the `performance-§12` exemption, no `debugprofilestop` and no
`WhatGroupPerfDB`.
