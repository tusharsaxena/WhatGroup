-- WhatGroup_Frame.lua
-- Custom popup dialog frame for displaying group details.
--
-- Everything in this file is **lazy** — no frames are created at file
-- load. The popup, the Close button, the SecureActionButtonTemplate
-- teleport button, and the UISpecialFrames registration all happen
-- inside `buildFrame()`, which fires on the first `WhatGroup:ShowFrame()`
-- call.
--
-- The reason for the lazy approach is taint: creating the popup +
-- secure button + UISpecialFrames entry at PLAYER_LOGIN was leaving a
-- taint trace that surfaced as `ADDON_ACTION_FORBIDDEN ... 'callback()'`
-- when the player clicked the GameMenu's Logout button — even on a
-- fresh /reload with no addon use. Deferring all of that until the
-- player actually opens the popup means the addon adds nothing to
-- Blizzard's secure-execute or UISpecialFrames lists during the boot
-- sequence, so GameMenu's `InitButtons` runs in a clean context and
-- the closures it builds for Logout / Settings / Macros are
-- taint-free. See [docs/wow-quirks.md] for the full taint analysis.

local FRAME_WIDTH  = 420
local FRAME_HEIGHT = 260
local LABEL_WIDTH  = 72
local yGap         = -18

-- Mirror of the chat-side table in WhatGroup.lua. Kept independently
-- duplicated so the popup file doesn't take a dependency on
-- WhatGroup.lua's internals at file-load time. See docs/frame.md.
local PLAYSTYLE_LABELS = {
    [Enum.LFGEntryGeneralPlaystyle.Learning]   = GROUP_FINDER_GENERAL_PLAYSTYLE1,
    [Enum.LFGEntryGeneralPlaystyle.FunRelaxed] = GROUP_FINDER_GENERAL_PLAYSTYLE2,
    [Enum.LFGEntryGeneralPlaystyle.FunSerious] = GROUP_FINDER_GENERAL_PLAYSTYLE3,
    [Enum.LFGEntryGeneralPlaystyle.Expert]     = GROUP_FINDER_GENERAL_PLAYSTYLE4,
}

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

-- These get assigned inside buildFrame() and are nil until the popup
-- is first shown. PopulateFields and ConfigureTeleportButton both
-- read them after buildFrame() has run, so they're always non-nil
-- by the time those functions execute.
local f, fields, ConfigureTeleportButton

local function buildFrame()
    if f then return end   -- one-shot

    f = CreateFrame("Frame", "WhatGroupFrame", UIParent, "BackdropTemplate")
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

    -- Title bar (drag handle)
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

    -- Content frame (plain, no scroll)
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT",     f, "TOPLEFT",   14, -38)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 44)

    -- Label builder
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

    local topAnchor = CreateFrame("Frame", nil, content)
    topAnchor:SetSize(1, 1)
    topAnchor:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -4)

    local lblGroup, valGroup = MakeLabel(content, topAnchor, 0,    "Group:",     "—")
    local lblInst,  valInst  = MakeLabel(content, lblGroup,  yGap, "Instance:",  "—")
    local lblType,  valType  = MakeLabel(content, lblInst,   yGap, "Type:",      "—")
    local lblLead,  valLead  = MakeLabel(content, lblType,   yGap, "Leader:",    "—")
    local lblStyle, valStyle = MakeLabel(content, lblLead,   yGap, "Playstyle:", "—")

    local lblPort = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblPort:SetPoint("TOPLEFT", lblStyle, "BOTTOMLEFT", 0, yGap)
    lblPort:SetText("|cffFFD700Teleport:|r")
    lblPort:SetJustifyH("LEFT")
    lblPort:SetWidth(LABEL_WIDTH)
    lblPort:SetWordWrap(false)

    -- Secure cast button — anonymous (no global name), parented
    -- directly to f, anchored via the implicit-parent SetPoint form
    -- (no explicit relativeTo, which is the only form the secure-frame
    -- system accepts on a protected frame). The (92, -68) offset
    -- positions the button at the Teleport row, right of the
    -- "Teleport:" label.
    local teleportBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    teleportBtn:SetSize(24, 24)
    teleportBtn:SetPoint("LEFT", 92, -68)
    teleportBtn:RegisterForClicks("AnyUp", "AnyDown")
    teleportBtn:Hide()

    local teleportIcon = teleportBtn:CreateTexture(nil, "ARTWORK")
    teleportIcon:SetAllPoints()

    content:SetHeight(math.abs(yGap) * 6 + 24)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    closeBtn:SetText("Close")
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ESC to close — register with UISpecialFrames *now*, lazily.
    -- Earlier versions did this at file-load and that addition was
    -- leaving taint that surfaced on Logout. Deferring it to here
    -- means the entry only exists once the player has actually opened
    -- the popup, by which point Blizzard's GameMenu has already
    -- initialised its button callbacks in a clean context.
    tinsert(UISpecialFrames, "WhatGroupFrame")

    fields = {
        group        = valGroup,
        instance     = valInst,
        type         = valType,
        leader       = valLead,
        playstyle    = valStyle,
        teleportBtn  = teleportBtn,
        teleportIcon = teleportIcon,
    }

    -- ConfigureTeleportButton is closed over `teleportBtn` /
    -- `teleportIcon` indirectly via the `fields` table. Defining it
    -- here (inside buildFrame) means it doesn't exist until the popup
    -- exists, which keeps it out of any addon-load-time iteration.
    ConfigureTeleportButton = function(btn, icon, info)
        -- Secure-button attribute writes (`type`, `macrotext`) and
        -- Show/Hide are protected while in combat — silently dropped,
        -- not erroring. Stash the info, queue a re-run on combat-end,
        -- and bail. The button retains its prior visual state until
        -- PLAYER_REGEN_ENABLED fires; at that point we Configure with
        -- the most recently-stashed info.
        if InCombatLockdown() then
            f._pendingTeleportInfo = info
            f:RegisterEvent("PLAYER_REGEN_ENABLED")
            f:SetScript("OnEvent", function(self, ev)
                if ev ~= "PLAYER_REGEN_ENABLED" then return end
                self:UnregisterEvent("PLAYER_REGEN_ENABLED")
                self:SetScript("OnEvent", nil)
                local pending = self._pendingTeleportInfo
                self._pendingTeleportInfo = nil
                if pending then
                    ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, pending)
                end
            end)
            return
        end

        local spellID, known = WhatGroup:GetTeleportSpell(info and info.activityID, info and info.mapID)
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

        btn:Show()
    end
