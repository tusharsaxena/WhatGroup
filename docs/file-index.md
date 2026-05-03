# File index

Where each responsibility lives in the source tree. Pair this map with the actual files before editing — `WhatGroup.toc` is the source of truth for load order.

## Top-level Lua

| File | Responsibility |
|------|----------------|
| `WhatGroup.toc` | Manifest. Interface line (`120000,120001,120005`), Title, Author, Version, `iconTexture`, `SavedVariables = WhatGroupDB`, `DefaultState = enabled`, `Category-enUS`, `X-License = MIT`. Then the load order: lib `.lua` files (order: `LibStub` → `CallbackHandler-1.0` → `AceAddon-3.0` → `AceEvent-3.0` → `AceConsole-3.0` → `AceDB-3.0`), then `AceGUI-3.0.xml` (which pulls in `widgets/`), then the four core `.lua` files (`WhatGroup.lua` → `data\TeleportSpells.lua` → `WhatGroup_Settings.lua` → `WhatGroup_Frame.lua`). AceHook-3.0 is intentionally **not** vendored — see `WhatGroup.lua` for the rationale. |
| `WhatGroup.lua` | AceAddon shell + capture pipeline + slash dispatch. Promotes any pre-existing `_G.WhatGroup` to an AceAddon via `LibStub("AceAddon-3.0"):NewAddon(existing, "WhatGroup", "AceConsole-3.0", "AceEvent-3.0")` and re-publishes the global. **Installs both direct `hooksecurefunc` post-hooks at file-load top-level** — one on `C_LFGList.ApplyToGroup`, one on `SetItemRef` (filtered to `WhatGroup:` link clicks). Houses `OnInitialize` / `OnEnable` (events-only — no hook installation, no Settings registration), the `CHAT_PREFIX = "\|cff00FFFF[WG]\|r"` constant, the session-only locals (`captureQueue`, `pendingApplications`, `wasInGroup`, `notifiedFor`, `notifyGen`), the `LFG_LIST_APPLICATION_STATUS_UPDATED` and `GROUP_ROSTER_UPDATE` handlers, the `_TryFireJoinNotify(reason)` dual-path notify scheduler with `notifyGen`-based cancellation, the `WhatGroup:WipeCapture()` consolidator (called from group-leave and from the master-switch off-flip), the `ShowNotification` chat-output builder, the `WhatGroup.Labels` namespace (`PLAYSTYLE`, `GetGroupTypeLabel`, `GetPlaystyleLabel`) shared with the popup, the `WhatGroup:GetTeleportSpell(activityID, mapID)` resolver (the `TeleportSpells` table itself lives in `data/TeleportSpells.lua`), and the `COMMANDS` slash-dispatch table. Also defines `WhatGroup:RunTest()` — the public method shared by `/wg test` and the panel's Test button. |
| `data/TeleportSpells.lua` | mapID → Path-of teleport spell ID lookup. Populates `WhatGroup.TeleportSpells` (referenced by `WhatGroup:GetTeleportSpell`). Keyed by the dungeon's instance map ID — stable across seasons, unlike LFG `activityID`. Values are either a single spellID (number) or a list `{ id1, id2 }` for dungeons whose teleport has been re-issued under a new spell ID over time (the resolver picks whichever the player has learned via `IsSpellKnown`). Loaded after `WhatGroup.lua` per the TOC so `_G.WhatGroup` exists at the assignment. Sectioned by expansion; per-row trailing comment is the dungeon name. Adding a row = appending to the table — see [common-tasks.md → Add a dungeon teleport spell mapping](./common-tasks.md#add-a-dungeon-teleport-spell-mapping). |
| `WhatGroup_Settings.lua` | Schema rows + Helpers + canvas-layout panel builder. Stamps `WhatGroup.Settings = { Schema, Helpers, _refreshers, _refresherOrder, _panels, BuildDefaults, Register, EnsureResetPopup }`. Schema rows are appended via `add{}` calls in source order — order = panel render order. Helpers covers `Get` / `RawSet` / `Set` / `FindSchema`, `ValidateSchema`, `RestoreDefaults` (popup-confirmed via `WHATGROUP_RESET_ALL`) / `RefreshAll`, plus the panel-rendering surface (`CreatePanel`, `PatchAlwaysShowScrollbar`, `Section`, `RenderField`, `InlineButton`, `RenderSchema`, `BuildMainContent`). `Helpers.Set` is the orchestrated single write-path — writes through `RawSet`, fires the row's `onChange`, then runs `RefreshAll` (with `opts.skipOnChange` / `opts.skipRefresh` escape hatches). `Helpers.RawSet` is the side-effect-free write reserved for callers that genuinely need it (none today). `_refresherOrder` is an array kept alongside the `_refreshers` hash so `RefreshAll` iterates in schema (= panel render) order rather than `pairs()` hash order. `BuildDefaults` walks the schema and threads each row's `default` into `profile.*`. `Register` is **lazy** — called only from `runConfig` (the `/wg config` slash handler), guarded by `WhatGroup._settingsRegistered` and self-guarded against `InCombatLockdown()` as defense-in-depth. `EnsureResetPopup` is also lazy — writes `StaticPopupDialogs["WHATGROUP_RESET_ALL"]` on first call (Defaults button or `/wg reset`); the same OnAccept body backs both routes. Both lazy paths exist because writing to a Blizzard-protected surface at PLAYER_LOGIN taints GameMenu's button callbacks. The Test button is rendered via an `afterGroup` callback in `Settings.Register`, not as a schema row. |
| `WhatGroup_Frame.lua` | The 420×260 popup dialog. **Everything is lazy**: file-load runs only the AceAddon lookup, the layout constants (`FRAME_WIDTH`, `FRAME_HEIGHT`, `LABEL_WIDTH`, `yGap`), and the `WhatGroup:ShowFrame()` method assignment. Reads `WhatGroup.Labels.{GetGroupTypeLabel, PLAYSTYLE}` at popup-render time. The actual frame creation — `WhatGroupFrame` (BackdropTemplate, `DIALOG` strata, drag handle, `SetClampedToScreen`), the row layout via `MakeLabel`, `ConfigureTeleportButton`, the `SecureActionButtonTemplate` teleport button parented to the popup, and the `UISpecialFrames` ESC-to-close registration — all happen inside a `buildFrame()` function that fires on the first `ShowFrame()` call only. Same lazy-creation rationale as the Settings panel and reset popup. Close button + ESC are the only hide paths. |
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
7. `AceGUI-3.0` (loaded via its `.xml`, last) — checkbox / slider / button / heading widgets used by the settings panel.

