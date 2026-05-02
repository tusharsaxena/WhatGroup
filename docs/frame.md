# Frame

The popup dialog that displays captured group info. Lives in `WhatGroup_Frame.lua` as a single global Frame named `WhatGroupFrame`.

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
| 3 | `Type:` | `info.shortName` (fallback `GetGroupTypeLabel(info)`) |
| 4 | `Leader:` | `info.leaderName` |
| 5 | `Playstyle:` | `info.playstyleString` (server-rendered) → `PLAYSTYLE_LABELS[info.generalPlaystyle]` → fallback dim em-dash |
| 6 | `Teleport:` | 24×24 spell icon button (hidden when no spell mapped) |

Labels use a fixed 72px column (`LABEL_WIDTH`) coloured gold (`|cffFFD700`); values are anchored 6px to the right of the label and use `GameFontHighlight` (white). The 18px row gap (`yGap`) gives a clean vertical rhythm and the content frame's height is set explicitly to `abs(yGap) * 6 + 24` so the layout can't underflow.

## `MakeLabel` helper

```lua
local function MakeLabel(parent, anchor, yOffset, labelText, valueText)
    -- gold "label:" FontString, 72px wide, left-justified, no wrap
    -- white value FontString, anchored 6px to the right of the label
    return label, value
end
```

Called once at file load to build the static layout. The returned `value` FontStrings are stored in the module-local `fields` table so `PopulateFields` can update them on every `ShowFrame()`.

## `VALUE_COLORS` resolver table

Per-field hex resolver. Each entry is a function `(info) → hex` (or returns `nil`/`""` to leave the value uncoloured):

```lua
local VALUE_COLORS = {
    group     = function(info) return nil end,
    instance  = function(info) return nil end,
    type      = function(info) return nil end,
    leader    = function(info) return nil end,
    playstyle = function(info) return nil end,
}
```

Today every resolver returns `nil` — values render in plain white. The hook is in place so future per-field colour rules (e.g. red for low-rated leaders, gold for current-tier raids) can be added by editing one resolver without touching the populator.

`ColorizeValue(text, resolver, info)` wraps the text in `|cff<hex>…|r` only if the resolver returns a non-empty hex. Plain text is returned otherwise.

## `PopulateFields()`

Called on every `ShowFrame()`. Reads `WhatGroup.pendingInfo` and updates each field via the appropriate FontString's `SetText`.

Edge cases:

- **`pendingInfo == nil`** — every text field shows `|cff888888No data|r` and the teleport button hides. This shouldn't normally happen (`/wg show` and `/wg test` both set `pendingInfo` before calling `ShowFrame`), but the populator defends against it.
- **`info.fullName == ""`** — Instance row falls back to `"Unknown"`.
- **`info.shortName == ""`** — Type row falls back to `GetGroupTypeLabel(info)`.
- **`info.playstyleString == ""` AND `PLAYSTYLE_LABELS[info.generalPlaystyle] == nil`** — Playstyle row falls back to a dim em-dash. This is also the path taken when `generalPlaystyle == Enum.LFGEntryGeneralPlaystyle.None` (= 0).

## Teleport button

`teleportBtn` is a `SecureActionButtonTemplate` Button (globally named `WhatGroupFrameTeleportButton`) registered for `AnyUp` / `AnyDown` clicks. The secure template is mandatory: `CastSpellByID` from a non-secure `OnClick` handler fires `ADDON_ACTION_FORBIDDEN` in retail. The macro-attribute approach below routes the click through Blizzard's secure action handler, which is the only legal cast path from addon code.

The button is parented to **`UIParent`**, not to the popup. Retail's secure-frame system rejects anchoring a protected frame to any non-secure region — including FontStrings, sibling frames, and even the protected frame's own non-secure parent. UIParent is the only universally allowed anchor for a protected frame, so the button lives there.

A non-secure proxy Frame (`teleportSlot`) sits inside the popup, anchored to the `Teleport:` label, marking where the icon should appear visually. `syncTeleportButton()` mirrors the secure button's screen position to `teleportSlot:GetCenter()` whenever the layout changes:

- inline at the end of `ShowFrame()` (after `f:Show()`)
- one frame later via `C_Timer.After(0, ...)` — covers the race where `teleportSlot:GetCenter()` returns nil because the layout pass hasn't run yet
- on the popup's drag-stop (re-anchor as the popup moves)
- on `PLAYER_REGEN_ENABLED` — `SetPoint` on a protected frame is blocked during combat, so a `ShowFrame` triggered mid-combat retries on combat exit

