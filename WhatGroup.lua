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
-- version with RegisterChatCommand / RegisterEvent / db / etc. Hooks
-- are direct `hooksecurefunc` post-hooks installed at file-load
-- (below) — not AceHook. AceHook adds a per-invocation closure that
-- taints Blizzard's secure-execute chain at GameMenu Logout time.

local existing = _G.WhatGroup or {}
local WhatGroup = LibStub("AceAddon-3.0"):NewAddon(
    existing, "WhatGroup",
    "AceConsole-3.0", "AceEvent-3.0")
_G.WhatGroup = WhatGroup
WhatGroup.VERSION = "1.1.0"

-- Direct `hooksecurefunc` post-hooks installed at file-load (NOT in
-- OnEnable). Hooks live at the top of the file; the addon table is
-- the only persistent reference; no closures captured from event
-- handlers. Installing these in OnEnable (PLAYER_LOGIN) was tainting
-- Blizzard's GameMenu callbacks — the closures Blizzard builds for
-- Logout/Settings/Macros buttons were inheriting our addon's
-- load-time taint and rejecting their secure-execute calls with
-- ADDON_ACTION_FORBIDDEN. File-load hook registration runs before
-- GameMenu's InitButtons builds those closures, so they remain
-- taint-free.
hooksecurefunc(C_LFGList, "ApplyToGroup", function(searchResultID, ...)
    if WhatGroup.OnApplyToGroup then
        WhatGroup:OnApplyToGroup(searchResultID, ...)
    end
end)

hooksecurefunc("SetItemRef", function(linkArg, text, button, ...)
    if type(linkArg) ~= "string" then return end
    if not linkArg:match("^WhatGroup:") then return end
    if WhatGroup.OnSetItemRef then
        WhatGroup:OnSetItemRef(linkArg, text, button, ...)
    end
end)

local CHAT_PREFIX = "|cff00FFFF[WG]|r"

-- Session-only state. Cleared on group leave; never persisted.
local captureQueue        = {}   -- FIFO: captures awaiting their appID assignment
local pendingApplications = {}   -- [appID] -> capturedInfo (set when "applied" fires)
local wasInGroup          = false
local notifiedFor         = nil  -- pendingInfo identity that already fired notify+popup

local function dbg(...)
    if WhatGroup.debug then
        print(CHAT_PREFIX, "|cffFF8C00[DBG]|r", ...)
    end
end

local function p(...)
    print(CHAT_PREFIX, ...)
end
WhatGroup._print = p
-- Public so WhatGroup_Frame.lua can route its diagnostic prints
-- through the same prefix path; users still toggle via /wg debug.
WhatGroup._dbg   = dbg

-- ---------------------------------------------------------------------------
-- Teleport spell lookup
-- ---------------------------------------------------------------------------

