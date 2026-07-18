# 01 — Current State

**Addon:** Ka0s WhatGroup · **Prefix:** `WG-` · **Audited against:** Ka0s WoW Addon
Standard **v2.7.0 (2026-07-17)** · **Audit date:** 2026-07-18 · **Mode:** read-only

This is a **re-audit**. The first audit (`docs/audits/2026-07-12/`) ran against standard
**v1.0.0** and catalogued 13 MUST + 6 SHOULD deviations (`WG-01`…`WG-19`); its
`06_EXECUTION_OUTCOME.md` records the remediation. Most of those are now **closed** (see the
per-section notes below). This run measures the *current* tree against the *current* standard
(v2.7.0), which has grown many rules since v1.0.0 — the new findings here are predominantly
rules that postdate the original audit.

Deviation IDs are **stable and per-addon-prefixed** (`WG-`): a recurring gap keeps its old ID;
new gaps continue the sequence from `WG-22` (`WG-20`/`WG-21` are the sanctioned font/logo
exceptions recorded in code). See `02_DEVIATIONS.md`.

---

## Snapshot by section

### layout
- Modular tree present: `core/`, `defaults/`, `settings/`, `locales/`, `modules/`, `libs/`,
  `media/`, `tests/`, `docs/` (`WhatGroup.toc`, tree). Subfolders lowercase; Lua files PascalCase.
- `core/` holds `Compat.lua`, `Database.lua`, `DebugLog.lua`, `WhatGroup.lua`. No separate
  `Namespace.lua` / `Constants.lua` / `State.lua` / `Util.lua` — acceptable for a small addon
  ("thin folders"); `NS.State` and constants are set inline in `core/WhatGroup.lua`.
- `media/` uses typed subfolders (`media/fonts/`, `media/logos/`, `media/screenshots/`) — WG-11
  (logo formerly under `screenshots/`) is **closed**; logo now under `media/logos/`.
- Largest source file `core/WhatGroup.lua` = 891 LOC — under the 1500 cap.
- **Gap:** no `defaults/Profile.lua`; profile defaults live in `settings/Schema.lua` (WG-24).

### toc-file
- Metadata block field order matches the mandated order (`WhatGroup.toc:1-13`). `X-License: MIT`,
  `X-Standard`, `X-Curse-Project-ID: 1489907` present. WG-15 (field hygiene: OptionalDeps,
  IconTexture casing, Category-enUS) is **closed**.
- **Gap:** `X-Wago-ID` absent (WG-09, recurring/conditional).
- **Gap:** the `#`-section file listing order is `Libraries → Core → Defaults → Locales →
  Settings → Modules`; the standard mandates `Libraries → Locales → Core → Defaults → Modules →
  Settings` (WG-14, recurring/redefined).
- Single Retail `Interface: 120007`; no multi-flavor. Libs listed directly (no `embeds.xml`).

### library-stack
- All eight mandatory Ace3 libs vendored under `libs/` and committed; `LibSharedMedia-3.0` too.
  No `externals:`, no lib forks, no suite dependencies.
- **Gap:** `AceTimer-3.0` (mandatory-lib table) is neither vendored nor mixed in; the addon uses
  raw `C_Timer.After` with an in-code justification (WG-17, recurring/accepted).

### architecture
- Private `NS` namespace via `local addonName, NS = ...` in every file; no `_G.WhatGroup`
  (WG-01 **closed**). AceAddon promoted at `core/WhatGroup.lua:30-33` with `NS` as first arg.
- Schema-as-single-source implemented well: one `Settings.Schema` row drives widgets, slash
  get/set/list, AceDB defaults, and reset (`settings/Schema.lua`). One write seam
  `Helpers.Set` (validate → write → onChange → refresh). Schema validated at boot via
  `Settings.Register()` (called from `OnEnable`) — WG-18 **closed**.
- No message bus — small addon, direct `NS.<Module>` method calls; acceptable at this size.

### savedvariables
- `AceDB:New("WhatGroupDB", …, true)`; single global; `schemaVersion` in `global`; idempotent
  `NS:RunMigrations()` in `core/Database.lua` (WG-08 **closed**).
- **Gap:** defaults hardcoded in `settings/Schema.lua`, not `defaults/Profile.lua` (WG-24).

### options-ui
- Strongly compliant: eager category registration at `OnEnable` (WG-02 **closed**), lazy body in
  `OnShow` wrapped in `C_Timer.After(0,…)`, landing page (logo + tagline + slash-command Labels),
  General subcategory, two-column Flow grid, section `Heading`s, always-visible scrollbar rebind,
  layout constants. **Defaults button is an AceGUI `Button`** (`settings/Panel.lua:113-121`) —
  options-ui-§5 satisfied. In-place `refreshers` (no O(N) rebuild) — options-ui-§11 / anti-#39 OK.
- **Gap:** combat panel-open refusal prints a non-canonical, uncoloured message rather than the
  mandated grey canonical notice (WG-25).

