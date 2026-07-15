# File index

Where each responsibility lives in the source tree. Pair this map with the actual files before editing — `WhatGroup.toc` is the source of truth for load order.

## Source files

| File | Responsibility |
|------|----------------|
| `WhatGroup.toc` | Manifest. Interface line (`120007`), Title, Author, Version, `IconTexture`, `SavedVariables = WhatGroupDB`, `OptionalDeps` (includes `LibSharedMedia-3.0`), `DefaultState = enabled`, `Category-enUS = Chat`, `X-License = MIT`, `X-Standard`, `X-Curse-Project-ID`. Then the load order: lib `.lua` files (order: `LibStub` → `CallbackHandler-1.0` → `AceAddon-3.0` → `AceEvent-3.0` → `AceConsole-3.0` → `AceDB-3.0`), then `AceGUI-3.0.xml` (which pulls in `widgets/`), then `LibSharedMedia-3.0\lib.xml`, then the addon `.lua` files grouped by folder (`# Core`: `core/Compat.lua` → `core/Database.lua` → `core/DebugLog.lua` → `core/WhatGroup.lua`; `# Defaults`: `defaults/TeleportSpells.lua`; `# Locales`: `locales/enUS.lua`; `# Settings`: `settings/Schema.lua` → `settings/Panel.lua`; `# Modules`: `modules/Frame.lua`). AceHook-3.0 is intentionally **not** vendored — see `core/WhatGroup.lua` for the rationale. |
| `core/WhatGroup.lua` | AceAddon shell + capture pipeline + slash dispatch. Builds the addon on the shared private namespace via `LibStub("AceAddon-3.0"):NewAddon(NS, addonName, "AceConsole-3.0", "AceEvent-3.0")` and sets `NS.addon` — **no `_G.WhatGroup`**. **Installs both direct `hooksecurefunc` post-hooks at file-load top-level** — one on `C_LFGList.ApplyToGroup`, one on `SetItemRef` (filtered to `WhatGroup:` link clicks). Houses `OnInitialize` (also calls `RunMigrations`) / `OnEnable` (events-only — no hook installation, no Settings registration), the `NS.PREFIX = "\|cff00FFFF[WG]\|r"` constant (aliased to `CHAT_PREFIX`) plus the shared `NS.Print` chat seam, the `NS.FONT_MONO` path constant + its `LibSharedMedia-3.0` font registration (consumed by `core/DebugLog.lua`), the session-only `NS.State.debug` flag, the session-only locals (`captureQueue`, `pendingApplications`, `wasInGroup`, `notifiedFor`, `notifyGen`), the `LFG_LIST_APPLICATION_STATUS_UPDATED` and `GROUP_ROSTER_UPDATE` handlers, the `_TryFireJoinNotify(reason)` dual-path notify scheduler with `notifyGen`-based cancellation, the `WhatGroup:WipeCapture(reason)` consolidator (called from group-leave with no reason, and from the master-switch off-flip with `"addon disabled"` — a passed reason emits a one-line `[Capture] wiped` material-effect log only when something was in flight, debug-logging-§10), the `WhatGroup:InitSummary()` builder for the one-line `[Init]` session summary (the debug-logging-§5 identity fields `WhatGroup v<version>, schema v<schemaVersion>, profile '<profile>'` plus the current runtime state) that the `DebugLog:SetEnabled` seam appends on enable, right after the bracket line (debug-logging-§5 / debug-logging-§8), the `ShowNotification` chat-output builder, the `WhatGroup.Labels` namespace (`PLAYSTYLE`, `GetGroupTypeLabel`, `GetPlaystyleLabel`) shared with the popup, the `WhatGroup:GetTeleportSpell(activityID, mapID)` resolver (the `TeleportSpells` table itself lives in `defaults/TeleportSpells.lua`), and the `COMMANDS` slash-dispatch table. Also defines `WhatGroup:RunTest()` — the public method shared by `/wg test` and the panel's Test button. |
| `core/DebugLog.lua` | On-screen debug console (debug-logging §). Hangs `NS.DebugLog` and the global `NS.Debug(tag, fmt, …)` sink on the namespace. Owns the `WhatGroupDebugWindow` (`BackdropTemplate`, `DIALOG` strata, 700×344, monospace `ScrollingMessageFrame`, `Debug: ON/OFF` header toggle, `Copy`/`Clear`/`×`) and the `WhatGroupDebugCopyWindow` read-through `EditBox`. Frames are lazily created on first `Add`/`Show`. Two pure formatters (`FormatPlain` / `FormatColored`) back the plain Copy buffer and the coloured console view. `SetEnabled(on)` is the single state seam (set `NS.State.debug` → refresh header → chat ack via `NS.Print` → `[Debug] logging enabled/disabled` console line); the slash command and the header toggle both route through it. `NS.Debug` is zero-alloc when off. Loads before `core/WhatGroup.lua` so `NS.Debug` exists before any runtime handler fires. Reference: AbsorbTracker `core/DebugLog.lua`. See [debug-console.md](./debug-console.md). |
| `defaults/TeleportSpells.lua` | mapID → Path-of teleport spell ID lookup. Populates `NS.TeleportSpells` (referenced by `WhatGroup:GetTeleportSpell`, where `self == NS`). Keyed by the dungeon's instance map ID — stable across seasons, unlike LFG `activityID`. Values are either a single spellID (number) or a list `{ id1, id2 }` for dungeons whose teleport has been re-issued under a new spell ID over time (the resolver picks whichever the player has learned via `IsSpellKnown`). Writes straight to `NS`, so its load order relative to `core/WhatGroup.lua` is irrelevant. Sectioned by expansion; per-row trailing comment is the dungeon name. Adding a row = appending to the table — see [common-tasks.md → Add a dungeon teleport spell mapping](./common-tasks.md#add-a-dungeon-teleport-spell-mapping). |
| `settings/Schema.lua` | Schema rows + schema/db Helpers. Stamps `WhatGroup.Settings = { Schema, Helpers, _refreshers, _refresherOrder, _panels }` and hangs the schema-access Helpers on it. Schema rows are appended via `add{}` calls in source order — order = panel render order. Helpers here: `Get` / `RawSet` / `Set` / `FindSchema`, `ValidateSchema`, `BuildDefaults`, `RestoreDefaults` (popup-confirmed via `WHATGROUP_RESET_ALL`) / `RefreshAll`. `Helpers.Set` is the orchestrated single write-path — writes through `RawSet`, fires the row's `onChange`, then runs `RefreshAll` (with `opts.skipOnChange` / `opts.skipRefresh` escape hatches). `Helpers.RawSet` is the side-effect-free write reserved for callers that genuinely need it (none today). `_refresherOrder` is an array kept alongside the `_refreshers` hash so `RefreshAll` iterates in schema (= panel render) order rather than `pairs()` hash order. `BuildDefaults` walks the schema and threads each row's `default` into `profile.*`. `Settings.EnsureResetPopup` is **lazy** — writes `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` on first call (Defaults button or `/wg reset`); the same OnAccept body backs both routes. Lazy because writing to a Blizzard-protected surface at PLAYER_LOGIN taints GameMenu's button callbacks. |
| `settings/Panel.lua` | The Blizzard canvas-layout settings panel (landing page + General sub-page). Adds the panel-rendering Helpers to `WhatGroup.Settings.Helpers` — `CreatePanel`, `PatchAlwaysShowScrollbar`, `Section`, `RenderField`, `InlineButton`, `RenderSchema`, `BuildMainContent` — plus `Settings.Register`. Renders the schema (`settings/Schema.lua`) as a two-column AceGUI Flow layout inside an always-visible ScrollFrame. `Register` runs from `OnEnable` (so the panel is in the AddOns list at login) and again as an idempotent no-op from `runConfig`; guarded by `WhatGroup._settingsRegistered` and self-guarded against `InCombatLockdown()`. The Test button is rendered via an `afterGroup` callback in `Settings.Register`, not as a schema row. Loads after `settings/Schema.lua`. |
| `modules/Frame.lua` | The 420×260 popup dialog. **Everything is lazy**: file-load runs only the AceAddon lookup, the layout constants (`FRAME_WIDTH`, `FRAME_HEIGHT`, `LABEL_WIDTH`, `yGap`), and the `WhatGroup:ShowFrame()` method assignment. Reads `WhatGroup.Labels.{GetGroupTypeLabel, PLAYSTYLE}` at popup-render time. The actual frame creation — `WhatGroupFrame` (BackdropTemplate, `DIALOG` strata, drag handle, `SetClampedToScreen`), the row layout via `MakeLabel`, `ConfigureTeleportButton`, the `SecureActionButtonTemplate` teleport button parented to the popup, and the `UISpecialFrames` ESC-to-close registration — all happen inside a `buildFrame()` function that fires on the first `ShowFrame()` call only. Same lazy-creation rationale as the Settings panel and reset popup. Close button + ESC are the only hide paths. |
| `LICENSE` | MIT, current year, copyright add1kted2ka0s. |
| `README.md` | User-facing manual. Covers what the addon does, install instructions, slash commands, FAQ, troubleshooting, version history, contributing guide. |
| `CLAUDE.md` | Engineer working notes: hard rules, working environment, response style, doc index. |
| `ARCHITECTURE.md` | High-level design overview: what-it-does blurb, subsystem diagram, subsystems table → `docs/*`, invariants, dependencies, load order. |
| `docs/*.md` | Topic-specific deep dives (this file is one of them). |

