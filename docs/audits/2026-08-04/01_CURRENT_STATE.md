# Ka0s WhatGroup — Current State (2026-08-04)

**Audited against:** Ka0s WoW Addon Standard **v2.17.1 (2026-08-03)**.

**Addon HEAD:** `114e79913bd4e6895c6ad20a6f7764cc3fb0e6a9` — *docs+i18n: complete the v2.17.1 dialect
sweep*.

**Deviation-ID prefix:** `WG-` (assigned on the first audit, 2026-07-12; reused here). New IDs in
this run start at `WG-30`.

---

## Standard provenance

The playbook and the standard were fetched **over the network** from the raw URL and then verified
against the local canonical checkout. Both routes agree byte-for-byte.

| Artifact | How obtained | Verification |
|---|---|---|
| `AUDIT.md` | `curl -fsSL .../master/AUDIT.md` | `diff` vs `../WowAddonStandards/AUDIT.md` → **exit 0** |
| `standards/STANDARDS.md` | `curl -fsSL .../master/standards/STANDARDS.md` | `diff` vs local → **exit 0** |
| **All 24 section files** linked from the Sections list | one `curl --max-time 10` per file into a scratch dir | `diff -r` of the whole fetched directory vs `../WowAddonStandards/standards/standards/` → **exit 0** |

- The Sections list names **24** live section files. A 25th name, `tiered-layout.md`, appears only in
  the **changelog** (the v2.0.0 rename entry) and is not part of the standard; the raw URL correctly
  404s for it.
- The local checkout used for verification was clean at `2141229 v2.17.1 — finish the v2.17.0
  rollout: no fourth slot, no drop-in imperative`. Nothing under `WowAddonStandards/` was written.
- **No section was unassessed.** No rule in this bundle is reconstructed from memory.

---

## Layout (`layout`)

Modular layout, fully populated:

```
core/       Compat.lua  CoreSetup.lua  Database.lua  DebugLogSetup.lua  Util.lua  WhatGroup.lua
defaults/   Profile.lua  TeleportSpells.lua
settings/   OptionsSetup.lua  Panel.lua  Schema.lua  Slash.lua
locales/    enUS.lua
modules/    Frame.lua
media/      fonts/  logos/  screenshots/          (typed subfolders only, nothing loose)
libs/       LibStub  CallbackHandler-1.0  Ace{Addon,Event,Console,Timer,DB,GUI}-3.0
            LibSharedMedia-3.0  LibKa0s/
tests/      _kit/  run.lua  loader.lua  wow_mock.lua  test_*.lua (14 suites)
docs/       ARCHITECTURE.md  testing.md  smoke-tests.md  test-cases.md  + topic detail
            audits/2026-07-12  audits/2026-07-18  reviews/2026-05-02  reviews/2026-08-03
```

