# WoW API quirks

The Blizzard-side gotchas WhatGroup specifically depends on, and the conventions that follow from them. If a future patch breaks the addon, this file is the first place to look.

## Hook discipline

| Target | Hook type | Why |
|---|---|---|
| `C_LFGList.ApplyToGroup` | direct `hooksecurefunc` (no AceHook) | Observation only. We need the `searchResultID` so we can call `C_LFGList.GetSearchResultInfo` for the same ID. AceHook's `SecureHook` would also work *behaviourally*, but its per-invocation bookkeeping closure leaves a taint trace that the GameMenu's Logout-button secure chain detects later, firing `ADDON_ACTION_FORBIDDEN ... 'callback()'` attributed to the addon. Direct `hooksecurefunc` registers the callback inside Blizzard's secure post-hook list with no addon-side wrapper, so no taint. |
| `SetItemRef` | `hooksecurefunc` (post-hook, filtered to our prefix) | Blizzard's default `SetItemRef` walks an `if/elseif` chain on `linkType` and silently returns for unknown prefixes — our `WhatGroup:show` link falls through with no error and no tooltip — so a post-hook is enough; we don't need to suppress the original. We previously used `RawHook` here, but `RawHook` replaces the global function with a non-secure wrapper, which leaves a taint trace that the GameMenu's Logout-button secure chain detects later, firing `ADDON_ACTION_FORBIDDEN ... 'callback()'`. `hooksecurefunc` doesn't replace the global, so no taint. |

The rule:

