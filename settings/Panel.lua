-- settings/Panel.lua
-- Blizzard canvas-layout settings panel: landing page + General sub-page.
--
-- Renders the schema (settings/Schema.lua) into AceGUI widgets inside a lazy
-- ScrollFrame. Panel layout follows Ka0s KickCD:
--   * Parent "Ka0s WhatGroup" — canvas-layout category with an addon-landing
--     page (logo + notes + slash command list).
--   * Sub-page "General" — schema widgets in a two-column Flow layout, wrapped
--     in an always-visible ScrollFrame. Header carries a breadcrumb title,
--     divider, and a Defaults button.
--   * Non-setting actions (e.g. "Test") render via afterGroup callbacks using
--     Helpers.InlineButton, so the schema stays settings-only.
--
-- Loads after settings/Schema.lua, which initialises Settings.Schema /
-- Settings.Helpers on the shared table this file reads.

local addonName, NS = ...
local WhatGroup = NS.addon
local AceGUI    = LibStub("AceGUI-3.0")

local Settings = WhatGroup.Settings
local Schema   = Settings.Schema
local Helpers  = Settings.Helpers

-- Chat-out via WhatGroup._print so the cyan [WG] prefix lives in one place
-- (mirrors settings/Schema.lua's pout).
local function pout(...)
    if WhatGroup._print then return WhatGroup._print(...) end
    print(...)
end

-- ---------------------------------------------------------------------------
-- Layout constants
-- ---------------------------------------------------------------------------

local PADDING_X     = 16
local HEADER_TOP    = 20
local HEADER_HEIGHT = 54
local DEFAULTS_W    = 110

local SECTION_TOP_SPACER    = 10
local SECTION_BOTTOM_SPACER = 6
local SECTION_HEADING_H     = 26
local ROW_VSPACER           = 8

-- ---------------------------------------------------------------------------
-- Tooltip helper — works on AceGUI widgets (via SetCallback) and plain
-- Blizzard frames (via HookScript). Anchors on widget.frame when the
-- target is an AceGUI widget.
-- ---------------------------------------------------------------------------

local function attachTooltip(widget, label, tooltip)
    if not widget then return end
    if not (tooltip and tooltip ~= "") and not (label and label ~= "") then return end
    local anchor = widget.frame or widget
    if not anchor then return end

    local function show()
        if not GameTooltip then return end
        GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
        if label and label ~= "" then
            GameTooltip:SetText(label, 1, 1, 1)
        end
        if tooltip and tooltip ~= "" then
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end
    local function hide() if GameTooltip then GameTooltip:Hide() end end

    if widget.SetCallback then
        widget:SetCallback("OnEnter", show)
        widget:SetCallback("OnLeave", hide)
    elseif widget.HookScript then
        widget:HookScript("OnEnter", show)
        widget:HookScript("OnLeave", hide)
    end
end

-- ---------------------------------------------------------------------------
-- Header (title + Defaults button + divider)
-- ---------------------------------------------------------------------------

local function buildHeader(panel, title, opts)
    -- Sub-pages render with an "Ka0s WhatGroup ▸ <Page>" breadcrumb. The
    -- separator is an inline atlas (not a glyph) so it renders the same
    -- regardless of the active FontString font / locale fallback. The
    -- parent/main page opts in to the unprefixed form via opts.isMain
    -- (otherwise it would read "Ka0s WhatGroup ▸ Ka0s WhatGroup"). The
    -- Blizzard tree label is driven by panel.name in CreatePanel and
    -- stays unprefixed so subpages indent cleanly under the parent.
    local displayTitle = title
    if not opts.isMain then
        local sep = " |A:common-icon-forwardarrow:16:16|a "
        displayTitle = "Ka0s WhatGroup" .. sep .. title
    end

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING_X, -HEADER_TOP)
    titleFS:SetText(displayTitle)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PADDING_X, -HEADER_HEIGHT)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_HEIGHT)
    -- Tint to match the title font (Blizzard NORMAL_FONT_COLOR yellow on
    -- GameFontNormalHuge). Reading from the title rather than hardcoding
    -- the gold tracks any future theme retune.
    divider:SetVertexColor(titleFS:GetTextColor())

    local defaultsBtn
    if opts.defaultsButton then
        defaultsBtn = AceGUI:Create("Button")
        defaultsBtn:SetText("Defaults")
        defaultsBtn:SetWidth(DEFAULTS_W)
        defaultsBtn.frame:SetParent(panel)
        defaultsBtn.frame:ClearAllPoints()
        defaultsBtn.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT",
                                   -PADDING_X, -HEADER_TOP)
        defaultsBtn.frame:Show()
        attachTooltip(defaultsBtn, "Defaults", opts.defaultsTooltip)
    end

    return titleFS, divider, defaultsBtn
