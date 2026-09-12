-- core/WhatGroup.lua
-- AceAddon shell, event handling, group-info capture, slash dispatch.
--
-- Settings layer lives in settings/Schema.lua (schema + helpers) and
-- settings/Panel.lua (canvas panel). Frame UI lives in modules/Frame.lua. All persistent
-- user prefs go through self.db.profile via the Settings.Helpers
-- Get/Set path; capture/pending state is session-only and lives in
-- module-local tables.

-- ---------------------------------------------------------------------------
-- AceAddon bootstrap
-- ---------------------------------------------------------------------------
--
-- Private-namespace pattern (architecture-§1, public-api): `NS` is the addon's private table,
-- shared across every source file via the second load vararg. AceAddon
-- mixes its methods (RegisterChatCommand / RegisterEvent / db / …) directly
-- INTO `NS`, so `NS` IS the addon object and `NS.addon` aliases it. Earlier
-- files have already hung their fields on this same table — locales/enUS.lua
-- (NS.L; the `# Locales` section now precedes `# Core`, WG-14), core/Util.lua
-- (NS.Util / NS.SafeToString / NS.Windows), Compat (NS.Compat), Database
-- (NS:RunMigrations) — and NewAddon preserves them. L strings are still
-- referenced as NS.L[...] at runtime, never captured at file scope here.
--
-- No `_G.WhatGroup` — the addon exposes no public global (WG-01). Downstream
-- files pick the object up with `local WhatGroup = NS.addon`. The apply hook
-- is a direct `hooksecurefunc` post-hook and the chat-link click an
-- EventRegistry callback, both installed at file-load (below) — not AceHook.
-- AceHook adds a per-invocation closure that taints Blizzard's secure-execute
-- chain at GameMenu Logout time.

