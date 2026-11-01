local addonName, NS = ...

-- modules/FrameLayout.lua -- the group-info popup's regions: the title bar, the field rows, the
-- secure teleport button with its icon, swipe and note, and the Close button. Peeled out of
-- modules/Frame.lua's buildFrame (WHATGROUP-R-14). modules/Frame.lua creates the window, sets its
-- OnHide and OnShow, and owns every state; this file only lays out what goes in it.
--
-- NOTHING HERE RUNS AT LOAD. Build is called from buildFrame, on the first show, for the taint
-- reason modules/Frame.lua's header gives: a secure button created during boot is what broke the
-- GameMenu's Logout.
--
-- The returns are the title bar and the Close button, the two plain controls the combat soft hide
-- makes mouse-dead, and `fields`, the table PopulateFields and the teleport configure write to.

local WhatGroup = NS.addon
local L         = NS.L

local LABEL_WIDTH  = 72
local yGap         = -18
local Look         = NS.FrameSkin     -- the popup's look (modules/FrameSkin.lua, loaded above)

local FrameLayout = {}
NS.FrameLayout = FrameLayout

--- f is the popup, dismissPopup what the Close button runs.
function FrameLayout.Build(f, dismissPopup)
    -- The whole look comes from the owner's skin (skinning-§3): the window through NS.ApplySkin
    -- with the owner, which hands it to the skin's Shell, and every string and control through
    -- modules/FrameSkin.lua, which also repaints the title and re-anchors the secure button on a
    -- skin change. `f.title` and `f.divider` are assigned first, below, because the Shell tints
    -- whichever of them the frame carries, so the call sits after the header.

    -- Title bar (drag handle)
    local titleBar = CreateFrame("Frame", nil, f)
    titleBar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(30)   -- the skin's title.height takes over at Look.TitleBar, below; 30 degraded
    titleBar:EnableMouse(true)
    -- LOCKED IS READ AT DRAG TIME, not wired once: the checkbox is a plain profile value with no
    -- onChange, because there is nothing to apply -- the next mouse-down is where it takes effect.
    -- StopMovingOrSizing and the save still run unconditionally; both are harmless on a frame that
    -- never started moving, and guarding them would leave a drag that began before the lock was
    -- ticked stuck to the cursor.
    titleBar:SetScript("OnMouseDown", function()
        local pr = WhatGroup.db and WhatGroup.db.profile
        if pr and pr.locked then return end
        f:StartMoving()
    end)
    titleBar:SetScript("OnMouseUp",   function()
        f:StopMovingOrSizing()
        NS.Windows.Save("popup", f)   -- persist geometry (WG-26)
    end)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titleText:SetPoint("CENTER", titleBar, "CENTER", 0, 0)
    Look.Title(titleText)
    f.title = titleText

    -- Separator line under title. The color is set by ApplySkin below (0.24, 0.24, 0.27, 0.85 —
    -- the normative Ka0s divider), so no literal here.
    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT",  titleBar, "BOTTOMLEFT",  14, 0)
    sep:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", -14, 0)
    f.divider = sep

    -- Wear the shared skin for this owner (skinning-§1), now that the two regions it tints exist.
    NS.ApplySkin(f, nil, addonName)
    Look.TitleBar(f, titleBar, titleText)

    -- Content frame (plain, no scroll). Hung off the bar, as the divider is, so title.height moves both.
    local content = CreateFrame("Frame", nil, f)
    content:SetPoint("TOPLEFT",     titleBar, "BOTTOMLEFT", 14, -8)
    content:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -14, 44)

    -- Label builder
    local function MakeLabel(parent, anchor, yOffset, labelText, valueText)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, yOffset)
        label:SetWidth(LABEL_WIDTH)
        label:SetText(labelText)
        Look.Label(label)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(false)

        local value = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        value:SetPoint("TOPLEFT", label, "TOPLEFT", LABEL_WIDTH + 6, 0)
        value:SetJustifyH("LEFT")
        Look.Value(value, valueText or "")

        return label, value
    end

    local topAnchor = CreateFrame("Frame", nil, content)
    topAnchor:SetSize(1, 1)
    topAnchor:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -4)

    local lblGroup, valGroup = MakeLabel(content, topAnchor, 0,    L["Group:"],     "—")
    local lblInst,  valInst  = MakeLabel(content, lblGroup,  yGap, L["Instance:"],  "—")
    local lblType,  valType  = MakeLabel(content, lblInst,   yGap, L["Type:"],      "—")
    local lblLead,  valLead  = MakeLabel(content, lblType,   yGap, L["Leader:"],    "—")
    -- The signed-up role (WhatGroup#1). Always drawn: notify.showRole gates the chat row only.
    local lblRole,  valRole  = MakeLabel(content, lblLead,   yGap, L["Role:"],      "—")
    local lblStyle, valStyle = MakeLabel(content, lblRole,   yGap, L["Playstyle:"], "—")

    local lblPort = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lblPort:SetPoint("TOPLEFT", lblStyle, "BOTTOMLEFT", 0, yGap)
    lblPort:SetText(L["Teleport:"])
    Look.Label(lblPort)
    lblPort:SetJustifyH("LEFT")
    lblPort:SetWidth(LABEL_WIDTH)
    lblPort:SetWordWrap(false)

    -- Secure cast button — anonymous (no global name), parented directly to f, and anchored
    -- beside the Teleport label by modules/FrameSkin.lua (Look.Attach, below), which takes the
    -- offset from the label's rendered position and takes it again when a skin's font moves it.
    local teleportBtn = CreateFrame("Button", nil, f, "SecureActionButtonTemplate")
    teleportBtn:SetSize(24, 24)
    -- BOTH edges are required, and this comment is the reason. WG-R-05 offered two resolutions —
    -- "register one click edge" OR "document the PreClick gate as the reason both are needed" —
    -- and this is the second one, taken on measured in-game evidence.
    --
    -- A bare SecureActionButtonTemplate with type="macro" does NOT run its macro on the down
    -- edge. Blizzard's own action buttons cast on down because they opt into it; this button
    -- inherits none of that, so "AnyUp" is the edge that actually executes `/cast`.
    -- Registering "AnyDown" alone is SILENT failure with no Lua error: the button still receives
    -- the down edge — the PreClick trace (modules/Frame.lua) proves it, by printing — and nothing is cast.
    -- That regression shipped once, in [M4-24], on the reasoned-but-never-tested premise that two
    -- registered edges meant two casts per press. In the client it means one cast, on the up edge.
    --
    -- The PreClick trace gates on `down` precisely so that carrying both edges still yields
    -- exactly one debug line per press. That gate is what makes the second edge free.
    teleportBtn:RegisterForClicks("AnyUp", "AnyDown")
    teleportBtn:Hide()
    Look.Attach({ frame = f, title = titleText, label = lblPort, button = teleportBtn,
                  labelWidth = LABEL_WIDTH })

    local teleportIcon = teleportBtn:CreateTexture(nil, "ARTWORK")
    teleportIcon:SetAllPoints()

    -- The icon's edge is the skin's (S.IconBorder), on a plain child and never on the secure button:
    -- a skin switch repaints in combat, and a nine-slice skin re-anchors the holder against whatever
    -- it was handed. A child shows, hides and dims with the button, and takes no mouse.
    local teleportEdge = CreateFrame("Frame", nil, teleportBtn)
    teleportEdge:SetAllPoints()
    Look.IconEdge(teleportEdge)

    -- The swipe has no Lua-side repeat: the Cooldown widget animates engine-side once armed, so it
    -- costs the addon no OnUpdate and no timer of its own. The note's countdown beside the button
    -- is the one repeating thing in the addon, the ratified cooldown ticker (modules/Frame.lua's stopCooldownTicker;
    -- the reasoning is in docs/performance.md and the performance-§12 register row). The
    -- numbers are hidden because at 24px they are unreadable, and the note carries the figure.
    local teleportSwipe = CreateFrame("Cooldown", nil, teleportBtn, "CooldownFrameTemplate")
    teleportSwipe:SetAllPoints()
    teleportSwipe:SetHideCountdownNumbers(true)

    -- Sits beside the button rather than on it, for the same reason: a readable sentence at the
    -- popup's own font size, where a 24px overlay would be a smear. Anchored to the Teleport label
    -- (a plain frame region) rather than to the secure button, whose anchoring is restricted.
    local teleportNote = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    teleportNote:SetPoint("TOPLEFT", lblPort, "TOPLEFT", LABEL_WIDTH + 6 + 24 + 8, -6)
    teleportNote:SetJustifyH("LEFT")
    Look.Note(teleportNote)
    teleportNote:Hide()

    -- (No content:SetHeight here — content's TOPLEFT and BOTTOMRIGHT
    -- anchors fully determine its size, so a SetHeight call would be a
    -- no-op overridden by the anchors.)

    -- Close button
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    closeBtn:SetSize(90, 24)
    closeBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 12)
    closeBtn:SetText(L["Close"])
    -- Goes through hidePopup for the reason spelled out at ApplyFrameVisibility: f parents a
    -- SecureActionButtonTemplate button, so f:Hide() is refused in combat and calling it anyway
    -- raised ADDON_ACTION_BLOCKED naming this addon. The press is remembered instead and honored
    -- the moment the lockdown lifts, which is the closest thing to "close" the client permits.
    closeBtn:SetScript("OnClick", dismissPopup)
    Look.Button(closeBtn)   -- after the script: the primitive HookScripts its hover pair

    return titleBar, closeBtn, {
        group        = valGroup,
        instance     = valInst,
        type         = valType,
        leader       = valLead,
        role         = valRole,
        playstyle    = valStyle,
        teleportBtn   = teleportBtn,
        teleportIcon  = teleportIcon,
        teleportSwipe = teleportSwipe,
        teleportNote  = teleportNote,
    }
end