-- Keyed by mapID (the dungeon's instance map ID — stable across seasons).
-- mapID is captured into pendingInfo.mapID from
-- C_LFGList.GetActivityInfoTable's mapID field; activityIDs rotate per
-- season and aren't reliable lookup keys.
--
-- Values are either a single spellID (number) or a list of candidates
-- (table). When multiple Path-of spells have been issued for the same
-- dungeon over the years (e.g. an original spell + a later refresh),
-- list both — `GetTeleportSpell` picks whichever the player actually
-- knows via IsSpellKnown.
--
-- Primary source for spell IDs and names:
--   https://warcraft.wiki.gg/wiki/Category:Instance_teleport_abilities
--
-- Each entry below cites the wiki spell page in its trailing comment so
-- the validation chain is auditable. Entries without a learnable
-- Path-of spell on the wiki (Eye of Azshara, Maw of Souls, The Arcway,
-- Vault of the Wardens, Cathedral of Eternal Night) are absent.
--
-- Refresh recipe (new season / patch): see
-- docs/common-tasks.md → "Add a dungeon teleport spell mapping".
WhatGroup.TeleportSpells = {

    -- ===== Cataclysm =====
    [643]  = 424142,              -- Throne of the Tides                — Path of the Tidehunter
    [657]  = 410080,              -- The Vortex Pinnacle                — Path of Wind's Domain
    [658]  = 1254555,             -- Pit of Saron                       — Path of Unyielding Blight
    [670]  = 445424,              -- Grim Batol                         — Path of the Twilight Fortress

    -- ===== Mists of Pandaria =====
    [959]  = 131206,              -- Shado-Pan Monastery                — Path of the Shado-Pan
    [960]  = 131204,              -- Temple of the Jade Serpent         — Path of the Jade Serpent
    [961]  = 131205,              -- Stormstout Brewery                 — Path of the Stout Brew
    [962]  = 131225,              -- Gate of the Setting Sun            — Path of the Setting Sun
    [994]  = 131222,              -- Mogu'shan Palace                   — Path of the Mogu King
    [1001] = 131229,              -- Scarlet Monastery                  — Path of the Scarlet Mitre
    [1004] = 131231,              -- Scarlet Halls                      — Path of the Scarlet Blade
    [1007] = 131232,              -- Scholomance                        — Path of the Necromancer
    [1011] = 131228,              -- Siege of Niuzao Temple             — Path of the Black Ox

    -- ===== Warlords of Draenor =====
    [1175] = 159895,              -- Bloodmaul Slag Mines               — Path of the Bloodmaul
    [1176] = 159899,              -- Shadowmoon Burial Grounds          — Path of the Crescent Moon
    [1182] = 159897,              -- Auchindoun                         — Path of the Vigilant
    [1195] = 159896,              -- Iron Docks                         — Path of the Iron Prow
    [1208] = 159900,              -- Grimrail Depot                     — Path of the Dark Rail
    [1209] = { 159898, 1254557 }, -- Skyreach                           — Path of the Skies / Path of the Crowning Pinnacle
    [1279] = 159901,              -- The Everbloom                      — Path of the Verdant
    [1358] = 159902,              -- Upper Blackrock Spire              — Path of the Burning Mountain

    -- ===== Legion =====
    [1458] = 410078,              -- Neltharion's Lair                  — Path of the Earth-Warder
    [1466] = 424163,              -- Darkheart Thicket                  — Path of the Nightmare Lord
    [1477] = 393764,              -- Halls of Valor                     — Path of Proven Worth
    [1501] = 424153,              -- Black Rook Hold                    — Path of Ancient Horrors
    [1571] = 393766,              -- Court of Stars                     — Path of the Grand Magistrix
    [1651] = 373262,              -- Return to Karazhan                 — Path of the Fallen Guardian
    [1753] = 1254551,             -- Seat of the Triumvirate            — Path of Dark Dereliction

    -- ===== Battle for Azeroth =====
    [1594] = 467553,              -- The MOTHERLODE!!                   — Path of the Azerite Refinery
    [1754] = 410071,              -- Freehold                           — Path of the Freebooter
    [1763] = 424187,              -- Atal'Dazar                         — Path of the Golden Tomb
    [1822] = 445418,              -- Siege of Boralus                   — Path of the Besieged Harbor
    [1841] = 410074,              -- The Underrot                       — Path of Festering Rot
    [1862] = 424167,              -- Waycrest Manor                     — Path of Heart's Bane
    [2097] = 373274,              -- Operation: Mechagon                — Path of the Scrappy Prince     (legacy mega-dungeon ID; the M+ split versions Workshop and Junkyard appear to share this mapID, but verify in-game if a player reports the icon missing)

    -- ===== Shadowlands =====
    [2284] = 354469,              -- Sanguine Depths                    — Path of the Stone Warden
    [2285] = 354466,              -- Spires of Ascension                — Path of the Ascendant
    [2286] = 354462,              -- The Necrotic Wake                  — Path of the Courageous
    [2287] = 354465,              -- Halls of Atonement                 — Path of the Sinful Soul
    [2289] = 354463,              -- Plaguefall                         — Path of the Plagued
    [2290] = 354464,              -- Mists of Tirna Scithe              — Path of the Misty Forest
    [2291] = 354468,              -- De Other Side                      — Path of the Scheming Loa
    [2293] = 354467,              -- Theater of Pain                    — Path of the Undefeated
    [2296] = 373190,              -- Castle Nathria (raid)              — Path of the Sire
    [2441] = 367416,              -- Tazavesh: Streets / So'leah's      — Path of the Streetwise Merchant
    [2450] = 373191,              -- Sanctum of Domination (raid)       — Path of the Tormented Soul
    [2481] = 373192,              -- Sepulcher of the First Ones (raid) — Path of the First Ones

    -- ===== Dragonflight =====
    -- mapIDs for Brackenhide Hollow, Dawn of the Infinite, and the
    -- raids below are best-effort — verify in-game with `/wg debug`
    -- or `/run print(select(8, GetInstanceInfo()))` when on-site.
    [2080] = 393267,              -- Brackenhide Hollow                 — Path of the Rotting Woods       (verify mapID in-game)
    [2451] = 393283,              -- Halls of Infusion                  — Path of the Titanic Reservoir
    [2515] = 393279,              -- The Azure Vault                    — Path of Arcane Secrets
    [2516] = 393262,              -- The Nokhud Offensive               — Path of the Windswept Plains
    [2519] = 393276,              -- Neltharus                          — Path of the Obsidian Hoard
    [2521] = 393256,              -- Ruby Life Pools                    — Path of the Clutch Defender
    [2522] = 432254,              -- Vault of the Incarnates (raid)     — Path of the Primal Prison       (verify mapID in-game)
    [2526] = 393222,              -- Uldaman: Legacy of Tyr             — Path of the Watcher's Legacy
    [2549] = 432258,              -- Amirdrassil, the Dream's Hope (raid) — Path of the Scorching Dream  (verify mapID in-game)
    [2569] = 432257,              -- Aberrus, the Shadowed Crucible (raid) — Path of the Bitter Legacy   (verify mapID in-game)
    [2579] = 424197,              -- Dawn of the Infinite               — Path of Twisted Time            (verify mapID in-game)

    -- ===== The War Within =====
    -- Liberation of Undermine and Manaforge Omega mapIDs are best-effort
    -- — verify in-game when the addon sees them in the wild.
    [2648] = 445443,              -- The Rookery                        — Path of the Fallen Stormriders
    [2649] = 445444,              -- Priory of the Sacred Flame         — Path of the Light's Reverence
    [2651] = 445441,              -- Darkflame Cleft                    — Path of the Warding Candles
    [2652] = 445269,              -- The Stonevault                     — Path of the Corrupted Foundry
    [2660] = 445417,              -- Ara-Kara, City of Echoes           — Path of the Ruined City
    [2661] = 445440,              -- Cinderbrew Meadery                 — Path of the Flaming Brewery
    [2662] = 445414,              -- The Dawnbreaker                    — Path of the Arathi Flagship
    [2669] = 445416,              -- City of Threads                    — Path of Nerubian Ascension
    [2769] = 1226482,             -- Liberation of Undermine (raid)     — Path of the Full House          (verify mapID in-game)
    [2773] = 1216786,             -- Operation: Floodgate               — Path of the Circuit Breaker
    [2810] = 1239155,             -- Manaforge Omega (raid)             — Path of the All-Devouring       (verify mapID in-game)
    [2830] = 1237215,             -- Eco-Dome Al'dani                   — Path of the Eco-Dome

    -- ===== Midnight =====
    [2805] = 1254400,             -- Windrunner Spire                   — Path of the Windrunners
    [2811] = 1254572,             -- Magisters' Terrace                 — Path of Devoted Magistry
    [2874] = 1254559,             -- Maisara Caverns                    — Path of Maisara Caverns
    [2915] = 1254563,             -- Nexus-Point Xenas                  — Path of Nexus-Point Xenas

    -- =====================================================================
    -- Pending in-game mapID verification (spell ID is wiki-confirmed,
    -- mapID is unknown / unverified):
    --
    --   Algeth'ar Academy — 393273 — Path of the Draconic Diploma
    --     Older addon data assumed mapID 2526 for AA, but recent
    --     verification places 2526 at Uldaman: Legacy of Tyr (above).
    --     AA's actual mapID needs in-game confirmation. Run
    --       /run print(select(8, GetInstanceInfo()))
    --     inside the dungeon, or apply to an AA group with /wg debug
    --     on and read the `mapID=…` line from the log.
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
    -- OnEnable is intentionally minimal. Hooks are installed at
    -- file-load (top of this file). Settings panel registration is
    -- deferred to first `/wg config`. StaticPopup registration is
    -- deferred to first reset. All three of those used to live in
    -- OnEnable / file-load and were tainting Blizzard's GameMenu
    -- callbacks (Logout etc. fired ADDON_ACTION_FORBIDDEN). The
    -- common cause: addon-author writes that touch protected/secure
    -- surfaces (SettingsPanel categories, StaticPopupDialogs, AceHook
    -- closures) during the boot window leak taint into the closures
    -- Blizzard's GameMenu builds for its buttons.
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    wasInGroup = IsInGroup()
end

-- ---------------------------------------------------------------------------
-- Group-info capture
-- ---------------------------------------------------------------------------

function WhatGroup:CaptureGroupInfo(searchResultID)
    local info = C_LFGList.GetSearchResultInfo(searchResultID)
    if not info then
        dbg("CaptureGroupInfo: GetSearchResultInfo returned nil for id=" .. tostring(searchResultID))
        return
    end

    local captured = {
        title             = info.name or "Unknown",
        leaderName        = info.leaderName or "Unknown",
        numMembers        = info.numMembers or 0,
        voiceChat         = info.voiceChat or "",
        -- Playstyle: API offers three plausible fields. `playstyleString` is
        -- the server-rendered, localized text (preferred when present);
        -- `generalPlaystyle` is the integer enum (Enum.LFGEntryGeneralPlaystyle);
        -- `playstyle` is the legacy alias kept for older clients. Capture
        -- all three; consumers prefer playstyleString, then look up
        -- generalPlaystyle in PLAYSTYLE_LABELS.
        generalPlaystyle  = info.generalPlaystyle or info.playstyle or 0,
        playstyleString   = info.playstyleString or "",
        age               = info.age or 0,
        activityIDs       = info.activityIDs or {},
        activityID        = nil,
        fullName          = "",
        activityName      = "",
        maxNumPlayers     = 0,
        isMythicPlus      = false,
        isCurrentRaid     = false,
        isHeroicRaid      = false,
        categoryID        = 0,
        mapID             = nil,
    }
    captured.playstyle = captured.generalPlaystyle

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
            captured.mapID          = actInfo.mapID
        end
    end

    dbg("Capture: title=" .. tostring(captured.title)
        .. " activityID=" .. tostring(captured.activityID)
        .. " mapID=" .. tostring(captured.mapID))

    return captured
end

-- Resolve a TeleportSpells value (number OR list) to (spellID, isKnown).
-- For lists, prefer the first one the player has learned via
-- IsSpellKnown; if none are known (player never learned the spell),
-- return the first list entry with isKnown=false so the popup at least
-- shows the icon desaturated rather than hiding.
local function pickKnownSpell(value)
    if type(value) == "number" then
        local known = IsSpellKnown and IsSpellKnown(value) or false
        return value, known
    end
    if type(value) == "table" then
        if IsSpellKnown then
            for _, sid in ipairs(value) do
                if IsSpellKnown(sid) then return sid, true end
            end
        end
        return value[1], false
    end
end

function WhatGroup:GetTeleportSpell(activityID, mapID)
    -- mapID first: TeleportSpells is keyed by mapID. activityID lookup is
    -- a back-compat fallback; the table no longer carries activityID rows.
    if mapID and self.TeleportSpells[mapID] then
        return pickKnownSpell(self.TeleportSpells[mapID])
    end
    if activityID and self.TeleportSpells[activityID] then
        return pickKnownSpell(self.TeleportSpells[activityID])
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

-- Keyed by Enum.LFGEntryGeneralPlaystyle so the labels match the LFG UI's
-- own "Learning / Fun (Relaxed) / Fun (Serious) / Expert" wording, pulled
-- from Blizzard's localized GROUP_FINDER_GENERAL_PLAYSTYLE1..4 globals.
local PLAYSTYLE_LABELS = {
    [Enum.LFGEntryGeneralPlaystyle.Learning]   = GROUP_FINDER_GENERAL_PLAYSTYLE1,
    [Enum.LFGEntryGeneralPlaystyle.FunRelaxed] = GROUP_FINDER_GENERAL_PLAYSTYLE2,
    [Enum.LFGEntryGeneralPlaystyle.FunSerious] = GROUP_FINDER_GENERAL_PLAYSTYLE3,
    [Enum.LFGEntryGeneralPlaystyle.Expert]     = GROUP_FINDER_GENERAL_PLAYSTYLE4,
}
local function GetPlaystyleLabel(info)
    if info.playstyleString and info.playstyleString ~= "" then
        return info.playstyleString
    end
    return PLAYSTYLE_LABELS[info.generalPlaystyle] or ""
end

-- ---------------------------------------------------------------------------
-- Chat notification
-- ---------------------------------------------------------------------------

function WhatGroup:ShowNotification()
    local info = self.pendingInfo
    if not info then
        dbg("ShowNotification skip: pendingInfo is nil")
        return
    end
    local n = self.db and self.db.profile and self.db.profile.notify
    if not n or not n.enabled then return end

    local gold      = "FFD700"
    local clickLink = colorize(link("WhatGroup:show", "[Click here to view details]"), "00FF7F")

    print(CHAT_PREFIX .. " You have joined a group!")
    print(CHAT_PREFIX .. "   - " .. colorize("Group:", gold) .. " " .. tostring(info.title or "Unknown"))

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
        local spellID, known = self:GetTeleportSpell(info.activityID, info.mapID)
        if spellID then
            local spellLink = C_Spell and C_Spell.GetSpellLink and C_Spell.GetSpellLink(spellID)
                              or ("|cff71d5ff[Spell " .. spellID .. "]|r")
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
    dbg("ApplyToGroup id=" .. tostring(searchResultID))
    local captured = self:CaptureGroupInfo(searchResultID)
    if captured then
        table.insert(captureQueue, captured)
    end
end

-- Called from the file-load `hooksecurefunc("SetItemRef", ...)` post-hook
-- whenever the link prefix matches "WhatGroup:". Blizzard's default
-- SetItemRef has already run by this point and no-op'd on our prefix;
-- this just opens the popup (or prints a hint if pendingInfo is gone).
function WhatGroup:OnSetItemRef(linkArg, text, button, ...)
    dbg("ChatLink hasPending=" .. tostring(self.pendingInfo ~= nil))
    -- pendingInfo is session-only (cleared on group-leave or /reload).
    -- A click on a stale chat link from a previous session would
    -- otherwise open an empty "No data" popup; print a one-line hint.
    if not self.pendingInfo then
        p("Group info no longer available — captures clear on group-leave or |cffFFFF00/reload|r. Use |cffFFFF00/wg test|r to preview.")
        return
    end
    self:ShowFrame()
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------

-- Schedule notify+popup IF: we're in a group, pendingInfo is set, and
-- we haven't already fired for this pendingInfo.
--
-- Called from BOTH GROUP_ROSTER_UPDATE (covers the case where pendingInfo
-- was already set when the in-group transition arrived) AND from the
-- inviteaccepted handler (covers the retail case where GROUP_ROSTER_UPDATE
-- fires BEFORE inviteaccepted, missing the wasInGroup-based transition
-- because pendingInfo wasn't set yet at that moment).
--
-- `notifiedFor` is the identity of the pendingInfo we already fired for;
-- it gets cleared when pendingInfo is replaced or wiped. This is what
-- prevents double-firing when both event paths catch the same join.
function WhatGroup:_TryFireJoinNotify(reason)
    if not self.pendingInfo then
        -- Only log "no pendingInfo" from the inviteaccepted path —
        -- ROSTER transitions hit this constantly and just clutter chat.
        if reason == "inviteaccepted" then
            dbg("Notify(" .. reason .. ") skip: no pendingInfo")
        end
        return
    end
    if notifiedFor == self.pendingInfo then return end
    if not IsInGroup() then return end

    notifiedFor = self.pendingInfo
    local delay = (self.db and self.db.profile and self.db.profile.notify
                   and self.db.profile.notify.delay) or 1.5
    local autoShow = not (self.db and self.db.profile and self.db.profile.frame
                          and self.db.profile.frame.autoShow == false)
    dbg("Notify(" .. reason .. ") scheduling in " .. tostring(delay) .. "s")
    C_Timer.After(delay, function()
        self:ShowNotification()
        if autoShow then self:ShowFrame() end
    end)
end

function WhatGroup:GROUP_ROSTER_UPDATE()
    local inGroup = IsInGroup()
    -- Suppress the no-op tick log: this event fires on every roster
    -- change (talents, specs, auras on some patches) and floods chat.
    -- Only log on a transition or when there's pendingInfo to clear.
    if inGroup ~= wasInGroup or (not inGroup and self.pendingInfo) then
        dbg("ROSTER inGroup=" .. tostring(inGroup)
            .. " wasInGroup=" .. tostring(wasInGroup)
            .. " hasPending=" .. tostring(self.pendingInfo ~= nil))
    end

    if inGroup and not wasInGroup then
        self:_TryFireJoinNotify("ROSTER transition")
    end
    wasInGroup = inGroup

    if not inGroup then
        self.pendingInfo = nil
        notifiedFor      = nil
        wipe(captureQueue)
        wipe(pendingApplications)
    end
end

function WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED(event, appID, newStatus)
    dbg("LFG_STATUS appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))
    if newStatus == "applied" then
        local capture = table.remove(captureQueue, 1)
        if capture then
            pendingApplications[appID] = capture
        end
    elseif newStatus == "invited" then
        -- Wait for the user to accept; multiple invites can arrive.
    elseif newStatus == "inviteaccepted" then
        -- Pick the more-complete capture between fresh (re-fetched
        -- from the LFG API now that the invite is accepted) and
        -- queued (captured at apply time). Prefer whichever has
        -- mapID — that's the field most prone to apply-time staleness
        -- AND the one that drives the teleport icon. If both have
        -- mapID, fresh wins (most current data).
        local queued = pendingApplications[appID]
        local fresh  = self:CaptureGroupInfo(appID)
        local final
        if fresh and fresh.mapID then
            final = fresh
        elseif queued and queued.mapID then
            final = queued
        elseif fresh then
            final = fresh
        elseif queued then
            final = queued
        end
        self.pendingInfo = final
        notifiedFor      = nil  -- new pendingInfo identity → eligible to fire again

        dbg("inviteaccepted: pendingInfo="
            .. (final and ("title=" .. tostring(final.title)
                           .. " mapID=" .. tostring(final.mapID))
                      or "NIL"))

        wipe(captureQueue)
        wipe(pendingApplications)

        -- Retail timing: GROUP_ROSTER_UPDATE often fires BEFORE this
        -- "inviteaccepted" status, so the wasInGroup transition has
        -- already passed by the time pendingInfo lands. Try firing now
        -- as a fallback — _TryFireJoinNotify gates on IsInGroup() and
        -- the notifiedFor flag, so if ROSTER_UPDATE already fired it
        -- this is a no-op, and if ROSTER_UPDATE missed because
        -- pendingInfo was nil this catches up.
        self:_TryFireJoinNotify("inviteaccepted")
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

local function schema()
    return WhatGroup.Settings and WhatGroup.Settings.Schema
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
    local H, S = helpers(), schema()
    if not (H and S) then
        return p("Settings layer not ready yet")
    end
    p("Available settings:")
    -- Group by section for readable output. Skip rows without a path
    -- (e.g. type="action" buttons) — they have no value to display.
    local bySection, order = {}, {}
    for _, def in ipairs(S) do
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
    -- EnsureResetPopup lazily registers the dialog on first use; writing
    -- to StaticPopupDialogs at file-load taints GameMenu callbacks.
    if StaticPopup_Show and self.Settings and self.Settings.EnsureResetPopup then
        self.Settings.EnsureResetPopup()
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
    -- mapID 2652 is The Stonevault — exercises the mapID-keyed teleport
    -- lookup (445269 in TeleportSpells). generalPlaystyle exercises the
    -- enum-based label path; leave playstyleString empty so the lookup
    -- falls through to PLAYSTYLE_LABELS instead of using the pre-rendered
    -- string.
    self.pendingInfo = {
        title             = "Test Group — Stonevault +12",
        leaderName        = "Testadin-Silvermoon",
        numMembers        = 3,
        voiceChat         = "",
        age               = 127,
        activityIDs       = {2516},
        activityID        = 2516,
        fullName          = "Dungeons > Mythic+ > The Stonevault",
        activityName      = "The Stonevault",
        maxNumPlayers     = 5,
        isMythicPlus      = true,
        isCurrentRaid     = false,
        isHeroicRaid      = false,
        categoryID        = 1,
        mapID             = 2652,
        generalPlaystyle  = Enum.LFGEntryGeneralPlaystyle.FunSerious,
        playstyle         = Enum.LFGEntryGeneralPlaystyle.FunSerious,
        playstyleString   = "",
        shortName         = "Mythic+",
    }
    self:ShowNotification()
    self:ShowFrame()
end

function runTest(self) self:RunTest() end

function runConfig(self)
    -- Settings UI uses secure templates protected during combat;
    -- opening it mid-combat can taint. Refuse and print a hint.
    if InCombatLockdown() then
        return p("Cannot open the settings panel during combat. Try again after combat ends.")
    end

    -- Lazy Settings registration: we deliberately don't register at
    -- PLAYER_LOGIN because direct calls to
    -- `_G.Settings.RegisterCanvasLayoutCategory` /
    -- `_G.Settings.RegisterAddOnCategory` from non-secure addon code
    -- at boot taint Blizzard's GameMenu callbacks (Logout etc. fail
    -- with ADDON_ACTION_FORBIDDEN). Registering on first /wg config
    -- means the addon adds nothing to Blizzard's settings/menu
    -- surface during the boot sequence.
    if self.Settings and self.Settings.Register then
        self.Settings.Register()
    end

    local parent = self._parentSettingsCategory
    if not (Settings and Settings.OpenToCategory and parent) then
        return p("Settings panel is not available.")
    end
    Settings.OpenToCategory(parent:GetID())

    -- Unfold the parent in the sidebar tree so every subcategory is
    -- one click away. Reaches into SettingsPanel.CategoryList →
    -- CategoryEntry — private Blizzard internals — so wrap in pcall:
    -- if a future patch refactors the tree, the panel still opens
    -- and we just lose the auto-unfold instead of throwing.
    pcall(function()
        if not SettingsPanel then return end
        local list = SettingsPanel.GetCategoryList
            and SettingsPanel:GetCategoryList()
            or SettingsPanel.CategoryList
        if not (list and list.GetCategoryEntry) then return end
        local entry = list:GetCategoryEntry(parent)
        if entry and entry.SetExpanded then
            entry:SetExpanded(true)
        end
    end)
end

function runDebug(self)
    local H = helpers()
    local newVal = not self.debug
    -- The schema row's onChange sets WhatGroup.debug; orchestrated Set
    -- handles persist + onChange + panel refresh. Direct-write fallback
    -- only if the Settings layer hasn't loaded yet (early-boot edge).
    if H and H.Set then
        H.Set("debug", newVal)
    elseif self.db and self.db.profile then
        self.db.profile.debug = newVal
        self.debug = newVal
    end
    p("Debug mode: " .. (newVal and "|cff00FF00ON|r" or "|cffFF4444OFF|r"))
end
