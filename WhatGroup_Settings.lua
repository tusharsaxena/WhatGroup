-- WhatGroup_Settings.lua
-- Schema rows + Helpers + canvas-layout panel builder.
--
-- Every option is one row in WhatGroup.Settings.Schema. The same row
-- drives:
--   * the AceGUI widget rendered in the Settings panel
--   * /wg list (groups by `section`, prints path = formattedValue)
--   * /wg get <path>  (uses Helpers.FindSchema + Helpers.Get)
--   * /wg set <path> <value>  (type-aware parse → Helpers.Set → onChange → RefreshAll)
--   * AceDB defaults (BuildDefaults walks Schema and threads `default`
--     values into the nested `profile` table)
--
-- Adding a new option = one schema row; UI, CLI, and defaults all
-- follow automatically.
--
-- Panel layout follows Ka0s KickCD:
--   * Parent category "Ka0s WhatGroup" is registered with a placeholder
--     panel — in WoW 12.0, a parent category with subcategories hides
--     its own widgets, so widgets there would never display anyway.
--   * Subcategory "General" hosts every schema widget, rendered in a
--     two-column Flow layout (50%/50% per row). `solo = true` forces a
--     widget onto its own row (left half occupied, right half empty);
--     `spacerBefore = true` inserts a blank row before the widget.

local WhatGroup = LibStub("AceAddon-3.0"):GetAddon("WhatGroup")
local AceGUI    = LibStub("AceGUI-3.0")

WhatGroup.Settings = WhatGroup.Settings or {}
local Settings    = WhatGroup.Settings
Settings.Schema   = {}
Settings.Helpers  = {}
Settings._refreshers = {}   -- { [path] = function() widget:SetValue(Helpers.Get(path)) end }

local Schema  = Settings.Schema
local Helpers = Settings.Helpers

-- ---------------------------------------------------------------------------
-- Schema
-- ---------------------------------------------------------------------------
--
-- Panel layout intent (rows are positioned in schema-declaration order):
--
--   --- General ---
--   [Enable]        | [Auto Show]
--   [Print to Chat] | [Notification Delay]
--   [Test]          | [Debug]
--
--   --- Notify ---
--   [Show Instance]
--   [Show Type]
--   [Show Leader]
--   [Show Playstyle]
--   [Show ClickLink]
--   [Show Teleport]
--
-- The Test row uses `type = "action"` — rendered as a Button widget
-- in the panel, ignored by /wg list/get/set (it has no path / value).
-- panelHidden = true is still supported by the renderer for any future
-- power-user-only setting that should stay out of the panel.

