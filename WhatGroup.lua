-- WhatGroup.lua
-- Core logic: events, data capture, chat message output

WhatGroup = WhatGroup or {}

local frame = CreateFrame("Frame")
local wasInGroup = false
local captureQueue        = {}   -- FIFO: captures awaiting their appID assignment
local pendingApplications = {}   -- [appID] -> capturedInfo, set when "applied" status arrives

WhatGroup.debug = false   -- toggled per-session with /wg debug; never saved to SVs

local CHAT_PREFIX = "|cff00FFFF[WG]|r"

local function dbg(...)
    if WhatGroup.debug then
        print(CHAT_PREFIX, "|cffFF8C00[DBG]|r", ...)
    end
end

-- ============================================================
-- Teleport Spell Lookup Table
-- Keys are activityIDs or instanceIDs mapped to spellIDs.
-- Spells are shown grayed if not known, clickable if known.
-- ============================================================
WhatGroup.TeleportSpells = {
    -- Dragonflight era dungeon teleports (still available in Midnight)
    -- Brackenhide Hollow
    [2522] = 393256,
    -- Halls of Infusion
    [2526] = 393262,
    -- Neltharus
    [2519] = 393279,
    -- Ruby Life Pools
    [2521] = 393265,
    -- The Azure Vault
    [2515] = 393273,
    -- The Nokhud Offensive
    [2516] = 393276,
    -- Uldaman: Legacy of Tyr
    [2451] = 393222,
    -- Algeth'ar Academy
    [2526] = 393270,
    -- Dawn of the Infinite: Galakrond's Fall
    [2579] = 424163,
    -- Dawn of the Infinite: Murozond's Rise
    [2580] = 424167,
    -- Waycrest Manor
    [1862] = 322118,
    -- Siege of Boralus
    [1822] = 322746,
    -- Tol Dagor
    [1841] = 324235,
    -- Mechagon: Workshop
    [2097] = 324802,
    -- Operation: Mechagon - Junkyard
    [2097] = 323822,
}

-- ============================================================
-- Utility: Build colored chat string
-- ============================================================
local function colorize(text, hex)
    return "|cff" .. hex .. text .. "|r"
end

local function link(linkData, display)
    return "|H" .. linkData .. "|h" .. display .. "|h"
end

-- ============================================================
-- Data Capture
-- ============================================================
function WhatGroup:CaptureGroupInfo(searchResultID)
    local info = C_LFGList.GetSearchResultInfo(searchResultID)
    dbg("GetSearchResultInfo returned:", info ~= nil)
    if WhatGroup.debug and info then
        for k, v in pairs(info) do dbg("  info." .. tostring(k), "=", tostring(v)) end
    end
    if not info then return end

    local captured = {
        title       = info.name or info.title or "Unknown",
        leaderName  = info.leaderName or "Unknown",
        numMembers  = info.numMembers or 0,
        voiceChat   = info.voiceChat or "",
        playstyle   = info.playstyle or 0,
        age         = info.age or 0,
        activityIDs = info.activityIDs or (info.activityID and {info.activityID}) or {},
        activityID  = nil,
        fullName    = "",
        activityName= "",
        maxNumPlayers       = 0,
        isMythicPlus        = false,
        isCurrentRaid       = false,
        isHeroicRaid        = false,
        categoryID          = 0,
        mapID               = nil,
    }

    -- Resolve first activity ID for display info
    local firstActivityID = captured.activityIDs[1]
    dbg("firstActivityID:", tostring(firstActivityID))
    dbg("GetActivityInfoTable exists:", tostring(C_LFGList.GetActivityInfoTable ~= nil))
    if firstActivityID then
        captured.activityID = firstActivityID
        local actInfo = C_LFGList.GetActivityInfoTable and C_LFGList.GetActivityInfoTable(firstActivityID)
        dbg("actInfo:", tostring(actInfo ~= nil))
        if WhatGroup.debug and actInfo then
            for k, v in pairs(actInfo) do dbg("  actInfo." .. tostring(k), "=", tostring(v)) end
        end
        if actInfo then
            captured.fullName           = actInfo.fullName or actInfo.activityName or ""
            captured.activityName       = actInfo.activityName or ""
            captured.maxNumPlayers      = actInfo.maxNumPlayers or 0
            captured.isMythicPlus       = actInfo.isMythicPlusActivity or false
            captured.isCurrentRaid      = actInfo.isCurrentRaidActivity or false
            captured.isHeroicRaid       = actInfo.isHeroicRaidActivity or false
            captured.categoryID         = actInfo.categoryID or 0
            captured.shortName          = actInfo.shortName or ""
        end
    end

    dbg("captured.fullName:", tostring(captured.fullName))
    dbg("captured.activityID:", tostring(captured.activityID))
    return captured
end

-- ============================================================
-- Teleport spell helper
-- ============================================================
function WhatGroup:GetTeleportSpell(activityID, mapID)
    if activityID and WhatGroup.TeleportSpells[activityID] then
        return WhatGroup.TeleportSpells[activityID]
    end
    if mapID and WhatGroup.TeleportSpells[mapID] then
        return WhatGroup.TeleportSpells[mapID]
    end
    return nil