`syncTeleportButton` also handles visibility: it `Show`s the secure button when the popup is visible AND `ConfigureTeleportButton` set the `type="macro"` attribute, and `Hide`s it otherwise. `f:HookScript("OnHide", ...)` hides the secure button when the popup closes (it lives on UIParent, so it doesn't auto-hide with `f`).

`ConfigureTeleportButton(btn, icon, info)`:

1. `WhatGroup:GetTeleportSpell(info.activityID, info.mapID)` — returns a spell ID or nil. The lookup is keyed by `mapID` (see [capture-pipeline.md → Teleport spell lookup](./capture-pipeline.md#teleport-spell-lookup)).
2. If nil: clear the macro attributes, `Hide()`, return.
3. Otherwise: spell name from `C_Spell.GetSpellName(spellID)` (with `GetSpellInfo` legacy fallback); icon texture from `C_Spell.GetSpellTexture(spellID)` (with `134400` — the `?` glyph — as a fallback texID).
4. `IsSpellKnown(spellID)` AND a non-nil spell name:
   - **known + named**: full alpha, `EnableMouse(true)`, `type="macro"` and `macrotext="/cast <SpellName>"` so a click runs the cast through the secure handler. `OnEnter` shows `GameTooltip:SetSpellByID(spellID)`.
   - **not known / unnamed**: 50% alpha, desaturated icon, `EnableMouse(false)`, secure attributes cleared.

`SetAttribute` calls are safe in or out of combat — only `SetPoint` is gated by combat lockdown, which is why position sync is what's deferred to `PLAYER_REGEN_ENABLED`, not attribute config.

The label `Teleport:` is built directly inline (not via `MakeLabel`) because it anchors to a proxy Frame rather than a FontString, and `teleportSlot`'s `LEFT` is attached at `LABEL_WIDTH + 6` from `lblPort`.

## Public API

```lua
function WhatGroup:ShowFrame()
    PopulateFields()
    f:Show()
    f:Raise()
end
```

`ShowFrame` re-populates from the current `pendingInfo` every call — so toggling `pendingInfo` and re-calling `ShowFrame` updates the visible rows without recreating widgets. The `Raise()` call ensures the dialog comes to the front of its strata when re-opened over another popup.

There is intentionally no programmatic Hide method. The frame is closed by:

- The Close button at the bottom (`UIPanelButtonTemplate`, 90×24) — calls `f:Hide()` directly.
- The ESC key (`UISpecialFrames` registration).
- The `WhatGroup:show` chat link → `WhatGroup:ShowFrame()` (re-opens, doesn't close).

## Why `GetGroupTypeLabel` and `PLAYSTYLE_LABELS` are duplicated

Both helpers exist in `WhatGroup.lua` (used by `ShowNotification`) and `WhatGroup_Frame.lua` (used by `PopulateFields`).

The duplication is intentional — keeping `WhatGroup_Frame.lua` independent of `WhatGroup.lua`'s internals lets the popup file load without taking a dependency on the addon's slash / dispatch / event-handler code paths during boot. The popup file does reach into `WhatGroup.pendingInfo` (read) and `WhatGroup:GetTeleportSpell()` (call), but it doesn't need anything from the chat-output code.

If the helpers ever need to diverge (e.g. the popup adopts an icon-based type indicator while the chat keeps text), the duplication makes that change one-sided and obvious. If they stay aligned forever, an extraction to a shared module would be a small refactor — but that's not load-bearing today.

## Frame dependencies

- **`WhatGroup` global** — read at file-load time to attach the `ShowFrame` method, and again at `PopulateFields` time for `WhatGroup.pendingInfo` and `WhatGroup:GetTeleportSpell`.
- **WoW API** — `CreateFrame`, `BackdropTemplate`, `UISpecialFrames`, `GameFontNormalLarge` / `GameFontNormal` / `GameFontHighlight`, `GameTooltip`, `C_Spell.GetSpellTexture`, `IsSpellKnown`, `CastSpellByID`.
- **No Ace3 dependencies.** The popup uses raw Blizzard `Frame` / `FontString` / `Texture` / `Button` — no AceGUI. (AceGUI is only used in the Settings panel.)
