-- modules/Frame.lua
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

local addonName, NS = ...
local WhatGroup = NS.addon
local L         = NS.L

local FRAME_WIDTH  = 420
local FRAME_HEIGHT = 260
local LABEL_WIDTH  = 72
local yGap         = -18

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
    -- Restore the saved position over the default center if the player has moved
    -- the popup before (WG-26; no-op on a fresh profile). Anchored offsets for
    -- the secure teleport button below are computed relative to f, so they stay
    -- aligned wherever f ends up.
    NS.Windows.Restore("popup", f)
    f:Hide()

    -- The whole look — backdrop AND colors — now comes from LibKa0s-Core-1.0's shared SKIN
    -- through NS.ApplySkin (standalone-windows: the Ka0s window edge is normative, and a window
    -- MUST NOT draw one that diverges from it). The popup's own 1px hairline is what the shared
    -- edge already is, so the geometry is unchanged; what it gains is the 1px gray inner highlight
    -- ApplySkin synthesizes, and a black outer border in place of the old gray one.
    --
    -- `f.title` and `f.divider` are assigned first, below, because ApplySkin tints whichever of
    -- them the frame carries and skips the ones it does not — which is why the call itself sits
    -- after the header rather than here. The title's own |cffFFD700 span survives the tint (an
    -- inline color code wins over SetTextColor for its span), and the gold ApplySkin sets is the
    -- color GameFontNormalLarge already renders in, so the header reads exactly as before.

    -- Title bar (drag handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)
    titleBar:EnableMouse(true)
    titleBar:SetScript("OnMouseDown", function() f:StartMoving() end)
    titleBar:SetScript("OnMouseUp",   function()
        f:StopMovingOrSizing()
        NS.Windows.Save("popup", f)   -- persist geometry (WG-26)
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, -2)
    titleText:SetText("|cffFFD700" .. L["WhatGroup"] .. "|r — " .. L["Group Info"])
    f.title = titleText

    -- Separator line under title. The color is set by ApplySkin below (0.24, 0.24, 0.27, 0.85 —
    -- the normative Ka0s divider), so no literal here.
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  f, "TOPLEFT",  14, -30)
    sep:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -30)
    f.divider = sep

    -- Wear the shared skin, now that the two regions it tints exist.
    NS.ApplySkin(f)

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

    local lblGroup, valGroup = MakeLabel(content, topAnchor, 0,    L["Group:"],     "—")
    local lblInst,  valInst  = MakeLabel(content, lblGroup,  yGap, L["Instance:"],  "—")
    local lblType,  valType  = MakeLabel(content, lblInst,   yGap, L["Type:"],      "—")
    local lblLead,  valLead  = MakeLabel(content, lblType,   yGap, L["Leader:"],    "—")
    local lblStyle, valStyle = MakeLabel(content, lblLead,   yGap, L["Playstyle:"], "—")

    local lblPort = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblPort:SetPoint("TOPLEFT", lblStyle, "BOTTOMLEFT", 0, yGap)
    lblPort:SetText("|cffFFD700" .. L["Teleport:"] .. "|r")
    lblPort:SetJustifyH("LEFT")
    lblPort:SetWidth(LABEL_WIDTH)
    lblPort:SetWordWrap(false)

    -- Secure cast button — anonymous (no global name), parented directly
    -- to f. The implicit-parent SetPoint form is the only one the
    -- secure-frame system accepts on a protected frame, so we anchor
    -- the button's TOPLEFT against f's TOPLEFT with offsets derived
    -- from the Teleport label's actual rendered position. This way the
    -- button stays aligned with its label even if LABEL_WIDTH, yGap,
    -- or the row count changes — no magic offsets to retune.
    local btnX = (lblPort:GetLeft() - f:GetLeft()) + LABEL_WIDTH + 6
    local btnY = lblPort:GetTop()  - f:GetTop()   -- negative; lblPort sits below f.TOPLEFT

    local teleportBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    teleportBtn:SetSize(24, 24)
    teleportBtn:SetPoint("TOPLEFT", btnX, btnY)
    -- BOTH edges are required, and this comment is the reason. WG-R-05 offered two resolutions —
    -- "register one click edge" OR "document the PreClick gate as the reason both are needed" —
    -- and this is the second one, taken on measured in-game evidence.
    --
    -- A bare SecureActionButtonTemplate with type="macro" does NOT run its macro on the down
    -- edge. Blizzard's own action buttons cast on down because they opt into it; this button
    -- inherits none of that, so "AnyUp" is the edge that actually executes `/cast`.
    -- Registering "AnyDown" alone is SILENT failure with no Lua error: the button still receives
    -- the down edge — the PreClick trace below proves it, by printing — and nothing is cast.
    -- That regression shipped once, in [M4-24], on the reasoned-but-never-tested premise that two
    -- registered edges meant two casts per press. In the client it means one cast, on the up edge.
    --
    -- The PreClick trace gates on `down` precisely so that carrying both edges still yields
    -- exactly one debug line per press. That gate is what makes the second edge free.
    teleportBtn:RegisterForClicks("AnyUp", "AnyDown")
    teleportBtn:Hide()

    local teleportIcon = teleportBtn:CreateTexture(nil, "ARTWORK")
    teleportIcon:SetAllPoints()

    -- (No content:SetHeight here — content's TOPLEFT and BOTTOMRIGHT
    -- anchors fully determine its size, so a SetHeight call would be a
    -- no-op overridden by the anchors.)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    closeBtn:SetText(L["Close"])
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ESC to close — register with UISpecialFrames *now*, lazily.
    -- Earlier versions did this at file-load and that addition was
    -- leaving taint that surfaced on Logout. Deferring it to here
    -- means the entry only exists once the player has actually opened
    -- the popup, by which point Blizzard's GameMenu has already
    -- initialized its button callbacks in a clean context.
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
        NS.Debug("Frame", "teleport spellID=" .. tostring(spellID)
            .. " known=" .. tostring(known)
            .. " (activity=" .. tostring(info and info.activityID)
            .. " map=" .. tostring(info and info.mapID) .. ")")
        if not spellID then
            btn:SetAttribute("type", nil)
            btn:SetAttribute("macrotext", nil)
            btn:Hide()
            return
        end

        local spellName = NS.Compat.GetSpellName(spellID)
        local texID     = NS.Compat.GetSpellTexture(spellID) or 134400

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
            -- Material-effect trace (debug-logging-§10): log the actual press.
            -- The button registers the down edge only (see RegisterForClicks in buildFrame), so
            -- one press is one line. The `down` check stays as a guard rather than a filter: it
            -- costs nothing and keeps the trace honest if the registration is ever widened again.
            -- PreClick is non-secure work that runs alongside the secure /cast, so it's taint-free
            -- even in combat.
            btn:SetScript("PreClick", function(_, mouseButton, down)
                if down then
                    NS.Debug("Frame", "teleport button pressed \226\134\146 /cast "
                        .. spellName .. " (spellID=" .. tostring(spellID)
                        .. ", button=" .. tostring(mouseButton) .. ")")
                end
            end)
        else
            btn:SetAttribute("type", nil)
            btn:SetAttribute("macrotext", nil)
            btn:EnableMouse(false)
            btn:SetScript("OnEnter", nil)
            btn:SetScript("OnLeave", nil)
            btn:SetScript("PreClick", nil)
        end

        btn:Show()
    end