local addonName, NS = ...
local WhatGroup = LibStub("AceAddon-3.0"):NewAddon(
    NS, addonName,
    "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
NS.addon = WhatGroup
WhatGroup.VERSION = "1.4.0"

-- Session-only runtime state — never persisted (debug-logging-§5). Debug is off on
-- every login and toggled only by `/wg debug`.
NS.State = NS.State or {}
NS.State.debug = false

-- Single shared chat prefix (slash-commands-§4). NS.PREFIX is the one source of
-- truth; the secret-safe printer (core/Util.lua) prepends it to every line.
NS.PREFIX = "|cff00FFFF[WG]|r"

-- Both subscriptions below are installed at file-load (NOT in OnEnable):
-- the apply post-hook and the chat-link callback. They live at the top of the
-- file; the addon table is the only persistent reference; no closures
-- captured from event handlers. Installing hooks in OnEnable (PLAYER_LOGIN)
-- was tainting Blizzard's GameMenu callbacks — the closures Blizzard builds
-- for Logout/Settings/Macros buttons were inheriting our addon's load-time
-- taint and rejecting their secure-execute calls with ADDON_ACTION_FORBIDDEN.
-- File-load registration runs before GameMenu's InitButtons builds those
-- closures, so they remain taint-free.
-- Both closures take ONLY what they read. The client passes more -- ApplyToGroup also carries the
-- role flags and the applicant note, the link click the link text, the mouse button and the chat
-- frame -- and a closure that declares fewer parameters simply drops the rest, which is what
-- happens to them here anyway. Until `M4c-04` these mirrored the client's full signatures and
-- forwarded them on, so `text`, `button` and two varargs traveled into handler bodies that read
-- none of them, on every apply and every link click. The client's signatures are recorded in
-- docs/data-flow.md, which is where a signature nothing reads belongs.
hooksecurefunc(C_LFGList, "ApplyToGroup", function(searchResultID)
    if WhatGroup.OnApplyToGroup then
        WhatGroup:OnApplyToGroup(searchResultID)
    end
end)

-- THE DETAILS CHAT LINK, AND HOW A CLICK ON IT REACHES US.
--
-- It is Blizzard's addon link type, `|Haddon:WhatGroup:show|h…|h`, heard as EventRegistry's
-- "SetItemRef" event. Blizzard registers a handler for that type
-- (Blizzard_UIPanels_Game/Shared/ItemRefHandlersShared.lua:278-281 at 12.1.0) that triggers the
-- event and counts as Handled, so SetItemRef (Mainline/ItemRef.lua:6-27) returns before its
-- fallthrough. Until 2026-09-12 the link was `|HWhatGroup:show|h`, an UNREGISTERED type, heard by
-- a SetItemRef post-hook. For that type Blizzard's body runs first and falls through, to
-- ShowUIPanel(ItemRefTooltip) plus ItemRefSetHyperlink on a bogus link, or to
-- HandleModifiedItemClick on a modified click, and a post-hook runs only if that body returns.
-- On a real group join the click did nothing at all: no popup and no stale-link hint.
--
-- The callback's owner is the addon object. The registry keeps one callback per (event, owner),
-- so the owner is also what makes a second registration replace the first rather than stack.
-- The registry calls it through securecallfunction as `func(owner, link, text, button, frame)`.
--
-- A client without that path (NS.Compat.AddOnLinkType answers nil) keeps the old link and the old
-- post-hook, which is the only click route such a client has.
local ADDON_LINK_TYPE    = NS.Compat.AddOnLinkType()
local DETAILS_LINK_KEY   = "WhatGroup:show"
local DETAILS_LINK       = ADDON_LINK_TYPE and (ADDON_LINK_TYPE .. ":" .. DETAILS_LINK_KEY)
                           or DETAILS_LINK_KEY
-- Matched as a plain prefix, not a pattern, and the trailing ":" is part of it: another addon's
-- `addon:WhatGroupSomething:` link must not be ours.
local DETAILS_LINK_PREFIX = (ADDON_LINK_TYPE and (ADDON_LINK_TYPE .. ":") or "") .. "WhatGroup:"

local function onDetailsLinkClick(linkArg)
    if type(linkArg) ~= "string" then return end
    if linkArg:sub(1, #DETAILS_LINK_PREFIX) ~= DETAILS_LINK_PREFIX then return end
    if WhatGroup.OnSetItemRef then
        WhatGroup:OnSetItemRef()
    end
end

if ADDON_LINK_TYPE then
    EventRegistry:RegisterCallback("SetItemRef", function(_, linkArg)
        onDetailsLinkClick(linkArg)
    end, WhatGroup)
else
    hooksecurefunc("SetItemRef", onDetailsLinkClick)
end

-- Session-only state. Cleared on group leave; never persisted.
-- Keyed by SEARCH-RESULT id, not by arrival order (WG-R-07). The apply hook knows the
-- search-result id and nothing else; the status event knows the application id and nothing
-- else. The only thing that joins them is C_LFGList.GetApplicationInfo, so that is what the
-- key has to be. A FIFO looks equivalent while one application is outstanding and silently
-- swaps the two captures the moment a second one is, because the server answers applications
-- in whatever order it likes.
local capturesByResult    = {}   -- [searchResultID] -> capturedInfo (set at apply time)
local pendingApplications = {}   -- [appID] -> capturedInfo (set when "applied" fires)
local wasInGroup          = false
local notifiedFor         = nil  -- pendingInfo identity that already fired notify+popup

-- Single secret-safe chat seam (slash-commands-§4, WG-22). Every user-facing
-- line funnels through NS.Util.print (core/Util.lua), which prepends NS.PREFIX
-- and stringifies each arg via NS.SafeToString — so a combat-protected value
-- can never raise in the chat path. `p` is the file-local alias for the many
-- call sites; NS.Print / _print expose the same one seam to other files
-- (core/DebugLogSetup.lua, loaded later, uses NS.Print for its
-- enable/disable acks).
local p = NS.Util.print
WhatGroup._print = p
NS.Print = p

-- The on-screen debug console MUST render in a monospace face (debug-logging-§2)
-- and retail WoW ships no guaranteed one, so a non-Blizzard TTF is needed. It is
-- no longer OURS: JetBrains Mono (OFL) arrives inside the LibKa0s payload, and
-- WG-20 — the accepted deviation that justified vendoring a private copy under
-- media/fonts/ — collapses into the library-stack media rule with it. Six Ka0s
-- addons shipped six copies of the same bytes; two copies of a font is two
-- licenses to track and two provenance stories, and the collection stops looking
-- like one author's work the first time one copy is regenerated and the rest are
-- not. This is still the only non-Blizzard font the addon draws with; every other
-- FontString uses a GameFont* object.
--
-- THE NAME IS A CONSTANT because two places need it and they are in two repos:
-- this file asks the library for it, and the library registers it with
-- LibSharedMedia under the same string. A literal duplicated in the suite is the
-- drift a constant exists to prevent.
NS.FONT_MONO_NAME = "JetBrains Mono"

-- THE FALLBACK IS A REAL CLIENT FONT, and that is the whole point of the `or`.
-- SetFont accepts a path to a file that is not there, fails to load it, and the
-- text simply does not draw — so a degraded install must land on something the
-- client definitely has, never on a dead path and never on nil (the library
-- validates the console's `font` as a string at :New time). Proportional but
-- legible beats monospace but invisible.
--
-- The LSM registration that used to sit here moved to core/MediaSetup.lua's
-- Media.RegisterLSM(addonName): one call now registers every face the library
-- ships, under the key every other Ka0s addon registers it under, pointing at
-- one set of bytes rather than six.
NS.FONT_MONO = NS.MediaFont and NS.MediaFont(NS.FONT_MONO_NAME) or _G.STANDARD_TEXT_FONT

-- ---------------------------------------------------------------------------
-- Teleport spell lookup
-- ---------------------------------------------------------------------------
--
-- The mapID → spellID table itself lives in TeleportSpells.lua, loaded
-- via the .toc; it populates NS.TeleportSpells (== self.TeleportSpells).
-- Resolver below reads from it.

local function colorize(text, hex)
    return "|cff" .. hex .. text .. "|r"
end

local function link(linkData, display)
    return "|H" .. linkData .. "|h" .. display .. "|h"
end

-- ---------------------------------------------------------------------------
-- Lifecycle
-- ---------------------------------------------------------------------------

-- The three profile events' shared reaction: switching, copying or resetting a profile replaces
-- every stored value at once. At file scope, so the OnProfileCopied method below and the closures
-- OnInitialize registers share one copy.
local function reloadProfile(self)
    -- The incoming profile may predate the current schema version.
    self:RunMigrations()
    -- And every open panel is showing the outgoing profile's values.
    local H = NS.Settings and NS.Settings.Helpers
    if H and H.RefreshAll then H.RefreshAll() end
end

-- A profile copy is logged HERE, once (debug-logging-§10): AceDB copying one profile over another is
-- wholesale replacement, not a write through the helper, so its line comes from the profile-event
-- handler, worded by the event. AceDB fires OnProfileCopied(event, db, sourceProfileKey), and the
-- copy has landed in the ACTIVE profile. A method rather than a closure, so a test can call it with
-- those real arguments directly (since kit revision 18 the AceDB mock passes the source as well).
function WhatGroup:OnProfileCopied(_, _, source)
    NS.Debug("Set", "copied profile '%s' \226\134\146 '%s'", tostring(source),
             tostring(self.db:GetCurrentProfile()))
    reloadProfile(self)
end

function WhatGroup:OnInitialize()
    -- settings/Schema.lua loads after this file but BEFORE OnInitialize
    -- fires (OnInitialize runs on ADDON_LOADED, after every TOC line has
    -- executed). So Settings.BuildDefaults is guaranteed to exist here.
    local defaults = self.Settings and self.Settings.BuildDefaults
                     and self.Settings.BuildDefaults()
                     or { profile = {} }

    self.db = LibStub("AceDB-3.0"):New("WhatGroupDB", defaults, true)

    -- Migration seam: run once, right after AceDB:New, before any code
    -- reads the profile (WG-08 / Database.lua). Idempotent.
    self:RunMigrations()

    -- PROFILE CALLBACKS, and this addon had none.
    --
    -- Switching, copying or resetting a profile replaces every stored value at
    -- once, and nothing here reacted: an open settings panel kept showing the
    -- OLD profile's values until it was closed and reopened, and the migrations
    -- never ran on an incoming profile that a copy could have authored at an
    -- older schema version. It went unnoticed because nothing in this addon
    -- switched profiles -- until options-ui-§12 made the GLOBAL RESET a profile
    -- reset, which fires the same event and needs the same reaction.
    --
    -- The function form rather than the string-method one: CallbackHandler takes
    -- both, and a closure keeps this readable. The reaction itself is the
    -- file-scope reloadProfile above. OnProfileCopied is the one method, because
    -- its line needs AceDB's source-key argument and a test has to be able to
    -- pass it the real one.
    if self.db.RegisterCallback then
        local function reload() reloadProfile(self) end
        -- A reset is logged HERE, once (debug-logging-§10): AceDB replacing the whole profile is
        -- not a write through the helper, so it gets no per-row line and no bulk-bracket line, just
        -- this one from the profile-event handler. Here rather than in Helpers.RestoreAllDefaults,
        -- because a reset driven straight at the db (AceDBOptions, a /run) is the same act. N is the
        -- rows whose stored value the reset changed. Helpers.RestoreAllDefaults counts them just
        -- before it resets and hands the count over; a reset from anywhere else has no such count,
        -- and §10 lets the line omit it.
        local function logReset()
            local S = NS.Settings
            local name = self.db:GetCurrentProfile()
            local n = S and S.ConsumeResetCount and S.ConsumeResetCount()
            if n then
                NS.Debug("Set", "reset profile '%s' to defaults (%d rows)", name, n)
            else
                NS.Debug("Set", "reset profile '%s' to defaults", name)
            end
        end
        self.db.RegisterCallback(self, "OnProfileChanged", reload)
        self.db.RegisterCallback(self, "OnProfileCopied",  function(...) self:OnProfileCopied(...) end)
        self.db.RegisterCallback(self, "OnProfileReset",   function()
            logReset()
            reload()
        end)
    end

    -- Debug is session-only (NS.State.debug), off on every login. It is
    -- NOT seeded from SavedVariables (WG-12).

    self:RegisterChatCommand("wg",        "OnSlashCommand")
    self:RegisterChatCommand("whatgroup", "OnSlashCommand")
end

function WhatGroup:OnEnable()
    -- Hooks are installed at file-load (top of this file), not here.
    self:RegisterEvent("GROUP_ROSTER_UPDATE")
    self:RegisterEvent("LFG_LIST_APPLICATION_STATUS_UPDATED")
    -- The popup's `visibility` setting has two combat-dependent values, and combat state changes
    -- without the player touching the panel — so the gate needs an event, not just an onChange.
    -- Both edges route to ONE handler because the answer is a single re-evaluation either way;
    -- which edge it is comes from the event name (see modules/Frame.lua's visibilityAllows).
    -- Registered here in OnEnable and never in OnInitialize, like the two above.
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnCombatStateChanged")
    self:RegisterEvent("PLAYER_REGEN_ENABLED",  "OnCombatStateChanged")
    wasInGroup = IsInGroup()

    -- Register the Settings panel at login so the "Ka0s WhatGroup" entry shows
    -- in Settings → AddOns without the player running `/wg config` first — the
    -- same place every other Ka0s addon registers it (AbsorbTracker / KickCD do
    -- this at OnEnable too). Registering a canvas category at boot does NOT taint
    -- GameMenu's Logout closure; WhatGroup's real boot-taint sources — the secure
    -- teleport button and the `UISpecialFrames` insert — stay deferred to first
    -- popup show (Frame.lua). Panel widget bodies still build lazily on first
    -- OnShow (Panel.lua), so no AceGUI frame is created inside a secure-execute
    -- chain. Register() is idempotent (the `_settingsRegistered` guard), so
    -- runConfig's call becomes a harmless no-op fallback. Registration is not
    -- combat-gated (options-ui-§9), so a `/reload` taken in combat still lands the
    -- category in the list — only panel *open* is refused under lockdown.
    if self.Settings and self.Settings.Register then
        self.Settings.Register()
    end
    -- No lifecycle line here: the debug flag is session-only and off at login,
    -- so a boot-time summary would always be gated off (debug-logging-§5 / debug-logging-§8). The [Init]
    -- summary is emitted at the DebugLog:SetEnabled seam instead, the only
    -- point where it is both current and visible — see InitSummary below.
end

-- One-line [Init] session summary (debug-logging-§5 MUST / debug-logging-§8 boot-summary):
-- addon name + version, schema/DB version, active AceDB profile. A pure builder
-- — the DebugLog:SetEnabled seam calls it and appends the line via raw D:Add on
-- enable. Guarded so it can't error before the db is ready. Values are plain
-- (no combat-protected secrets), so tostring is secret-safe here.
function WhatGroup:InitSummary()
    local db = self.db
    local schema  = db and db.global and db.global.schemaVersion
    local profile = (db and db.GetCurrentProfile and db:GetCurrentProfile()) or "?"
    local pr = (db and db.profile) or {}
    -- Standard-mandated identity fields first (name/version/schema/profile, debug-logging-§5),
    -- then the current runtime state so a debug session opens with full context.
    return string.format(
        "%s v%s, schema v%s, profile '%s' (enabled=%s, notify.delay=%ss, autoShow=%s, inGroup=%s, hasPending=%s)",
        addonName, tostring(self.VERSION), tostring(schema), tostring(profile),
        tostring(pr.enabled),
        tostring(pr.notify and pr.notify.delay),
        tostring(not (pr.frame and pr.frame.autoShow == false)),
        tostring(IsInGroup() and true or false),
        tostring(self.pendingInfo ~= nil))
end

-- ---------------------------------------------------------------------------
-- Group-info capture
-- ---------------------------------------------------------------------------

-- Flatten one GetSearchResultInfo result into the captured shape: every search field defaulted,
-- and the activity fields pre-seeded with placeholders so a capture whose activity never resolved
-- is still readable without nil checks. Two deliberate exceptions — `shortName` is not seeded at
-- all (applyActivityInfo below says why), and `activityID`/`mapID` are spelled out as `nil`, which
-- sets no key at all: they are listed for the reader and the shape stays nil-able. The key set
-- here is a contract read by modules/Frame.lua (PopulateFields), Labels.GetGroupTypeLabel and
-- ShowNotification.
--
-- Every default below is an `or` chain, NOT `if src == nil then`. The two are different: `or`
-- replaces a stored `false` with the default, `== nil` keeps it. `or` is what shipped and what the
-- downstream consumers assume — Labels.GetGroupTypeLabel compares categoryID numerically and
-- ShowNotification tests `shortName ~= ""`, so a `false` reaching either degrades the output
-- silently. (0 and "" are TRUTHY in Lua, so an `or` chain never swallows a stored zero or empty
-- string; only `false` and `nil`.) These functions exist to keep CaptureGroupInfo's complexity
-- down — the split is the whole point, the `or`s stay literal.
local function buildCapture(info)
    local unknown = NS.L["Unknown"]
    local captured = {
        title             = info.name or unknown,
        leaderName        = info.leaderName or unknown,
        numMembers        = info.numMembers or 0,
        voiceChat         = info.voiceChat or "",
        -- Playstyle: API offers three plausible fields. `playstyleString` is
        -- the server-rendered, localized text (preferred when present);
        -- `generalPlaystyle` is the integer enum (Enum.LFGEntryGeneralPlaystyle);
        -- `playstyle` is the legacy alias kept for older clients. Capture
        -- all three; consumers prefer playstyleString, then look up
        -- generalPlaystyle in WhatGroup.Labels.PLAYSTYLE.
        generalPlaystyle  = info.generalPlaystyle or info.playstyle or 0,
        playstyleString   = info.playstyleString or "",
        age               = info.age or 0,
        -- A FRESH table per call, never a shared module-level empty one: captures are held in
        -- capturesByResult, and a shared fallback would alias every id-less capture together.
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
    return captured
end

-- Overlay the resolved activity's fields onto a capture. `shortName` is set ONLY here and is
-- deliberately absent from buildCapture's literal — ShowNotification's `info.shortName ~= ""`
-- test distinguishes "no activity resolved" from "activity with no short name".
local function applyActivityInfo(captured, actInfo)
    captured.fullName       = actInfo.fullName or actInfo.activityName or ""
    captured.activityName   = actInfo.activityName or ""
    captured.maxNumPlayers  = actInfo.maxNumPlayers or 0
    captured.isMythicPlus   = actInfo.isMythicPlusActivity or false
    captured.isCurrentRaid  = actInfo.isCurrentRaidActivity or false
    captured.isHeroicRaid   = actInfo.isHeroicRaidActivity or false
    captured.categoryID     = actInfo.categoryID or 0
    captured.shortName      = actInfo.shortName or ""
    -- No default: mapID stays nil-able, and GetTeleportSpell reads it that way.
    captured.mapID          = actInfo.mapID
end

function WhatGroup:CaptureGroupInfo(searchResultID)
    local info = C_LFGList.GetSearchResultInfo(searchResultID)
    if not info then
        NS.Debug("Capture", "GetSearchResultInfo returned nil for id=" .. tostring(searchResultID))
        return
    end

    local captured = buildCapture(info)

    local firstActivityID = captured.activityIDs[1]
    if firstActivityID then
        captured.activityID = firstActivityID
        local actInfo = NS.Compat.GetActivityInfoTable(firstActivityID)
        if actInfo then
            applyActivityInfo(captured, actInfo)
        end
    end

    -- No success line here: OnApplyToGroup emits one [Apply] summary that
    -- carries the captured title/activity/map, so a single line covers the
    -- whole apply→capture step (debug-logging-§9). The nil-result no-op above is still
    -- logged — that's the "why nothing was captured" trace (debug-logging-§8).
    return captured
end

-- Application id -> search-result id (F-004).
--
-- CaptureGroupInfo above takes a searchResultID, but the LFG status events hand
-- us an appID. C_LFGList.GetApplicationInfo(appID) is the documented bridge:
-- its first return is the search-result id the application was made against.
-- Older code fed the appID straight into GetSearchResultInfo, which only works
-- because for the player's own application appID == searchResultID —
-- undocumented behavior a patch could decouple at any time.
--
-- The appID path stays as the fallback rather than being deleted: it is what
-- shipped and is known to work at retail 120000-120007, so if
-- GetApplicationInfo is missing, raises, or yields nothing usable, capture
-- degrades to the old behavior instead of going dark. Both returns shapes are
-- accepted — the multi-return form (id, appStatus, …) and a table, in case a
-- future patch converts it like it did GetActivityInfoTable.
-- This is a resolver rather than part of the capture wrapper because two callers need the id
-- and only one of them wants a capture: the "applied" status event uses it to find the capture
-- the apply hook already took, and re-capturing there would be a second LFG round-trip for a
-- table that is already in hand.
function WhatGroup:ResolveSearchResultID(appID)
    local resultID = appID
    local getAppInfo = C_LFGList and C_LFGList.GetApplicationInfo

    if getAppInfo then
        local ok, res = pcall(getAppInfo, appID)
        if not ok then
            NS.Debug("Capture", "GetApplicationInfo raised for appID=%s; falling back to appID",
                NS.SafeToString(appID))
        else
            if type(res) == "table" then
                res = res.searchResultID or res.id
            end
            if res then
                resultID = res
            else
                NS.Debug("Capture", "GetApplicationInfo gave no id for appID=%s; falling back to appID",
                    NS.SafeToString(appID))
            end
        end
    else
        NS.Debug("Capture", "GetApplicationInfo unavailable; falling back to appID=%s",
            NS.SafeToString(appID))
    end

    return resultID
end

-- Re-capture from an application id: resolve, then capture.
function WhatGroup:CaptureGroupInfoFromApplication(appID)
    return self:CaptureGroupInfo(self:ResolveSearchResultID(appID))
end

-- Resolve a TeleportSpells value (number OR list) to (spellID, isKnown).
-- For lists, prefer the first one the player has learned via
-- IsSpellKnown; if none are known (player never learned the spell),
-- return the first list entry with isKnown=false so the popup at least
-- shows the icon desaturated rather than hiding.
local function pickKnownSpell(value)
    if type(value) == "number" then
        return value, NS.Compat.IsSpellKnown(value)
    end
    if type(value) == "table" then
        for _, sid in ipairs(value) do
            if NS.Compat.IsSpellKnown(sid) then return sid, true end
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

-- Shared label namespace consumed by both ShowNotification (chat) and
-- modules/Frame.lua's PopulateFields (popup). Single source of truth
-- so a new playstyle enum or group-type rule lands in one place.
WhatGroup.Labels = WhatGroup.Labels or {}

-- Keyed by Enum.LFGEntryGeneralPlaystyle so the labels match the LFG UI's
-- own "Learning / Fun (Relaxed) / Fun (Serious) / Expert" wording, pulled
-- from Blizzard's localized GROUP_FINDER_GENERAL_PLAYSTYLE1..4 globals.
WhatGroup.Labels.PLAYSTYLE = {
    [Enum.LFGEntryGeneralPlaystyle.Learning]   = GROUP_FINDER_GENERAL_PLAYSTYLE1,
    [Enum.LFGEntryGeneralPlaystyle.FunRelaxed] = GROUP_FINDER_GENERAL_PLAYSTYLE2,
    [Enum.LFGEntryGeneralPlaystyle.FunSerious] = GROUP_FINDER_GENERAL_PLAYSTYLE3,
    [Enum.LFGEntryGeneralPlaystyle.Expert]     = GROUP_FINDER_GENERAL_PLAYSTYLE4,
}

function WhatGroup.Labels.GetGroupTypeLabel(info)
    if info.isMythicPlus then
        return NS.L["Mythic+"]
    elseif info.isCurrentRaid then
        return NS.L["Raid (Current)"]
    elseif info.isHeroicRaid then
        return NS.L["Heroic Raid"]
    elseif info.categoryID == 2 then
        return NS.L["PvP"]
    elseif info.categoryID == 1 then
        return NS.L["Dungeon"]
    elseif info.maxNumPlayers and info.maxNumPlayers >= 10 then
        return NS.L["Raid"]
    elseif info.maxNumPlayers and info.maxNumPlayers > 0 then
        return NS.L["Dungeon"]
    else
        return NS.L["Group"]
    end
end

function WhatGroup.Labels.GetPlaystyleLabel(info)
    if info.playstyleString and info.playstyleString ~= "" then
        return info.playstyleString
    end
    return WhatGroup.Labels.PLAYSTYLE[info.generalPlaystyle] or ""
end

local Labels = WhatGroup.Labels

-- ---------------------------------------------------------------------------
-- Chat notification
-- ---------------------------------------------------------------------------

local GOLD = "FFD700"

-- The teleport row's value: the spell link, plus a gray note saying why it is unusable — either
-- "(not learned)" or "(on cooldown)". Returns nil when there is no teleport for this activity/map
-- at all — the row is then absent, not empty.
--
-- "Not learned" is checked first and wins: an unlearned spell can still report a cooldown, and
-- naming the cooldown would bury the reason the player cannot use it.
--
-- The cooldown tag deliberately carries NO time remaining. This line is printed once into the
-- player's scrollback with no way to refresh itself, so a figure here would be wrong a second
-- later and stay wrong. The popup's countdown is the live one.
local function teleportValue(self, info)
    local spellID, known = self:GetTeleportSpell(info.activityID, info.mapID)
    if not spellID then return nil end
    local spellLink = NS.Compat.GetSpellLink(spellID)
                      or ("|cff71d5ff[Spell " .. spellID .. "]|r")

    local tag
    if not known then
        tag = NS.L["(not learned)"]
    elseif NS.Compat.GetSpellCooldownRemaining(spellID) > 0 then
        tag = NS.L["(on cooldown)"]
    end

    return spellLink .. (tag and (" |cff888888" .. tag .. "|r") or "")
end

-- The independently-toggled notification rows, IN THE ORDER they print. Built once at file load
-- (after `Labels` is bound above), never per notification. `flag` is the db.profile.notify key that
-- gates the row; `label` is looked up in NS.L at print time, so a locale swap still applies.
--
-- `omitWhenNil` is opt-IN, and only Playstyle and Teleport declare it, because only those two ever
-- had a second inner `if` suppressing their own row. Instance, Type and Leader print whenever their
-- flag is on — Leader in particular printed a nil leaderName straight through NS.SafeToString, and
-- a blanket nil gate here would have silently deleted that row. An absent row and a row reading
-- "nil" are different outputs; the flag keeps them apart.
local NOTIFY_ROWS = {
    { flag = "showInstance",  label = "Instance:",
      value = function(_, info) return info.fullName ~= "" and info.fullName or NS.L["Unknown"] end },
    { flag = "showType",      label = "Type:",
      value = function(_, info)
          return info.shortName ~= "" and info.shortName or Labels.GetGroupTypeLabel(info)
      end },
    { flag = "showLeader",    label = "Leader:",
      value = function(_, info) return info.leaderName end },
    { flag = "showPlaystyle", label = "Playstyle:", omitWhenNil = true,
      value = function(_, info)
          local playStyle = Labels.GetPlaystyleLabel(info)
          if playStyle == "" then return nil end
          return playStyle
      end },
    { flag = "showTeleport",  label = "Teleport:", omitWhenNil = true, value = teleportValue },
}

function WhatGroup:ShowNotification()
    local info = self.pendingInfo
    if not info then
        NS.Debug("Notify", "skip: no pendingInfo (notification)")
        return
    end
    local n = self.db and self.db.profile and self.db.profile.notify
    if not n or not n.enabled then return end

    -- Every line routes through the single secret-safe printer `p` (WG-23):
    -- the label (a constant color-coded string) and the value are passed as
    -- SEPARATE args, so the LFG-sourced values are stringified by the seam
    -- rather than pre-concatenated through `..`/tostring at the call site.
    p(NS.L["You have joined a group!"])
    p("   - " .. colorize(NS.L["Group:"], GOLD), info.title or NS.L["Unknown"])

    for i = 1, #NOTIFY_ROWS do
        local row = NOTIFY_ROWS[i]
        if n[row.flag] then
            local v = row.value(self, info)
            local omit = row.omitWhenNil and v == nil
            if not omit then
                p("   - " .. colorize(NS.L[row.label], GOLD), v)
            end
        end
    end

    -- The click link stays inline: it is the one row with no label and its own green, so a table
    -- entry for it would cost more indirection than it saves.
    if n.showClickLink then
        p("   - " .. colorize(link(DETAILS_LINK, NS.L["[Click here to view details]"]), "00FF7F"))
    end
end

-- ---------------------------------------------------------------------------
-- Hooks
-- ---------------------------------------------------------------------------

function WhatGroup:OnApplyToGroup(searchResultID)
    -- Master enable gate: when disabled, the addon ignores the apply
    -- entirely so no capture → no pendingInfo → no notification or
    -- popup later. /wg test and /wg show still work (they bypass the
    -- capture pipeline) so the user can preview / re-view at any time.
    if not (self.db and self.db.profile and self.db.profile.enabled) then
        return
    end
    local captured = self:CaptureGroupInfo(searchResultID)
    if captured then
        capturesByResult[searchResultID] = captured
        NS.Debug("Apply", 'id=%s captured "%s" (activity=%s map=%s m+=%s)',
            tostring(searchResultID), tostring(captured.title),
            tostring(captured.activityID), tostring(captured.mapID),
            tostring(captured.isMythicPlus))
    end
end

-- Called from the file-load click subscription (top of this file) whenever the link starts with
-- the details link's prefix: `addon:WhatGroup:` through EventRegistry's "SetItemRef" event, or
-- `WhatGroup:` through the SetItemRef post-hook on a client without Blizzard's addon link path.
-- On the first route Blizzard's SetItemRef has already counted the link Handled and returns before
-- its ItemRef fallthrough. This just opens the popup, or prints a hint if pendingInfo is gone.
-- The name is the event's.
--
-- TAKES NOTHING. The subscription has already decided the click is ours -- that is the whole
-- content of the link argument by the time control gets here -- and there is exactly one details
-- link, the one built in ShowNotification, so there is no sub-prefix left to branch on. The link
-- text, the mouse button and the chat frame the client also passes were carried into this
-- signature and never read.
function WhatGroup:OnSetItemRef()
    NS.Debug("ChatLink", "clicked hasPending=" .. tostring(self.pendingInfo ~= nil))
    -- pendingInfo is session-only (cleared on group-leave or /reload).
    -- A click on a stale chat link from a previous session would
    -- otherwise open an empty "No data" popup; print a one-line hint.
    if not self.pendingInfo then
        p(NS.L["Group info no longer available — captures clear on group-leave or |cffFFFF00/reload|r. Use |cffFFFF00/wg test|r to preview."])
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
            NS.Debug("Notify", "skip: no pendingInfo (" .. reason .. ")")
        end
        return
    end
    if notifiedFor == self.pendingInfo then return end
    if not IsInGroup() then return end

    notifiedFor = self.pendingInfo
    local capturedInfo = self.pendingInfo
    local delay = (self.db and self.db.profile and self.db.profile.notify
                   and self.db.profile.notify.delay) or 0
    -- Cancel any still-pending notify before scheduling a fresh one so a rapid
    -- re-fire can't leave two timers racing to the same popup.
    if self.notifyTimer then self:CancelTimer(self.notifyTimer) end
    NS.Debug("Notify", "scheduling in " .. tostring(delay) .. "s (" .. reason .. ")")
    -- WG-17 (library-stack-§1): the one-shot notify delay runs through
    -- AceTimer-3.0 (the mandated timer lib). The handle is stashed in
    -- self.notifyTimer and canceled by WipeCapture (group-leave, master-switch
    -- off) via CancelTimer; the in-callback identity check below still guards a
    -- same-tick replacement of pendingInfo. (The next-frame C_Timer.After(0, …)
    -- secure-defer hops in the panel/frame are a distinct taint-avoidance idiom,
    -- not delayed timers, so they stay raw.)
    self.notifyTimer = self:ScheduleTimer(function()
        self.notifyTimer = nil
        -- Cancel if a newer notify replaced the pending info before we fired.
        if self.pendingInfo ~= capturedInfo then
            NS.Debug("Notify", "canceled (superseded)")
            return
        end
        NS.Debug("Notify", "fired")
        self:ShowNotification()
        -- Read at FIRE time, not at schedule time (WG-R-14). autoShow decides what to do now;
        -- a player who turns the popup off during the delay window means it now. `delay` above
        -- is the opposite case and stays where it is: it is the timer's own argument, and
        -- there is no later moment at which it could be read.
        if not (self.db and self.db.profile and self.db.profile.frame
                and self.db.profile.frame.autoShow == false) then
            self:ShowFrame()
        end
    end, delay)
end

-- Capture-state wipe used by group-leave (GROUP_ROSTER_UPDATE) and by
-- the master-switch off-flip (enabled.onChange). Cancels any in-flight notify
-- timer so a scheduled callback can't fire after the capture it belonged to is
-- gone. `reason` (optional) turns on a one-line material-effect log (debug-logging-§10): only the
-- caller that wipes for a *reason the reader can't infer from context* (the
-- master-switch off-flip) passes one, and only when something was actually in
-- flight. Group-leave passes nothing — the [Roster] line already tells that story.
function WhatGroup:WipeCapture(reason)
    local hadInFlight = self.pendingInfo ~= nil
        or next(capturesByResult) ~= nil or next(pendingApplications) ~= nil
    self.pendingInfo = nil
    notifiedFor      = nil
    if self.notifyTimer then
        self:CancelTimer(self.notifyTimer)
        self.notifyTimer = nil
    end
    wipe(capturesByResult)
    wipe(pendingApplications)
    if reason and hadInFlight then
        NS.Debug("Capture", "wiped (" .. reason .. ")")
    end
end

-- Both combat edges, one handler. The body is deliberately the smallest thing that can be: this is
-- the addon's first PLAYER_REGEN_DISABLED registration and therefore its first handler that runs
-- inside a combat window, which is a `performance-§12` question — a table read, up to three string
-- compares, and at most one Show or Hide, twice per pull.
--
-- The event name is passed down rather than re-derived from InCombatLockdown(), because the API can
-- still answer false on the frame PLAYER_REGEN_DISABLED fires.
--
-- Guarded on the method existing: modules/Frame.lua loads after this file, so at file-load time
-- the member is not there yet. It always is by the time an event fires; the guard is the same
-- belt-and-braces the other cross-file seams carry rather than a live possibility.
function WhatGroup:OnCombatStateChanged(event)
    if not self.ApplyFrameVisibility then return end
    self:ApplyFrameVisibility(event == "PLAYER_REGEN_DISABLED")
end

function WhatGroup:GROUP_ROSTER_UPDATE()
    local inGroup = IsInGroup()
    -- Suppress the no-op tick log: this event fires on every roster
    -- change (talents, specs, auras on some patches) and floods chat.
    -- Only log on a transition or when there's pendingInfo to clear.
    if inGroup ~= wasInGroup or (not inGroup and self.pendingInfo) then
        NS.Debug("Roster", "inGroup=" .. tostring(inGroup)
            .. " wasInGroup=" .. tostring(wasInGroup)
            .. " hasPending=" .. tostring(self.pendingInfo ~= nil))
    end

    if inGroup and not wasInGroup then
        self:_TryFireJoinNotify("ROSTER transition")
    end
    wasInGroup = inGroup

    if not inGroup then
        self:WipeCapture()
    end
end

-- Statuses that end an application with no invite behind them. Blizzard sends the bare
-- "declined" only sometimes — a full or delisted group carries its reason in the status
-- string, and those are the declines a player actually meets — so all three spellings are
-- here. Without this arm a dead application's capture stayed in the tables until the next
-- group-leave and could be handed to a later invite (WG-R-07).
local APPLICATION_ENDED = {
    declined          = true,
    declined_full     = true,
    declined_delisted = true,
    cancelled         = true,
}

-- The two short status arms live out here rather than inline. The handler is the file's most
-- complex function and sits at the `code-quality-§3` ceiling; the "inviteaccepted" arm is the
-- one that has to be read as a whole, so the other two pay for it by being named instead.

-- Move the capture off its search-result key and onto the application id the server has just
-- minted for it. Nothing under that key is not an error: the apply may have happened with the
-- master switch off, or GetSearchResultInfo may have given nothing back.
local function pairApplication(self, appID)
    local resultID = self:ResolveSearchResultID(appID)
    local capture = capturesByResult[resultID]
    if capture then
        capturesByResult[resultID] = nil
        pendingApplications[appID] = capture
    end
end

-- Clear BOTH sides: "applied" may never have arrived, in which case the capture is still filed
-- under its search-result id and has no application id at all.
local function dropApplication(self, appID, newStatus)
    local resultID = self:ResolveSearchResultID(appID)
    local dropped  = pendingApplications[appID] or capturesByResult[resultID]
    capturesByResult[resultID] = nil
    pendingApplications[appID] = nil
    if dropped then
        NS.Debug("LFG", "dropped the capture for appID=%s (%s)",
            NS.SafeToString(appID), NS.SafeToString(newStatus))
    end
end

function WhatGroup:LFG_LIST_APPLICATION_STATUS_UPDATED(event, appID, newStatus)
    NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))
    if newStatus == "applied" then
        pairApplication(self, appID)
    elseif APPLICATION_ENDED[newStatus] then
        dropApplication(self, appID, newStatus)
    elseif newStatus == "invited" then -- luacheck: ignore 542
        -- Deliberately empty, and the emptiness is the behavior: "invited" is the client asking
        -- the player, not an answer, and the capture must survive untouched until "inviteaccepted"
        -- or one of APPLICATION_ENDED arrives -- multiple invites can arrive for one application.
        -- Named rather than folded into the `else` so a status this addon has no arm for still
        -- falls through to nothing by accident and this one falls through to nothing on purpose.
        -- The pragma is on the branch line and covers that line alone: the next empty branch
        -- written anywhere in this file, or this one, still reports.
    elseif newStatus == "inviteaccepted" then
        -- Master enable gate, same read as OnApplyToGroup: when disabled the
        -- addon must capture nothing, so the fresh re-fetch below never runs,
        -- pendingInfo is never set and no notify or popup follows. Without
        -- this the queue gate alone is not enough — the fresh fetch reaches
        -- the LFG API directly and would resurrect a capture the master
        -- switch was meant to suppress (WG-R-01).
        if not (self.db and self.db.profile and self.db.profile.enabled) then
            return
        end
        -- Pick the more-complete capture between fresh (re-fetched
        -- from the LFG API now that the invite is accepted) and
        -- queued (captured at apply time). Prefer whichever has
        -- mapID — that's the field most prone to apply-time staleness
        -- AND the one that drives the teleport icon. If both have
        -- mapID, fresh wins (most current data).
        local queued = pendingApplications[appID]
        -- Re-fetch through the application id, not by feeding appID to
        -- GetSearchResultInfo directly (F-004) — see
        -- CaptureGroupInfoFromApplication and docs/data-flow.md.
        local fresh  = self:CaptureGroupInfoFromApplication(appID)
        local final, source
        if fresh and fresh.mapID then
            final, source = fresh, "fresh"
        elseif queued and queued.mapID then
            final, source = queued, "queued"
        elseif fresh then
            final, source = fresh, "fresh"
        elseif queued then
            final, source = queued, "queued"
        end
        self.pendingInfo = final
        notifiedFor      = nil  -- new pendingInfo identity → eligible to fire again

        if final then
            NS.Debug("Invite", 'accepted appID=%s → "%s" map=%s (source=%s)',
                tostring(appID), tostring(final.title), tostring(final.mapID),
                tostring(source))
        else
            NS.Debug("Invite", "accepted appID=" .. tostring(appID) .. " → no capture")
        end

        wipe(capturesByResult)
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
-- Preview / test injection
-- ---------------------------------------------------------------------------
--
-- The slash surface itself lives in settings/Slash.lua: the COMMANDS table, the
-- host verbs, and the LibKa0s-Slash-1.0 descriptor that owns the dispatcher, the
-- help renderer, the value parser and the list/get/set/reset schema verbs. What
-- stays here is the one thing two callers share — `/wg test` and the settings
-- panel's Test button both need this body, and neither should go through the
-- other's entry point.

-- Public method so the Settings panel's Test button can invoke the
-- same code path as /wg test without going through the slash dispatch.
function WhatGroup:RunTest()
    -- mapID 2805 is Windrunner Spire — exercises the mapID-keyed teleport
    -- lookup (1254400, Path of the Windrunners). generalPlaystyle exercises
    -- the enum-based label path; leave playstyleString empty so the lookup
    -- falls through to WhatGroup.Labels.PLAYSTYLE instead of using the
    -- pre-rendered string.
    --
    -- activityID is synthetic and deliberately NOT a key in TeleportSpells:
    -- the resolver checks mapID first, so a fixture whose activityID also
    -- named a real row would still pass with the mapID path broken.
    self.pendingInfo = {
        title             = "Test Group — Windrunner Spire +12",
        leaderName        = "Testadin-Silvermoon",
        numMembers        = 3,
        voiceChat         = "",
        age               = 127,
        activityIDs       = {990001},
        activityID        = 990001,
        fullName          = "Dungeons > Mythic+ > Windrunner Spire",
        activityName      = "Windrunner Spire",
        maxNumPlayers     = 5,
        isMythicPlus      = true,
        isCurrentRaid     = false,
        isHeroicRaid      = false,
        categoryID        = 1,
        mapID             = 2805,
        generalPlaystyle  = Enum.LFGEntryGeneralPlaystyle.FunSerious,
        playstyle         = Enum.LFGEntryGeneralPlaystyle.FunSerious,
        playstyleString   = "",
        shortName         = "Mythic+",
    }
    NS.Debug("Test", 'synthetic capture injected "' .. tostring(self.pendingInfo.title) .. '"')
    self:ShowNotification()
    self:ShowFrame()
end
