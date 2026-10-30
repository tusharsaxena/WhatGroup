-- tests/test_skinsetup.lua — the LibKa0s-Skin-1.0 seam (core/SkinSetup.lua, skinning-§1 to §3).
--
-- What this addon owes the skin engine, and nothing the library pins itself: the owner is
-- registered under the FOLDER name at file load with this addon's read and write seams and its own
-- tokens; the eight `skin.*` keys default to Ka0s Default and are skip-render schema rows on the
-- Appearance tab, written only through Helpers.Set; the tab sits after Notifications and before
-- Keybindings; the profile's skin is applied right after AceDB exists and again on every profile
-- event; the popup's window edge is handed the owner; and the degraded arm answers Ka0s Default
-- from a host copy the live library holds to its own values.
--
-- Every case builds its own instance (tests/run.lua), so no skin state leaks between cases.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local OWNER = "WhatGroup"
local PATHS = {
    "skin.source", "skin.skin", "skin.ignorePanel", "skin.ignoreFonts",
    "skin.font", "skin.texture", "skin.outline", "skin.pickerSeen",
}

local function skinLib(mock) return mock.LibStub("LibKa0s-Skin-1.0") end

--- Run `fn` with chat output swallowed, so a verb's own lines stay out of the run's log.
local function quietly(NS, fn)
    local print = NS.Print
    NS.Print = function() end
    local ok, err = pcall(fn)
    NS.Print = print
    if not ok then error(err, 0) end
end

--- A counter on the owner's OnLooksChanged, which fires once per effective skin change.
local function looksCounter(NS)
    local n = { looks = 0 }
    NS.Skin.OnLooksChanged(function() n.looks = n.looks + 1 end)
    return n
end

local function near(a, b) return math.abs(a - b) < 1e-6 end

-- ── the owner ────────────────────────────────────────────────────────────────────────────────

test("skin seam: the owner is the folder name, registered at file load, and NS.Skin is its facade",
function()
    -- red under: registering under the brand or a typo (the library keys every frame and listener
    -- by owner), registering at PLAYER_LOGIN instead of file load, or publishing another facade.
    local NS, _, mock = T.newAddon()
    local Skin = skinLib(mock)
    assertTrue(Skin:IsOwner(OWNER), "core/SkinSetup.lua did not register the owner at file load")
    assertTrue(rawequal(NS.Skin, Skin:For(OWNER)), "NS.Skin is not Skin:For(\"WhatGroup\")")
    assertEqual(NS.Skin.owner, OWNER)
    assertEqual(Skin:OwnerLabel(OWNER), NS.BRAND_NAME, "the copy confirmation names the addon by its brand")
end)

test("skin seam: the read answers Ka0s Default before the profile store exists", function()
    -- RegisterOwner calls `get` at FILE LOAD, before OnInitialize builds AceDB; a getter that
    -- raised there would be a visible Lua error on every login.
    local NS = T.newAddon()
    assertNil(NS.addon.db, "the store must not exist yet in this case")
    local ok, source, skin = pcall(NS.SkinChoice)
    assertTrue(ok, "NS.SkinChoice raised without a store: " .. tostring(source))
    assertEqual(source, "ka0s")
    assertEqual(skin, "ka0s")
    local font, texture = NS.SkinOverride()
    assertFalse(font)
    assertFalse(texture)
end)

-- ── the owner tokens (skinning rollout X1, X2, X12) ──────────────────────────────────────────

test("skin seam: the owner tokens draw today's exact pixels under Ka0s Default", function()
    -- X1: a near miss keeps its Ka0s Default value through an owner token rather than snapping to
    -- the nearest library token. FFD700 on the title's brand span and the field labels, 888888 on
    -- the placeholders and the teleport note (modules/Frame.lua).
    -- red under: snapping a token to title.text / text.heading / text.disabled, or a typo'd byte.
    local NS = T.newAddon()
    local want = {
        ["wg.brand"]       = { 1, 215 / 255, 0 },
        ["wg.label"]       = { 1, 215 / 255, 0 },
        ["wg.placeholder"] = { 136 / 255, 136 / 255, 136 / 255 },
    }
    for name, rgb in pairs(want) do
        local r, g, b, a = NS.Skin.Color(name)
        assertTrue(r ~= nil, name .. " is not a token this owner can read")
        assertTrue(near(r, rgb[1]) and near(g, rgb[2]) and near(b, rgb[3]), name .. ": Ka0s Default value")
        assertTrue(a == nil or a == 1, name .. ": opaque")
    end
    assertEqual(NS.SkinEscape("wg.label"), "|cffffd700", "the label gold, byte for byte")
    assertEqual(NS.SkinEscape("wg.placeholder"), "|cff888888", "the placeholder gray, byte for byte")
end)