end

-- ============================================================
-- Determine group type label
-- ============================================================
local function GetGroupTypeLabel(info)
    if info.isMythicPlus then
        return "Mythic+"
    elseif info.isCurrentRaid then
        return "Raid (Current)"
    elseif info.isHeroicRaid then
        return "Heroic Raid"
    elseif info.categoryID == 2 then
        return "PvP"
    elseif info.categoryID == 1 then
        return "Dungeon"
    elseif info.maxNumPlayers and info.maxNumPlayers >= 10 then
        return "Raid"
    elseif info.maxNumPlayers and info.maxNumPlayers > 0 then
        return "Dungeon"
    else
        return "Group"
    end
end

local PLAYSTYLE_LABELS = { [1] = "Casual", [2] = "Moderate", [3] = "Serious" }
local function GetPlaystyleLabel(info)
    return PLAYSTYLE_LABELS[info.playstyle] or ""
end

-- ============================================================
-- Chat Notification
-- ============================================================
function WhatGroup:ShowNotification()
    local info = WhatGroup.pendingInfo
    if not info then return end

    local gold = "FFD700"
    local clickLink = colorize(link("WhatGroup:show", "[Click here to view details]"), "00FF7F")

    print(CHAT_PREFIX .. " You have joined a group!")
    print(CHAT_PREFIX .. "   - " .. colorize("Group:", gold) .. " " .. info.title)
    print(CHAT_PREFIX .. "   - " .. colorize("Instance:", gold) .. " " .. (info.fullName ~= "" and info.fullName or "Unknown"))
    local typeStr = info.shortName ~= "" and info.shortName or GetGroupTypeLabel(info)
    print(CHAT_PREFIX .. "   - " .. colorize("Type:", gold) .. " " .. typeStr)
    print(CHAT_PREFIX .. "   - " .. colorize("Leader:", gold) .. " " .. info.leaderName)
    local playStyle = GetPlaystyleLabel(info)
    if playStyle ~= "" then
        print(CHAT_PREFIX .. "   - " .. colorize("Playstyle:", gold) .. " " .. playStyle)
    end
    print(CHAT_PREFIX .. "   - " .. clickLink)
end

-- ============================================================
-- Hyperlink handler — clicking the chat link re-opens frame
-- ============================================================
local origSetItemRef = SetItemRef
SetItemRef = function(linkArg, text, button, ...)
    if linkArg and linkArg:match("^WhatGroup:") then
        WhatGroup:ShowFrame()
        return
    end
    return origSetItemRef(linkArg, text, button, ...)
end

-- ============================================================
-- Hook C_LFGList.ApplyToGroup to capture info at apply time
-- ============================================================
local origApplyToGroup = C_LFGList.ApplyToGroup
C_LFGList.ApplyToGroup = function(searchResultID, ...)
    dbg("ApplyToGroup hook fired, searchResultID:", tostring(searchResultID))
    local captured = WhatGroup:CaptureGroupInfo(searchResultID)
    if captured then
        table.insert(captureQueue, captured)
    end
    return origApplyToGroup(searchResultID, ...)
end

-- Backup: also capture on application status update
frame:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

-- ============================================================
-- Settings panel registration (ESC > Options > AddOns)
-- Ensures the addon appears as "Ka0s WhatGroup" in the in-game
-- Settings UI sidebar. Idempotent: skips if already registered.
-- ============================================================
function WhatGroup:RegisterSettingsPanel()
    if WhatGroup._settingsRegistered or not Settings or not Settings.RegisterAddOnCategory then
        return
    end

    local displayName = "Ka0s WhatGroup"
    local panel = CreateFrame("Frame", "WhatGroupSettingsPanel", UIParent)
    panel.name = displayName

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("|cffFFD700Ka0s WhatGroup|r")

    local body = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    body:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    body:SetJustifyH("LEFT")
    body:SetJustifyV("TOP")
    body:SetSpacing(4)
    body:SetText(table.concat({
        "Notifies you of group details after joining via Premade Group Finder.",
        " ",
        "Slash commands (|cffFFFF00/whatgroup|r is an alias of |cffFFFF00/wg|r):",
        "  |cffFFFF00/wg|r          — show help",
        "  |cffFFFF00/wg show|r     — show last group info dialog",
        "  |cffFFFF00/wg test|r     — preview the dialog with fake data",
        "  |cffFFFF00/wg config|r   — open this Settings panel",
        "  |cffFFFF00/wg debug|r    — toggle debug logging",
        "  |cffFFFF00/wg help|r     — list commands",
        " ",
        "No saved settings — state is session-only and clears on group leave.",
    }, "\n"))

    local category = Settings.RegisterCanvasLayoutCategory(panel, displayName)
    Settings.RegisterAddOnCategory(category)
    WhatGroup._settingsCategory = category
    WhatGroup._settingsRegistered = true
end

