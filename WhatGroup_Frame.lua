-- WhatGroup_Frame.lua
-- Custom popup dialog frame for displaying group details

local FRAME_WIDTH  = 420
local FRAME_HEIGHT = 260

-- ============================================================
-- Frame creation
-- ============================================================
local f = CreateFrame("Frame", "WhatGroupFrame", UIParent, "BackdropTemplate")
f:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
f:SetPoint("CENTER", UIParent, "CENTER", 0, math.floor(UIParent:GetHeight() * 0.25))
f:SetFrameStrata("DIALOG")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:Hide()

f:SetBackdrop({
    bgFile   = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    tile     = false,
    tileSize = 0,
    edgeSize = 1,
    insets   = { left = 1, right = 1, top = 1, bottom = 1 },
})
f:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)

-- ============================================================
-- Title bar (drag handle)
-- ============================================================
local titleBar = CreateFrame("Frame", nil, f)
titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
titleBar:SetHeight(30)
titleBar:EnableMouse(true)
titleBar:SetScript("OnMouseDown", function() f:StartMoving() end)
titleBar:SetScript("OnMouseUp",   function() f:StopMovingOrSizing() end)

local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -2)
titleText:SetText("|cffFFD700WhatGroup|r — Group Info")

-- Separator line under title
local sep = f:CreateTexture(nil, "ARTWORK")
sep:SetColorTexture(0.4, 0.4, 0.4, 0.8)
sep:SetHeight(1)
sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -30)
sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -30)

-- ============================================================
-- Content frame (plain, no scroll)
-- ============================================================
local content = CreateFrame("Frame", nil, f)
content:SetPoint("TOPLEFT",     f, "TOPLEFT",   14, -38)
content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 44)

-- ============================================================
-- Label builder helpers
-- ============================================================
local LABEL_WIDTH = 72

local function MakeLabel(parent, anchor, yOffset, labelText, valueText)
    local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
    label:SetWidth(LABEL_WIDTH)
    label:SetText("|cffFFD700" .. labelText .. "|r")
    label:SetJustifyH("LEFT")
    label:SetWordWrap(false)

    local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    value:SetPoint("TOPLEFT", label, "TOPLEFT", LABEL_WIDTH + 6, 0)
    value:SetJustifyH("LEFT")
    value:SetText(valueText or "")

    return label, value
end

-- Storage for dynamic value FontStrings so we can update them
local fields = {}

-- ============================================================
-- Build content layout (called once, values updated on Show)
-- ============================================================
local topAnchor = CreateFrame("Frame", nil, content)
topAnchor:SetSize(1, 1)
topAnchor:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -4)

local yGap = -18

local lblGroup, valGroup   = MakeLabel(content, topAnchor,  0,      "Group:",    "—")
local lblInst,  valInst    = MakeLabel(content, lblGroup,   yGap,   "Instance:", "—")
local lblType,  valType    = MakeLabel(content, lblInst,    yGap,   "Type:",     "—")
local lblLead,  valLead    = MakeLabel(content, lblType,    yGap,   "Leader:",   "—")

local PLAYSTYLE_LABELS = { [1] = "Casual", [2] = "Moderate", [3] = "Serious" }

-- Value color resolvers: each field can define a function(info) → hex color or nil (plain).
-- Return nil or "" to leave text uncolored.
local VALUE_COLORS = {
    group     = function(info) return nil end,
    instance  = function(info) return nil end,
    type      = function(info) return nil end,
    leader    = function(info) return nil end,
    playstyle = function(info) return nil end,
}

local function ColorizeValue(text, resolver, info)
    local hex = resolver and resolver(info)
    if hex and hex ~= "" then
        return "|cff" .. hex .. text .. "|r"
    end
    return text
end

local lblStyle, valStyle   = MakeLabel(content, lblLead,    yGap,   "Playstyle:", "—")

local lblPort = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
lblPort:SetPoint("TOPLEFT", lblStyle, "BOTTOMLEFT", 0, yGap)
lblPort:SetText("|cffFFD700Teleport:|r")
lblPort:SetJustifyH("LEFT")
lblPort:SetWidth(LABEL_WIDTH)
lblPort:SetWordWrap(false)