end

local function PopulateFields()
    local info = WhatGroup.pendingInfo
    if not info then
        local noData = "|cff888888" .. L["No data"] .. "|r"
        fields.group:SetText(noData)
        fields.instance:SetText(noData)
        fields.type:SetText(noData)
        fields.leader:SetText(noData)
        fields.playstyle:SetText("|cff888888—|r")
        fields.teleportBtn:Hide()
        return
    end

    fields.group:SetText(info.title)

    local instText = info.fullName ~= "" and info.fullName or L["Unknown"]
    fields.instance:SetText(instText)

    local Labels = WhatGroup.Labels
    local typeStr = info.shortName ~= "" and info.shortName or Labels.GetGroupTypeLabel(info)
    fields.type:SetText(typeStr)

    fields.leader:SetText(info.leaderName)

    -- Through the sibling of the GetGroupTypeLabel call above, not open-coded: the helper already
    -- prefers the server-rendered playstyleString and falls back to the PLAYSTYLE enum lookup, and
    -- a second copy here is the copy that would keep the old rule the day the helper changes.
    -- Empty string ("") and Enum.LFGEntryGeneralPlaystyle.None (= 0) both come back as "" and fall
    -- through to the dim em-dash placeholder, which stays the POPUP's decision — the chat summary
    -- renders the same absence differently.
    local playStyle = Labels.GetPlaystyleLabel(info)
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
            WhatGroup._print(L["Popup deferred until combat ends."])
        end
        if not WhatGroup._frameBuildQueued then
            WhatGroup._frameBuildQueued = true
            local pending = WhatGroup.pendingInfo
            local waitFrame = CreateFrame("Frame")
            waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            waitFrame:SetScript("OnEvent", function(wf)
                wf:UnregisterAllEvents()
                wf:SetScript("OnEvent", nil)
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
    do
        local info = WhatGroup.pendingInfo
        NS.Debug("Frame", info
            and ('popup shown "' .. tostring(info.title) .. '" map='
                 .. tostring(info.mapID))
            or "popup shown (no pendingInfo → 'No data' fallbacks)")
    end
    PopulateFields()
    f:Show()
    f:Raise()
end
