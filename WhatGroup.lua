-- WhatGroup.lua
-- Core logic: events, data capture, chat message output

WhatGroup = WhatGroup or {}

local frame = CreateFrame("Frame")
local wasInGroup = false
local captureQueue        = {}   -- FIFO: captures awaiting their appID assignment
local pendingApplications = {}   -- [appID] -> capturedInfo, set when "applied" status arrives

WhatGroup.debug = false   -- toggled per-session with /wg debug; never saved to SVs

local function dbg(...)
    if WhatGroup.debug then
        print("|cffFF8C00[WhatGroup DBG]|r", ...)
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

    local header    = colorize("[WhatGroup]", "FFD700")
    local title     = colorize(info.title, "FFFFFF")
    local inst      = colorize(info.fullName ~= "" and info.fullName or "Unknown", "71d5ff")
    local typeStr   = info.shortName ~= "" and info.shortName or GetGroupTypeLabel(info)
    local leader    = colorize(info.leaderName, "FFFF00")
    local clickLink = colorize(link("WhatGroup:show", "[Click here to view details]"), "00FF7F")

    print(header .. " You have joined a group!")
    print("  - Group: "    .. title)
    print("  - Instance: " .. inst)
    print("  - Type: "     .. typeStr)
    print("  - Leader: "   .. leader)
    local playStyle = GetPlaystyleLabel(info)
    if playStyle ~= "" then
        print("  - Playstyle: " .. playStyle)
    end
    print("  - " .. clickLink)
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
-- Events
-- ============================================================
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...
        if addonName == "WhatGroup" then
            wasInGroup = IsInGroup()
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
        print("|cffFFD700[WhatGroup]|r Debug mode: " .. (WhatGroup.debug and "|cff00FF00ON|r" or "|cffFF4444OFF|r"))

    elseif cmd == "show" or cmd == "" then
        if WhatGroup.pendingInfo then
            WhatGroup:ShowFrame()
        else
            print("|cffFFD700[WhatGroup]|r No group info available. Use |cffFFFF00/wg test|r to preview.")
        end

    else
        print("|cffFFD700[WhatGroup]|r Commands:")
        print("  |cffFFFF00/wg|r          — show last group info dialog")
        print("  |cffFFFF00/wg test|r     — show dialog with fake test data")
        print("  |cffFFFF00/wg debug|r    — toggle debug logging")
        print("  |cffFFFF00/wg help|r     — show this help")
    end
end

