# Frame

The popup dialog that displays captured group info. Lives in `WhatGroup_Frame.lua` as a single global Frame named `WhatGroupFrame`.

## Lazy creation

**Nothing in `WhatGroup_Frame.lua` runs at file-load.** All frame creation — the popup, the Close button, the SecureActionButtonTemplate teleport button, the `UISpecialFrames` entry — is wrapped in a `buildFrame()` function that fires on the first `WhatGroup:ShowFrame()` call only. The reason is taint: creating these things at PLAYER_LOGIN was leaving a residue that surfaced as `ADDON_ACTION_FORBIDDEN ... 'callback()'` when the player clicked the GameMenu's Logout button. Specifically, adding `"WhatGroupFrame"` to `UISpecialFrames` and creating a `SecureActionButtonTemplate` button before Blizzard's `GameMenuFrame:InitButtons()` first ran caused GameMenu's button-callback closures to inherit the addon's load-time taint — by the time the player clicked Logout, those closures' invocation of `Logout()` was rejected by the secure system and attributed to WhatGroup. Deferring all frame creation to first show fixes this: GameMenu's `InitButtons` runs in a clean context during the boot sequence, the closures it builds for Logout / Settings / Macros / etc. are taint-free, and any taint we generate later is contained to a session where the player has actually used the addon.