-- ============================================================
-- Events
-- ============================================================
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WhatGroup" then
            wasInGroup = IsInGroup()
            WhatGroup:RegisterSettingsPanel()
        end

    elseif event == "GROUP_ROSTER_UPDATE" then
        local inGroup = IsInGroup()
        dbg("GROUP_ROSTER_UPDATE inGroup:", tostring(inGroup), "wasInGroup:", tostring(wasInGroup), "hasPending:", tostring(WhatGroup.pendingInfo ~= nil))
        if inGroup and not wasInGroup and WhatGroup.pendingInfo then
            -- Small delay to allow zone-in to settle
            C_Timer.After(1.5, function()
                WhatGroup:ShowNotification()
                WhatGroup:ShowFrame()
            end)
        end
        wasInGroup = inGroup

        -- Clear pending info on leaving group
        if not inGroup then
            WhatGroup.pendingInfo = nil
            wipe(captureQueue)
            wipe(pendingApplications)
        end

    elseif event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
        local appID, newStatus = ...
        dbg("LFG_LIST_APPLICATION_STATUS_UPDATED appID:", tostring(appID), "status:", tostring(newStatus))
        if newStatus == "applied" then
            -- Correlate the most-recent ApplyToGroup capture with this appID
            local capture = table.remove(captureQueue, 1)
            if capture then
                pendingApplications[appID] = capture
                dbg("Stored capture for appID:", tostring(appID))
            end
        elseif newStatus == "invited" then
            -- Leader accepted us — keep data in pendingApplications, do not set pendingInfo yet.
            -- Multiple invites can arrive simultaneously; we wait for the user to accept one.
            dbg("Invite received for appID:", tostring(appID), "(waiting for inviteaccepted)")
        elseif newStatus == "inviteaccepted" then
            -- User clicked Accept on this specific invite — this is the group they are joining.
            local info = pendingApplications[appID]
            if info then
                WhatGroup.pendingInfo = info
                dbg("pendingInfo set from inviteaccepted appID:", tostring(appID))
            end
            -- Clean up all pending state (only one group can be joined)
            wipe(captureQueue)
            wipe(pendingApplications)
        end
    end
end)

-- ============================================================
-- Slash commands: /wg [test|show|help]  and  /whatgroup [...]
-- ============================================================
SLASH_WHATGROUP1 = "/wg"
SLASH_WHATGROUP2 = "/whatgroup"

local function PrintHelp()
    print(CHAT_PREFIX .. " |cffFFFFFFCommands (|r|cffFFFF00/whatgroup|r|cffFFFFFF is an alias of |r|cffFFFF00/wg|r|cffFFFFFF):|r")
    print(CHAT_PREFIX .. "   |cffFFFF00/wg|r          |cffFFFFFF— show this help|r")
    print(CHAT_PREFIX .. "   |cffFFFF00/wg show|r     |cffFFFFFF— show last group info dialog|r")
    print(CHAT_PREFIX .. "   |cffFFFF00/wg test|r     |cffFFFFFF— show dialog with fake test data|r")
    print(CHAT_PREFIX .. "   |cffFFFF00/wg config|r   |cffFFFFFF— open the Settings panel|r")
    print(CHAT_PREFIX .. "   |cffFFFF00/wg debug|r    |cffFFFFFF— toggle debug logging|r")
    print(CHAT_PREFIX .. "   |cffFFFF00/wg help|r     |cffFFFFFF— show this help|r")
end

SlashCmdList["WHATGROUP"] = function(msg)
    local cmd = msg and msg:lower():match("^%s*(%S*)") or ""

    if cmd == "test" then
        -- Inject synthetic pendingInfo so all UI paths are exercised
        WhatGroup.pendingInfo = {
            title         = "Test Group — Stonevault +12",
            leaderName    = "Testadin-Silvermoon",
            numMembers    = 3,
            voiceChat     = "",
            age           = 127,
            activityIDs   = {2516},
            activityID    = 2516,
            fullName      = "Dungeons > Mythic+ > The Stonevault",
            activityName  = "The Stonevault",
            maxNumPlayers = 5,
            isMythicPlus  = true,
            isCurrentRaid = false,
            isHeroicRaid  = false,
            categoryID    = 1,
            mapID         = nil,
            playstyle     = 2,   -- "Moderate"
            shortName     = "Mythic+",
        }
        WhatGroup:ShowNotification()
        WhatGroup:ShowFrame()

    elseif cmd == "debug" then
        WhatGroup.debug = not WhatGroup.debug
        print(CHAT_PREFIX .. " Debug mode: " .. (WhatGroup.debug and "|cff00FF00ON|r" or "|cffFF4444OFF|r"))

    elseif cmd == "config" then
        local category = WhatGroup._settingsCategory
        if Settings and Settings.OpenToCategory and category then
            Settings.OpenToCategory(category:GetID())
        else
            print(CHAT_PREFIX .. " Settings panel is not available.")
        end

    elseif cmd == "show" then
        if WhatGroup.pendingInfo then
            WhatGroup:ShowFrame()
        else
            print(CHAT_PREFIX .. " No group info available. Use |cffFFFF00/wg test|r to preview.")
        end

    else
        PrintHelp()
    end
end

