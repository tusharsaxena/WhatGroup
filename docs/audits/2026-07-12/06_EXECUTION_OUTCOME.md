# 06 — Execution Outcome (remediation build)

**Addon:** Ka0s WhatGroup · **Prefix:** `WG-` · **Standard:** v1.0.0 (2026-07-12) · **Date:** 2026-07-12

Outcome of executing the remediation designed in `04_TECHNICAL_DESIGN.md` and ordered in
`05_EXECUTION_PLAN.md`. Both commit gates are green: **`lua tests/run.lua` → 28 passed / 0 failed**,
**`luacheck .` → 0 warnings / 0 errors**. No version bump; nothing staged or committed (per `CLAUDE.md`).

---

## Decisions taken (asked up front)

| Topic | Decision |
|---|---|
| **WG-17 AceTimer** | Keep raw `C_Timer.After`; add a SHOULD-justification comment at each site + a "Timers" note in `docs/ARCHITECTURE.md`. Not vendored. |
| **WG-01 global** | Remove `_G.WhatGroup` **entirely** — no public global. Everything internal via the private `NS`. |
| **Execution scope** | Build all sprints **except WG-02 / WG-18** (eager taint-safe settings registration + boot-time schema validation), deferred to a focused pass after in-game taint verification. |

---

## What was built, by deviation ID

### Closed (MUST)

| ID | Change |
|---|---|
| **WG-01** | `local addonName, NS = ...` header in every source file; `NS.addon = AceAddon:NewAddon(NS, addonName, …)`; `_G.WhatGroup` removed; downstream files alias `local WhatGroup = NS.addon`. |
| **WG-03** | New `Compat.lua` → `NS.Compat.{GetSpellName,GetSpellInfo,GetSpellTexture,GetSpellLink,IsSpellKnown,GetActivityInfoTable}`; sole caller of the variant APIs; all call sites in `WhatGroup.lua` / `WhatGroup_Frame.lua` rerouted. |
| **WG-04** | `tests/{run,loader,wow_mock}.lua` harness + 5 suites (compat, database, settings, labels, capture). 28 tests. |
| **WG-05** | `.luacheckrc` (std lua51; excludes `libs/ audit/ reviews/ tests/`; WoW `read_globals`; `globals={WhatGroupDB,StaticPopupDialogs}`). |
| **WG-06** | `.pkgmeta` (`package-as: WhatGroup`; **no `externals:`**; `ignore` list). |
| **WG-07** | New `Locale.lua` → `NS.L` metatable shell; notify / popup / help / reset / group-type literals routed through `L[...]`. |
| **WG-08** | New `Database.lua` → `NS.SCHEMA_VERSION=1` + idempotent `NS:RunMigrations()` called after `AceDB:New`; `BuildDefaults` seeds `global.schemaVersion`. |
| **WG-09** | TOC: added `X-Standard`, `X-Curse-Project-ID: 1489907` (after `X-License`, mandated order). |
| **WG-10** | Root `CLAUDE.md` → stub (Tier 1 Flat + standard link + `docs/` pointer); full brief → `docs/agent-context.md`; `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`. |
| **WG-11** | Logo `media/screenshots/whatgroup.logo.{tga,png}` → `media/logos/`; `MAIN_LOGO_TEXTURE` repointed. |
| **WG-12** | `debug` removed from schema + persisted defaults; session-only `NS.State.debug` (off each login); `/wg debug` toggles the runtime flag only. |
| **WG-13** | README: `## Testing` section added; Standard badge added; `[wow]` badge synced to `120007` (12.0.7); `## For contributors` folded/removed; canonical §15.1 order. |

### Closed (SHOULD)

