local addonName, NS = ...

-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§1 to §3).
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("WhatGroup")`: the painting vocabulary
--                           (Shell, TitleBar, Button, Font, Text, ...) and Token / Color / Resolve /
--                           OnLooksChanged. Every surface that draws reads its colors here.
--   NS.SKIN_TOKENS          this addon's own tokens (skinning-§1, LibKa0s-Skin-1.0 minor 7), handed
--                           to RegisterOwner: the colors the popup draws that no library token
--                           holds exactly. Each keeps its Ka0s Default value and follows a role
--                           token in every other skin (the rollout's X1, X2 and X12).
--   NS.SkinChoice()         the stored (source, skin) pair, read through Helpers.Get; "ka0s",
--                           "ka0s" before OnInitialize has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through Helpers.Set, the one seam
--                           `/wg set` and the panel already write through (architecture-§5); `i`,
--                           the Scope's `{ panel, fonts }`, writes the two exceptions, and `m`, the
--                           Font and texture section's `{ font, texture }` (LibKa0s-Skin-1.0 minor
--                           6), writes the two overrides, "" for false (the skin's own).
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before the store exists.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints
--                           every frame recorded for this owner and THEN fires OnLooksChanged. No
--                           argument applies the stored pair (addon:OnInitialize, the profile
--                           events), and with it the stored exceptions and overrides; a nil half
--                           keeps that half (each Appearance row's onChange).
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions: `Skin:SetIgnore`, live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.ApplySkinOverride(f,t) moves the applied overrides: `Skin:SetOverride`, live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/Schema.lua reads both.
--   NS.SKIN_FALLBACK        the host copy of the Ka0s Default tokens the degraded facade answers.
--   NS.SkinColor(name)      a color token as a call site writes it (three components when opaque).
--   NS.SkinEscape(name)     a color token as a "|cffrrggbb" escape, rounded to the byte, so markup
--                           written as a literal keeps its bytes on Ka0s Default (|cffffd700).
--   NS.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this owner:
--   NS.SkinPaintAceTree(c)  `Skin:PaintAce` / `Skin:PaintAceTree` with the owner bound (the facade
--                           carries neither). Release restores stock.
--   NS.SkinOnRelease(w, fn) host release work chained onto the widget's own OnRelease
--                           (`Skin:OnRelease`), so it and the skin's restore both run.
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua, whose NS.BRAND_NAME is the owner's label at THIS file's load and whose
-- NS.ApplySkin the degraded facade's Shell routes to; before settings/Schema.lua, which reads
-- NS.SKIN_OPTIONS at file load, and before modules/Frame.lua, the one module that paints. The call
-- runs at FILE LOAD, never at PLAYER_LOGIN, because the EllesmereUI provider offers the owner to
-- EllesmereUI before EllesmereUI dispatches its skins (skinning-§5). Nothing here reads the profile
-- at load: RegisterOwner calls `get` once, before AceDB exists, and it answers Ka0s Default; the
-- profile's pair is applied by NS.ApplySkinChoice right after AceDB:New (core/WhatGroup.lua).
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Appearance tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice
-- FIRST and write the store after, one half at a time. A row reaction that re-applied the whole
-- stored pair would apply the half-written one in between: a second repaint, to a skin the player
-- never picked. Applying only the row's own half against the applied choice makes each write a
-- no-op (SetChoice is idempotent), so a pick is ONE effective SetChoice and one repaint, while a
-- bare `/wg set skin.skin obsidian` still repaints. Nothing skin-related keys off a settings
-- refresh: a surface that rebuilds on a skin change subscribes to NS.Skin.OnLooksChanged.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local DEFAULT = "ka0s"

-- This addon's own tokens (skinning-§1). The popup draws two colors no library token holds
-- exactly: the brand gold FFD700 on the title's "WhatGroup" span and the field labels, 6/255 off
-- title.text and text.heading, and the 888888 gray on the placeholders and the teleport note, 8/255
-- off text.disabled (modules/Frame.lua). Snapping either would move a Ka0s Default pixel (the
-- rollout's X1), so each is a token of its own, namespaced `wg.` (X12), that keeps today's value
-- under Ka0s Default and follows its role token under every other skin and EllesmereUI (X2). The
-- brand span and the labels are two tokens because they follow two roles: the title's color and
-- the heading color, which a skin may set apart.
NS.SKIN_TOKENS = {
    ["wg.brand"]       = { default = { 1, 215 / 255, 0, 1 }, follow = "title.text" },
    ["wg.label"]       = { default = { 1, 215 / 255, 0, 1 }, follow = "text.heading" },
    ["wg.placeholder"] = { default = { 136 / 255, 136 / 255, 136 / 255, 1 }, follow = "text.disabled" },
}

-- The Ka0s Default tokens the DEGRADED facade answers, copied from the library and limited to the
-- ones this addon reads: the window edge NS.ApplySkin's fallback (core/CoreSetup.lua) draws, and
-- this addon's own tokens at their defaults. Both arms publish the table, so
-- tests/test_skinsetup.lua can hold each entry to the live library's Ka0s Default value: a copy
-- that drifts goes red there. A surface converted to a token adds the token here in the same change.
NS.SKIN_FALLBACK = {
    ["win.bg"]         = { 0.06, 0.06, 0.08, 0.92 },
    ["win.border"]     = { 0, 0, 0, 1 },
    ["win.inner"]      = { 0.24, 0.24, 0.27, 0.85 },
    ["title.text"]     = { 1, 0.82, 0, 1 },
    ["divider"]        = { 0.24, 0.24, 0.27, 0.85 },
}
for name, def in pairs(NS.SKIN_TOKENS) do NS.SKIN_FALLBACK[name] = def.default end

--- A color token's components AS A CALL SITE WRITES THEM: r, g, b for an opaque color and r, g, b,
--- a otherwise, so a site that passed three components before it read a token still passes three
--- on Ka0s Default. nil for a token the skin leaves alone. Read through NS.Skin at call time.
function NS.SkinColor(name)
    local r, g, b, a = NS.Skin.Color(name)
    if r == nil then return nil end
    if a == nil or a == 1 then return r, g, b end
    return r, g, b, a
end

--- A color token as a "|cffrrggbb" escape, each channel rounded to the nearest byte, so markup a
--- call site wrote as a literal keeps its bytes on Ka0s Default. nil for a token the skin leaves
--- alone. Read at call time: a cached escape would stay in the old skin after a switch.
function NS.SkinEscape(name)
    local r, g, b = NS.Skin.Color(name)
    if r == nil then return nil end
    local function byte(v) return math.floor(v * 255 + 0.5) end
    return ("|cff%02x%02x%02x"):format(byte(r), byte(g), byte(b))
end

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

--- The schema seam (settings/Schema.lua's Helpers), once the profile store exists; nil before.
local function seam()
    local a = NS.addon
    local H = a and a.Settings and a.Settings.Helpers
    if not (a and a.db and a.db.profile and H and H.Get and H.Set) then return nil end
    return H
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    local H = seam()
    if not H then return DEFAULT, DEFAULT end
    return H.Get(SOURCE_PATH) or DEFAULT, H.Get(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through Helpers.Set (validate, store, the [Set] line, onChange).
function NS.WriteSkinChoice(source, skin, ignore, media)
    local H = seam()
    if not H then return end
    if source ~= nil then H.Set(SOURCE_PATH, source) end
    if skin ~= nil then H.Set(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        H.Set(PANEL_PATH, ignore.panel == true)
        H.Set(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        H.Set(FONT_PATH, storedKey(media.font))
        H.Set(TEXTURE_PATH, storedKey(media.texture))
    end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
    local H = seam()
    if not H then return false, false end
    local font, texture = storedKey(H.Get(FONT_PATH)), storedKey(H.Get(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: false, false until the profile store exists.
local function storedIgnore()
    local H = seam()
    if not H then return false, false end
    return H.Get(PANEL_PATH) == true, H.Get(FONTS_PATH) == true
end

-- AceGUI keeps ONE callback per event name (options-ui-§19). Without the library's chain there is
-- no skin restore to share the release with, so the host's work takes the callback.
local function releaseByCallback(widget, fn)
    if type(widget) ~= "table" or type(fn) ~= "function" or type(widget.SetCallback) ~= "function" then
        return nil
    end
    widget:SetCallback("OnRelease", function(w) fn(w) end)
    return fn
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function color(name)
        local c = NS.SKIN_FALLBACK[name]
        if c then return c[1], c[2], c[3], c[4] or 1 end
    end
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, and a primitive with no host meaning is a no-op that never
    -- raises. The list is LibKa0s-Skin-1.0's VOCAB; tests/test_surface_parity.lua holds this table
    -- to the live facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture",
    }) do S[name] = noop end

    S.Token = function(name) return NS.SKIN_FALLBACK[name] end
    S.Color = color
    S.Resolve = function(kind, value, fromSkin)
        if fromSkin or value == S.FROM_SKIN then return S.Token(kind) end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end

    -- The window edge is CoreSetup's pre-library skin, byte for byte what a working install draws.
    S.Shell = function(frame) if NS.ApplySkin then NS.ApplySkin(frame) end end
    -- A title bar's text in the title color, the one NS.ApplySkin gives a shelled frame's `title`.
    S.TitleBar = function(bar, opts)
        local fs = (type(opts) == "table" and opts.text) or (bar and (bar.title or bar.text))
        if fs and fs.SetTextColor then fs:SetTextColor(color("title.text")) end
    end
    S.Text = function(fs, role)
        local r, g, b, a = color(role == "title" and "title.text" or ("text." .. tostring(role)))
        if r and fs and fs.SetTextColor then fs:SetTextColor(r, g, b, a) end
    end
    S.GetPanelColor = function() return color("win.bg") end
    S.GetFont = function() return _G.STANDARD_TEXT_FONT end
    S.ChartStyle = function() return {} end
    S.BarStyle = function() return {} end

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.ApplySkinOverride() return false end
    -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
    function NS.SkinPaintAce() return false end
    function NS.SkinPaintAceTree() return 0 end
    NS.SkinOnRelease = releaseByCallback
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label  = NS.BRAND_NAME,
    get    = NS.SkinChoice,
    set    = NS.WriteSkinChoice,
    tokens = NS.SKIN_TOKENS,
})

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- leaving an EllesmereUI that painted this session). The Appearance tab raises the library's popup
-- for its own picks.
local RELOAD_LINE = NS.L and NS.L["Reload your interface (/reload) to finish changing the skin."]
    or "Reload your interface (/reload) to finish changing the skin."

-- The AceGUI rows (SkinAce.lua). Each guards on the member, so a copy whose SkinAce secondary did
-- not attach paints nothing.
function NS.SkinPaintAce(widget)
    if type(Skin.PaintAce) ~= "function" then return false end
    return Skin:PaintAce(addonName, widget)
end

function NS.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

function NS.SkinOnRelease(widget, fn)
    if type(Skin.OnRelease) ~= "function" then return releaseByCallback(widget, fn) end
    return Skin:OnRelease(widget, fn)
end

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride (a Skin major before minor 6) moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored pair AND the stored exceptions and overrides (addon:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Appearance row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
    end
    return changed, reload
end
