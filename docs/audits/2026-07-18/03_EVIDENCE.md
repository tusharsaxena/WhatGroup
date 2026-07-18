# 03 — Evidence

**Addon:** Ka0s WhatGroup · **Standard:** v2.7.0 (2026-07-17) · **Date:** 2026-07-18

`file:line` citations backing every deviation in `02_DEVIATIONS.md`, plus compliance evidence for
the major claims in `01_CURRENT_STATE.md`. Line numbers are as of this audit's tree state.

---

## Deviation evidence

### WG-09 — missing `X-Wago-ID`
- `WhatGroup.toc:1-13` — metadata block ends at `## X-Curse-Project-ID: 1489907` (line 13); no
  `## X-Wago-ID` line follows. `X-Curse-Project-ID` present ⇒ published ⇒ toc-file-§1 wants Wago too.

### WG-14 — TOC file-listing section order
- `WhatGroup.toc:15` `# Libraries (must load first)`
- `WhatGroup.toc:25` `# Core`
- `WhatGroup.toc:31` `# Defaults`
- `WhatGroup.toc:34` `# Locales`
- `WhatGroup.toc:37` `# Settings`
- `WhatGroup.toc:42` `# Modules`
- Order = Libraries → Core → Defaults → Locales → Settings → Modules; mandated (toc-file-§5) =
  Libraries → **Locales** → Core → Defaults → **Modules** → **Settings**.

### WG-19 — help header trailing colon
- `core/WhatGroup.lua:636-637` — `p("v" .. WhatGroup.VERSION .. " " .. NS.L["slash commands"] ..
  " (|cffFFFF00/whatgroup|r is an alias for |cffFFFF00/wg|r):")` — the printed line ends in `):`.

### WG-22 — printer/sink not secret-safe
- `core/WhatGroup.lua:79-81` — `local function p(...) print(CHAT_PREFIX, ...) end` — global
  `print`, raw varargs, no secret-safe stringifier.
- `core/WhatGroup.lua:85` — `NS.Print = p` (the shared chat seam is this un-guarded `p`).
- `core/DebugLog.lua:286-290` — `function NS.Debug(tag, fmt, ...) … local msg =
  select("#", ...) > 0 and fmt:format(...) or fmt; D:Add(tag, msg) end` — `fmt:format(...)` runs
  on raw args; no secret-safe path.
- Repo-wide search for `SafeToString` / `IsConcatSafe` returns **no definition** (only a comment
  at `core/WhatGroup.lua:174` asserting a specific call site is secret-safe by inspection).

### WG-23 — call sites bypass the shared printer
- `core/WhatGroup.lua:343-373` — `WhatGroup:ShowNotification` builds each line by hand, e.g.:
  - `:343` `print(CHAT_PREFIX .. " " .. NS.L["You have joined a group!"])`
  - `:344` `print(CHAT_PREFIX .. "   - " .. colorize(NS.L["Group:"], gold) .. " " .. tostring(info.title …))`
  - `:352,:355,:360,:369,:373` — same `print(CHAT_PREFIX .. … )` pattern with `..`/`tostring`/`colorize`.
- These call global `print`, hand-write `CHAT_PREFIX`, and pre-concatenate before any shared seam.

### WG-24 — defaults not in `defaults/Profile.lua`
- `defaults/` directory contains only `TeleportSpells.lua` (data table) — no `Profile.lua`.
- `settings/Schema.lua:80-192` — each `add{ … default = <value> … }` row hardcodes a default
  (`default = true`, `default = 0`, …).
- `settings/Schema.lua:318-338` — `Settings.BuildDefaults()` walks `Schema` and threads each
  row's `default` into the AceDB `profile` table; this is the only defaults source.

### WG-25 — combat panel-open message non-canonical / uncoloured
- `core/WhatGroup.lua:831-833` — `if InCombatLockdown() then return p(NS.L["Cannot open the
  settings panel during combat. Try again after combat ends."]) end`.
- `locales/enUS.lua:84-85` — the string literal; no grey colour code, not the canonical
  "cannot open settings during combat — Blizzard's category-switch is protected".

### WG-26 — windows don't persist geometry
- `modules/Frame.lua:39-46` — `f = CreateFrame("Frame", "WhatGroupFrame", …)`; `:41`
  `f:SetPoint("CENTER", UIParent, "CENTER", 0, math.floor(UIParent:GetHeight()*0.25))` — fixed
  point each build; `:65-66` `StartMoving`/`StopMovingOrSizing` with no position capture; no
  SavedVariables read/write of a window point anywhere in the file.
- `core/DebugLog.lua:70-76` — `frame:SetPoint("CENTER", 220, -80)`; `:84-85` drag start/stop with
  no persistence; console geometry never written to `db`.

### WG-29 — no `version` verb
- `core/WhatGroup.lua:605-624` — `COMMANDS` table lists `help, show, test, config, list, get,
  set, reset, debug`; no `version` entry.