| ID | Change |
|---|---|
| **WG-14** | TOC `# Core` → `# Addon`. |
| **WG-15** | TOC `OptionalDeps: Ace3, LibStub, CallbackHandler-1.0`; `iconTexture` → `IconTexture`; `Category-enUS: Chat`. |
| **WG-16** | `data/TeleportSpells.lua` → root `TeleportSpells.lua`; `data/` removed; writes to `NS.TeleportSpells`. |
| **WG-17** | Documented `C_Timer` deviation — justification comment at each `C_Timer.After` + ARCHITECTURE "Timers" note. |
| **WG-19** | `NS.PREFIX` single shared constant; help header aligned to §7.4 `<tag> v<ver> slash commands`. |

### Deferred (by explicit decision — NOT closed)

| ID | Why | Where it stands |
|---|---|---|
| **WG-02** | Taint-sensitive: eager settings registration must be verified against the GameMenu→Logout taint repro in-game. | `Settings.Register()` remains **lazy on first `/wg config`** (unchanged). |
| **WG-18** | Rides with WG-02 (design §B). | `Helpers.ValidateSchema()` still called from within `Settings.Register`, not at boot. |

### Residuals (need input / follow-up)

- **`X-Wago-ID`** — omitted. The addon is CurseForge-only (project 1489907); no Wago ID exists. Add the field if/when the addon is published on Wago. Not a fabricated value.
- **Some topic docs under `docs/` (`settings-system.md`, `frame.md`, `capture-pipeline.md`, `slash-dispatch.md`, `wow-quirks.md`)** may still describe pre-refactor details (e.g. `CHAT_PREFIX` as a bare local, `WhatGroup.debug` persistence). The refreshed source-of-truth set — `CLAUDE.md`, `docs/agent-context.md`, `docs/ARCHITECTURE.md`, `docs/file-index.md`, `docs/common-tasks.md`, `README.md` — is now consistent with the `NS` namespace and root `TeleportSpells.lua`. Recommend a `/wow-addon:sync-docs` pass to sweep the remaining topic docs (out of the audit's MUST scope).

---

## File-level change map

**New:** `Compat.lua`, `Locale.lua`, `Database.lua`, `TeleportSpells.lua` (moved from `data/`),
`.luacheckrc`, `.pkgmeta`, `tests/run.lua`, `tests/loader.lua`, `tests/wow_mock.lua`,
`tests/test_{compat,database,settings,labels,capture}.lua`, `docs/agent-context.md`.

**Moved:** `ARCHITECTURE.md` → `docs/ARCHITECTURE.md`; `media/screenshots/whatgroup.logo.*` → `media/logos/`.

**Modified:** `WhatGroup.lua`, `WhatGroup_Settings.lua`, `WhatGroup_Frame.lua`, `WhatGroup.toc`,
`CLAUDE.md` (→ stub), `README.md`, `docs/smoke-tests.md`.

---

## Test harness

A headless Lua 5.1 harness that loads the addon under a WoW API mock — no game client needed.

### Layout (`tests/`)

| File | Role |
|---|---|
| `run.lua` | Runner + micro-framework (`test` / `assertEqual` / `assertTrue` / `assertFalse` / `assertNil`). Loads sources in TOC order, exposes `_G.WHATGROUP_TEST`, runs each suite under `pcall`, prints PASS/FAIL, exits non-zero on any failure. |
| `loader.lua` | Headless source loader: `loadfile` each source → `setfenv(chunk, env)` → `chunk(addonName, NS)`, threading one shared `NS` — reproducing the in-game `local addonName, NS = ...` header. |
| `wow_mock.lua` | Fresh env + control table per test. Fakes `LibStub` (AceAddon/AceDB/AceGUI), `CreateFrame`, `C_LFGList`, `C_Spell`, `IsSpellKnown`, `C_Timer`, `Settings`, `Enum.LFGEntryGeneralPlaystyle`, `GROUP_FINDER_*`, and captures `print`. WoW globals resolve here; Lua built-ins fall through to real `_G`. |
| `test_compat.lua` | `NS.Compat.*` shims (name/texture/link/known/activity). |
| `test_database.lua` | Fresh DB → `schemaVersion == 1`; `RunMigrations` idempotent + re-seeds a missing version. |
| `test_settings.lua` | `BuildDefaults` (profile + `global.schemaVersion`); `debug` absent from schema/defaults; `ValidateSchema` = 0 errors; `Get/Set` round-trip; `RestoreDefaults`; `enabled=false` onChange wipes capture. |
| `test_labels.lua` | `GetGroupTypeLabel` (M+/dungeon/raid/fallback); `GetPlaystyleLabel` (string vs enum); `GetTeleportSpell` (known-from-list / unknown-first / no-mapping). |
| `test_capture.lua` | The apply → applied → inviteaccepted event flow: fresh-vs-queued **mapID-preference merge**, queued survival when fresh is nil, and the master-switch capture gate. Drives the real event methods and asserts `pendingInfo` — not a tautology. |

### Running it

```
cd <repo root>
lua5.1 tests/run.lua      # 28 passed, 0 failed  (exit 0 on green, 1 on any failure)
luacheck .                # 0 warnings / 0 errors
```

### What it does NOT cover (stays manual, in-game)

AceGUI panel rendering, the `SecureActionButtonTemplate` teleport button, `UISpecialFrames`/ESC,
and — most importantly — **taint** (the GameMenu→Logout check). Those require the real client;
see the smoke tests below.

---

## Manual smoke tests — validate this build in-game

Run these on a retail (Midnight, Interface 120007) client after installing the modified addon.
The full canonical checklist is `docs/smoke-tests.md`; the list below targets **what this build changed**.

### A. Boot + taint (CRITICAL — guards the whole refactor)

1. Cold-load / `/reload` on any character. **Expect:** no Lua errors; no `[WG]` spam (debug is off).
2. Press **ESC** → GameMenu → click **Logout**. **Expect:** clean logout, **no `ADDON_ACTION_FORBIDDEN`**.
   - This is the load-bearing check: the namespace refactor, the new `Compat`/`Locale`/`Database`
     files, and the reordered TOC all execute during boot. Repeat the Logout check after `/wg test`,
     after `/wg config`, and after `/wg reset` → Yes.

### B. Namespace / no-global (WG-01)

3. `/run print(WhatGroup)` **Expect:** `nil` — the addon no longer exposes a global table.
4. `/wg` **Expect:** help prints as `[WG] v1.2.0 slash commands (/whatgroup is an alias for /wg):`
   followed by one row per command (the §7.4 header shape).

### C. Debug session-only (WG-12)

5. `/wg debug` → `Debug mode: ON`. `/wg list` **Expect:** **no `debug` row** in the settings list.
6. `/reload`, then `/wg debug` status via `/run print(...)` is not needed — just confirm the panel
   **General** page has **no Debug checkbox**, and that after a fresh login debug starts **OFF**
   (no `[DBG]` lines until you `/wg debug` again).

### D. Compat routing (WG-03) — teleport + notify

7. `/wg test` **Expect:** chat notification with all lines incl. `Teleport: [Path of the Corrupted
   Foundry]` (or `(not learned)`), and the popup with a teleport icon. Icon full-alpha if you know
   the Stonevault teleport, desaturated if not. (Exercises `NS.Compat.GetSpellName/GetSpellTexture/
   GetSpellLink/IsSpellKnown` + `GetActivityInfoTable`.)
8. Click the teleport icon (if learned). **Expect:** cast attempt, **no `ADDON_ACTION_FORBIDDEN`**.

### E. Media path (WG-11)

9. `/wg config` **Expect:** the landing page **logo renders** (now loaded from `media\logos\`). A
   broken/missing logo means the `MAIN_LOGO_TEXTURE` path is wrong for your install.

### F. Settings still work (regression)

10. `/wg config` opens on **Ka0s WhatGroup**; **General** subcategory expands; two-column layout;
    **Defaults** button top-right. Toggle **Auto Show** off → `/wg get frame.autoShow` = `false`.
11. `/wg set notify.delay 3.0` → `/wg get notify.delay` = `3.0s`. `/reload` → still `3.0s`
    (persistence). Restore with `/wg set notify.delay 1.5`.
12. `/wg reset` → confirm popup → **Yes** → "all settings reset to defaults" prints with `[WG]`.

### G. Real LFG (end-to-end)

13. `/wg debug`, `/reload`, apply to a Mythic+/raid group, accept the invite. **Expect:** after
    `notify.delay`s, the chat notification + popup show the **real** group's name / leader / mapID
    teleport. Leave the group → `/wg show` reports "No group info available." (session-only capture).

If **A** passes and **D**/**F** behave as before the refactor, the build is behaviourally sound.
The one thing headless testing cannot prove is taint — treat **A** as mandatory before trusting it.

---

## Verification workflow

A 6-agent adversarial verification workflow audited the finished build across six dimensions
(namespace, modules/routing, TOC/media, tests/lint, docs, behavioural-regression/taint) — 6 agents,
0 errors, 247k subagent tokens. Clean dimensions: **namespace/prefix**, **TOC/media**, **tests/lint**
(harness + luacheck re-run green; capture merge confirmed non-tautological). It surfaced **7 findings**
(1 major, 3 minor, 3 nit); each was triaged and resolved or consciously accepted:

| Sev | Finding | Resolution |
|---|---|---|
| **major** | `README.md` linked `ARCHITECTURE.md` at the root path, but the file was moved to `docs/`. | **Fixed** — link repointed to `docs/ARCHITECTURE.md`. |
| minor | Slash-CLI diagnostics (`unknown command`, `Usage: …`, `Debug mode:`) not routed through `NS.L`. | **Accepted + documented** — `Locale.lua` now states these developer/power-user CLI strings are deliberately out of locale scope; the player-facing surfaces (notify/popup/help/reset) all route through `L`. |
| minor | `docs/file-index.md` still described `_G.WhatGroup` promotion + `data/TeleportSpells.lua` as current. | **Fixed** — rewritten for the `NS` namespace and root `TeleportSpells.lua`; TOC field/casing list corrected. |
| minor | `/wg help` header dropped the em-dash (`v1.2.0 — slash commands` → `v1.2.0 slash commands`). | **Accepted (intended)** — the §7.4 mandated header shape is `<tag> v<ver> slash commands`, no em-dash. |
| nit | `docs/common-tasks.md` pointed at `data/TeleportSpells.lua` / `WhatGroup.TeleportSpells`. | **Fixed** — paths → root `TeleportSpells.lua` / `NS.TeleportSpells`. |
| nit | README Version History 1.2.0 line mentions `data/TeleportSpells.lua`. | **Accepted (historical)** — accurately records what the 1.2.0 release did; changelog, not current-state. |
| nit | `Compat.GetSpellName` didn't fall through to legacy `GetSpellInfo` when `C_Spell.GetSpellName` returns nil. | **Fixed** — restored the `A(x) or B(x)` fallthrough for exact behavioural parity. |

After fixes: `lua tests/run.lua` → **28 passed**; `luacheck .` → **0/0**. No stale `_G.WhatGroup` /
`data/TeleportSpells` current-state claim remains in `CLAUDE.md`, `README.md`, `docs/agent-context.md`,
`docs/ARCHITECTURE.md`, or `docs/file-index.md` (only intentional negations and the historical changelog line).

---

## Commit gate status

- `lua tests/run.lua` → **28 passed, 0 failed**
- `luacheck .` → **0 warnings / 0 errors in 7 files**
- 13/13 MUST IDs closed **except** the explicitly-deferred WG-02/WG-18; 5/5 remediated SHOULDs closed
  (WG-17 via documented-deviation comments).
