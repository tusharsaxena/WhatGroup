-- WhatGroup.lua
-- AceAddon shell, event handling, group-info capture, slash dispatch.
--
-- Settings layer lives in WhatGroup_Settings.lua (schema + helpers +
-- canvas panel). Frame UI lives in WhatGroup_Frame.lua. All persistent
-- user prefs go through self.db.profile via the Settings.Helpers
-- Get/Set path; capture/pending state is session-only and lives in
-- module-local tables.

-- ---------------------------------------------------------------------------
-- AceAddon bootstrap
-- ---------------------------------------------------------------------------
--
-- The plain `_G.WhatGroup` table that the legacy file populated is
-- promoted to an AceAddon, preserving every prior field. Downstream
-- files (Settings, Frame) read `_G.WhatGroup` and see the mixed-in
-- version with RegisterChatCommand / RegisterEvent / SecureHook /
-- RawHook / db / etc.

local existing = _G.WhatGroup or {}
local WhatGroup = LibStub("AceAddon-3.0"):NewAddon(
    existing, "WhatGroup",
    "AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0")
_G.WhatGroup = WhatGroup
WhatGroup.VERSION = "1.1.0"

local CHAT_PREFIX = "|cff00FFFF[WG]|r"

-- Session-only state. Cleared on group leave; never persisted.
local captureQueue        = {}   -- FIFO: captures awaiting their appID assignment
local pendingApplications = {}   -- [appID] -> capturedInfo (set when "applied" fires)
local wasInGroup          = false

local function dbg(...)
    if WhatGroup.debug then
        print(CHAT_PREFIX, "|cffFF8C00[DBG]|r", ...)
    end
end

local function p(...)
    print(CHAT_PREFIX, ...)
end
WhatGroup._print = p

-- ---------------------------------------------------------------------------
-- Teleport spell lookup
-- ---------------------------------------------------------------------------