local function add(t) Schema[#Schema + 1] = t end

-- General

add{
    section = "general",  group = "General",
    path    = "enabled",  type = "bool",
    label   = "Enable",
    tooltip = "Master switch. When off, WhatGroup ignores group applications entirely — no capture, no notification, no popup. Re-enable to resume tracking on your next /lfg apply.",
    default = true,
}

add{
    section = "frame",  group = "General",
    path    = "frame.autoShow",  type = "bool",
    label   = "Auto Show",
    tooltip = "Open the group-info popup automatically when joining. With this off, the chat notification still prints and you can re-open the popup with /wg show or the chat link.",
    default = true,
}

add{
    section = "notify",  group = "General",
    path    = "notify.enabled",  type = "bool",
    label   = "Print to Chat",
    tooltip = "Print the group-details summary to chat after joining a group.",
    default = true,
}

add{
    section = "notify",  group = "General",
    path    = "notify.delay",  type = "number",
    label   = "Notification Delay",
    tooltip = "Seconds to wait after joining before printing the notification and showing the popup. Lets the zone-in settle.",
    default = 1.5,
    min = 0, max = 10, step = 0.5, fmt = "%.1fs",
}

-- Test action — paired with Debug on the same row. Action rows have no
-- `path` and no value, so they're skipped by /wg list / get / set;
-- they're purely a panel affordance. Mirror code path is /wg test
-- (both go through WhatGroup:RunTest).
add{
    section = "general",  group = "General",
    type    = "action",
    label   = "Test",
    tooltip = "Inject synthetic group info and run the full notification + popup flow. Useful for previewing changes to the chat-output toggles without joining a real group.",
    onClick = function() if WhatGroup.RunTest then WhatGroup:RunTest() end end,
}

add{
    section = "general",  group = "General",
    path    = "debug",  type = "bool",
    label   = "Debug",
    tooltip = "Print every internal event/hook to chat. Useful for diagnosing capture issues.",
    default = false,
    onChange = function(v) WhatGroup.debug = v and true or false end,
}

-- Notify — per-line gates for the chat notification. Each row is solo
-- so the section reads as a vertical checklist of "include this line
-- when printing the notification."

add{
    section = "notify",  group = "Notify",
    path    = "notify.showInstance",  type = "bool",
    label   = "Show Instance",
    tooltip = "Include the Instance line in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showType",  type = "bool",
    label   = "Show Type",
    tooltip = "Include the Type line (Mythic+, Raid, Dungeon, …) in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showLeader",  type = "bool",
    label   = "Show Leader",
    tooltip = "Include the Leader line in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showPlaystyle",  type = "bool",
    label   = "Show Playstyle",
    tooltip = "Include the Playstyle line (Casual / Moderate / Serious) in the chat notification.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showClickLink",  type = "bool",
    label   = "Show \"Click here to view details\" link",
    tooltip = "Include the clickable chat link that re-opens the popup. Disable if you only want the chat summary.",
    default = true,
    solo    = true,
}

add{
    section = "notify",  group = "Notify",
    path    = "notify.showTeleport",  type = "bool",
    label   = "Show Teleport spell",
    tooltip = "Include a Teleport line with the dungeon's teleport spell link (and a \"not learned\" tag if you don't have it). Skipped silently when the dungeon has no known teleport.",
    default = true,
    solo    = true,
}

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

-- Walk a dotted path into db.profile and return (parent, key) so the
-- caller can read parent[key] or write parent[key] = value.
local function Resolve(path)
    if not (WhatGroup.db and WhatGroup.db.profile) then return nil, nil end
    local segments = {}
    for part in string.gmatch(path, "[^.]+") do
        segments[#segments + 1] = part
    end
    if #segments == 0 then return nil, nil end
    local parent = WhatGroup.db.profile
    for i = 1, #segments - 1 do
        local k = segments[i]
        if type(parent[k]) ~= "table" then parent[k] = {} end
        parent = parent[k]
    end
    return parent, segments[#segments]
end
Helpers.Resolve = Resolve

function Helpers.Get(path)
    local parent, key = Resolve(path)
    if not parent then return nil end
    return parent[key]
end

function Helpers.Set(path, value)
    local parent, key = Resolve(path)
    if not parent then return end
    parent[key] = value
end

function Helpers.FindSchema(path)
    for _, def in ipairs(Schema) do
        if def.path == path then return def end
    end
end

-- Walk Schema and build the nested AceDB defaults table by threading
-- each row's `default` into the path it names.
function Settings.BuildDefaults()
    local out = { profile = {} }
    for _, def in ipairs(Schema) do
        if def.path then   -- skip action rows (no value to seed)
            local segs = {}
            for part in string.gmatch(def.path, "[^.]+") do
                segs[#segs + 1] = part
            end
            local parent = out.profile
            for i = 1, #segs - 1 do
                parent[segs[i]] = parent[segs[i]] or {}
                parent = parent[segs[i]]
            end
            parent[segs[#segs]] = def.default
        end
    end
    return out
end

-- Reset every schema row to its declared default. Fires onChange on
-- each row, then refreshes the open settings panel widgets.
function Helpers.RestoreDefaults()
    for _, def in ipairs(Schema) do
        if def.path then   -- skip action rows
            Helpers.Set(def.path, def.default)
            if def.onChange then
                local ok, err = pcall(def.onChange, def.default)
                if not ok then
                    print("|cff00FFFF[WG]|r RestoreDefaults onChange failed for "
                          .. def.path .. ": " .. tostring(err))
                end
            end
        end
    end
    Helpers.RefreshAll()
end

-- Re-sync every panel widget against the current db.profile value.
function Helpers.RefreshAll()
    for _, refresher in pairs(Settings._refreshers) do
        local ok, err = pcall(refresher)
        if not ok then
            print("|cff00FFFF[WG]|r refresher failed: " .. tostring(err))
        end
    end
end

-- ---------------------------------------------------------------------------
-- Canvas panel builder
-- ---------------------------------------------------------------------------
--
-- Renders Schema as AceGUI widgets stacked inside a SimpleGroup parented
-- to a Blizzard Frame registered via Settings.RegisterCanvasLayoutSubcategory.
-- Group transitions emit a Heading; widgets are paired into 50%/50%
-- Flow rows. `solo = true` forces a widget onto its own row;
-- `spacerBefore = true` inserts a blank row before the widget.

local PADDING       = 16
local HEADER_HEIGHT = 56
local ROW_VSPACER   = 6
local SECTION_TOP   = 10

local function attachTooltip(widget, label, tooltip)
    if not (widget and tooltip and tooltip ~= "") then return end
    widget:SetCallback("OnEnter", function(self)
        GameTooltip:SetOwner(self.frame, "ANCHOR_RIGHT")
        if label and label ~= "" then
            GameTooltip:SetText(label, 1, 1, 1)
        end
        GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    widget:SetCallback("OnLeave", function() GameTooltip:Hide() end)
end

local function makeCheckbox(def)
    local w = AceGUI:Create("CheckBox")
    w:SetLabel(def.label)
    w:SetRelativeWidth(0.5)
    w:SetValue(Helpers.Get(def.path) and true or false)
    w:SetCallback("OnValueChanged", function(_, _, v)
        local val = v and true or false
        Helpers.Set(def.path, val)
        if def.onChange then
            local ok, err = pcall(def.onChange, val)
            if not ok then
                print("|cff00FFFF[WG]|r onChange failed for "
                      .. def.path .. ": " .. tostring(err))
            end
        end
    end)
    Settings._refreshers[def.path] = function()
        w:SetValue(Helpers.Get(def.path) and true or false)
    end
    attachTooltip(w, def.label, def.tooltip)
    return w
end

local function makeSlider(def)
    local w = AceGUI:Create("Slider")
    w:SetLabel(def.label)
    w:SetSliderValues(def.min or 0, def.max or 1, def.step or 0.1)
    w:SetIsPercent(false)
    w:SetRelativeWidth(0.5)
    w:SetValue(Helpers.Get(def.path) or def.default or 0)
    w:SetCallback("OnValueChanged", function(_, _, v)
        Helpers.Set(def.path, v)
        if def.onChange then
            local ok, err = pcall(def.onChange, v)
            if not ok then
                print("|cff00FFFF[WG]|r onChange failed for "
                      .. def.path .. ": " .. tostring(err))
            end
        end
    end)
    Settings._refreshers[def.path] = function()
        w:SetValue(Helpers.Get(def.path) or def.default or 0)
    end
    attachTooltip(w, def.label, def.tooltip)
    return w
end

-- Action button — used for "Test" and any future inline panel action.
-- Action rows have no `path` and no `default`, so they're skipped by
-- BuildDefaults / RestoreDefaults / /wg list / get / set; they exist
-- purely to render a button in the panel's grid alongside checkbox and
-- slider rows. SetRelativeWidth(0.5) means they participate in the
-- two-column pairing — a Test action followed by a bool row puts the
-- two on the same line.
local function makeActionButton(def)
    local btn = AceGUI:Create("Button")
    btn:SetText(def.label or "")
    btn:SetRelativeWidth(0.5)
    btn:SetCallback("OnClick", function()
        if not def.onClick then return end
        local ok, err = pcall(def.onClick)
        if not ok then
            print("|cff00FFFF[WG]|r action onClick failed: " .. tostring(err))
        end
    end)
    attachTooltip(btn, def.label, def.tooltip)
    return btn
end

local function makeField(def)
    if def.type == "bool"   then return makeCheckbox(def)     end
    if def.type == "number" then return makeSlider(def)       end
    if def.type == "action" then return makeActionButton(def) end
end

local function makeHeading(text)
    local h = AceGUI:Create("Heading")
    h:SetText(text)
    h:SetFullWidth(true)
    h:SetHeight(28)
    if h.label and h.label.SetFontObject and _G.GameFontNormalLarge then
        h.label:SetFontObject(_G.GameFontNormalLarge)
    end
    return h
end

local function addSpacer(container, height)
    local sp = AceGUI:Create("SimpleGroup")
    sp:SetLayout(nil)
    sp:SetFullWidth(true)
    sp:SetHeight(height or ROW_VSPACER)
    container:AddChild(sp)
end

-- Build the body of the General subcategory: every schema row, paired
-- into two-column rows (or solo, per def.solo). Group transitions emit
-- a Heading; def.spacerBefore inserts a blank row before that widget.
local function renderSchema(container)
    local pendingRow, pendingCount, lastGroup = nil, 0, nil

    local function flushRow()
        if pendingRow then
            container:AddChild(pendingRow)
            addSpacer(container, ROW_VSPACER)
            pendingRow, pendingCount = nil, 0
        end
    end

    local function startRow()
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)
        return row
    end

    for _, def in ipairs(Schema) do
        if not def.panelHidden then
            if def.group and def.group ~= lastGroup then
                flushRow()
                if lastGroup ~= nil then addSpacer(container, SECTION_TOP) end
                container:AddChild(makeHeading(def.group))
                addSpacer(container, ROW_VSPACER)
                lastGroup = def.group
            end

            if def.spacerBefore then
                flushRow()
                addSpacer(container, ROW_VSPACER * 2)
            end

            -- A solo widget always starts a fresh row and ends it.
            if def.solo and pendingCount > 0 then flushRow() end

            if not pendingRow then pendingRow = startRow() end
            pendingRow:AddChild(makeField(def))
            pendingCount = pendingCount + 1

            if def.solo or pendingCount >= 2 then flushRow() end
        end
    end
    flushRow()
end


-- Build a canvas-layout panel Frame compatible with both
-- RegisterCanvasLayoutCategory and RegisterCanvasLayoutSubcategory.
-- Stamps a unified header (gold title + subtitle) on top.
local function createPanel(name, title, subtitle)
    local panel = CreateFrame("Frame", name, UIParent)
    panel.name = title
    panel:Hide()

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -PADDING)
    titleFS:SetText("|cffFFD700" .. title .. "|r")

    if subtitle and subtitle ~= "" then
        local subFS = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        subFS:SetPoint("TOPLEFT", titleFS, "BOTTOMLEFT", 0, -6)
        subFS:SetText(subtitle)
    end

    return panel
end

-- Parent ("addon landing") panel: title + divider stay fixed at the top;
-- everything below scrolls vertically inside a UIPanelScrollFrameTemplate.
-- Body order: logo (300×300 .tga, left-aligned, no resize) → TOC Notes
-- one-liner (left-aligned) → separator → "Slash Commands" header → list
-- iterated from WhatGroup.COMMANDS.
local LOGO_TEXTURE     = "Interface\\AddOns\\WhatGroup\\media\\screenshots\\whatgroup.logo.tga"
local LOGO_SIZE        = 300
local DIVIDER_OFFSET_Y = PADDING + 32
local SCROLLBAR_GUTTER = 24   -- room on the right for the scrollbar

local function createParentPanel(name, title)
    local panel = CreateFrame("Frame", name, UIParent)
    panel.name = title
    panel:Hide()

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING, -PADDING)
    titleFS:SetText("|cffFFD700" .. title .. "|r")

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PADDING, -DIVIDER_OFFSET_Y)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING, -DIVIDER_OFFSET_Y)
    divider:SetVertexColor(titleFS:GetTextColor())

    -- Scrollable body. The scrollbar is part of UIPanelScrollFrameTemplate
    -- and anchors to the scroll frame's right edge — leaving SCROLLBAR_GUTTER
    -- of margin on the right keeps it inside the panel.
    local scrollFrame = CreateFrame("ScrollFrame", name .. "Scroll", panel,
                                    "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     panel, "TOPLEFT",      PADDING,
                         -(DIVIDER_OFFSET_Y + 12))
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -PADDING - SCROLLBAR_GUTTER,
                         PADDING)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(1, 1)   -- height set after layout; width tracks scroll viewport
    scrollFrame:SetScrollChild(content)
    scrollFrame:HookScript("OnSizeChanged", function(_, w)
        if w and w > 0 then content:SetWidth(w) end
    end)

    local y = 0

    -- Logo — left-aligned, fixed 300×300
    local logo = content:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(LOGO_TEXTURE)
    logo:SetSize(LOGO_SIZE, LOGO_SIZE)
    logo:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    y = y + LOGO_SIZE + 14

    -- TOC Notes one-liner — left-aligned, pulled live from metadata.
    local meta  = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
    local notes = (meta and meta("WhatGroup", "Notes")) or ""
    local notesFS = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    notesFS:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    notesFS:SetText(notes)
    y = y + 16 + 18

    -- Separator before the slash commands section.
    local sep = content:CreateTexture(nil, "ARTWORK")
    sep:SetAtlas("Options_HorizontalDivider", true)
    sep:SetPoint("TOPLEFT",  content, "TOPLEFT",  0, -y)
    sep:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -y)
    sep:SetVertexColor(titleFS:GetTextColor())
    y = y + 8 + 10

    local slashHeading = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    slashHeading:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
    slashHeading:SetText("|cffFFD700Slash Commands|r")
    y = y + 22 + 6

    for _, entry in ipairs(WhatGroup.COMMANDS or {}) do
        local row = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -y)
        row:SetText(("|cffFFFF00/wg %s|r  —  %s"):format(entry[1], entry[2]))
        y = y + 16
    end

    content:SetHeight(y + PADDING)

    return panel