### WG-17 — AceTimer absent (accepted)
- `core/WhatGroup.lua:30-32` — `NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0")` — no
  `AceTimer-3.0` mixin.
- `core/WhatGroup.lua:452-458` — `C_Timer.After(delay, …)` with the WG-17 justification comment.
- `libs/` contains no `AceTimer-3.0/` folder (directory listing).

### WG-27 — standards-reference heading not canonical
- `CLAUDE.md:6` — `## Standards adherence — read before any change` (not `## Standards
  compliance (read first)`).
- `CLAUDE.md:18-19` — cites the retired `§0` notation.
- `docs/agent-context.md:18` — first `## Hard rules` bullet points to `docs/audits/2026-07-12/`,
  not to a `CLAUDE.md` "Standards compliance" section by name.

### WG-28 — no shared SKIN/ApplySkin seam
- `modules/Frame.lua:48-57` — inline `f:SetBackdrop{…}` + `SetBackdropColor`/`SetBackdropBorderColor`.
- `core/DebugLog.lua:27-38` — a **local** `BACKDROP` table + local `applySkin(f)`; not shared with
  the popup, so two independent skin definitions exist.

---

## Compliance evidence (spot checks backing "closed"/OK claims)

- **Private `NS`, no global (WG-01 closed):** `core/WhatGroup.lua:29-33`, `docs/agent-context.md:20`.
- **Eager settings registration (WG-02 closed):** `core/WhatGroup.lua:161-163` (Register from
  `OnEnable`); `settings/Panel.lua:641-771` (`Settings.Register`, idempotent guard, lazy `OnShow`).
- **Compat sole caller (WG-03 closed):** `core/Compat.lua:24-98`; call sites use `NS.Compat.*`
  (`core/WhatGroup.lua:233,265,367`; `modules/Frame.lua:205-206`).
- **Tests green (WG-04):** `lua tests/run.lua` → `48 passed, 0 failed` (run this audit);
  `docs/test-cases.md:66-75` totals = 48; README `![Tests](…Tests-48%2F48…)` at `README.md:7`.
- **Lint clean (WG-05):** `luacheck .` → `0 warnings / 0 errors in 9 files` (run this audit);
  `.luacheckrc:1-39`.
- **`.pkgmeta` no externals (WG-06):** `.pkgmeta:1-11`.
- **Locale module (WG-07 closed):** `locales/enUS.lua:28-31` (metatable fallback), routed strings.
- **schemaVersion + migration (WG-08 closed):** `core/Database.lua:16-45`;
  `settings/Schema.lua:322` seeds `global.schemaVersion`.
- **CLAUDE stub + docs quartet (WG-10 closed):** `CLAUDE.md:26-42`; `docs/agent-context.md`,
  `docs/ARCHITECTURE.md`, `docs/testing.md`, `docs/smoke-tests.md`, `docs/test-cases.md` all present.
- **Logo under media/logos (WG-11 closed):** `media/logos/whatgroup.logo.tga` + `.png`;
  `settings/Panel.lua:551`.
- **Debug session-only (WG-12 closed):** `core/WhatGroup.lua:38-39`; `core/DebugLog.lua:251-272`;
  not a schema row (`settings/Schema.lua:116-123`).
- **Canonical README (WG-13 closed):** `README.md:1-98` (H1, 5-badge row, logo, description,
  Screenshots, Usage, How it works, FAQ, Troubleshooting, Issues, Version History).
- **Field hygiene (WG-15 closed):** `WhatGroup.toc:8` OptionalDeps, `:6` `IconTexture`, `:10`
  `Category-enUS: Chat`.
- **Schema validated at boot (WG-18 closed):** `settings/Panel.lua:660` (`ValidateSchema()` inside
  `Register`, called from `OnEnable`).
- **AceGUI Defaults button (options-ui-§5 OK):** `settings/Panel.lua:112-121` (`AceGUI:Create("Button")`
  → `frame:SetParent(panel)` → `TOPRIGHT` at `(-PADDING_X, -HEADER_TOP)`).
- **In-place refreshers, no O(N) rebuild (options-ui-§11 OK):** `settings/Schema.lua:382-392`
  (`RefreshAll` runs updater closures); `settings/Panel.lua:383-390,410-416`.
- **Always-visible scrollbar (options-ui-§10 OK):** `settings/Panel.lua:176-283`.
- **ID-based game-data matching (localization-§4 OK):** `core/WhatGroup.lua:291-296` (Enum keys),
  `:305-306` (numeric `categoryID`), `:274-279` (`mapID`/`activityID`).
- **Deferred secure writes (events-frames-taint-§2 OK):** `modules/Frame.lua:177-191, 296-317`.
- **Debug console shape (debug-logging OK):** `core/DebugLog.lua:67-145` (700×344, DIALOG,
  UISpecialFrames, mono font), `:149-159` (two pure formatters), `:251-281` (SetEnabled seam,
  colour-coded ack, `[Debug]` bracket, `[Init]` summary).