WhatGroup.TeleportSpells = {
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

local function colorize(text, hex)
    return "|cff" .. hex .. text .. "|r"
end

local function link(linkData, display)
    return "|H" .. linkData .. "|h" .. display .. "|h"
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

function WhatGroup:OnInitialize()
    -- WhatGroup_Settings.lua loads after this file but BEFORE OnInitialize
    -- fires (OnInitialize runs on ADDON_LOADED, after every TOC line has
    -- executed). So Settings.BuildDefaults is guaranteed to exist here.
    local defaults = self.Settings and self.Settings.BuildDefaults
                     and self.Settings.BuildDefaults()
                     or { profile = {} }

    self.db = LibStub("AceDB-3.0"):New("WhatGroupDB", defaults, true)

    -- Seed runtime debug flag from the persisted preference. /wg debug
    -- and the schema setter both write back to db.profile.debug so this
    -- stays in sync.
    self.debug = self.db.profile.debug and true or false

    self:RegisterChatCommand("wg",        "OnSlashCommand")
    self:RegisterChatCommand("whatgroup", "OnSlashCommand")
end

function WhatGroup:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")

    -- SecureHook observes ApplyToGroup AFTER the original runs. We only
    -- need to read GetSearchResultInfo for the same searchResultID, so
    -- before/after doesn't matter for correctness.
    self:SecureHook(C_LFGList, "ApplyToGroup", "OnApplyToGroup")

    -- SetItemRef must intercept (return early) on our custom link, so
    -- RawHook is required — SecureHook can't short-circuit the original.
    self:RawHook("SetItemRef", "OnSetItemRef", true)

    wasInGroup = IsInGroup()

    -- Settings panel registration is deferred via the Settings module
    -- so we don't need to know its internals here.
    if self.Settings and self.Settings.Register then
        self.Settings.Register()
    end
end

-- ---------------------------------------------------------------------------
-- Group-info capture
-- ---------------------------------------------------------------------------

function WhatGroup:CaptureGroupInfo(searchResultID)
    local info = C_LFGList.GetSearchResultInfo(searchResultID)
    dbg("GetSearchResultInfo returned:", info ~= nil)
    if self.debug and info then
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

    local firstActivityID = captured.activityIDs[1]
    if firstActivityID then
        captured.activityID = firstActivityID
        local actInfo = C_LFGList.GetActivityInfoTable
                        and C_LFGList.GetActivityInfoTable(firstActivityID)
        if actInfo then
            captured.fullName       = actInfo.fullName or actInfo.activityName or ""
            captured.activityName   = actInfo.activityName or ""
            captured.maxNumPlayers  = actInfo.maxNumPlayers or 0
            captured.isMythicPlus   = actInfo.isMythicPlusActivity or false
            captured.isCurrentRaid  = actInfo.isCurrentRaidActivity or false
            captured.isHeroicRaid   = actInfo.isHeroicRaidActivity or false
            captured.categoryID     = actInfo.categoryID or 0
            captured.shortName      = actInfo.shortName or ""
        end
    end

    return captured
end

function WhatGroup:GetTeleportSpell(activityID, mapID)
    if activityID and self.TeleportSpells[activityID] then
        return self.TeleportSpells[activityID]
    end
    if mapID and self.TeleportSpells[mapID] then
        return self.TeleportSpells[mapID]
    end
    return nil
end

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

-- ---------------------------------------------------------------------------
-- Chat notification
-- ---------------------------------------------------------------------------

function WhatGroup:ShowNotification()
    local info = self.pendingInfo
    if not info then return end
    local n = self.db and self.db.profile and self.db.profile.notify
    if not n or not n.enabled then return end

    local gold      = "FFD700"
    local clickLink = colorize(link("WhatGroup:show", "[Click here to view details]"), "00FF7F")

    print(CHAT_PREFIX .. " You have joined a group!")
    print(CHAT_PREFIX .. "   - " .. colorize("Group:", gold) .. " " .. info.title)

    if n.showInstance then
        print(CHAT_PREFIX .. "   - " .. colorize("Instance:", gold)
              .. " " .. (info.fullName ~= "" and info.fullName or "Unknown"))
    end
    if n.showType then
        local typeStr = info.shortName ~= "" and info.shortName or GetGroupTypeLabel(info)
        print(CHAT_PREFIX .. "   - " .. colorize("Type:", gold) .. " " .. typeStr)
    end
    if n.showLeader then
        print(CHAT_PREFIX .. "   - " .. colorize("Leader:", gold) .. " " .. info.leaderName)
    end
    if n.showPlaystyle then
        local playStyle = GetPlaystyleLabel(info)
        if playStyle ~= "" then
            print(CHAT_PREFIX .. "   - " .. colorize("Playstyle:", gold) .. " " .. playStyle)
        end
    end
    if n.showTeleport then
        local spellID = self:GetTeleportSpell(info.activityID, info.mapID)
        if spellID then
            local spellLink = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID)
                              or ("|cff71d5ff[Spell " .. spellID .. "]|r")
            local known = IsSpellKnown and IsSpellKnown(spellID)
            local note  = known and "" or " |cff888888(not learned)|r"
            print(CHAT_PREFIX .. "   - " .. colorize("Teleport:", gold) .. " " .. spellLink .. note)
        end
    end
    if n.showClickLink then
        print(CHAT_PREFIX .. "   - " .. clickLink)
    end
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

function WhatGroup:OnApplyToGroup(searchResultID, ...)
    -- Master enable gate: when disabled, the addon ignores the apply
    -- entirely so no capture → no pendingInfo → no notification or
    -- popup later. /wg test and /wg show still work (they bypass the
    -- capture pipeline) so the user can preview / re-view at any time.
    if not (self.db and self.db.profile and self.db.profile.enabled) then
        return
    end
    dbg("ApplyToGroup hook fired, searchResultID:", tostring(searchResultID))
    local captured = self:CaptureGroupInfo(searchResultID)
    if captured then
        table.insert(captureQueue, captured)
    end
end

function WhatGroup:OnSetItemRef(linkArg, text, button, ...)
    if linkArg and linkArg:match("^WhatGroup:") then
        self:ShowFrame()
        return
    end
    return self.hooks.SetItemRef(linkArg, text, button, ...)
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

function WhatGroup:GROUP_ROSTER_UPDATE()
    local inGroup = IsInGroup()
    dbg("GROUP_ROSTER_UPDATE inGroup:", tostring(inGroup),
        "wasInGroup:", tostring(wasInGroup),
        "hasPending:", tostring(self.pendingInfo ~= nil))

    if inGroup and not wasInGroup and self.pendingInfo then
        local delay = (self.db and self.db.profile and self.db.profile.notify
                       and self.db.profile.notify.delay) or 1.5
        local autoShow = not (self.db and self.db.profile and self.db.profile.frame
                              and self.db.profile.frame.autoShow == false)
        C_Timer.After(delay, function()
            self:ShowNotification()
            if autoShow then self:ShowFrame() end
        end)
    end
    wasInGroup = inGroup

    if not inGroup then
        self.pendingInfo = nil
        wipe(captureQueue)
        wipe(pendingApplications)
    end
