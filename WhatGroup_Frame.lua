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

-- Mirror of the chat-side table in WhatGroup.lua. Kept independently
-- duplicated so the popup file doesn't take a dependency on
-- WhatGroup.lua's internals at file-load time. See docs/frame.md.
local PLAYSTYLE_LABELS = {
    [Enum.LFGEntryGeneralPlaystyle.Learning]   = GROUP_FINDER_GENERAL_PLAYSTYLE1,
    [Enum.LFGEntryGeneralPlaystyle.FunRelaxed] = GROUP_FINDER_GENERAL_PLAYSTYLE2,
    [Enum.LFGEntryGeneralPlaystyle.FunSerious] = GROUP_FINDER_GENERAL_PLAYSTYLE3,
    [Enum.LFGEntryGeneralPlaystyle.Expert]     = GROUP_FINDER_GENERAL_PLAYSTYLE4,
}

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

-- Teleport button has to be SecureActionButtonTemplate so the click
-- can run /cast — `CastSpellByID` from a non-secure OnClick fires
-- ADDON_ACTION_FORBIDDEN in retail. Retail's secure-frame system also
-- rejects anchoring a protected frame to any non-secure region
-- (FontString, sibling frame, or even the protected frame's own
-- non-secure parent), so the only universally allowed parent is
-- UIParent. The button lives there and mirrors `teleportSlot`'s
-- screen position via syncTeleportButton().
local teleportSlot = CreateFrame("Frame", nil, content)
teleportSlot:SetSize(24, 24)
teleportSlot:SetPoint("LEFT", lblPort, "LEFT", LABEL_WIDTH + 6, 0)

local teleportBtn = CreateFrame("Button", "WhatGroupFrameTeleportButton",
                                UIParent, "SecureActionButtonTemplate")
teleportBtn:SetSize(24, 24)
teleportBtn:SetFrameStrata("DIALOG")
teleportBtn:SetFrameLevel((f:GetFrameLevel() or 0) + 5)
teleportBtn:RegisterForClicks("AnyUp", "AnyDown")
teleportBtn:Hide()

local teleportIcon = teleportBtn:CreateTexture(nil, "ARTWORK")
teleportIcon:SetAllPoints()

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
    if WhatGroup._dbg then
        WhatGroup._dbg("ConfigureTeleportButton:",
            "info.activityID=" .. tostring(info and info.activityID),
            "info.mapID=" .. tostring(info and info.mapID),
            "spellID=" .. tostring(spellID))
    end
    if not spellID then
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
        btn:Hide()
        return
    end

    local spellName = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID))
                      or (GetSpellInfo and GetSpellInfo(spellID))
    local texID     = (C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID))
                      or 134400
    local known     = IsSpellKnown and IsSpellKnown(spellID)

    icon:SetTexture(texID)
    icon:SetDesaturated(not known)
    btn:SetAlpha(known and 1.0 or 0.5)

    if known and spellName then
        -- Secure-handler macro path: clicking runs `/cast <SpellName>`
        -- through Blizzard's secure action system, side-stepping the
        -- ADDON_ACTION_FORBIDDEN that a non-secure CastSpellByID hits.
        btn:SetAttribute("type", "macro")
        btn:SetAttribute("macrotext", "/cast " .. spellName)
        btn:EnableMouse(true)
        btn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spellID)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    else
        btn:SetAttribute("type", nil)
        btn:SetAttribute("macrotext", nil)
        btn:EnableMouse(false)
        btn:SetScript("OnEnter", nil)
        btn:SetScript("OnLeave", nil)
    end
    -- Visibility is set by syncTeleportButton (called from ShowFrame
    -- after f:Show so teleportSlot's screen position is finalized).
end

-- Mirror teleportBtn's screen position to teleportSlot's center.
-- Called from ShowFrame, the popup's drag-stop handler, and on
-- PLAYER_REGEN_ENABLED. Skips in combat — protected SetPoint is
-- blocked there (the post-combat event handler retries).
local function syncTeleportButton()
    if InCombatLockdown() then return end
    if not f:IsVisible() then
        teleportBtn:Hide()
        return
    end
    -- ConfigureTeleportButton clears the macro attribute when there's
    -- no mapped spell or the player doesn't know it.
    if teleportBtn:GetAttribute("type") ~= "macro" then
        teleportBtn:Hide()
        return
    end
    local cx, cy = teleportSlot:GetCenter()
    if not (cx and cy) then return end
    teleportBtn:ClearAllPoints()
    teleportBtn:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx, cy)
    teleportBtn:Show()
end

f:HookScript("OnHide", function() teleportBtn:Hide() end)
titleBar:HookScript("OnMouseUp", function() syncTeleportButton() end)

local _combatSync = CreateFrame("Frame")
_combatSync:RegisterEvent("PLAYER_REGEN_ENABLED")
_combatSync:SetScript("OnEvent", function() syncTeleportButton() end)

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

    -- Prefer the server-rendered playstyleString when present; otherwise
    -- look up the integer enum in PLAYSTYLE_LABELS. Empty string ("") and
    -- Enum.LFGEntryGeneralPlaystyle.None (= 0) both fall through to the
    -- dim em-dash placeholder.
    local playStyle = info.playstyleString
    if not playStyle or playStyle == "" then
        playStyle = PLAYSTYLE_LABELS[info.generalPlaystyle] or ""
    end
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
-- Public API: ShowFrame
-- ============================================================
function WhatGroup:ShowFrame()
    if WhatGroup._dbg then
        local info = WhatGroup.pendingInfo
        WhatGroup._dbg("ShowFrame: pendingInfo="
            .. (info
                and ("title=" .. tostring(info.title)
                     .. " mapID=" .. tostring(info.mapID)
                     .. " activityID=" .. tostring(info.activityID))
                or "NIL — popup will render 'No data' fallbacks"))
    end
    PopulateFields()
    f:Show()
    f:Raise()
    -- Inline sync catches the common case; deferred sync covers the
    -- race where the layout pass that resolves teleportSlot's screen
    -- position hasn't run yet on the inline call.
    syncTeleportButton()
    C_Timer.After(0, syncTeleportButton)
end
