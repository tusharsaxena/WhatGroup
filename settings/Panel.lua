-- settings/Panel.lua
-- The two halves of the settings surface that are genuinely this addon's: the landing page's body,
-- the one action button the flow engine cannot express, and the General page's registration.
--
-- Everything else — the canvas factory, the unified header and breadcrumb, the lazy Defaults
-- button, the always-shown scrollbar, the AceGUI ScrollFrame, the tooltip helper, the section
-- heading, the checkbox and slider makers, the two-column flow engine, the page registry, the
-- panel-open combat gate and the refresh fan-out — is LibKa0s-Options-1.0's, wired up in
-- settings/OptionsSetup.lua, which loads immediately before this file.
--
-- Loads after settings/Schema.lua and settings/OptionsSetup.lua, and takes the instance as a
-- file-scope upvalue (options-ui-§1).

local addonName, NS = ...
local WhatGroup = NS.addon

local Settings = WhatGroup.Settings
local Helpers  = Settings.Helpers
-- Default VALUES, so the composed Master controls block stores this addon's numbers rather than
-- the library's (defaults/Profile.lua is still the one place any of them is written down).
local C        = NS.C

-- Chat-out via WhatGroup._print so the cyan [WG] prefix lives in one place (mirrors
-- settings/Schema.lua's pout).
local function pout(...)
    if WhatGroup._print then return WhatGroup._print(...) end
    print(...)
end

-- ---------------------------------------------------------------------------
-- Inline action button — host-owned, and why
-- ---------------------------------------------------------------------------
--
-- The library's InlineButtonPair lays TWO buttons across one Flow row at BUTTON_PAIR_REL (0.492)
-- each. This addon has exactly one such button — "Test", under the General group — and it is a
-- fixed 160px left-aligned control, which that maker cannot express: passing a single spec renders
-- it at half the panel width. Declining is the smaller change (issue #9,
-- LIBKA0S-09 (issue #9)); converging would be a visible resize of the only button on the page.
--
-- It reads every layout value and every helper off the library instance rather than restating one
-- (options-ui-§8): a host copy of a library constant is the copy that goes stale.
function Helpers.InlineButton(ctx, spec)
    local AceGUI = Helpers.AceGUI
    local scroll = Helpers.EnsureScroll(ctx)
    if not (AceGUI and scroll) then return end

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(28)

    local btn = AceGUI:Create("Button")
    btn:SetText(spec.text or "")
    btn:SetWidth(spec.width or 160)
    btn:SetCallback("OnClick", function()
        if not spec.onClick then return end
        -- pcall'd and REPORTED, for the reason the library's own maker gives: a raise here would
        -- propagate into AceGUI's dispatch and take the click handling of every widget on the frame
        -- down with it.
        local ok, err = pcall(spec.onClick)
        if not ok then pout("button onClick failed: " .. tostring(err)) end
    end)
    row:AddChild(btn)

    Helpers.AttachTooltip(btn, spec.text, spec.tooltip)
    scroll:AddChild(row)
    Helpers.AddSpacer(scroll, Helpers.ROW_VSPACER)
    return btn
end

-- ---------------------------------------------------------------------------
-- Parent (landing) page content
-- ---------------------------------------------------------------------------
--
-- Logo + TOC notes one-liner + Slash Commands heading + per-command Labels, all rendered as AceGUI
-- widgets inside the library's lazy ScrollFrame. The library owns WHEN this draws (first OnShow,
-- against a container that has a width by then); what it draws is the host's half by design
-- (options-ui-§5), because the logo and the command list are the two things about a Ka0s panel that
-- are genuinely per-addon.

-- WG-21 (Blizzard-default-only — accepted deviation): the settings landing page shows the addon's
-- own brand logo, a vendored TGA under media/logos/. It's the only non-Blizzard default texture in
-- the addon — every other texture/border is Blizzard-shipped (WHITE8X8, the
-- Options_HorizontalDivider atlas, spell icons). Branding art, analogous to the TOC IconTexture; no
-- Blizzard asset could substitute. options-ui-§5 mandates a logo here, so this is a deviation from
-- the addon's own Blizzard-default-only baseline, not from the standard.
local MAIN_LOGO_TEXTURE   = "Interface\\AddOns\\WhatGroup\\media\\logos\\whatgroup.logo.tga"
-- The landing page's own constants (options-ui-§8 lists these as the host's, because the body is).
local MAIN_LOGO_SIZE      = 300
local MAIN_GAP_AFTER_LOGO = 8
local MAIN_GAP_AFTER_DESC = 12
local MAIN_GAP_BELOW_HEAD = 6

-- Left-justify a text widget's own FontString. The notes line and every command row share this;
-- it used to be written out twice, once at each call site, and the guard is carried over from
-- them verbatim.
--
-- The guard is defensive, NOT load-order-sensitive: AceGUI's Label creates its `.label`
-- FontString in the constructor (libs/AceGUI-3.0/widgets/AceGUIWidget-Label.lua), so for the
-- Labels this page makes, both halves are always true. It stays because `.label` is a
-- per-widget-type field rather than part of the AceGUI widget contract — hand this a widget type
-- that has no text FontString and it must skip, not raise.
local function justifyLeft(widget)
    local fs = widget.label
    if fs and fs.SetJustifyH then
        fs:SetJustifyH("LEFT")
    end
end

-- Logo. SimpleGroup is a full-width child so AceGUI's List layout gives it the scroll's full
-- width; the texture inside is anchored TOPLEFT at the source TGA's native dimensions, so it
-- renders pixel-exact and left-aligned regardless of panel width.
local function addLogo(AceGUI, scroll)
    local logoGroup = AceGUI:Create("SimpleGroup")
    logoGroup:SetLayout(nil)
    logoGroup:SetFullWidth(true)
    logoGroup:SetHeight(MAIN_LOGO_SIZE)

    local logoTex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
    logoTex:SetTexture(MAIN_LOGO_TEXTURE)
    logoTex:SetSize(MAIN_LOGO_SIZE, MAIN_LOGO_SIZE)
    logoTex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
    scroll:AddChild(logoGroup)

    Helpers.AddSpacer(scroll, MAIN_GAP_AFTER_LOGO)
end

-- TOC Notes one-liner — full-width Label, left-justified.
local function addNotesLine(AceGUI, scroll)
    local notes = NS.Meta("Notes") or ""

    local desc = AceGUI:Create("Label")
    desc:SetFullWidth(true)
    desc:SetText(notes)
    if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
        desc.label:SetFontObject(_G.GameFontHighlight)
    end
    justifyLeft(desc)
    scroll:AddChild(desc)

    Helpers.AddSpacer(scroll, MAIN_GAP_AFTER_DESC)
end

-- One Label per command, rendered through LibKa0s-Slash-1.0's ONE command-row formatter
-- (convergence #2). This page used to carry a second formatter for the same data — double
-- spaces around the em dash, the dash explicitly white-wrapped and the description bare —
-- which is exactly the silent drift between a panel and its chat help that a shared renderer
-- exists to end. Un-indented, because a landing-page row is its own label; the chat form
-- (Sl:HelpRows) is the same rows with a two-space indent.
--
-- Still generated from WhatGroup.COMMANDS, so the list stays in lockstep with `/wg help`:
-- LandingRows walks the same table this page used to walk directly.
local function addCommandRows(AceGUI, scroll)
    local Sl = NS.SlashCommands
    for _, line in ipairs(Sl and Sl:LandingRows() or {}) do
        local row = AceGUI:Create("Label")
        row:SetFullWidth(true)
        row:SetText(line)
        justifyLeft(row)
        scroll:AddChild(row)
    end
end

function Helpers.BuildMainContent(ctx)
    local AceGUI = Helpers.AceGUI
    local scroll = Helpers.EnsureScroll(ctx)
    if not (AceGUI and scroll) then return end
    -- Re-rendered pages must not stack: the library re-runs a renderer when a hidden page is
    -- marked dirty and shown again. This has to happen before any widget is created below.
    Helpers.ClearScroll(ctx)
    scroll = Helpers.EnsureScroll(ctx)

    addLogo(AceGUI, scroll)
    addNotesLine(AceGUI, scroll)
    -- "Slash Commands" heading — the library's own Section, so it is the same AceGUI Heading (and
    -- the same font bump and spacers) every sub-page's section headers use. It takes `ctx`, not
    -- `scroll`, so it stays here where the page's outline reads. Routed through NS.L because it is
    -- pure chrome the addon authors — it carries no structural role, unlike "General", which is
    -- simultaneously this page's id, its schema `group` key and its subcategory label.
    Helpers.Section(ctx, NS.L["Slash Commands"])
    Helpers.AddSpacer(scroll, MAIN_GAP_BELOW_HEAD)
    addCommandRows(AceGUI, scroll)
end

-- ---------------------------------------------------------------------------
-- The Master controls tab (options-ui-§15)
-- ---------------------------------------------------------------------------
--
-- COMPOSED, NOT WRITTEN. `Helpers.MasterControls` emits the canonical eight-control block — enable,
-- general visibility, master scale, master alpha, lock frame, debug console, and the closing reset
-- pair — from this one declaration, so the tab every player looks at first is the same tab in all
-- nine addons and no addon can drift by editing a row. Composed HERE rather than in
-- settings/Schema.lua because the composer is a member of the LibKa0s instance, and the instance
-- does not exist until settings/OptionsSetup.lua has run — which is the file immediately before
-- this one in the TOC.
--
-- WhatGroup is NOT frameless: modules/Frame.lua's popup is SetMovable(true) and drag-persisted
-- (WG-26), so all four frame rows apply and all four are wired there.
--
-- `defaults` is passed for every leaf so the composer stores THIS addon's values, and
-- `debugConsolePath` is the collection's verbatim `state.debugConsole` — a path
-- settings/Schema.lua's SESSION table intercepts in front of db.profile, which is what keeps the
-- console session-only now that it is a schema row (WG-12).
local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{
    prefix           = "",
    page             = "general",
    addonName        = "WhatGroup",
    debugConsolePath = "state.debugConsole",
    defaults         = {
        enabled      = C.enabled,
        visibility   = C.visibility,
        scale        = C.scale,
        alpha        = C.alpha,
        locked       = C.locked,
        -- The console starts closed at every login, and `/wg resetall` closes it again
        -- (options-ui-§12 sweeps the session-only rows a profile reset cannot reach).
        debugConsole = false,
    },
    onResetPosition  = function() WhatGroup:ResetFramePosition() end,
    -- The SAME body the header Defaults button parks below, and the same one `/wg resetall`
    -- reaches: options-ui-§12 puts all three behind one implementation, and this addon's is
    -- confirmation-gated because the act is irreversible.
    onResetAll       = function()
        Settings.EnsureResetPopup()
        StaticPopup_Show("WHATGROUP_RESET_ALL")
    end,
}

-- What the composer does not emit, because it cannot know it: `/wg list`'s grouping key, and the
-- side effects three of these rows have on a frame the library has never seen. Stamped onto the
-- composed rows by path rather than declared beside them, so the block above stays one call and
-- the canonical row set stays the library's to change.
--
-- Every one of these is a MOVE or a first wiring, never a second control: `enabled`'s onChange is
-- the off-flip wipe that used to sit on the row in settings/Schema.lua, and the other three are
-- the settings modules/Frame.lua grew for this pass.
local MASTER_HOOKS = {
    -- Off-flip wipes any in-flight capture so a pre-toggle apply can't still surface a
    -- notify/popup after the user has explicitly disabled the addon. WipeCapture also CancelTimers
    -- any notify callback already scheduled (AceTimer, self.notifyTimer). The reason argument is
    -- what makes it a material-effect log (debug-logging-§10): the [Set] line already shows
    -- `enabled = false`, and WipeCapture logs only when there was something to drop.
    enabled    = function(v) if not v then WhatGroup:WipeCapture("addon disabled") end end,
    -- A popup already on screen when the gate closes has to go, or the setting reads as ignored
    -- until the next open.
    visibility = function() WhatGroup:ApplyFrameVisibility() end,
    scale      = function() WhatGroup:ApplyFrameScale() end,
    alpha      = function() WhatGroup:ApplyFrameAlpha() end,
}

for _, row in ipairs(MASTER_ROWS) do
    -- One section for the whole block: `/wg list` groups by section, and these eight are one
    -- subject however they are stored.
    row.section  = "general"
    row.onChange = MASTER_HOOKS[row.path]
end

-- HEAD OF THE ARRAY, because RenderTabbedSchema partitions by `group` in DECLARATION order and
-- options-ui-§15 requires this tab to be the FIRST one. Spliced rather than declared in
-- settings/Schema.lua for the load-order reason above; the rows are ordinary schema rows from the
-- moment they land here.
for i = #MASTER_ROWS, 1, -1 do
    table.insert(Settings.Schema, 1, MASTER_ROWS[i])
end

-- ---------------------------------------------------------------------------
-- The General page
-- ---------------------------------------------------------------------------
--
-- Hoisted to file scope rather than rebuilt per render: the library keeps its own one-shot
-- bookkeeping for the hook (a call-local set, not the caller's table), so a re-render gets the
-- inline button again instead of silently dropping it.

-- KEYED TO A TAB, not appended to the page. With the page tabbed (options-ui-§13), "after the
-- schema" is no longer "at the bottom of the page" -- RenderTabbedSchema fires this hook after the
-- last row of the NAMED group, so each button belongs to one tab and never appears under another
-- tab's rows.
--
-- The Test button follows the tab its group ended up on. It was keyed to "General", and General is
-- the Master controls tab now: `enabled` became one of options-ui-§15's canonical eight and
-- `notify.delay` moved to Chat, which is where this button's own tooltip already said it belonged
-- -- previewing the chat-output toggles. It is NOT folded into the Master controls button pair: a
-- 160px left-aligned action is not one of that block's two resets.
local AFTER_GROUP = {
    ["Master controls"] = MASTER_TAIL,
    -- Full-width action button, below the grid and on a fresh line.
    ["Chat"] = function(ctx)
        Helpers.InlineButton(ctx, {
            text    = "Test",
            tooltip = "Inject synthetic group info and run the full notification + popup flow. "
                   .. "Useful for previewing changes to the chat-output toggles without joining a "
                   .. "real group.",
            onClick = function()
                if WhatGroup.RunTest then WhatGroup:RunTest() end
            end,
        })
    end,
}

-- NO `pairWith` TABLE ANY MORE. It carried exactly one entry — a bespoke SessionCheckbox drawing
-- the debug console beside "Enable" — and options-ui-§15 makes that console a canonical row of the
-- Master controls block instead. The console itself is untouched: same window, same
-- NS.DebugLog:ConsoleCheckbox() get/set, reached now through settings/Schema.lua's SESSION table
-- rather than through a hook. Two controls over one thing is what this pass exists to remove.

local function buildGeneralPage(parentCategory)
    local ctx = Helpers.CreatePanel("WhatGroupGeneralPanel", "General", {
        pageKey         = "general",
        defaultsButton  = true,
        defaultsTooltip = "Reset every WhatGroup setting to its default. Asks for confirmation.",
    })

    -- Parked, not wired: the button itself does not exist until the panel's first OnShow. The
    -- library's CreatePanel also forwards Blizzard's own footer Defaults control here, so the two
    -- controls are one implementation (options-ui-§1).
    ctx.panel.defaultsOnClick = function()
        Settings.EnsureResetPopup()
        StaticPopup_Show("WHATGROUP_RESET_ALL")
    end

    Helpers.SetRenderer(ctx, function(c)
        Helpers.ClearScroll(c)
        -- TABBED (options-ui-§13): one tab per distinct `group` in settings/Schema.lua, in
        -- declaration order -- Master controls, Chat, Popup. The call is otherwise RenderSchema's:
        -- the afterGroup table is passed through unchanged, and there is no pairWith left to pass.
        --
        -- No page banner (options-ui-§14) and none is possible: WhatGroup has no per-window
        -- settings and no active-window state, so there is no instance for a banner to name.
        Helpers.RenderTabbedSchema(c, "general", AFTER_GROUP)
    end)

    local sub = _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, "General")
    WhatGroup._settingsCategory = sub
    -- The parent handle, for anything that wants to reason about the tree. The panel-OPEN path goes
    -- through Helpers.OpenOptionsPanel, which holds its own.
    WhatGroup._parentSettingsCategory = parentCategory
    return sub
end

Helpers.RegisterOptionsPage("general", "General", buildGeneralPage)

-- ---------------------------------------------------------------------------
-- Public registration
-- ---------------------------------------------------------------------------
--
-- Called from `OnEnable` (PLAYER_LOGIN) so the panel is in the Settings → AddOns list at login, and
-- again as an idempotent no-op from `runConfig`. Registering a canvas category at login is
-- taint-safe — WhatGroup's real GameMenu-taint sources (the secure teleport button + the
-- UISpecialFrames insert) stay deferred in modules/Frame.lua. See docs/midnight-quirks.md → "Lazy popup
-- and secure button" for the taint reasoning, and anti-patterns #22 for why deferring the CATEGORY
-- behind `/wg config` is the wrong fix.
--
-- Deliberately NOT combat-gated (options-ui-§9): registration never taints, and eager registration
-- at load is a MUST. Only panel *open* is combat-gated, and that gate lives inside the library's
-- `OpenOptionsPanel` so every caller inherits it. A guard here only meant that a `/reload` taken in
-- combat left WhatGroup missing from the Settings → AddOns list until the next login.

function Settings.Register()
    if WhatGroup._settingsRegistered or not _G.Settings
       or not _G.Settings.RegisterCanvasLayoutCategory
       or not _G.Settings.RegisterCanvasLayoutSubcategory then
        return
    end

    -- Resolves AceGUI, runs the schema validation, registers the main canvas with its landing-page
    -- renderer, then runs every registered page builder. Idempotent in its own right; the flag
    -- below makes the second (`runConfig`) call a cheap no-op.
    Helpers.CreateOptionsPanel()

    WhatGroup._settingsRegistered = true
end