end

function WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED(event, appID, newStatus)
    dbg("LFG_LIST_APPLICATION_STATUS_UPDATED appID:", tostring(appID),
        "status:", tostring(newStatus))
    if newStatus == "applied" then
        local capture = table.remove(captureQueue, 1)
        if capture then
            pendingApplications[appID] = capture
        end
    elseif newStatus == "invited" then
        -- Wait for the user to accept; multiple invites can arrive.
    elseif newStatus == "inviteaccepted" then
        local info = pendingApplications[appID]
        if info then
            self.pendingInfo = info
        end
        wipe(captureQueue)
        wipe(pendingApplications)
    end
end

-- ---------------------------------------------------------------------------
-- Slash dispatch
-- ---------------------------------------------------------------------------
--
-- Two ordered tables drive the slash UX. Adding a command = one row;
-- help text is generated by iterating the table so it stays in sync.

local function trim(s)
    return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function helpers()
    return WhatGroup.Settings and WhatGroup.Settings.Helpers
end

local function formatValue(def, v)
    if v == nil then return "nil" end
    if def.type == "number" then
        if def.fmt then return def.fmt:format(v) end
        return tostring(v)
    end
    return tostring(v)
end

-- Forward declarations so the COMMANDS table can reference handlers
-- before they're defined below.
local printHelp, listSettings, getSetting, setSetting
local runReset, runShow, runTest, runConfig, runDebug

local COMMANDS = {
    {"help",   "List available commands",
        function(self) printHelp(self) end},
    {"show",   "Show the last group info dialog",
        function(self) runShow(self) end},
    {"test",   "Inject synthetic group info and run the full notify + frame flow",
        function(self) runTest(self) end},
    {"config", "Open the Ka0s WhatGroup Settings panel",
        function(self) runConfig(self) end},
    {"list",   "List every setting and its current value",
        function(self) listSettings(self) end},
    {"get",    "Print a setting's current value — `/wg get <path>`",
        function(self, rest) getSetting(self, rest) end},
    {"set",    "Set a setting — `/wg set <path> <value>` (try /wg list)",
        function(self, rest) setSetting(self, rest) end},
    {"reset",  "Reset every setting to defaults",
        function(self) runReset(self) end},
    {"debug",  "Toggle debug logging",
        function(self) runDebug(self) end},
}
WhatGroup.COMMANDS = COMMANDS

local function findCommand(list, name)
    for _, entry in ipairs(list) do
        if entry[1] == name then return entry end
    end
end

function printHelp(self)
    p("v" .. WhatGroup.VERSION
      .. " — slash commands (|cffFFFF00/whatgroup|r is an alias for |cffFFFF00/wg|r):")
    for _, entry in ipairs(COMMANDS) do
        p(("  |cffFFFF00/wg %s|r — |cffFFFFFF%s|r"):format(entry[1], entry[2]))
    end
end

function WhatGroup:OnSlashCommand(input)
    local raw = trim(input)
    if raw == "" then return printHelp(self) end

    -- Lowercase only the command name; preserve case in `rest` so schema
    -- paths like `notify.showInstance` survive `/wg set ...`.
    local cmd, rest = raw:match("^(%S+)%s*(.*)$")
    cmd  = (cmd or ""):lower()
    rest = rest or ""

    local entry = findCommand(COMMANDS, cmd)
    if entry then return entry[3](self, rest) end

    p("unknown command '" .. cmd .. "'")
    printHelp(self)
end

-- ---------------------------------------------------------------------------
-- Schema-driven /wg list|get|set
-- ---------------------------------------------------------------------------