Nothing loose at the repo root but `README.md`, `CLAUDE.md`, `LICENSE`, `.luacheckrc`, `.pkgmeta`
and `WhatGroup.toc`. Every `.lua` is well under the 1500-LOC cap (largest addon-owned file is
`core/WhatGroup.lua`). Casing is PascalCase files under lowercase folders throughout.
`docs/agent-context.md` does **not** exist, and `CLAUDE.md:27-42` states so explicitly
(documentation-§3, anti-pattern #49). No `TODO.md`.

## TOC (`toc-file`)

`WhatGroup.toc:1-13` — field order matches toc-file-§1 exactly: Interface → Title → Notes → Author →
Version → IconTexture → SavedVariables → OptionalDeps → DefaultState → Category-enUS → X-License →
X-Standard → X-Curse-Project-ID. No blank line inside the block; single Interface `120007`; no
`Dependencies:`. `X-Wago-ID` / `X-WoWI-ID` are correctly **omitted** (the addon lists only on
CurseForge — a MAY since v2.8.0, which closes the prior `WG-09`).

The file listing (`:15-50`) is `# Libraries → # Locales → # Core → # Defaults → # Modules →
# Settings`, in that order, with every vendored library named directly and `libs\LibKa0s\LibKa0s.xml`
listed **once** as the aggregate (closes the prior `WG-14`). No `embeds.xml`.

**One gap:** `## SavedVariables: WhatGroupDB` declares only the settings global. toc-file-§2 requires
**exactly two**, with `WhatGroupPerfDB` second (`WG-31`).

## Library stack (`library-stack`)

Every mandatory lib is vendored and committed, folder-per-lib, loaded first: LibStub,
CallbackHandler-1.0, AceAddon/AceEvent/AceConsole/AceTimer/AceDB-3.0, AceGUI-3.0 via its `.xml`,
plus LibSharedMedia-3.0 via `lib.xml`. AceTimer is both vendored and mixed in at
`core/WhatGroup.lua:31-33` (closes the prior `WG-17`). No Ace fork, no suite dependency, no
`externals:`.

`libs/LibKa0s/` is the **whole ship folder** — `Core.lua`, `DebugLog.lua`, `Slash.lua`, `Options.lua`,
`OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, `LibKa0s.xml`, `LICENSE` —
including the two `Perf` files the addon does not wire, which is exactly what library-stack-§7
requires. `tests/_kit/` holds the harness, never `libs/`. **Both vendor diffs are empty** (see
`03_EVIDENCE.md`).

## Shared-subsystem wiring (the four setup files)

The addon owns **descriptors and degradation stubs**, not implementations. There is no
`modules/DebugLog.lua`, no widget-maker file, no hand-rolled dispatcher and no hand-written test
framework anywhere in the repo — that is the compliant state.

| Module | Setup file | Lookup | Stub shape |
|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:39` | `LibStub("LibKa0s-Core-1.0", true)` | member-answering; the sanctioned pre-library fallbacks (`:48-98`), announcing once |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:20` | `LibStub("LibKa0s-DebugLog-1.0", true)` | member-answering, 20 members, one announce **per entry point** (`:34-83`) |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua:17` | `LibStub("LibKa0s-Options-1.0", true)` | **load-completing** — the documented options-ui-§1 exception, measured load-time set = empty, pinned by `tests/test_libka0s.lua` |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:73` | `LibStub("LibKa0s-Slash-1.0", true)` | member-answering; every lost verb names the missing library (`:86-126`) |
| `LibKa0s-Perf-1.0` | **none** | — | **not wired** (`WG-30`) |

Stub coverage was checked call-site by call-site for the three member-answering stubs: every member
the addon reaches on an instance is answered by the library-absent branch. Deliberate omissions carry
their reasons in-code (`core/DebugLogSetup.lua:44-46` — no formatter copies; `settings/OptionsSetup.lua:78-82`
— no layout constants). `NS.LIBKA0S_MISSING` is published once, outside the branch, and each seam
appends its own consequence clause.

## Architecture (`architecture`)

`local addonName, NS = ...` at the head of every file. `AceAddon:NewAddon(NS, addonName,
"AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")` at `core/WhatGroup.lua:31`; the printer is
published on `NS.Util.print` (out of AceConsole's reach) **and** reclaimed at `:84` — both sanctioned
fixes for anti-pattern #36, belt and braces. No `_G.WhatGroup`. Schema-as-single-source is
implemented: `settings/Schema.lua` rows drive AceDB defaults, panel widgets, the CLI and reset, with
`Helpers.Set` as the single write seam handed to **both** the Options and Slash descriptors.

The addon has **one** feature module and **no message bus** — no `SendMessage`/`RegisterMessage`
anywhere. architecture-§4's receiver-clobber rules are therefore not reachable; there is nothing to
deviate from.

## SavedVariables (`savedvariables`)

`defaults/Profile.lua` holds `NS.C`, the only place a profile default is hardcoded; each schema row
references `NS.C.<path>` (closes the prior `WG-24`). `core/Database.lua:16-33` carries
`NS.SCHEMA_VERSION = 1` and an idempotent `NS:RunMigrations()` with the migration ladder scaffolded.
One AceDB global, `WhatGroupDB`. The sanctioned second global, `WhatGroupPerfDB`, is absent
(`WG-31`).

## Options UI (`options-ui`)

`Settings.Helpers` **is** the library instance (`settings/OptionsSetup.lua:96-206`), decorated in
place. Descriptor supplies `parentTitle`, `mainPanelName`, `get`/`set`/`applyDefault` through the
single write seam, `rowsForPage`/`allRows`, `validate` and `buildMain`; the fields it declines
(`colorDecode`, `getLSM`, `skipRestoreAll`, `onAceGUI`) each carry a written reason. Parent category
registers eagerly at `OnEnable` (`settings/Panel.lua:238-259`), body and Defaults button build
lazily; `defaultsOnClick` is parked at registration (`:207-210`). The panel-open combat gate lives
inside the library's `OpenOptionsPanel`, and the canonical gray refusal is the library's string
(closes the prior `WG-25`). Landing page draws logo → notes → "Slash Commands" heading → one row per
`COMMANDS` entry, through the **library's** row formatter.

One narrow gap: `Settings.Register()` also refuses under `InCombatLockdown()`, so a login in combat
leaves the category unregistered until the user acts (`WG-40`).

## Standalone windows (`standalone-windows`)

`modules/Frame.lua` is a plain non-secure `CreateFrame`, registered in `UISpecialFrames` (`:168`),
position-persisted through `NS.Windows` (closes the prior `WG-26`), and skinned by `NS.ApplySkin`
(`:91`) — the library's `Core.ApplySkin`, published unwrapped at `core/CoreSetup.lua:114-116`
(closes the prior `WG-28`). `f.title` and `f.divider` are assigned before the call so the library
tints them; no colour value is restated locally. No `makeCloseButton` / `skin` / `applySkin` override
is passed to DebugLog (`core/DebugLogSetup.lua:132-135`), so the console keeps the library's edge and
close glyph, as standalone-windows-§2 requires.

## Slash commands (`slash-commands`)

`/wg` primary, `/whatgroup` alias, both registered through AceConsole
(`settings/Slash.lua:294-296`, `core/WhatGroup.lua` `OnInitialize`). `COMMANDS` is the host's,
positional triples, published as `WhatGroup.COMMANDS` and passed into the descriptor as plain data.
Reserved verbs present: `help`, `show`, `test`, `config`, `version`, `list`, `get`, `set`, `reset`
(path form), `resetall`, `debug`. `reset` converged onto the path form with a deprecation notice.
`version` reads TOC metadata first (closes the prior `WG-29`). The mandated cyan tag is one constant,
`NS.PREFIX = "|cff00FFFF[WG]|r"` (`core/WhatGroup.lua:44`). The one parser override (`toggle`) goes
through the descriptor's `parse` seam, the sanctioned form.

**`perf` is absent** from `COMMANDS` (`WG-32`).

## Localization (`localization`)

`locales/enUS.lua` exports `NS.L` with the key-returning metatable. English strings are the keys.
Game data is matched on IDs and tokens — `mapID`, `spellID`, `Enum.*`, and Blizzard's own
`GROUP_FINDER_GENERAL_PLAYSTYLE1..4` GlobalStrings — never on localized display text. A repo-wide
sweep for British spellings across README, `CLAUDE.md`, all addon source, locales and `docs/` returns
**zero** hits (localization-§5 clean).

## Events / frames / taint (`events-frames-taint`)

AceEvent for `GROUP_ROSTER_UPDATE` and `LFG_LIST_APPLICATION_STATUS_UPDATED`; two direct
`hooksecurefunc` post-hooks installed at file load, deliberately not AceHook, with the taint
reasoning written down. Secure writes (`SecureActionButtonTemplate` attributes, the
`UISpecialFrames` insert, the first `buildFrame`) are gated on `InCombatLockdown()` and replayed on
`PLAYER_REGEN_ENABLED`. Chat and debug output funnel through the library's secret-safe printer and
the gated sink. Two dead-code `print()` fallbacks remain in the settings layer (`WG-37`).

## Compat (`compat`)

`core/Compat.lua` is the sole caller of the version-variant spell and LFG APIs; every consumer goes
through `NS.Compat.*`. No `WOW_PROJECT_ID` branching anywhere.

## Debug logging (`debug-logging`)

Wired to `LibKa0s-DebugLog-1.0`. Descriptor supplies `name`, `title`, `font`, `slash`,
`isEnabled`/`setEnabled` over the session-only `NS.State.debug`, call-time forwarders for `print`
and `safeToString`, `initSummary` and `onVisibilityChanged`. Sink bound bare: `NS.Debug =
NS.DebugLog.Debug`. JetBrains Mono is vendored with its `OFL.txt` and registered with LSM. Trace
sites pass format-plus-args, never a pre-built string. Settings writes log one `[Set]` at the single
seam; the global reset coalesces to one `[Reset]`.

## Testing (`testing`)

`tests/_kit/` is the vendored kit, byte-identical to source. `tests/wow_mock.lua` extends
`mock_base` with ten documented overrides rather than replacing it. `tests/run.lua` derives the
addon's load list from the TOC via `Loader.tocFiles`, spells out every `LibKa0s.xml` file explicitly,
and `tests/test_harness.lua:27-70` pins all four testing-§9 properties — derivation order, on-disk
existence, no `libs/` leakage, and the explicit LibKa0s list matching the XML in XML order. The
degraded path is verified by **actually loading with the library absent**
(`tests/test_libka0s.lua`), including the schema-row-count comparison options-ui-§1 requires.
`docs/test-cases.md` is generated (`--list`), totals **415**, and the README badge reads `415/415`.

`tests/perf.lua` does not exist (`WG-34`).

## Performance (`performance`)

**Not wired.** No `core/PerfSetup.lua`, no `NS.Perf`, no buckets, no `perf` verb, no `WhatGroupPerfDB`,
no `docs/performance.md`, no `docs/perf-runs/`, no `tests/perf.lua`. The decline is a recorded,
user-taken decision — `docs/pending/LEDGER.md:63` (`LIBKA0S-15`), dated 2026-08-02 — on two grounds:
the addon has no hot path (zero `OnUpdate`, zero tickers, zero repeating timers), and `suspend` would
make a *capture* addon miss the applies and invites it exists to record. The `libs/LibKa0s/Perf.lua`
and `PerfPanel.lua` files are vendored regardless, correctly.

The standard's wiring requirements are nonetheless MUSTs, so they are recorded as deviations
(`WG-30`, `WG-31`, `WG-32`, `WG-33`, `WG-34`, `WG-35`) with the recorded rationale attached.

## Packaging / lint (`packaging`, `lint`)

`.pkgmeta` declares `package-as: WhatGroup`, no `externals:`, and ignores `.luacheckrc`,
`.gitignore`, `.gitattributes`, `docs`, `tests`. It omits `_dev` (`WG-36`). `.luacheckrc` sets
`std = "lua51"`, excludes `libs/`, `docs/audits/`, `docs/reviews/`, `tests/`, and declares
`WhatGroupDB` plus a commented `StaticPopupDialogs`. It omits `debugprofilestop` and
`WhatGroupPerfDB` (`WG-35`).

## Documentation (`documentation`)

Root ships exactly `README.md`, `CLAUDE.md`, `LICENSE`. The README is player-facing, plain-language,
US English, with the five canonical badges in order (standard badge uses `_`, not `%20`), logo,
description, `## What's new in 1.3.0` immediately above `## Screenshots`, Usage with both required
subsections, `## How it works`, FAQ, Troubleshooting, Issues, Version History — top row agreeing with
What's new. No angle-bracket placeholders in shipped content (only deliberate `<br>` inside table
cells). It carries one **extra** section, `## Bundled libraries` (`WG-38`).