## Embedded libraries

Vendored under `libs/`. Order in `WhatGroup.toc` is dependency order:

1. `LibStub` — every Ace3 module's bootstrap.
2. `CallbackHandler-1.0` — needed by AceEvent.
3. `AceAddon-3.0` — `NewAddon`, `OnInitialize` / `OnEnable` lifecycle.
4. `AceEvent-3.0` — `RegisterEvent`, event handler dispatch.
5. `AceConsole-3.0` — `RegisterChatCommand`.
6. `AceDB-3.0` — `WhatGroupDB` storage.
7. `AceGUI-3.0` (loaded via its `.xml`) — checkbox / slider / button / heading widgets used by the settings panel.
8. `LibSharedMedia-3.0` (loaded via its `lib.xml`, last) — media registry; `WhatGroup.lua` registers the vendored JetBrains Mono font with it at load so the debug console (`DebugLog.lua`) can render monospace.

`AceHook-3.0` was previously vendored (for `SecureHook` / `RawHook`), but both have been replaced with direct Blizzard `hooksecurefunc` calls — AceHook's wrappers leave per-invocation closures that taint Blizzard's secure-execute chain on Logout. The library directory has been removed from `libs/`.

Libs are copied as-is from Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD/libs/`) so versions stay aligned across the user's addons — except `LibSharedMedia-3.0`, copied from Ka0s AbsorbTracker alongside its JetBrains Mono font. Refresh by re-copying those directories.

## media/

- `logos/`, `screenshots/` — logo / screenshot assets referenced by `README.md` and the Settings landing page. Not loaded by Lua directly (the logo is referenced by texture path).
- `fonts/JetBrainsMono-Regular.ttf` (+ `OFL.txt`) — the vendored monospace font for the debug console (debug-logging-§2), registered via LibSharedMedia and referenced by `NS.FONT_MONO`. Shipped with its OFL license file.

## Top-level docs

- [README.md](../README.md) — user-facing.
- [CLAUDE.md](../CLAUDE.md) — engineer working notes (hard rules + response style + doc index).
- [ARCHITECTURE.md](./ARCHITECTURE.md) — design overview + invariants + doc index.
- `docs/*.md` — topic chunks. Read on demand:
  - [scope.md](./scope.md) — in / out of scope + resolved decisions
  - [capture-pipeline.md](./capture-pipeline.md) — LFG state machine + FIFO + `hooksecurefunc` on `SetItemRef`
  - [settings-system.md](./settings-system.md) — schema, panel renderer, db.profile
  - [slash-dispatch.md](./slash-dispatch.md) — `/wg` UX + COMMANDS table
  - [debug-console.md](./debug-console.md) — on-screen debug console + `NS.Debug` sink
  - [frame.md](./frame.md) — popup dialog
  - [wow-quirks.md](./wow-quirks.md) — Blizzard-API gotchas
  - [common-tasks.md](./common-tasks.md) — recipes
  - [smoke-tests.md](./smoke-tests.md) — manual in-game smoke-test checklist