function listSettings(self)
    local H = helpers()
    if not (H and self.Settings.Schema) then
        return p("Settings layer not ready yet")
    end
    p("Available settings:")
    -- Group by section for readable output. Skip rows without a path
    -- (e.g. type="action" buttons) — they have no value to display.
    local bySection, order = {}, {}
    for _, def in ipairs(self.Settings.Schema) do
        if def.path then
            local key = def.section or "?"
            if not bySection[key] then
                bySection[key] = {}
                order[#order + 1] = key
            end
            table.insert(bySection[key], def)
        end
    end
    for _, key in ipairs(order) do
        p("  [" .. key .. "]")
        for _, def in ipairs(bySection[key]) do
            p(("    %s = %s"):format(def.path, formatValue(def, H.Get(def.path))))
        end
    end
end

function getSetting(self, rest)
    local H = helpers()
    if not H then return p("Settings layer not ready yet") end
    local path = (rest or ""):match("^(%S+)")
    if not path or path == "" then
        return p("Usage: /wg get <path>")
    end
    local def = H.FindSchema(path)
    if not def then
        return p(("Setting not found: %s"):format(path))
    end
    p(("%s = %s"):format(def.path, formatValue(def, H.Get(def.path))))
end

local function applyFromText(self, def, text)
    local H = helpers()
    if not H then return p("Settings layer not ready yet") end

    local args = {}
    for w in (text or ""):gmatch("%S+") do args[#args + 1] = w end

    local function fail(reason)
        p(("Invalid value for %s"):format(def.path))
        if reason and reason ~= "" then p("  " .. reason) end
    end

    local newValue
    if def.type == "bool" then
        local s = (args[1] or ""):lower()
        if s == "true" or s == "1" or s == "on"  or s == "yes" then newValue = true
        elseif s == "false" or s == "0" or s == "off" or s == "no" then newValue = false
        elseif s == "toggle" then newValue = not H.Get(def.path)
        else return fail("expected true/false/on/off/1/0/toggle") end
    elseif def.type == "number" then
        local n = tonumber(args[1])
        if not n then return fail("expected a number") end
        if def.min then n = math.max(def.min, n) end
        if def.max then n = math.min(def.max, n) end
        newValue = n
    else
        return fail("unknown setting type '" .. tostring(def.type) .. "'")
    end

    H.Set(def.path, newValue)
    if def.onChange then
        local ok, err = pcall(def.onChange, newValue)
        if not ok then p("onChange failed: " .. tostring(err)) end
    end
    if H.RefreshAll then H.RefreshAll() end

    p(("%s = %s"):format(def.path, formatValue(def, H.Get(def.path))))
end

function setSetting(self, rest)
    local H = helpers()
    if not H then return p("Settings layer not ready yet") end
    local path, value = (rest or ""):match("^(%S+)%s*(.*)$")
    if not path or path == "" then
        return p("Usage: /wg set <path> <value>")
    end
    local def = H.FindSchema(path)
    if not def then
        return p(("Setting not found: %s"):format(path))
    end
    applyFromText(self, def, value or "")
end

-- ---------------------------------------------------------------------------
-- Action commands
-- ---------------------------------------------------------------------------

function runReset(self)
    local H = helpers()
    if not (H and H.RestoreDefaults) then
        return p("Settings layer not ready yet")
    end
    -- Route through the same popup the Defaults button uses so both
    -- code paths share one OnAccept body (defined in WhatGroup_Settings.lua).
    if StaticPopup_Show then
        StaticPopup_Show("WHATGROUP_RESET_ALL")
    else
        H.RestoreDefaults()
        p("all settings reset to defaults")
    end
end

function runShow(self)
    if self.pendingInfo then
        self:ShowFrame()
    else
        p("No group info available. Use |cffFFFF00/wg test|r to preview.")
    end
end

-- Public method so the Settings panel's Test button can invoke the
-- same code path as /wg test without going through the slash dispatch.
function WhatGroup:RunTest()
    self.pendingInfo = {
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
        playstyle     = 2,
        shortName     = "Mythic+",
    }
    self:ShowNotification()
    self:ShowFrame()
end

function runTest(self) self:RunTest() end

function runConfig(self)
    local category = self._settingsCategory
    if Settings and Settings.OpenToCategory and category then
        Settings.OpenToCategory(category:GetID())
    else
        p("Settings panel is not available.")
    end
end

function runDebug(self)
    local H = helpers()
    local newVal = not self.debug
    self.debug = newVal
    -- Persist via the schema path so the Settings checkbox refreshes.
    -- Falls back to a direct write only if the settings layer isn't
    -- loaded yet (early-boot edge).
    if H and H.Set then
        H.Set("debug", newVal)
        if H.RefreshAll then H.RefreshAll() end
    elseif self.db and self.db.profile then
        self.db.profile.debug = newVal
    end
    p("Debug mode: " .. (newVal and "|cff00FF00ON|r" or "|cffFF4444OFF|r"))
end