end

-- ---------------------------------------------------------------------------
-- Public registration entry
-- ---------------------------------------------------------------------------
--
-- Called from WhatGroup:OnEnable. Idempotent.
--
-- WoW 12.0 hides a parent category's own widgets when the parent has
-- subcategories. So the parent panel is intentionally a thin description
-- page; every actual setting lives in the General subcategory.
-- WhatGroup._settingsCategory is set to the **subcategory** so /wg config
-- opens directly to the settings, not to the empty parent.

function Settings.Register()
    if WhatGroup._settingsRegistered or not _G.Settings
       or not _G.Settings.RegisterCanvasLayoutCategory
       or not _G.Settings.RegisterCanvasLayoutSubcategory then
        return
    end

    -- Parent: addon landing page. Header + divider, logo, TOC Notes
    -- one-liner, slash commands. Settings live in the General subcategory.
    local parentPanel = createParentPanel("WhatGroupParentPanel", "Ka0s WhatGroup")
    local parentCategory = _G.Settings.RegisterCanvasLayoutCategory(parentPanel, "Ka0s WhatGroup")
    _G.Settings.RegisterAddOnCategory(parentCategory)
    WhatGroup._parentSettingsCategory = parentCategory

    -- General subcategory: holds every schema widget.
    local generalPanel = createPanel("WhatGroupGeneralPanel", "General",
        "Settings auto-wire to |cffFFFF00/wg list|r, |cffFFFF00/wg get|r, |cffFFFF00/wg set|r")

    -- Defer the AceGUI body build until the panel is actually shown,
    -- so widgets render against a non-zero panel width.
    local built = false
    local container
    generalPanel:SetScript("OnShow", function()
        if built then return end
        built = true

        container = AceGUI:Create("SimpleGroup")
        container:SetLayout("List")
        container.frame:SetParent(generalPanel)
        container.frame:ClearAllPoints()
        container.frame:SetPoint("TOPLEFT",
            generalPanel, "TOPLEFT",      PADDING - 4, -HEADER_HEIGHT)
        container.frame:SetPoint("BOTTOMRIGHT",
            generalPanel, "BOTTOMRIGHT", -PADDING,      PADDING)
        container.frame:Show()

        -- Forward Blizzard's frame size into AceGUI so SetRelativeWidth /
        -- SetFullWidth widgets know how wide to draw. Without this,
        -- parented-to-blizzard AceGUI containers stay at width 0 until
        -- something kicks DoLayout.
        container.frame:SetScript("OnSizeChanged", function(_, w, h)
            if container.OnWidthSet  then container:OnWidthSet(w)  end
            if container.OnHeightSet then container:OnHeightSet(h) end
            if container.DoLayout    then container:DoLayout()     end
        end)

        renderSchema(container)
    end)

    local generalSub = _G.Settings.RegisterCanvasLayoutSubcategory(
        parentCategory, generalPanel, "General")
    WhatGroup._settingsCategory = generalSub
    WhatGroup._settingsRegistered = true
end