end

-- ---------------------------------------------------------------------------
-- CreatePanel — Frame compatible with RegisterCanvasLayout(Sub)category.
-- Returns a `ctx` table the caller threads through ensureScroll /
-- Section / RenderField / RenderSchema / InlineButton.
-- ---------------------------------------------------------------------------

function Helpers.CreatePanel(name, title, opts)
    opts = opts or {}

    local panel = CreateFrame("Frame", name, UIParent)
    panel.name = title
    panel:Hide()

    local titleFS, divider, defaultsBtn = buildHeader(panel, title, opts)
    panel.title       = titleFS
    panel.divider     = divider
    panel.defaultsBtn = defaultsBtn

    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, -(HEADER_HEIGHT + 8))
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.body = body

    local ctx = {
        panel       = panel,
        body        = body,
        scroll      = nil,
        refreshers  = {},
        lastGroup   = nil,
        panelKey    = opts.panelKey,
    }
    Settings._panels[#Settings._panels + 1] = ctx
    return ctx
end

-- ---------------------------------------------------------------------------
-- Always-visible scrollbar patch (ported from KickCD/settings/Panel.lua)
-- ---------------------------------------------------------------------------
--
-- AceGUI's stock ScrollFrame.FixScroll auto-hides the scrollbar when the
-- content fits inside the viewport. The General page is short and would
-- normally render without a scrollbar, while a future longer page would
-- show one — visually asymmetric. This helper keeps the scrollbar (and
-- its 20 px right gutter) visible at all times, parking the thumb at
-- the top and greying it out when there's nothing to scroll.
--
-- Stock FixScroll + OnRelease are restored on widget release so the
-- shared AceGUI pool returns to a clean state for the next acquirer.

function Helpers.PatchAlwaysShowScrollbar(scroll)
    if not scroll or scroll._wgAlwaysScrollbar then return end
    scroll._wgAlwaysScrollbar = true

    local origFixScroll  = scroll.FixScroll
    local origMoveScroll = scroll.MoveScroll
    local origOnRelease  = scroll.OnRelease

    local scrollbar = scroll.scrollbar
    local thumb     = scrollbar and scrollbar.GetThumbTexture and scrollbar:GetThumbTexture() or nil
    local sbName    = scrollbar and scrollbar.GetName and scrollbar:GetName() or nil
    local upBtn     = sbName and _G[sbName .. "ScrollUpButton"]   or nil
    local downBtn   = sbName and _G[sbName .. "ScrollDownButton"] or nil

    local currentEnabled

    local function setEnabled(want)
        if currentEnabled == want then return end
        currentEnabled = want
        if not scrollbar then return end

        if want then
            if scrollbar.Enable then scrollbar:Enable() end
            if thumb and thumb.SetVertexColor then
                thumb:SetVertexColor(1, 1, 1, 1)
            end
            if upBtn   and upBtn.Enable   then upBtn:Enable()   end
            if downBtn and downBtn.Enable then downBtn:Enable() end
        else
            scrollbar:SetValue(0)
            if scrollbar.Disable then scrollbar:Disable() end
            if thumb and thumb.SetVertexColor then
                thumb:SetVertexColor(0.5, 0.5, 0.5, 0.6)
            end
            if upBtn   and upBtn.Disable   then upBtn:Disable()   end
            if downBtn and downBtn.Disable then downBtn:Disable() end
        end
    end

    scroll.scrollBarShown = true
    if scrollbar then scrollbar:Show() end
    if scroll.scrollframe then
        scroll.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
    end
    if scroll.content and scroll.content.original_width then
        scroll.content.width = scroll.content.original_width - 20
    end

    scroll.FixScroll = function(self)
        if self.updateLock then return end
        self.updateLock = true

        if not self.scrollBarShown then
            self.scrollBarShown = true
            self.scrollbar:Show()
            self.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
            if self.content.original_width then
                self.content.width = self.content.original_width - 20
            end
        end

        local status = self.status or self.localstatus
        local height, viewheight =
            self.scrollframe:GetHeight(), self.content:GetHeight()
        local offset = status.offset or 0

        if viewheight < height + 2 then
            setEnabled(false)
            self.scrollbar:SetValue(0)
            self.scrollframe:SetVerticalScroll(0)
            status.offset = 0
        else
            setEnabled(true)
            local value = (offset / (viewheight - height) * 1000)
            if value > 1000 then value = 1000 end
            self.scrollbar:SetValue(value)
            self:SetScroll(value)
            if value < 1000 then
                self.content:ClearAllPoints()
                self.content:SetPoint("TOPLEFT",  0, offset)
                self.content:SetPoint("TOPRIGHT", 0, offset)
                status.offset = offset
            end
        end

        self.updateLock = nil
    end

    scroll.MoveScroll = function(self, value)
        if currentEnabled == false then return end
        if origMoveScroll then return origMoveScroll(self, value) end
    end

    scroll.OnRelease = function(self)
        self.FixScroll  = origFixScroll
        self.MoveScroll = origMoveScroll
        self.OnRelease  = origOnRelease
        self._wgAlwaysScrollbar = nil
        currentEnabled = nil
        if thumb and thumb.SetVertexColor then
            thumb:SetVertexColor(1, 1, 1, 1)
        end
        if scrollbar and scrollbar.Enable then scrollbar:Enable() end
        if upBtn   and upBtn.Enable   then upBtn:Enable()   end
        if downBtn and downBtn.Enable then downBtn:Enable() end
        if origOnRelease then origOnRelease(self) end
    end
end

-- ---------------------------------------------------------------------------
-- Lazy AceGUI scroll container
-- ---------------------------------------------------------------------------

local function ensureScroll(ctx)
    if ctx.scroll then return ctx.scroll end
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll.frame:SetParent(ctx.body)
    scroll.frame:ClearAllPoints()
    -- Right inset of PADDING_X+12 leaves room for the scrollbar (which
    -- AceGUI nudges 20 px to the right of the scrollframe when visible)
    -- without it sitting flush against the panel border.
    scroll.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      PADDING_X - 4, -8)
    scroll.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -(PADDING_X + 12), 8)
    scroll.frame:Show()

    -- AceGUI normally has its width/height set by a parent AceGUI
    -- container during DoLayout, which fires OnWidthSet / OnHeightSet
    -- and updates content.width / scrollbar visibility. We parent it to
    -- a Blizzard frame via anchors instead, so those callbacks never
    -- fire and `content.width` stays nil. Hook OnSizeChanged to forward
    -- the actual size into AceGUI and re-run DoLayout + FixScroll on
    -- every resize.
    scroll.frame:SetScript("OnSizeChanged", function(_, w, h)
        if scroll.OnWidthSet  then scroll:OnWidthSet(w)  end
        if scroll.OnHeightSet then scroll:OnHeightSet(h) end
        if scroll.DoLayout    then scroll:DoLayout()     end
        if scroll.FixScroll   then scroll:FixScroll()    end
    end)

    Helpers.PatchAlwaysShowScrollbar(scroll)

    ctx.scroll = scroll
    return scroll