The pattern is borrowed from a similar reference addon that demonstrates the same lazy approach for its group-reminder popup; see [wow-quirks.md → Lazy popup + secure button creation](./wow-quirks.md#lazy-popup--secure-button-creation) for the full background.

## Shape

| Property | Value |
|---|---|
| Frame name | `WhatGroupFrame` (globally accessible) |
| Size | 420 × 260 |
| Anchor | `CENTER` of UIParent, offset up by 25% of UIParent's height |
| Strata | `DIALOG` |
| Template | `BackdropTemplate` |
| Background | dark grey `0.08, 0.08, 0.08, 0.95` |
| Border | 1px grey `0.3, 0.3, 0.3, 1.0` |
| Drag handle | top-30px title bar; `StartMoving` / `StopMovingOrSizing` |
| Clamping | `SetClampedToScreen(true)` |
| ESC-to-close | `tinsert(UISpecialFrames, "WhatGroupFrame")` |

## Layout

A single content frame inset 14px from the title bar and 14px / 44px from the bottom (the 44px reserves space for the Close button). Inside it, six rows top-down:

| Row | Label | Value source |
|---|---|---|
| 1 | `Group:` | `info.title` |
| 2 | `Instance:` | `info.fullName` (fallback `"Unknown"`) |
| 3 | `Type:` | `info.shortName` (fallback `WhatGroup.Labels.GetGroupTypeLabel(info)`) |
| 4 | `Leader:` | `info.leaderName` |
| 5 | `Playstyle:` | `info.playstyleString` (server-rendered) → `WhatGroup.Labels.PLAYSTYLE[info.generalPlaystyle]` → fallback dim em-dash |
| 6 | `Teleport:` | 24×24 spell icon button (hidden when no spell mapped) |

Labels use a fixed 72px column (`LABEL_WIDTH`) coloured gold (`|cffFFD700`); values are anchored 6px to the right of the label and use `GameFontHighlight` (white). The 18px row gap (`yGap`) gives a clean vertical rhythm. The content frame's size is fully determined by its TOPLEFT + BOTTOMRIGHT anchors against `f` (insets `14, -38` and `-14, 44`), so no explicit `SetHeight` is needed — the row stack just has to fit inside that natural extent.

## `MakeLabel` helper

```lua
local function MakeLabel(parent, anchor, yOffset, labelText, valueText)
    -- gold "label:" FontString, 72px wide, left-justified, no wrap
    -- white value FontString, anchored 6px to the right of the label
    return label, value
end
```

Called once inside `buildFrame()` (i.e. on first `ShowFrame()`) to build the static layout. The returned `value` FontStrings are stored in the module-local `fields` table so `PopulateFields` can update them on every `ShowFrame()`.

## `PopulateFields()`

Called on every `ShowFrame()`. Reads `WhatGroup.pendingInfo` and updates each field via the appropriate FontString's `SetText`.

Edge cases:

- **`pendingInfo == nil`** — every text field shows `|cff888888No data|r` and the teleport button hides. This shouldn't normally happen (`/wg show` and `/wg test` both set `pendingInfo` before calling `ShowFrame`), but the populator defends against it.
- **`info.fullName == ""`** — Instance row falls back to `"Unknown"`.
- **`info.shortName == ""`** — Type row falls back to `WhatGroup.Labels.GetGroupTypeLabel(info)`.
- **`info.playstyleString == ""` AND `WhatGroup.Labels.PLAYSTYLE[info.generalPlaystyle] == nil`** — Playstyle row falls back to a dim em-dash. This is also the path taken when `generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None` (= 0).

## Teleport button

`teleportBtn` is an anonymous `SecureActionButtonTemplate` Button registered for `AnyUp` / `AnyDown` clicks. The secure template is mandatory: `CastSpellByID` from a non-secure `OnClick` handler fires `ADDON_ACTION_FORBIDDEN` in retail. The macro-attribute approach below routes the click through Blizzard's secure action handler, which is the only legal cast path from addon code.

**The button is parented directly to `f` (the popup), not to `UIParent`.** Earlier iterations parented it to UIParent and synced its screen position from a non-secure proxy frame inside the popup; that pattern leaked taint into Blizzard's secure-execute chain, surfacing as `ADDON_ACTION_FORBIDDEN ... 'callback()'` when the player clicked Logout in the GameMenu. Parenting directly to `f` means the button rides on the parent-child relationship: `f:Show()` shows the button, `f:Hide()` hides it, dragging the popup moves the button with it. No `syncTeleportButton`, no `PLAYER_REGEN_ENABLED` handler, no deferred Hide, no proxy frame.

**Anchor uses the implicit-parent `SetPoint` form** with offsets derived from the Teleport label's actual rendered position:

```lua
local btnX = (lblPort:GetLeft() - f:GetLeft()) + LABEL_WIDTH + 6
local btnY = lblPort:GetTop()  - f:GetTop()      -- negative; lblPort is below f.TOPLEFT

teleportBtn:SetPoint("TOPLEFT", btnX, btnY)
```

Retail's secure-frame system rejects any `SetPoint` call on a protected frame that names a non-secure region as the anchor target — even when that region is the protected frame's own parent. The 3-arg form lets the engine resolve the parent transitively after the protection check has already passed, so anchoring against `f` works inside `buildFrame()`. The offsets are computed from the Teleport label's actual rendered position via `GetLeft()`/`GetTop()` rather than hard-coded magic numbers, so changes to `LABEL_WIDTH`, `yGap`, or the row count keep the button aligned with its label automatically. See [wow-quirks.md → Secure buttons can't have an explicit non-secure anchor target](./wow-quirks.md#secure-buttons-cant-have-an-explicit-non-secure-anchor-target).

`ConfigureTeleportButton(btn, icon, info)`:

1. `WhatGroup:GetTeleportSpell(info.activityID, info.mapID)` — returns a spell ID or nil. The lookup is keyed by `mapID` (see [capture-pipeline.md → Teleport spell lookup](./capture-pipeline.md#teleport-spell-lookup)).
2. If nil: clear the macro attributes, `Hide()`, return.
3. Otherwise: spell name from `C_Spell.GetSpellName(spellID)` (with `GetSpellInfo` legacy fallback); icon texture from `C_Spell.GetSpellTexture(spellID)` (with `134400` — the `?` glyph — as a fallback texID).
4. `IsSpellKnown(spellID)` AND a non-nil spell name:
   - **known + named**: full alpha, `EnableMouse(true)`, `type="macro"` and `macrotext="/cast <SpellName>"` so a click runs the cast through the secure handler. `OnEnter` shows `GameTooltip:SetSpellByID(spellID)`.
   - **not known / unnamed**: 50% alpha, desaturated icon, `EnableMouse(false)`, secure attributes cleared.

The function ends with `btn:Show()` — straightforward, because the button is `f`'s child, so `f:Hide()` automatically hides it when the popup closes; we don't need the deferred-Hide cleanup that earlier UIParent-parented iterations required.

The label `Teleport:` is built directly inline (not via `MakeLabel`) because its value side is the button rather than a FontString, attached at `LABEL_WIDTH + 6` from the label.

## Public API

```lua
function WhatGroup:ShowFrame()
    -- First-show-in-combat defer: see § Combat-defer below.
    if not f and InCombatLockdown() then …queue on PLAYER_REGEN_ENABLED… ; return end

    buildFrame()    -- lazy: first call only
    PopulateFields()
    f:Show()
    f:Raise()
end
```

`ShowFrame` re-populates from the current `pendingInfo` every call — so toggling `pendingInfo` and re-calling `ShowFrame` updates the visible rows without recreating widgets. The `Raise()` call ensures the dialog comes to the front of its strata when re-opened over another popup.

## Combat-defer

`SecureActionButtonTemplate` attribute writes (`type`, `macrotext`) and `Show`/`Hide` are protected during `InCombatLockdown()` — silently dropped, not erroring. Three call sites are guarded:

- **`ConfigureTeleportButton`** (called every `PopulateFields`, i.e. every `ShowFrame`). When in combat: stash `info` on `f._pendingTeleportInfo`, register `PLAYER_REGEN_ENABLED` on the popup frame, and return. When the event fires, unregister and rerun `ConfigureTeleportButton` with the most recently-stashed info. Repeated calls during the same combat window safely overwrite the stash; `RegisterEvent` is idempotent. The button retains its prior visual state until the rerun.
- **`WhatGroup:ShowFrame` first-build** (the `not f and InCombatLockdown()` branch above). Creating the popup itself is fine in combat, but `buildFrame()` creates a `SecureActionButtonTemplate` and inserts `"WhatGroupFrame"` into `UISpecialFrames` — both protected. So the very first show is queued via a one-shot `CreateFrame("Frame")` waiting on `PLAYER_REGEN_ENABLED`, with a `[WG] Popup deferred until combat ends.` chat hint. The captured `pendingInfo` is restored on combat-end only if it was cleared mid-wait (group-leave during the window). Subsequent in-combat shows route through `ConfigureTeleportButton`'s guard, since `f` already exists.
- **`Settings.Register()`** in `WhatGroup_Settings.lua` self-guards on `InCombatLockdown()` after the idempotent check (defense-in-depth atop `runConfig`'s slash-handler refusal). Same combat-taint rationale as the popup's secure button — registering Settings categories mid-combat taints the GameMenu callback chain.

There is intentionally no programmatic Hide method. The frame is closed by:

- The Close button at the bottom (`UIPanelButtonTemplate`, 90×24) — calls `f:Hide()` directly.
- The ESC key (`UISpecialFrames` registration).
- The `WhatGroup:show` chat link → `WhatGroup:ShowFrame()` (re-opens, doesn't close).

## Shared label helpers

`GetGroupTypeLabel` and the `PLAYSTYLE` enum→string table live on the shared `WhatGroup.Labels` namespace (defined in `WhatGroup.lua`). Both `ShowNotification` (chat output) and `PopulateFields` (popup) read from the same source so a new playstyle enum or group-type rule lands in one place. `WhatGroup.lua` loads before `WhatGroup_Frame.lua` per the TOC, so `WhatGroup.Labels` exists by the time the popup file runs `PopulateFields`.

## Frame dependencies

- **`WhatGroup` global** — read at `PopulateFields` time for `WhatGroup.pendingInfo`, `WhatGroup:GetTeleportSpell`, and `WhatGroup.Labels.{GetGroupTypeLabel, PLAYSTYLE}`. Read at file-load time to attach the `ShowFrame` method. Also reads `WhatGroup._dbg` and `WhatGroup._print` for debug logging and chat hints.
- **WoW API** — `CreateFrame`, `BackdropTemplate`, `UISpecialFrames`, `GameFontNormalLarge` / `GameFontNormal` / `GameFontHighlight`, `GameTooltip`, `C_Spell.GetSpellName` (with `GetSpellInfo` legacy fallback), `C_Spell.GetSpellTexture` (with `134400` fallback texID), `IsSpellKnown`, `InCombatLockdown`, `PLAYER_REGEN_ENABLED` event. Casting itself is delegated to Blizzard's secure action handler via `type="macro"` + `macrotext="/cast <SpellName>"` — `CastSpellByID` is never called from non-secure code.
- **No Ace3 dependencies.** The popup uses raw Blizzard `Frame` / `FontString` / `Texture` / `Button` — no AceGUI. (AceGUI is only used in the Settings panel.)
