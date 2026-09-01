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
-- The General page
-- ---------------------------------------------------------------------------
--
-- Hoisted to file scope rather than rebuilt per render: the library keeps its own one-shot
-- bookkeeping for both hooks (call-local sets, not the caller's tables), so a re-render gets the
-- inline button and the paired widget again instead of silently dropping them.

-- KEYED TO A TAB, not appended to the page. With the page tabbed (options-ui-§13), "after the
-- schema" is no longer "at the bottom of the page" -- RenderTabbedSchema fires this hook after the
-- last row of the NAMED group, so the Test button belongs to General and never appears under the
-- Chat or Popup rows.
local AFTER_GROUP = {
    -- Full-width action button, below the grid and on a fresh line.
    ["General"] = function(ctx)
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

local PAIR_WITH = {
    -- The session-only console checkbox, packed into the same two-column grid so it pairs with
    -- "Enable" instead of sitting on a line of its own. It was keyed to `notify.enabled` until the
    -- retabbing moved "Print to Chat" to the Chat tab; the console is a General affordance and
    -- following its old partner across would have put a debug control on the tab that decides what
    -- the chat line says. Deliberately NOT a schema row
    -- (WG-12 / debug-logging-§5) — it toggles ONLY the console window's visibility, never the debug
    -- logging flag and never db.profile, so nothing about it persists. SessionCheckbox is the
    -- library's maker for exactly that: a checkbox wired to caller-supplied get/set instead of a
    -- settings path, which still registers a refresher so an external Show/Hide re-syncs it.
    --
    -- The spec is DebugLog's own ConsoleCheckbox() data contract, so the label and the tooltip come
    -- from the module that owns the window rather than from a second description of it here.
    ["enabled"] = function(ctx, rowGroup)
        Helpers.SessionCheckbox(ctx, rowGroup, 0.5, NS.DebugLog:ConsoleCheckbox())
    end,
}

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
        -- declaration order -- General, Chat, Popup. The call is otherwise RenderSchema's: the
        -- afterGroup and pairWith hooks are the same two tables, passed through unchanged.
        --
        -- No page banner (options-ui-§14) and none is possible: WhatGroup has no per-window
        -- settings and no active-window state, so there is no instance for a banner to name.
        Helpers.RenderTabbedSchema(c, "general", AFTER_GROUP, PAIR_WITH)
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
