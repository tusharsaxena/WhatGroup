# 01 — Current State

**Addon:** Ka0s WhatGroup
**Repo:** `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup`
**Audit date:** 2026-07-12
**Deviation-ID prefix:** `WG-` (first audit; prefix assigned here, reuse in all future runs)
**Standard audited against:** Ka0s WoW Addon Standard **v1.0.0 (2026-07-12)** — `standards/01_STANDARD.md` @ `github.com/tusharsaxena/WowAddonStandards`
**Playbook:** `AUDIT.md` @ same repo (fetched verbatim via `curl`).

This is a **read-only** snapshot of what the addon does today, walked section-by-section against the
standard. Gaps are catalogued in `02_DEVIATIONS.md`; evidence in `03_EVIDENCE.md`.

---

## Layout & tier

Flat source at repo root plus a `data/` subfolder:

```
WhatGroup.toc
WhatGroup.lua            (792 LOC)  entry: AceAddon bootstrap, hooks, capture pipeline, slash dispatch
WhatGroup_Settings.lua  (1056 LOC) schema + helpers + canvas panel
WhatGroup_Frame.lua     (319 LOC)  popup dialog + secure teleport button
data/TeleportSpells.lua (120 LOC)  mapID → teleport spellID table
ARCHITECTURE.md         (root)
CLAUDE.md               (root, full agent brief — 8.4 KB)
README.md               (root)
LICENSE                 (MIT)
libs/                   vendored Ace3 subset, committed
media/screenshots/      chat.png, dialog.png, whatgroup.logo.png, whatgroup.logo.tga
docs/                   9 topic docs
reviews/2026-05-02/     prior code-review bundle (not an audit)
```

- **4 source files** → correctly **Tier 1 (flat)** by count. Tier is **not declared** in `CLAUDE.md`.
- Every `.lua` file is well under the 1500-LOC cap (largest 1056). ✅ (§1.1)
- `TeleportSpells.lua` sits in a `data/` **source subfolder**; Tier 1 mandates a flat tree. (§1.1)
- No `libs/`-casing or PascalCase file-name issues.

## TOC (`WhatGroup.toc`)

Single `## Interface: 120007` (Retail-only, no multi-flavor list). ✅ (§2.3)
Present fields: Interface, Title (`Ka0s WhatGroup`), Notes, Author, Version (`1.2.0`), `iconTexture`,
SavedVariables (`WhatGroupDB`), DefaultState, `Category-enUS: Chat & Communication`, `X-License: MIT`.
**Missing:** `OptionalDeps`, `X-Standard`, `X-Curse-Project-ID`, `X-Wago-ID` (the addon **is published** —
CurseForge project 1489907, tagged `1.2.0-release`). `IconTexture` is mis-cased; `Category-enUS` value is
outside the allowed enum. File listing uses `# Libraries` + `# Core` (Tier-1 wants `# Addon`). File ends
with a trailing newline. ✅

## Libraries (`libs/`)

Vendored & committed, folder-per-lib, no `.pkgmeta externals`: LibStub, CallbackHandler-1.0,
AceAddon-3.0, AceEvent-3.0, AceConsole-3.0, AceDB-3.0, AceGUI-3.0. ✅ (§3.3)
**AceTimer-3.0 is absent** — §3.1 lists it mandatory; the addon uses raw `C_Timer.After` instead.

## Architecture & namespace