`AceHook-3.0` was previously vendored (for `SecureHook` / `RawHook`), but both have been replaced with direct Blizzard `hooksecurefunc` calls — AceHook's wrappers leave per-invocation closures that taint Blizzard's secure-execute chain on Logout. The library directory has been removed from `libs/`.

Libs are copied as-is from Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD/libs/`) so versions stay aligned across the user's addons. Refresh by re-copying that directory.

## media/

Logo / screenshot assets referenced by `README.md`. Not loaded by Lua. Files there don't ship in the packaged addon unless explicitly listed in a `.pkgmeta` or required by the TOC.

## Top-level docs

- [README.md](../README.md) — user-facing.
- [CLAUDE.md](../CLAUDE.md) — engineer working notes (hard rules + response style + doc index).
- [ARCHITECTURE.md](../ARCHITECTURE.md) — design overview + invariants + doc index.
- `docs/*.md` — topic chunks. Read on demand:
  - [scope.md](./scope.md) — in / out of scope + resolved decisions
  - [capture-pipeline.md](./capture-pipeline.md) — LFG state machine + FIFO + `hooksecurefunc` on `SetItemRef`
  - [settings-system.md](./settings-system.md) — schema, panel renderer, db.profile
  - [slash-dispatch.md](./slash-dispatch.md) — `/wg` UX + COMMANDS table
  - [frame.md](./frame.md) — popup dialog
  - [wow-quirks.md](./wow-quirks.md) — Blizzard-API gotchas
  - [common-tasks.md](./common-tasks.md) — recipes
  - [smoke-tests.md](./smoke-tests.md) — manual in-game smoke-test checklist