test("skin seam: each owner token follows its library role token under another skin", function()
    -- X2: under any skin but Ka0s Default the token takes the role token's value, so every skin
    -- draws it in its own palette. Namespaced `wg.`, never a library family (X12).
    -- red under: a missing `follow`, or one naming the wrong role.
    local NS, _, mock = T.bootAddon()
    local follows = { ["wg.brand"] = "title.text", ["wg.label"] = "text.heading",
                      ["wg.placeholder"] = "text.disabled" }
    quietly(NS, function() NS.ApplySkinChoice("ka0s", "obsidian") end)
    local _, applied = skinLib(mock):GetChoice(OWNER)
    assertEqual(applied, "obsidian")
    for name, role in pairs(follows) do
        assertEqual(name:sub(1, 3), "wg.", name .. " is not in this addon's namespace")
        local r, g, b = NS.Skin.Color(name)
        local fr, fg, fb = NS.Skin.Color(role)
        assertTrue(near(r, fr) and near(g, fg) and near(b, fb), name .. " does not follow " .. role)
    end
end)

-- ── the keys and the rows ────────────────────────────────────────────────────────────────────

test("skin seam: the skin keys default to Ka0s Default, with the picker unseen", function()
    -- red under: a default other than today's look, the Scope defaults moved from the leg-1 owner
    -- call (settings panel left the client's, fonts skinned), or a profile that has seen the picker
    -- (owner ruling O3: the first-run picker shows on every profile, old and new).
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults().profile.skin
    assertEqual(d.source, "ka0s")
    assertEqual(d.skin, "ka0s")
    assertEqual(d.ignorePanel, true)
    assertEqual(d.ignoreFonts, false)
    assertEqual(d.font, "")
    assertEqual(d.texture, "")
    assertEqual(d.outline, "all")
    assertEqual(d.pickerSeen, false)
    assertEqual(NS.C.skin.skin, "ka0s", "the value lives in defaults/Profile.lua")
end)

test("skin seam: every skin key is a skip-render row on the Appearance tab", function()
    -- The tab is the library's O.AppearanceTab, which draws the rows itself; they stay schema rows
    -- so the defaults resolve, every reset reaches them and /wg get|set validates them.
    -- red under: a row that renders itself on top of the library's grids, or one filed elsewhere.
    local NS = T.newAddon()
    local H = NS.addon.Settings.Helpers
    for _, path in ipairs(PATHS) do
        local row = H.FindSchema(path)
        assertTrue(row ~= nil, path .. " is not a schema row")
        assertEqual(row.group, "Appearance", path .. ": group")
        assertEqual(row.section, "skin", path .. ": /wg list section")
        assertTrue(row.skipRender == true, path .. ": the tab draws it, so it must be skipRender")
    end
end)

test("skin seam: the skin row's values are every registered skin, in the library's order", function()
    local NS, _, mock = T.newAddon()
    local values = NS.addon.Settings.Helpers.FindSchema("skin.skin").values
    local skins = skinLib(mock):Skins()
    assertEqual(#values, #skins, "one value per registered skin")
    for i, def in ipairs(skins) do assertEqual(values[i].value, def.key, "value " .. i) end
    assertEqual(values[1].value, "ka0s", "Ka0s Default first")
    local sources = NS.addon.Settings.Helpers.FindSchema("skin.source").values
    assertEqual(sources[1].value, "ka0s")
    assertEqual(sources[2].value, "eui")
end)

test("skin seam: /wg set refuses an unknown skin and applies a registered one live", function()
    -- The `values` check is the CLI parser's. A bare set reaches the row's onChange, which moves
    -- the applied skin and repaints once.
    local NS, _, mock = T.bootAddon()
    local n = looksCounter(NS)
    quietly(NS, function() NS.addon:OnSlashCommand("set skin.skin no-such-skin") end)
    assertEqual(NS.addon.db.profile.skin.skin, "ka0s", "an unknown skin was stored")
    assertEqual(n.looks, 0, "a refused set repainted")
    quietly(NS, function() NS.addon:OnSlashCommand("set skin.skin obsidian") end)
    assertEqual(NS.addon.db.profile.skin.skin, "obsidian", "a registered skin was refused")
    local _, applied = skinLib(mock):GetChoice(OWNER)
    assertEqual(applied, "obsidian", "a bare set must move the applied skin (the row's onChange)")
    assertEqual(n.looks, 1, "one set, one repaint")
end)

test("skin seam: the write seam writes every half through Helpers.Set, never the profile directly",
function()
    -- architecture-§5: one write seam. The library's copy to every Ka0s addon and the picker both
    -- reach the profile only through `set`, NS.WriteSkinChoice.
    -- red under: a seam that assigns db.profile.skin.* around Helpers.Set.
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    local real, wrote = H.Set, {}
    H.Set = function(path, v, ...)
        wrote[#wrote + 1] = path .. "=" .. tostring(v)
        return real(path, v, ...)
    end
    local ok, err = pcall(function()
        quietly(NS, function()
            NS.WriteSkinChoice("ka0s", "ember", { panel = false, fonts = true },
                { font = "Ka0s Expressway", texture = false })
        end)
    end)
    H.Set = real
    if not ok then error(err, 0) end
    assertEqual(table.concat(wrote, " "), "skin.source=ka0s skin.skin=ember skin.ignorePanel=false "
        .. "skin.ignoreFonts=true skin.font=Ka0s Expressway skin.texture=")
    local p = NS.addon.db.profile.skin
    assertEqual(p.skin, "ember")
    assertEqual(p.ignoreFonts, true)
    assertEqual(p.font, "Ka0s Expressway")
    assertEqual(p.texture, "", "false is the skin's own, stored as the empty key")
end)

-- ── applying the stored choice ───────────────────────────────────────────────────────────────

test("skin seam: OnInitialize applies the profile's skin right after the store exists", function()
    -- red under: no apply at all (a non-default skin waits for a profile event), or one before
    -- AceDB (it would read Ka0s Default and never re-read).
    local NS = T.newAddon()
    local seen
    local real = NS.ApplySkinChoice
    NS.ApplySkinChoice = function(...)
        seen = { n = select("#", ...), db = NS.addon.db ~= nil }
        return real(...)
    end
    NS.addon:OnInitialize()
    NS.ApplySkinChoice = real
    assertTrue(seen ~= nil, "OnInitialize never applied the stored skin")
    assertEqual(seen.n, 0, "the whole stored choice, no argument")
    assertTrue(seen.db, "applied before the profile store existed")
end)

test("skin seam: a profile switch, copy or reset re-applies the incoming profile's skin live", function()
    -- skinning-§2: a profile change hands the new values to SetChoice, which repaints the owner's
    -- frames. A switch or copy writes no row, so only the profile-event reaction can do it.
    -- red under: reloadProfile not applying the skin, or applying only the source half.
    local NS, _, mock = T.bootAddon()
    local Skin = skinLib(mock)
    local db = NS.addon.db
    quietly(NS, function()
        db.profile.skin.skin = "ember"
        NS.addon:OnProfileChanged(nil, db, "Default")
    end)
    local _, applied = Skin:GetChoice(OWNER)
    assertEqual(applied, "ember", "OnProfileChanged did not re-apply the skin")
    quietly(NS, function()
        db.profile.skin.skin = "glass"
        NS.addon:OnProfileCopied(nil, db, "Other")
    end)
    _, applied = Skin:GetChoice(OWNER)
    assertEqual(applied, "glass", "OnProfileCopied did not re-apply the skin")
    quietly(NS, function() db:ResetProfile() end)
    _, applied = Skin:GetChoice(OWNER)
    assertEqual(applied, "ka0s", "a reset did not put Ka0s Default back")
end)

test("skin seam: a profile event re-applies the stored overrides and Scope too", function()
    local NS, _, mock = T.bootAddon()
    local Skin = skinLib(mock)
    local db = NS.addon.db
    quietly(NS, function()
        db.profile.skin.ignoreFonts = true
        NS.addon:OnProfileChanged(nil, db, "Default")
    end)
    local _, fonts = Skin:GetIgnore(OWNER)
    assertTrue(fonts == true, "the stored Ignore fonts was not applied")
end)

-- ── the tab ──────────────────────────────────────────────────────────────────────────────────

test("skin seam: the General strip carries the library's Skin tab before Keybindings", function()
    -- skinning-§3: the tab sits immediately before Keybindings, which stays last (options-ui-§20);
    -- its key is "Appearance" and the library labels it "Skin" (OptionsAppearance minor 3).
    -- red under: no opts.tabs entry, or one placed after Keybindings.
    local NS, mock = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    local real, keys = H.RenderTabbedSchema, nil
    H.RenderTabbedSchema = function(...)
        local groups, drawn = real(...)
        keys = drawn
        return groups, drawn
    end
    local ok, err = pcall(function()
        mock.frames["WhatGroupGeneralPanel"]:Show()
        mock.fireCTimers()
    end)
    H.RenderTabbedSchema = real
    if not ok then error(err, 0) end
    assertTrue(type(keys) == "table", "General drew no tab strip")
    assertEqual(table.concat(keys, " | "), "Master controls | Notifications | Appearance | Keybindings")
    local label
    for _, f in ipairs(mock.frames) do
        if f.__kind == "Button" and f.__text == "Skin" then label = f end
    end
    assertTrue(label ~= nil, "the Appearance tab is labeled Skin")
end)

-- ── the owner handed to every factory ────────────────────────────────────────────────────────

test("skin seam: the popup's window edge is painted for this owner", function()
    -- skinning-§1: Core.ApplySkin takes the owner, and without one draws Ka0s Default forever,
    -- whatever the player picked. red under: NS.ApplySkin(f) without the third argument.
    local NS = T.bootAddon()
    local real, owner, calls = NS.ApplySkin, nil, 0
    NS.ApplySkin = function(frame, skin, who, ...)
        calls, owner = calls + 1, who
        return real(frame, skin, who, ...)
    end
    local ok, err = pcall(function() NS.addon:ShowFrame() end)
    NS.ApplySkin = real
    if not ok then error(err, 0) end
    assertEqual(calls, 1, "the popup is skinned once, when it is built")
    assertEqual(owner, OWNER)
end)

-- ── the TOC ──────────────────────────────────────────────────────────────────────────────────

test("skin seam: the TOC loads the seam before the schema and lists EllesmereUI as optional", function()
    -- skinning-§5: EllesmereUI in OptionalDeps, never Dependencies, so it loads first where it is
    -- installed. settings/Schema.lua reads NS.SKIN_OPTIONS at file load, and NS.BRAND_NAME
    -- (core/CoreSetup.lua) is the owner's label, read at this file's load.
    local files = T.loadAddon.tocFiles
    local at = {}
    for i, rel in ipairs(files) do at[rel] = i end
    assertTrue(at["core/SkinSetup.lua"] ~= nil, "core/SkinSetup.lua is not in the TOC")
    assertTrue(at["core/SkinSetup.lua"] > at["core/CoreSetup.lua"], "after core/CoreSetup.lua")
    assertTrue(at["core/SkinSetup.lua"] < at["settings/Schema.lua"], "before settings/Schema.lua")
    assertTrue(at["core/SkinSetup.lua"] < at["modules/Frame.lua"], "before modules/Frame.lua")
    local fh = assert(io.open((T.root or ".") .. "/WhatGroup.toc", "rb"))
    local toc = fh:read("*a")
    fh:close()
    local optional = toc:match("## OptionalDeps:([^\r\n]*)") or ""
    assertTrue(optional:find("EllesmereUI", 1, true) ~= nil, "EllesmereUI is not in OptionalDeps")
    assertNil(toc:match("## Dependencies:[^\r\n]*EllesmereUI"), "EllesmereUI must never be required")
end)

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

test("skin seam: the host copy of Ka0s Default equals the library's, token for token", function()
    -- The degraded facade answers NS.SKIN_FALLBACK. Both arms publish it, so the live library holds
    -- each entry to its own Ka0s Default value here: a copy that drifts goes red.
    local NS = T.newAddon()
    local n = 0
    for name, c in pairs(NS.SKIN_FALLBACK) do
        n = n + 1
        local r, g, b, a = NS.Skin.Color(name)
        assertTrue(r ~= nil, name .. " is not a token the live facade answers")
        assertTrue(near(r, c[1]) and near(g, c[2]) and near(b, c[3]) and near(a or 1, c[4] or 1),
            name .. " drifted from the library's Ka0s Default")
    end
    assertTrue(n > 0, "the host copy is empty")
end)

test("skin seam: without the library the facade answers Ka0s Default and applies nothing", function()
    local degraded = T.newAddon{ skip = T.loadAddon.libFiles }
    local S = degraded.Skin
    assertTrue(type(S) == "table", "no facade on the degraded path")
    assertFalse(S.IsEnabled())
    local r, g, b = S.Color("wg.label")
    assertTrue(near(r, 1) and near(g, 215 / 255) and near(b, 0), "the degraded label gold")
    assertEqual(degraded.SkinEscape("wg.placeholder"), "|cff888888")
    local changed, reload = degraded.ApplySkinChoice("ka0s", "obsidian")
    assertFalse(changed)
    assertFalse(reload)
end)