### standalone-windows
- Popup (`modules/Frame.lua`) and debug console (`core/DebugLog.lua`) are non-secure movable
  frames, registered in `UISpecialFrames`, clamped to screen, built from stock Blizzard textures.
- **Gap:** neither persists window position/size to SavedVariables (WG-26).
- **Gap:** each hand-rolls its backdrop; no shared `SKIN` + `ApplySkin` re-skin seam (WG-28).

### preview-mode
- `/wg test` (`WhatGroup:RunTest`) injects synthetic data through the real notify+popup render
  path — satisfies the preview/test-mode SHOULD for the positionable popup.

### slash-commands
- AceConsole registration (`wg` + `whatgroup`); schema-driven dispatch via ordered `COMMANDS`
  table; help generated from the table; cyan `NS.PREFIX = "|cff00FFFF[WG]|r"` shared constant
  (WG-19 prefix part **closed**); mandated `list`/`get`/`set` colour scheme + shared `FormatKV`.
- **Gap:** no standalone `version` verb (WG-29).
- **Gap:** the generated help header line ends with a trailing colon (WG-19, recurring/partial).
- **Gap:** the printer isn't secret-safe and several call sites bypass it (WG-22 / WG-23).

### localization
- `locales/enUS.lua` exports `NS.L` with a return-the-key metatable; user-facing strings routed
  through `L[…]` (WG-07 **closed**). Game data matched on stable IDs/tokens
  (`Enum.LFGEntryGeneralPlaystyle`, numeric `categoryID`, `mapID`/`spellID`) — localization-§4 OK.

### events-frames-taint
- AceEvent subscriptions; `hooksecurefunc` (not AceHook) for the two hooks; secure teleport
  button + `UISpecialFrames` deferred to first popup show; `InCombatLockdown()` gates on secure
  writes with `PLAYER_REGEN_ENABLED` replay (`modules/Frame.lua:177-191`, `288-317`).
- **Gap:** no secret-safe stringifier; chat printer and the `NS.Debug` sink feed raw args to
  global `print` / `string.format` (WG-22), and call sites pre-concatenate / hand-write the tag
  (WG-23). Anti-pattern #35.

### public-api / compat
- No public API surface (fine — rule is opt-in). `core/Compat.lua` is the sole caller of the
  variant spell/LFG APIs, routed everywhere (WG-03 **closed**).

### debug-logging
- On-screen console `WhatGroupDebugWindow` (700×344, DIALOG strata, `UISpecialFrames`,
  monospace JetBrains Mono, two pure formatters, Copy/Clear, header toggle, session-only
  `NS.State.debug`, colour-coded acks + `[Debug]` bracket + `[Init]` summary on enable). WG-12
  (persisted debug flag) **closed**. Coverage/coalescing/`[Set]`-at-seam all present.
- **Gap:** the sink `NS.Debug` is not secret-safe (WG-22).

### packaging / lint / testing
- `.pkgmeta` (`package-as: WhatGroup`, no `externals:`, ignores `docs/`+`tests/`) — WG-06 closed.
- `.luacheckrc` present; `luacheck .` = **0 warnings / 0 errors** (verified) — WG-05 closed.
- `tests/` headless Lua 5.1 harness; `lua tests/run.lua` = **48 passed, 0 failed** (verified);
  `docs/test-cases.md` generated (48 total); README `[tests]` badge `48/48` in lockstep. WG-04 closed.

### documentation
- Root README is player-facing and canonical (H1, five-badge row in order, logo, description,
  Screenshots, Usage[slash+settings], How it works, FAQ, Troubleshooting, Issues, Version
  History) — WG-13 **closed**. `[wow]` badge `Midnight_12.0.7` ↔ TOC `120007` in lockstep.
- Root `CLAUDE.md` is a stub pointing into `docs/`; `docs/` carries the full quartet
  (`agent-context.md`, `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`) + generated
  `test-cases.md` (WG-10 **closed**). No `TODO.md`.
- **Gap:** the standards-reference section in `CLAUDE.md` is titled *"Standards adherence — read
  before any change"* rather than the mandated **`## Standards compliance (read first)`**, and
  the `docs/agent-context.md` first hard rule doesn't point back to it by that name (WG-27).

### audit-review-history / versioning-git
- `docs/audits/2026-07-12/` and `docs/reviews/2026-05-02/` retained as frozen bundles; this run
  drops a new dated folder. Semver in TOC (`1.3.0`) + code constant + README aligned.

---

## Verdict

**Moderate deviations — core architecture compliant.** The addon is well past its v1.0.0 audit:
the architecture-shaping rules (private `NS`, eager registration, Compat, schema-single-source,
tests, lint, packaging, locale, session-only debug console, canonical README, stub CLAUDE) are
all met. The open findings are **9 MUST** (all contained/mechanical) and **3 SHOULD**, dominated
by two themes: the **secret-safe single-printer seam** (events-frames-taint-§8, added after the
first audit) and a set of small **metadata/verb/text** gaps.