- **`SecureHook` / `hooksecurefunc` something whose original you want to keep running.** Examples: capturing data from a Blizzard call, reacting to a player action, telemetry, post-handling custom chat links whose prefix Blizzard's default no-ops on.
- **`RawHook` only when the original genuinely has visible side-effects you must suppress.** Replacing a global function with a non-secure wrapper leaves a taint trace that can surface much later in unrelated secure chains (the canonical symptom: `ADDON_ACTION_FORBIDDEN ... 'callback()'` on the GameMenu's Logout button after the player has touched the addon during the session). For most "intercept on a custom prefix" cases, `hooksecurefunc` is enough — Blizzard's default usually returns silently for unknown link types.
- **Never `SecureHook` something you wanted to suppress** — the original already ran by the time your hook fires.

## Settings API parent vs. subcategory

WoW 12.0's Settings API supports nested categories via:

```lua
local parent = Settings.RegisterCanvasLayoutCategory(parentPanel, "Ka0s WhatGroup")
Settings.RegisterAddOnCategory(parent)
local sub = Settings.RegisterCanvasLayoutSubcategory(parent, generalPanel, "General")
```

**Quirk: when a parent has subcategories, its own panel widgets are hidden.** The parent appears as a sidebar entry that expands to reveal subcategories — the parent's own panel content is not displayed.

Practical implication: don't put schema widgets on the parent panel. They won't render. Make the parent a thin landing page (just a title + a hint pointing at the subcategory) and put every actual setting on a subcategory.

WhatGroup follows this — see [settings-system.md](./settings-system.md#settingsregister) for the parent / General split.

## `Settings.OpenToCategory` requires the integer ID

```lua
Settings.OpenToCategory(self._settingsCategory:GetID())  -- correct
Settings.OpenToCategory("Ka0s WhatGroup > General")        -- WRONG (not a valid form)
Settings.OpenToCategory(self._settingsCategory)            -- WRONG (object, not ID)
```

`category:GetID()` returns the auto-assigned integer ID. **Do not overwrite `category.ID` with a string.** Doing so silently breaks the lookup and `OpenToCategory` becomes a no-op.

WhatGroup's `/wg config` calls `Settings.OpenToCategory(self._parentSettingsCategory:GetID())` against the **parent** and then reaches into `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` — the path the expand-arrow click handler itself uses — so the subcategory tree comes up unfolded. That whole traversal is wrapped in `pcall` because `CategoryList` / `GetCategoryEntry` / the `CategoryEntry:SetExpanded` shape are private Blizzard internals that can shift between patches; if any link goes missing the panel still opens, just without auto-unfold. The slash command also refuses to open during `InCombatLockdown()` — the Settings UI uses secure templates and opening it mid-combat can taint other addons' secure handlers.

## Lazy AceGUI panel build

Pure AceGUI containers manage their own width via `SetWidth` / `SetRelativeWidth` / `SetFullWidth`. But **AceGUI containers parented to a Blizzard Settings frame don't get a width until Blizzard sizes the panel on first show** — and even then the size doesn't propagate into AceGUI's layout pipeline automatically.

Two consequences:

1. Build the body **lazily** in the panel's `OnShow`, behind a `built` one-shot guard. If you build at registration time, the panel renders against width 0 and every relative-width widget collapses.
2. Hook `OnSizeChanged` on the AceGUI container's frame and forward the dimensions into AceGUI:

```lua
container.frame:SetScript("OnSizeChanged", function(_, w, h)
    if container.OnWidthSet  then container:OnWidthSet(w)  end
    if container.OnHeightSet then container:OnHeightSet(h) end
    if container.DoLayout    then container:DoLayout()     end
end)
```

Without this, widgets inside the AceGUI container stay at width 0 even after Blizzard sets a width on the outer panel.

WhatGroup's General subcategory uses both — see [settings-system.md](./settings-system.md#lazy-panel-build) for the full snippet.

## Lowercase only the slash command name

`AceConsole-3.0:RegisterChatCommand` passes the raw input (everything after the slash command name) to the handler. **Don't lowercase the whole input** — schema paths like `notify.showInstance` are camelCase and lowercasing them breaks `Helpers.FindSchema(path)`.

The pattern:

```lua
local cmd, rest = raw:match("^(%S+)%s*(.*)$")
cmd  = (cmd or ""):lower()   -- only lowercase the verb
rest = rest or ""              -- preserve case in everything else
```

See [slash-dispatch.md](./slash-dispatch.md#case-preserving-parse).

## `RawHook` short-circuit pattern (and why we avoid it for `SetItemRef`)

When you `RawHook` something to short-circuit on a prefix, the chain-through call goes through `self.hooks`:

```lua
function WhatGroup:OnSetItemRef(linkArg, text, button, ...)
    if linkArg and linkArg:match("^WhatGroup:") then
        self:ShowFrame()
        return                                       -- short-circuit
    end
    return self.hooks.SetItemRef(linkArg, text, button, ...)   -- pass through
end
```

`self.hooks.<originalName>` is AceHook's stash of the pre-hook function. Forgetting to chain through means every other addon's chat links stop working — a very obvious regression in chat scrollback. Always chain through on the fall-through branch.

**WhatGroup no longer uses this pattern for `SetItemRef`.** `RawHook` replaces the global function with a non-secure wrapper, and that replacement leaves a taint trace that the GameMenu's Logout-button secure-execute chain detects later, firing `ADDON_ACTION_FORBIDDEN ... 'callback()'` attributed to the addon. Because Blizzard's default `SetItemRef` no-ops on unknown link types (it walks an `if/elseif` chain on `linkType` and falls through), a `hooksecurefunc` post-hook gives the same user-visible behaviour without the global-function takeover. The pattern above is documented here for reference — only reach for `RawHook` when the original genuinely has a side-effect you must suppress and a benign prefix isn't possible.

## AceDB `true` for shared profile

```lua
self.db = LibStub("AceDB-3.0"):New("WhatGroupDB", defaults, true)
```

The third arg `true` means "use a single shared `Default` profile across every character on the account". Every character sees the same settings.

If WhatGroup ever needs per-character settings, that arg becomes `false` (or omitted) and AceDB creates a per-character profile by default. The current design is intentionally account-wide — see [scope.md](./scope.md#out-of-scope).

## `BuildDefaults` runs every login

```lua
local defaults = self.Settings.BuildDefaults()
self.db = LibStub("AceDB-3.0"):New("WhatGroupDB", defaults, true)
```

`BuildDefaults` walks the schema and returns a fresh nested defaults table. AceDB merges saved values over the defaults rather than replacing — so:

- **A new schema row appears with its `default` value** the first time the user logs in after the upgrade.
- **Existing keys are preserved untouched.**
- **Removed schema rows leave orphaned values in SVs.** The keys aren't surfaced in the UI / `/wg list` anymore but they sit in the saved-vars table. AceDB-3.0 has no automatic cleanup. Acceptable today; add a one-shot migration if a removal ever becomes user-visible.

## Secure buttons can't have an explicit non-secure anchor target

A `SecureActionButtonTemplate` Button (or any frame inheriting from `SecureFrameTemplate`) is "protected" the moment it's `CreateFrame`'d. Retail's secure-frame system rejects any `SetPoint` / `SetAllPoints` call on a protected frame that **explicitly names** a non-secure region as the anchor target — including the protected frame's own parent — with:

```
Action[SetPoint] failed because[Cannot anchor protected frames to regions]
```

This isn't combat-gated; it errors during initial layout. Once the load-time `SetPoint` errors, the rest of the source file aborts — anything defined after that line (including `WhatGroup:ShowFrame`) never registers, which surfaces as "attempt to call a nil value" at the next call site.

The protection check gates on the *explicit-region mention*, not on the underlying parent relationship. So the **implicit-parent form** (no `relativeTo` arg) is allowed:

```lua
-- These FAIL ("Cannot anchor protected frames to regions"):
secureBtn:SetAllPoints(parent)
secureBtn:SetPoint("LEFT", someFrame, "LEFT", x, y)

-- These WORK (no explicit relativeTo arg → resolved to parent transitively):
secureBtn:SetPoint("TOPLEFT", 0, 0)
secureBtn:SetPoint("BOTTOMRIGHT", 0, 0)
secureBtn:SetAllPoints()
```

**Workaround for popup-style usage**: parent the secure button **directly to the popup frame** (the same Frame that owns the row labels), and use the implicit-parent `SetPoint("LEFT", xOff, yOff)` form to position it. The protection check passes; visibility rides on the parent-child relationship (the popup's `Show()` / `Hide()` automatically propagate to the button); dragging the popup moves the button with it. No proxy frame, no UIParent parent, no screen-position sync, no combat handler.

## Lazy popup, secure button, and Settings registration

**Anything you do at PLAYER_LOGIN that touches Blizzard's secure surface taints Blizzard's GameMenu callbacks.** That taint surfaces as `ADDON_ACTION_FORBIDDEN ... 'callback()'` when the player clicks the GameMenu's Logout button — even on a fresh `/reload` with no addon use. The protected operation that fails is `Logout()`, but the error is attributed to whichever addon left the taint trace. The mechanism: Blizzard's `GameMenuFrame:InitButtons()` builds the Logout / Settings / Macros button-callback closures during boot. If any addon-driven mutation of secure state has happened before that runs, the closures inherit the addon's taint and refuse to invoke `Logout()` (or any other protected button action) when the user clicks them.

In WhatGroup's case, three boot-time operations were demonstrated to taint:

1. **Creating a `SecureActionButtonTemplate` Button** (the popup's teleport icon).
2. **`tinsert(UISpecialFrames, "WhatGroupFrame")`** — adding a frame name to UISpecialFrames so ESC closes it.
3. **`Settings.RegisterCanvasLayoutCategory(panel, name)` + `Settings.RegisterAddOnCategory(category)`** — registering with the modern Settings API.

The fix is the same pattern for all three: **defer everything to actual user demand**.

- `WhatGroup_Frame.lua`'s entire setup (popup creation, secure button creation, `UISpecialFrames` registration) is wrapped in a `buildFrame()` function that's called only on the first `WhatGroup:ShowFrame()` call.
- `Settings.Register()` is called only from `runConfig` (the `/wg config` slash handler) on first invocation. The addon doesn't appear in the Settings → AddOns list until the user has run `/wg config` once per session — minor UX trade-off for a clean GameMenu.

At PLAYER_LOGIN the addon now adds nothing to Blizzard's secure surface, GameMenu's `InitButtons` runs in a clean context during boot, and Logout works correctly. Any taint the addon does generate later (on first popup show, or first `/wg config`) is contained to a session where the player has actively used the addon — and even then, GameMenu's button closures were already built with the clean context they captured at boot.

The regression test for this lives in [smoke-tests.md → §1.3 GameMenu Logout — no taint regression](./smoke-tests.md#13-gamemenu-logout--no-taint-regression-critical). Run it after any change that touches hooks, the popup, the Settings panel, or the StaticPopup table.

See `WhatGroup_Frame.lua`'s `buildFrame()`, `WhatGroup_Settings.lua`'s `Settings.Register()`, and `WhatGroup.lua`'s `runConfig()`.

WhatGroup uses this pattern for the popup's teleport icon — see `WhatGroup_Frame.lua` and [frame.md → Teleport button](./frame.md#teleport-button).

> **Earlier iterations got this wrong.** A previous attempt parented the secure button to `UIParent` and synced its screen position from a non-secure proxy frame (`teleportSlot`) via a `syncTeleportButton` function, plus a `PLAYER_REGEN_ENABLED` retry, plus a deferred-Hide on the popup's `OnHide`. That pattern *worked* in the sense that the icon appeared in the right place — but the addon-driven `Show()` / `Hide()` / `SetPoint(... UIParent ...)` calls on a `SecureActionButtonTemplate` parented to `UIParent` accumulated taint that surfaced later as `ADDON_ACTION_FORBIDDEN ... 'callback()'` when the player clicked the GameMenu's Logout button (the Logout closure's `callback()` runs inside Blizzard's secure-execute chain at `Blizzard_GameMenu/Shared/GameMenuFrame.lua:69`, which detects the addon's prior taint of the secure system and refuses to run `Logout()`). Parenting to the popup frame directly eliminates all of those non-secure operations on the protected button — the only non-secure interaction left is `SetAttribute` calls in `ConfigureTeleportButton`, which is the standard pattern Blizzard expects.

Side note: `CastSpellByID` is also protected in retail (it fires `ADDON_ACTION_FORBIDDEN` from a non-secure `OnClick`). The macro-attribute path on a `SecureActionButtonTemplate` is the legal cast route from addon code — set `type="macro"` and `macrotext="/cast <SpellName>"`, and the click runs through Blizzard's secure action handler.

## Spell texture fallback (`134400`)

`C_Spell.GetSpellTexture(spellID)` returns `nil` for spell IDs that aren't currently loaded into the client's spell database (e.g. teleport spells the player has never trained). The popup's `ConfigureTeleportButton` falls back to `134400` (the `?` glyph fileID) so the row still shows *something*:

```lua
local texID = C_Spell.GetSpellTexture(spellID) or 134400
```

`134400` is widely used as a "dynamic / unknown spell" sentinel across Blizzard's UI. Not load-bearing — any other placeholder fileID would work — but it's the convention.

## Pattern reference

Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD`) is the source pattern for WhatGroup's slash dispatch and schema-driven settings rendering. The shape here is a scaled-down version of `KickCD/core/KickCD.lua` (slash dispatch) and `KickCD/settings/Panel.lua` (helpers + builder). When in doubt about how to extend a system here, check how the equivalent system is shaped over there.

The differences (smaller surface area in WhatGroup):

- No `valueGate` on schema rows (rows enabling/disabling on another value).
- One schema panel, not many. WhatGroup passes `panelKey = "main"` / `"general"` to `CreatePanel` for ctx tracking, but `RenderSchema` doesn't filter the schema by `panelKey` — every row renders into the General sub-page.
- `afterGroup` callbacks render non-setting actions (Test) outside the schema, but the schema rows themselves stay simpler than KickCD's (no module-specific post-render hooks).
- No vertical layout — every WhatGroup widget pairs into the two-column Flow grid.