end

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

    fields.group:SetText(info.title)

    local instText = info.fullName ~= "" and info.fullName or "Unknown"
    fields.instance:SetText(instText)

    local typeStr = info.shortName ~= "" and info.shortName or GetGroupTypeLabel(info)
    fields.type:SetText(typeStr)

    fields.leader:SetText(info.leaderName)

    -- Prefer the server-rendered playstyleString when present; otherwise
    -- look up the integer enum in PLAYSTYLE_LABELS. Empty string ("") and
    -- Enum.LFGEntryGeneralPlaystyle.None (= 0) both fall through to the
    -- dim em-dash placeholder.
    local playStyle = info.playstyleString
    if not playStyle or playStyle == "" then
        playStyle = PLAYSTYLE_LABELS[info.generalPlaystyle] or ""
    end
    fields.playstyle:SetText(playStyle ~= "" and playStyle or "|cff888888—|r")

    ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, info)
end

-- Public API
function WhatGroup:ShowFrame()
    -- First-show-in-combat defer: buildFrame creates a
    -- SecureActionButtonTemplate button and inserts into UISpecialFrames;
    -- both operations are protected. If we're in combat AND the popup
    -- has never been built, queue the build on PLAYER_REGEN_ENABLED and
    -- print a chat hint. Once buildFrame has run once, subsequent calls
    -- are safe in combat (only the secure-button reconfigure, handled
    -- by ConfigureTeleportButton's own combat guard, is at risk).
    if not f and InCombatLockdown() then
        if WhatGroup._print then
            WhatGroup._print("Popup deferred until combat ends.")
        end
        if not WhatGroup._frameBuildQueued then
            WhatGroup._frameBuildQueued = true
            local pending = WhatGroup.pendingInfo
            local waitFrame = CreateFrame("Frame")
            waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            waitFrame:SetScript("OnEvent", function(self)
                self:UnregisterAllEvents()
                self:SetScript("OnEvent", nil)
                WhatGroup._frameBuildQueued = nil
                -- Restore the captured pendingInfo only if it was
                -- cleared (e.g. group-leave) during the wait window;
                -- the user's intent was to see *this* group's popup.
                WhatGroup.pendingInfo = WhatGroup.pendingInfo or pending
                WhatGroup:ShowFrame()
            end)
        end
        return
    end

    buildFrame()    -- lazy: creates the popup + secure button +
                    -- UISpecialFrames entry on first call only.
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
end
