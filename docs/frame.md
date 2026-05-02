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
| 5 | `Playstyle:` | `PLAYSTYLE_LABELS[info.playstyle]` (fallback dim em-dash) |
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
- **`PLAYSTYLE_LABELS[info.playstyle] == nil` (or `""`)** — Playstyle row falls back to a dim em-dash.

## Teleport button

`ConfigureTeleportButton(btn, icon, info)`:

1. `WhatGroup:GetTeleportSpell(info.activityID, info.mapID)` — returns a spell ID or nil.
2. If nil, the button hides and the function returns.
3. Otherwise the icon texture is set from `C_Spell.GetSpellTexture(spellID)` (with `134400` as a fallback texID — the `?` glyph).
4. `IsSpellKnown(spellID)`:
   - **known**: full alpha, `EnableMouse(true)`, `OnClick` casts the spell, `OnEnter` shows `GameTooltip:SetSpellByID(spellID)`.
   - **not known**: 50% alpha, desaturated icon, `EnableMouse(false)`, no scripts wired up.

The label `Teleport:` is built directly inline (not via `MakeLabel`) because it anchors to a button rather than a FontString, and its value side is the button's `LEFT` attached at `LABEL_WIDTH + 6`.

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