- **Global namespace.** `_G.WhatGroup` is created and used as the addon table; no file uses the required
  `local addonName, NS = ...` private-namespace header. (§4.1, §10, anti-pattern #1)
- AceAddon registration promotes the existing `_G.WhatGroup` via `NewAddon(existing, "WhatGroup",
  "AceConsole-3.0", "AceEvent-3.0")`. ✅ shape, ✗ target (global).
- **Schema-as-single-source is implemented well** (§4.5): one `Schema` array drives AceDB defaults,
  AceGUI widgets, `/wg list|get|set`, and reset, through a single orchestrated `Helpers.Set` write-path.
  Schema **validation runs lazily** at first panel registration, not at boot.
- Tier 1, so no message bus / module registry — correctly N/A.

## SavedVariables / AceDB

- Single global `WhatGroupDB` via `AceDB:New("WhatGroupDB", defaults, true)`. ✅ (§2.2, §5.1)
- Capture/session state (`captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`, …) is
  module-local, never persisted. ✅
- **No `schemaVersion`** in defaults (defaults build only a `profile` table, no `global`), and **no
  `Database.lua` migration runner**. (§2.2, §5.1)

## Options UI

- Canonical Blizzard `Settings.RegisterCanvasLayoutCategory` + raw AceGUI, landing page + `General`
  subcategory, two-column Flow body, always-visible-scrollbar patch, gold header/divider, breadcrumb
  title with atlas chevron, lazy `OnShow` body wrapped in `C_Timer.After(0, …)`. Strong §6.5–§6.10
  compliance. ✅
- **Category registration is deferred to first `/wg config`** (`runConfig` → `Settings.Register`), the
  exact anti-pattern §6.9 / #22 names: the addon is **absent from the Blizzard options list until the
  user runs the slash command**. The code comments justify this as a taint fix. The standard's fix is to
  register **after `Blizzard_Settings` loads** and keep only the body lazy — not to defer registration.

## Slash commands

- AceConsole `RegisterChatCommand("wg", …)` + `whatgroup` alias, ordered `COMMANDS` table, generated
  help, unknown-verb → "unknown command" + help, case-preserving remainder, schema-driven `list/get/set`.
  Strong §7.1–§7.3 compliance. ✅
- Chat tag is a **file-local `CHAT_PREFIX = "|cff00FFFF[WG]|r"`**, not an exposed `NS.PREFIX`; help
  header format differs slightly from §7.4's mandated `<tag> v<ver> slash commands` shape.

## Localization

- **No locale module at all.** No `enUS.lua`, no `NS.L` metatable. All UI strings are inline English and
  playstyle labels read Blizzard `_G` strings (`GROUP_FINDER_GENERAL_PLAYSTYLE1..4`). §8.3 requires at
  minimum an `enUS.lua` shell and forbids leaning on `_G` strings as a substitute. `CLAUDE.md` records
  localization as a deliberate non-goal — but the standard still mandates the shell.

## Events / frames / taint

- Observation-only: two direct `hooksecurefunc` post-hooks (`C_LFGList.ApplyToGroup`, `SetItemRef`
  filtered to `WhatGroup:` links); no `AceHook`, no LFG-state mutation. AceEvent for events. Combat
  lockdown is guarded at every protected seam (panel open, frame build, secure teleport-button
  reconfigure). Popup uses lazy frame build + `SecureActionButtonTemplate` + `UISpecialFrames`. Careful,
  taint-conscious code. ✅ (§9.1, §9.2)

## Compat / deprecated APIs

- **No `Compat.lua`.** Version-variant API calls are scattered inline with ad-hoc
  `C_Spell and … or GetSpellInfo` fallbacks: `C_Spell.GetSpellLink`, `C_Spell.GetSpellName`,
  `C_Spell.GetSpellTexture`, `GetSpellInfo`, `IsSpellKnown`, `C_LFGList.GetActivityInfoTable`. (§11, #10)

## Debug / logging

- Debug routes to the **chat frame** via `dbg()` (cyan `[WG]` + orange `[DBG]`). The addon has no §6A
  persistent data-browser window (the popup is a transient dialog), so a chat fallback is defensible
  (§12.7) — **but** the debug flag is **persisted in SavedVariables** (`db.profile.debug`, seeded into
  `self.debug` at `OnInitialize`), whereas §12.5 mandates a **session-only** flag, off on every reload.

## Packaging / lint / tests

- **No `.pkgmeta`** (§13, MUST). **No `.luacheckrc`** (§14, MUST). **No `tests/` harness** (§14A, MUST /
  #24) — no headless suite, no TDD. Validation is manual/in-game only (`docs/smoke-tests.md`).

## Docs

- Root ships `README.md` (full), `LICENSE`, **and** a full-brief `CLAUDE.md` (should be a stub) **and**
  `ARCHITECTURE.md` (should live in `docs/`). (§15.2, §15.3, #26)
- `README.md` order: title, badges, logo, description, Screenshots, Usage, How It Works, FAQ,
  Troubleshooting, **For contributors** (non-canonical), Issues and feature requests, Version History.
  **Missing `## Testing`** (MUST) and a **Standard badge/link** (MUST). The `[wow]` badge reads
  "Midnight 12.0.5", not in lockstep with TOC `120007`. (§15.1, §2.3, #28)

## Versioning

- Semver `1.2.0`, TOC + `WhatGroup.VERSION` + README in agreement. ✅ (§17) — `schemaVersion` bump
  discipline N/A because no `schemaVersion` exists yet (see WG-08).

---

### Compliance highlights (what the addon already does to standard)

Schema-as-single-source (§4.5), the full options-panel look (§6.5–§6.10), slash dispatch (§7.1–§7.3),
taint discipline / observation-only hooks (§9), single-global AceDB (§5.1 structure), vendored-and-
committed libs with no externals (§3.3), single Retail Interface line (§2.3), semver (§17). These are
strong and should be preserved through remediation.
</content>
</invoke>