end

-- ---------------------------------------------------------------------------
-- Section header — AceGUI Heading with breathing room above and below.
-- ---------------------------------------------------------------------------

local function addSpacer(parent, height)
    local sp = AceGUI:Create("SimpleGroup")
    sp:SetLayout(nil)
    sp:SetFullWidth(true)
    sp:SetHeight(height or ROW_VSPACER)
    parent:AddChild(sp)
end

function Helpers.Section(ctx, label)
    local scroll = ensureScroll(ctx)

    if ctx.lastGroup ~= nil then
        addSpacer(scroll, SECTION_TOP_SPACER)
    end

    local h = AceGUI:Create("Heading")
    h:SetText(label)
    h:SetFullWidth(true)
    h:SetHeight(SECTION_HEADING_H)
    if h.label and h.label.SetFontObject and _G.GameFontNormalLarge then
        h.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(h)

    addSpacer(scroll, SECTION_BOTTOM_SPACER)
    return h
end

-- ---------------------------------------------------------------------------
-- Widget creators
-- ---------------------------------------------------------------------------

local function applyWidth(widget, relativeWidth)
    if relativeWidth then widget:SetRelativeWidth(relativeWidth)
    else                   widget:SetFullWidth(true) end
end

local function makeCheckbox(ctx, def, parent, relativeWidth)
    parent = parent or ensureScroll(ctx)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(def.label or def.path)
    applyWidth(cb, relativeWidth)
    cb:SetValue(Helpers.Get(def.path) and true or false)

    cb:SetCallback("OnValueChanged", function(_, _, value)
        Helpers.Set(def.path, value and true or false)
    end)

    if not Settings._refreshers[def.path] then
        Settings._refresherOrder[#Settings._refresherOrder + 1] = def.path
    end
    Settings._refreshers[def.path] = function()
        cb:SetValue(Helpers.Get(def.path) and true or false)
    end

    attachTooltip(cb, def.label, def.tooltip)
    parent:AddChild(cb)
    return cb
end

local function makeSlider(ctx, def, parent, relativeWidth)
    parent = parent or ensureScroll(ctx)
    local s = AceGUI:Create("Slider")
    s:SetLabel(def.label or def.path)
    s:SetSliderValues(def.min or 0, def.max or 1, def.step or 0.1)
    s:SetIsPercent(false)
    applyWidth(s, relativeWidth)
    s:SetValue(Helpers.Get(def.path) or def.default or 0)

    s:SetCallback("OnValueChanged", function(_, _, v)
        Helpers.Set(def.path, v)
    end)

    if not Settings._refreshers[def.path] then
        Settings._refresherOrder[#Settings._refresherOrder + 1] = def.path
    end
    Settings._refreshers[def.path] = function()
        s:SetValue(Helpers.Get(def.path) or def.default or 0)
    end

    attachTooltip(s, def.label, def.tooltip)
    parent:AddChild(s)
    return s
end

function Helpers.RenderField(ctx, def, parent, relativeWidth)
    if def.type == "bool"   then return makeCheckbox(ctx, def, parent, relativeWidth) end
    if def.type == "number" then return makeSlider(ctx, def, parent, relativeWidth)   end
end

-- Standalone action button rendered after a group's last schema row via
-- an afterGroup callback. Default 160 px wide, left-aligned in a full-
-- width Flow row — matches KickCD's General-tab "Reset position" pattern.
function Helpers.InlineButton(ctx, spec)
    local scroll = ensureScroll(ctx)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(28)

    local btn = AceGUI:Create("Button")
    btn:SetText(spec.text or "")
    btn:SetWidth(spec.width or 160)
    btn:SetCallback("OnClick", function()
        if not spec.onClick then return end
        local ok, err = pcall(spec.onClick)
        if not ok then pout("button onClick failed: " .. tostring(err)) end
    end)
    row:AddChild(btn)

    attachTooltip(btn, spec.text, spec.tooltip)
    scroll:AddChild(row)
    addSpacer(scroll, ROW_VSPACER)
    return btn
end

-- ---------------------------------------------------------------------------
-- Schema-driven render
-- ---------------------------------------------------------------------------
--
-- Schema widgets pair into 50%/50% Flow rows wrapped in a full-width
-- SimpleGroup, so the AceGUI layout pass gives both children half the
-- panel width and breaks them onto the same line. Section headings span
-- the full width (one per row), and every row is followed by a small
-- vertical spacer for breathing room.
--
-- afterGroup is { [groupName] = function(ctx) ... end }. The callback
-- runs once, immediately after the last schema row of that group is
-- rendered (and before the next group's section header). One-shot —
-- removed from the table after firing so a second sweep wouldn't
-- re-render it.

function Helpers.RenderSchema(ctx, afterGroup)
    local scroll = ensureScroll(ctx)
    local pendingRow, pendingCount = nil, 0

    local function flushRow()
        if pendingRow then
            scroll:AddChild(pendingRow)
            addSpacer(scroll, ROW_VSPACER)
            pendingRow, pendingCount = nil, 0
        end
    end

    local function startRow()
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        return row
    end

    for i, def in ipairs(Schema) do
        if def.group and def.group ~= ctx.lastGroup then
            flushRow()
            Helpers.Section(ctx, def.group)
            ctx.lastGroup = def.group
        end

        if def.solo and pendingCount > 0 then flushRow() end

        if not pendingRow then pendingRow = startRow() end
        Helpers.RenderField(ctx, def, pendingRow, 0.5)
        pendingCount = pendingCount + 1

        if def.solo or pendingCount >= 2 then flushRow() end

        local nextDef = Schema[i + 1]
        if afterGroup and def.group
           and (not nextDef or nextDef.group ~= def.group)
           and afterGroup[def.group] then
            flushRow()
            afterGroup[def.group](ctx)
            afterGroup[def.group] = nil
        end
    end
    flushRow()
    if scroll.DoLayout then scroll:DoLayout() end
end

-- ---------------------------------------------------------------------------
-- Parent (landing) page content
-- ---------------------------------------------------------------------------
--
-- Logo + TOC notes one-liner + Slash Commands heading + per-command
-- Labels, all rendered as AceGUI widgets inside the same lazy
-- ScrollFrame the General sub-page uses. Result: one scrollbar style
-- across both pages, AceGUI font hooks pick up theme changes for free.

-- WG-21 (Blizzard-default-only — accepted deviation): the settings landing
-- page shows the addon's own brand logo, a vendored TGA under media/logos/.
-- It's the only non-Blizzard default texture in the addon — every other
-- texture/border is Blizzard-shipped (WHITE8X8, UI-Tooltip-Border, the
-- Options_HorizontalDivider atlas, spell icons). Branding art, analogous to
-- the TOC IconTexture; no Blizzard asset could substitute. No standards
-- section mandates Blizzard-only textures, so this is a deviation from the
-- addon's own Blizzard-default-only baseline, not from the standard.
local MAIN_LOGO_TEXTURE   = "Interface\\AddOns\\WhatGroup\\media\\logos\\whatgroup.logo.tga"
local MAIN_LOGO_SIZE      = 300
local MAIN_GAP_AFTER_LOGO = 8
local MAIN_GAP_AFTER_DESC = 12
local MAIN_GAP_BELOW_HEAD = 6

function Helpers.BuildMainContent(ctx)
    local scroll = ensureScroll(ctx)

    -- Logo. SimpleGroup is a full-width child so AceGUI's List layout
    -- gives it the scroll's full width; the texture inside is anchored
    -- TOPLEFT at the source TGA's native dimensions, so it renders
    -- pixel-exact and left-aligned regardless of panel width.
    local logoGroup = AceGUI:Create("SimpleGroup")
    logoGroup:SetLayout(nil)
    logoGroup:SetFullWidth(true)
    logoGroup:SetHeight(MAIN_LOGO_SIZE)

    local logoTex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
    logoTex:SetTexture(MAIN_LOGO_TEXTURE)
    logoTex:SetSize(MAIN_LOGO_SIZE, MAIN_LOGO_SIZE)
    logoTex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
    scroll:AddChild(logoGroup)

    addSpacer(scroll, MAIN_GAP_AFTER_LOGO)

    -- TOC Notes one-liner — full-width Label, left-justified.
    local meta  = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local notes = (meta and meta("WhatGroup", "Notes")) or ""

    local desc = AceGUI:Create("Label")
    desc:SetFullWidth(true)
    desc:SetText(notes)
    if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
        desc.label:SetFontObject(_G.GameFontHighlight)
    end
    if desc.label and desc.label.SetJustifyH then
        desc.label:SetJustifyH("LEFT")
    end
    scroll:AddChild(desc)

    addSpacer(scroll, MAIN_GAP_AFTER_DESC)

    -- "Slash Commands" heading — AceGUI Heading widget delivers both
    -- the visual side dividers and the section title in one widget.
    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetHeight(SECTION_HEADING_H)
    heading:SetText("Slash Commands")
    if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
        heading.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(heading)

    addSpacer(scroll, MAIN_GAP_BELOW_HEAD)

    -- One Label per command pulled from WhatGroup.COMMANDS so the panel
    -- list stays in lockstep with /wg help — adding a command in
    -- WhatGroup.lua surfaces here automatically.
    for _, entry in ipairs(WhatGroup.COMMANDS or {}) do
        local row = AceGUI:Create("Label")
        row:SetFullWidth(true)
        row:SetText(("|cffffff00/wg %s|r  |cffffffff—|r  %s")
            :format(entry[1], entry[2]))
        if row.label and row.label.SetJustifyH then
            row.label:SetJustifyH("LEFT")
        end
        scroll:AddChild(row)
    end
end

-- ---------------------------------------------------------------------------
-- Public registration
-- ---------------------------------------------------------------------------
--
-- Called from `OnEnable` (PLAYER_LOGIN) so the panel is in the Settings →
-- AddOns list at login, like every other Ka0s addon; and again as an
-- idempotent no-op from `runConfig`. Registering a canvas category at login is
-- taint-safe — WhatGroup's real GameMenu-taint sources (the secure teleport
-- button + UISpecialFrames insert) stay deferred in modules/Frame.lua. See
-- docs/wow-quirks.md → "Lazy popup and secure button" for the taint reasoning.
--
-- The parent canvas is the addon-landing page (logo + TOC notes +
-- slash list); every actual setting lives in the General subcategory.
-- WhatGroup._parentSettingsCategory is the handle `/wg config` opens
-- against (also pcall-poking SettingsPanel.CategoryList's CategoryEntry
-- so the General subcategory shows unfolded in the sidebar tree);
-- WhatGroup._settingsCategory keeps the General-sub handle around for
-- any future "open straight to General" caller.

function Settings.Register()
    if WhatGroup._settingsRegistered or not _G.Settings
       or not _G.Settings.RegisterCanvasLayoutCategory
       or not _G.Settings.RegisterCanvasLayoutSubcategory then
        return
    end

    -- Defense in depth: `runConfig` already guards on InCombatLockdown,
    -- but registering Settings categories during combat taints the
    -- GameMenu callback chain. Refuse here too so any future caller
    -- that bypasses the slash-handler guard doesn't reintroduce the
    -- Logout taint.
    if InCombatLockdown() then
        if WhatGroup._print then
            WhatGroup._print("Cannot register settings panel during combat.")
        end
        return
    end

    Helpers.ValidateSchema()

    -- Parent: addon landing page. Same unified header (gold title +
    -- divider) as the sub-page, no Defaults button.
    local mainCtx = Helpers.CreatePanel(
        "WhatGroupParentPanel", "Ka0s WhatGroup",
        { isMain = true, panelKey = "main" })

    -- Defer body render until first OnShow: AceGUI's ScrollFrame lays
    -- children out against the parent's current width, which is zero at
    -- PLAYER_LOGIN, and there's no point building widgets for a panel
    -- the user may never open. We also wrap the actual build in
    -- C_Timer.After(0, …) so OnShow returns immediately — Blizzard's
    -- GameMenu / Logout flows can dispatch our OnShow inside a secure
    -- execute chain, and creating AceGUI frames synchronously inside
    -- that chain trips ADDON_ACTION_FORBIDDEN. Running the build on the
    -- next frame moves it out of the protected context entirely.
    -- (Raw C_Timer.After, not AceTimer-3.0 — deliberate; see the WG-17
    -- note in WhatGroup.lua and docs/ARCHITECTURE.md → "Timers".)
    local mainRendered, mainScheduled = false, false
    mainCtx.panel:SetScript("OnShow", function()
        if mainRendered or mainScheduled then return end
        mainScheduled = true
        C_Timer.After(0, function()
            if mainRendered then return end
            mainRendered = true
            Helpers.BuildMainContent(mainCtx)
        end)
    end)

    local parentCategory = _G.Settings.RegisterCanvasLayoutCategory(
        mainCtx.panel, "Ka0s WhatGroup")
    _G.Settings.RegisterAddOnCategory(parentCategory)
    WhatGroup._parentSettingsCategory = parentCategory

    -- General sub-page: schema widgets + Test button.
    local generalCtx = Helpers.CreatePanel(
        "WhatGroupGeneralPanel", "General",
        { panelKey = "general", defaultsButton = true,
          defaultsTooltip = "Reset every WhatGroup setting to its default. Asks for confirmation." })

    if generalCtx.panel.defaultsBtn then
        generalCtx.panel.defaultsBtn:SetCallback("OnClick", function()
            Settings.EnsureResetPopup()
            StaticPopup_Show("WHATGROUP_RESET_ALL")
        end)
    end

    -- Same deferral as the main panel — keep the synchronous OnShow body
    -- a no-op so it can't ever do work inside Blizzard's secure-execute
    -- chains. The build runs on the next frame in a clean context.
    -- (Raw C_Timer.After, not AceTimer-3.0 — deliberate; see WG-17.)
    local generalRendered, generalScheduled = false, false
    generalCtx.panel:SetScript("OnShow", function()
        if generalRendered or generalScheduled then return end
        generalScheduled = true
        C_Timer.After(0, function()
            if generalRendered then return end
            generalRendered = true
            Helpers.RenderSchema(generalCtx, {
                ["General"] = function(ctxRef)
                    -- Session-only "Debug console" toggle (WG-12 /
                    -- debug-logging-§5). Deliberately NOT a schema row: it
                    -- reflects and drives NS.State.debug, which is session-only
                    -- and OFF at every login, so it must never persist to
                    -- SavedVariables. Bound straight to the DebugLog seam
                    -- (SetEnabled + Show/Hide) rather than Helpers.Get/Set,
                    -- which would write db.profile. The checkbox is
                    -- authoritative over both logging state and console
                    -- visibility; a HookScript below re-syncs its value on
                    -- every panel open (state can change via `/wg debug` or the
                    -- console's own title-bar toggle while the panel is closed).
                    local scroll = ensureScroll(ctxRef)
                    local dbgRow = AceGUI:Create("SimpleGroup")
                    dbgRow:SetLayout("Flow")
                    dbgRow:SetFullWidth(true)

                    local dbgCB = AceGUI:Create("CheckBox")
                    dbgCB:SetLabel("Debug console")
                    dbgCB:SetRelativeWidth(0.5)
                    dbgCB:SetValue(NS.State and NS.State.debug or false)
                    dbgCB:SetCallback("OnValueChanged", function(_, _, value)
                        local on = value and true or false
                        if NS.DebugLog then
                            NS.DebugLog:SetEnabled(on)
                            if on then NS.DebugLog:Show() else NS.DebugLog:Hide() end
                        end
                    end)
                    attachTooltip(dbgCB, "Debug console",
                        "Show the on-screen debug console and enable debug logging for this session. Session-only — resets to off on every login or /reload; never saved to your profile.")
                    dbgRow:AddChild(dbgCB)
                    scroll:AddChild(dbgRow)
                    addSpacer(scroll, ROW_VSPACER)
                    generalCtx._debugCB = dbgCB

                    Helpers.InlineButton(ctxRef, {
                        text    = "Test",
                        tooltip = "Inject synthetic group info and run the full notification + popup flow. Useful for previewing changes to the chat-output toggles without joining a real group.",
                        onClick = function()
                            if WhatGroup.RunTest then WhatGroup:RunTest() end
                        end,
                    })
                end,
            })
        end)
    end)

    -- Re-sync the session-only Debug console checkbox each time General is
    -- shown: NS.State.debug can flip via `/wg debug` or the console's own
    -- title-bar toggle while this panel is closed. The build is deferred
    -- (C_Timer.After), so the checkbox may not exist yet on the first show —
    -- guarded. SetValue does not fire OnValueChanged, so this can't loop.
    generalCtx.panel:HookScript("OnShow", function()
        local cb = generalCtx._debugCB
        if cb then cb:SetValue(NS.State and NS.State.debug or false) end
    end)

    local generalSub = _G.Settings.RegisterCanvasLayoutSubcategory(
        parentCategory, generalCtx.panel, "General")
    WhatGroup._settingsCategory = generalSub
    WhatGroup._settingsRegistered = true
end