`CLAUDE.md` is a stub carrying `## Standards compliance (read first)` verbatim in substance (closes
the prior `WG-27`), the deviation rule, the docs pointer list, the green gate and the vendor gate.
The three-place standards reference (TOC `X-Standard`, README badge, `CLAUDE.md` section) is
complete.

`docs/` carries the canonical trio plus the generated `docs/test-cases.md` and ten topic-detail docs.
`docs/ARCHITECTURE.md` is thorough but omits four of the section headings documentation-§3 names
(`WG-39`). `docs/performance.md` and `docs/perf-runs/README.md` are absent (`WG-33`);
`docs/complexity.md` is absent (`WG-41`).

## Audit / review history, versioning, public API, preview mode

Frozen dated bundles under `docs/audits/` (2026-07-12, 2026-07-18) and `docs/reviews/` (2026-05-02,
2026-08-03), all retained, none edited. Semver `1.3.0` agrees across TOC, `WhatGroup.VERSION`, the
README badge row and Version History. Trunk-based history on `master`. The addon exposes no public
API, so `public-api` is not engaged. `preview-mode` is satisfied by the `/wg test` verb feeding the
real render path.

## Mechanical gate results

| Check | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 14 files |
| `lua tests/run.lua` | **415 passed, 0 failed, 415 total** |
| `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` | **empty** |
| `diff -r ../LibKa0s/testkit tests/_kit` | **empty** |

Full commands and output in `03_EVIDENCE.md`.

## Unverifiable from the repo

- Whether `## Interface: 120007` is still the **latest** Retail patch cannot be established offline.
  The TOC and the README `[wow]` badge agree with each other, which is the part that *is* checkable.
- testing-§12's mutation check (proving a negative-asserting case can go red) leaves no artifact and
  is explicitly **not** auditable; it is recorded here as *unverified*, never as a deviation.