local teleportBtn = CreateFrame("Button", nil, content)
teleportBtn:SetSize(24, 24)
teleportBtn:SetPoint("LEFT", lblPort, "LEFT", LABEL_WIDTH + 6, 0)
teleportBtn:Hide()

local teleportIcon = teleportBtn:CreateTexture(nil, "ARTWORK")
teleportIcon:SetAllPoints(teleportBtn)

content:SetHeight(math.abs(yGap) * 6 + 24)

fields.group       = valGroup
fields.instance    = valInst
fields.type        = valType
fields.leader      = valLead
fields.playstyle   = valStyle
fields.teleportBtn  = teleportBtn
fields.teleportIcon = teleportIcon

-- ============================================================
-- Teleport icon button configurator
-- ============================================================
local function ConfigureTeleportButton(btn, icon, info)
    local spellID = WhatGroup:GetTeleportSpell(info and info.activityID, info and info.mapID)
    if not spellID then
        btn:Hide()
        return
    end

    local texID = C_Spell.GetSpellTexture(spellID) or 134400
    local known = IsSpellKnown(spellID)

    icon:SetTexture(texID)
    icon:SetDesaturated(not known)
    btn:SetAlpha(known and 1.0 or 0.5)
    btn:EnableMouse(known)

    if known then
        btn:SetScript("OnClick", function()
            CastSpellByID(spellID)
        end)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spellID)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        btn:SetScript("OnClick", nil)
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
    end

    btn:Show()
end

-- ============================================================
-- Determine group type label (mirrors WhatGroup.lua helper)
-- ============================================================
local function GetGroupTypeLabel(info)
    if info.isMythicPlus       then return "Mythic+"
    elseif info.isCurrentRaid  then return "Raid (Current)"
    elseif info.isHeroicRaid   then return "Heroic Raid"
    elseif info.categoryID == 2 then return "PvP"
    elseif info.categoryID == 1 then return "Dungeon"
    elseif info.maxNumPlayers and info.maxNumPlayers >= 10 then return "Raid"
    elseif info.maxNumPlayers and info.maxNumPlayers > 0   then return "Dungeon"
    else return "Group"
    end
end

-- ============================================================
-- Populate fields from pendingInfo
-- ============================================================
local function PopulateFields()
    local info = WhatGroup.pendingInfo
    if not info then
        fields.group:SetText("|cff888888No data|r")
        fields.instance:SetText("|cff888888No data|r")
        fields.type:SetText("|cff888888No data|r")
        fields.leader:SetText("|cff888888No data|r")
        fields.playstyle:SetText("|cff888888—|r")
        fields.teleportBtn:Hide()
        return
    end

    fields.group:SetText(ColorizeValue(info.title, VALUE_COLORS.group, info))

    local instText = info.fullName ~= "" and info.fullName or "Unknown"
    fields.instance:SetText(ColorizeValue(instText, VALUE_COLORS.instance, info))

    local typeStr = info.shortName ~= "" and info.shortName or GetGroupTypeLabel(info)
    fields.type:SetText(ColorizeValue(typeStr, VALUE_COLORS.type, info))

    fields.leader:SetText(ColorizeValue(info.leaderName, VALUE_COLORS.leader, info))

    local playStyle = PLAYSTYLE_LABELS[info.playstyle] or ""
    fields.playstyle:SetText(playStyle ~= "" and ColorizeValue(playStyle, VALUE_COLORS.playstyle, info) or "|cff888888—|r")

    ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, info)
end

-- ============================================================
-- Close button
-- ============================================================
local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
closeBtn:SetSize(90, 24)
closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function() f:Hide() end)

-- ============================================================
-- ESC to close (register with UISpecialFrames)
-- ============================================================
tinsert(UISpecialFrames, "WhatGroupFrame")

-- ============================================================
-- Public API: ShowFrame / HideFrame
-- ============================================================
function WhatGroup:ShowFrame()
    PopulateFields()
    f:Show()
    f:Raise()
end

function WhatGroup:HideFrame()
    f:Hide()
end
