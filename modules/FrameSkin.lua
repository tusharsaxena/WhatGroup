local _, NS = ...

-- modules/FrameSkin.lua — the group-info popup's LOOK (skinning-§3, WG-02): every string and
-- control modules/Frame.lua draws takes its colors and font from the owner's skin facade
-- (core/SkinSetup.lua's NS.Skin, LibKa0s-Skin-1.0), never from a literal (anti-pattern #107).
--
-- ── WHAT IT PUBLISHES (NS.FrameSkin) ─────────────────────────────────────────────────────────
--
--   Title(fs)            the header text: the "WhatGroup" span in `wg.brand`, the rest in the
--                        title color the window's Shell gives `f.title`. Re-run on every skin
--                        change, because an escape is baked into the string.
--   Label(fs)            a field label in `wg.label`, in the body font.
--   Value(fs, text, dim) a field value: the text, in `text.highlight`, or with `dim` in
--                        `wg.placeholder` (the "No data" and em-dash placeholders).
--   Note(fs)             the teleport note beside the button, in `wg.placeholder`.
--   Button(btn)          the skin's push button (the Close button). Called after its OnClick is
--                        set: the primitive HookScripts its hover pair.
--   Attach(parts)        hands over the popup's frame, title, Teleport label and secure button,
--                        then anchors the button (AnchorTeleport).
--   AnchorTeleport()     the secure button's TOPLEFT beside its label, from the label's rendered
--                        position. Refused in combat and queued for combat end. A no-op while
--                        the addon stands down; NS.StandUp (core/WhatGroup.lua) calls it again.
--
-- ── WHY TOKENS AND NOT ROLES ─────────────────────────────────────────────────────────────────
--
-- The popup's gold (FFD700) and gray (888888) sit 6/255 and 8/255 off the nearest library roles,
-- so each is an owner token that keeps its Ka0s Default pixel and follows its role under every
-- other skin (the rollout's X1, X2 and X12; core/SkinSetup.lua's NS.SKIN_TOKENS). S.Text given a
-- token name paints that color in the body font and replays it on a skin switch, so nothing here
-- repaints a label or a value by hand: a later S.Text on the same string replaces the recorded
-- arguments, which is how a value moves between its placeholder and its data.
--
-- ── THE ONE THING A SWITCH REDOES BY HAND ────────────────────────────────────────────────────
--
-- OnLooksChanged (after the library has repainted every recorded string) re-sets the title,
-- whose brand span is markup, and re-anchors the secure teleport button. Its offset comes from
-- the Teleport label's rendered position, and the rows are stacked label to label, so a skin with
-- a larger body font moves the label and would leave the button behind (the inventory's R2). The
-- button is protected: SetPoint is refused in combat, so the anchor waits for combat end on
-- modules/Frame.lua's queue. Nothing here runs PopulateFields or ConfigureTeleportButton, whose
-- secure attribute writes have their own combat path (R3).

local L = NS.L
local FrameSkin = {}
NS.FrameSkin = FrameSkin

-- What Attach handed over; nil until the popup is built, which keeps a skin switch before the
-- first show a no-op (the popup is lazy for taint reasons, modules/Frame.lua's header).
local parts
local anchored = {}   -- the x, y last applied, so a switch that moved nothing queues nothing

function FrameSkin.Title(fs)
    fs:SetText((NS.SkinEscape("wg.brand") or "") .. L["WhatGroup"] .. "|r — " .. L["Group Info"])
end

function FrameSkin.Label(fs) NS.Skin.Text(fs, "wg.label") end

function FrameSkin.Value(fs, text, dim)
    fs:SetText(text)
    NS.Skin.Text(fs, dim and "wg.placeholder" or "text.highlight")
end

function FrameSkin.Note(fs) NS.Skin.Text(fs, "wg.placeholder") end

function FrameSkin.Button(btn) NS.Skin.Button(btn) end

function FrameSkin.AnchorTeleport()
    local p = parts
    if not p then return end
    -- Stood down, the addon owes no protected work: NS.FrameStandDown wiped the combat-end queue
    -- and nothing drains it again until the stand-up, so a skin moved meanwhile (another Ka0s
    -- addon's "Copy to every Ka0s addon", an EllesmereUI repaint) would leave an entry held. The
    -- cache is left alone, so the stand-up's call computes the anchor afresh.
    if NS.IsStoodDown and NS.IsStoodDown() then return end
    -- The implicit-parent SetPoint form is the only one the secure-frame system accepts on a
    -- protected frame, so the offsets are taken against f's TOPLEFT from where the Teleport label
    -- actually renders: the button stays beside its label whatever LABEL_WIDTH, the row gap, the
    -- row count or the skin's font does.
    local x = (p.label:GetLeft() - p.frame:GetLeft()) + p.labelWidth + 6
    local y = p.label:GetTop() - p.frame:GetTop()   -- negative; the label sits below f.TOPLEFT
    if anchored.x == x and anchored.y == y then return end
    if InCombatLockdown() then
        NS.FrameQueueForCombatEnd("teleportAnchor", FrameSkin.AnchorTeleport)
        return
    end
    p.button:ClearAllPoints()
    p.button:SetPoint("TOPLEFT", x, y)
    anchored.x, anchored.y = x, y
end

--- parts = { frame, title, label (the Teleport label), button (the secure one), labelWidth }.
function FrameSkin.Attach(t)
    parts = t
    FrameSkin.AnchorTeleport()
end

local function reskin()
    if not parts then return end
    FrameSkin.Title(parts.title)
    FrameSkin.AnchorTeleport()
end

if NS.Skin then NS.Skin.OnLooksChanged(reskin) end
