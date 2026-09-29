-- tests/test_profiles.lua — the Profiles settings page (settings/Profiles.lua) and the shared
-- reaction to AceDB's three profile events (core/WhatGroup.lua's reloadProfile).
--
-- The harness loads no vendored Ace library, so AceDBOptions, AceConfig and AceConfigDialog are
-- absent by default and the page opts out; that is the shape every other suite runs in. The cases
-- here register the three as recording fakes BEFORE any source loads (the loader's `opts.mock`),
-- which is when the client has them too.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local APP = "WhatGroup-Profiles"

--- The three libraries as recording fakes. `omit` names one to leave out.
local function fakes(omit)
    local rec = { opened = {} }
    local libs = {
        ["AceDBOptions-3.0"] = { GetOptionsTable = function(_, db)
            rec.db = db
            rec.options = { type = "group", args = {} }
            return rec.options
        end },
        ["AceConfig-3.0"] = { RegisterOptionsTable = function(_, app, options)
            rec.app, rec.registered = app, options
        end },
        ["AceConfigDialog-3.0"] = { Open = function(_, app, container)
            rec.opened[#rec.opened + 1] = { app = app, container = container }
        end },
    }
    return rec, function(mock)
        for name, lib in pairs(libs) do
            if name ~= omit then mock.__libs[name] = lib end
        end
    end
end

--- An enabled addon (OnInitialize + OnEnable, so the settings tree is registered) with the fakes.
local function withProfiles(omit)
    local rec, install = fakes(omit)
    local NS, env, mock = T.enableAddon({ mock = install })
    return NS, env, mock, rec
end

local function profilesPanel(mock) return mock.frames["WhatGroupProfilesPanel"] end

-- The client's two beats: Show fires OnShow, and this addon's SetRenderer wrapper builds on the
-- next frame (settings/OptionsSetup.lua).
local function open(mock, panel)
    panel:Show()
    mock.fireCTimers()
end

local function countLines(NS, fragment)
    local n = 0
    for _, line in ipairs(NS.DebugLog.buffer) do
        if line:find(fragment, 1, true) then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------------------
-- The page
-- ---------------------------------------------------------------------------

test("profiles: the page registers this db's AceDBOptions table, as the LAST subcategory", function()
    local NS, _, mock, rec = withProfiles()
    -- red under: the options table built over another db, registered under another name, or the
    -- page registered ahead of General (options-ui-§3 puts Profiles last in the tree).
    assertTrue(rec.db == NS.addon.db, "the options are this addon's database")
    assertEqual(rec.app, APP)
    assertTrue(rec.registered == rec.options, "the table AceDBOptions built is the one registered")
    assertEqual(#mock.categories, 3, "parent, General, Profiles")
    assertEqual(mock.categories[2].label, "General")
    assertEqual(mock.categories[3].label, "Profiles")
end)

test("profiles: the page has no Defaults button", function()
    -- Restoring a default here would mean deleting profiles, which is not what anyone means by it
    -- (options-ui-§3). AceDBOptions carries its own Reset Profile.
    local _, _, mock = withProfiles()
    local panel = profilesPanel(mock)
    assertTrue(panel ~= nil, "the Profiles canvas exists")
    assertNil(panel.defaultsOnClick, "nothing parked for a Defaults click")
    assertFalse(panel.wantsDefaultsButton and true or false, "and no Defaults button is wanted")
end)

test("profiles: without any one of the three libraries the page opts out", function()
    -- red under: dropping a library from the builder's guard, which then fails on first show
    -- instead of at registration.
    for _, omit in ipairs({ "AceDBOptions-3.0", "AceConfig-3.0", "AceConfigDialog-3.0" }) do
        local _, _, mock = withProfiles(omit)
        assertEqual(#mock.categories, 2, "no Profiles subcategory without " .. omit)
    end
end)

test("profiles: nothing is built until the page is first shown, then the dialog fills a SHOWN container", function()
    -- AceGUI:Release hides a frame before pooling it and neither AceGUI:Create nor
    -- AceConfigDialog:Open shows it again, so a pooled group filled as-is reads as a blank page.
    -- The kit's AceGUI never pools and starts every frame shown, so the case builds that state
    -- itself: a SimpleGroup handed out HIDDEN, the way a pooled one comes back, and then the same
    -- group hidden again between two renders.
    -- red under: dropping the container.frame:Show() from the Profiles renderer.
    local NS, _, mock, rec = withProfiles()
    mock.__libs["AceGUI-3.0"]:RegisterWidgetType("SimpleGroup", function()
        local w = mock.__makeAceGUIWidget("SimpleGroup")
        w.frame:Hide()
        return w
    end, 1)
    assertEqual(#rec.opened, 0, "the builder draws nothing (options-ui-§5)")
    open(mock, profilesPanel(mock))
    assertEqual(#rec.opened, 1, "the first show opens the dialog once")
    assertEqual(rec.opened[1].app, APP)
    local container = rec.opened[1].container
    assertTrue(container ~= nil and container.frame ~= nil, "AceConfigDialog is handed an AceGUI group")
    assertTrue(container.frame:IsShown(), "and the pooled, hidden group it fills is shown")
    container.frame:Hide()
    NS.addon.db:SetProfile("Alt")
    mock.fireCTimers()
    assertEqual(#rec.opened, 2, "the switch re-drew the open page")
    assertTrue(container.frame:IsShown(), "and every render shows the group again")
end)

-- ---------------------------------------------------------------------------
-- The shared reaction to a profile event
-- ---------------------------------------------------------------------------

test("profiles: a switch made elsewhere re-draws an OPEN Profiles page into the same container", function()
    -- AceConfigDialog re-reads the active profile only when it is fed again, so a switch from
    -- `/run`, a copy or `/wg resetall` would leave the page naming the old profile.
    -- red under: dropping the Profiles refresh from reloadProfile.
    local NS, _, mock, rec = withProfiles()
    open(mock, profilesPanel(mock))
    NS.addon.db:SetProfile("Alt")
    mock.fireCTimers()
    assertEqual(#rec.opened, 2, "the switch re-opened the dialog")
    assertTrue(rec.opened[1].container == rec.opened[2].container, "into the one container")
end)

test("profiles: a switch while the page is HIDDEN re-draws it on its next show", function()
    local NS, _, mock, rec = withProfiles()
    local panel = profilesPanel(mock)
    open(mock, panel)
    panel:Hide()
    NS.addon.db:SetProfile("Alt")
    mock.fireCTimers()
    assertEqual(#rec.opened, 1, "nothing drawn on a hidden page")
    open(mock, panel)
    assertEqual(#rec.opened, 2, "the next show draws the switched profile")
end)

test("profiles: a switch logs ONE [Profile] line naming the incoming profile (debug-logging-§10)", function()
    -- A switch rewrites no row through the seam, so it gets no [Set] line; the profile-event
    -- handler logs it once, as KickCD and MultiMeters word theirs.
    -- red under: OnProfileChanged going back to a bare reload with no line.
    local NS = T.bootAddon()
    NS.State.debug = true
    local set, prof = countLines(NS, "[Set]"), countLines(NS, "[Profile]")
    NS.addon.db:SetProfile("Alt")
    assertEqual(countLines(NS, "[Profile]") - prof, 1, "one line")
    assertEqual(countLines(NS, "[Profile] switched to 'Alt'"), 1, "worded by the event")
    assertEqual(countLines(NS, "[Set]") - set, 0, "and no [Set] line")
end)

test("profiles: a switch re-applies the popup's size, scale and alpha from the incoming profile", function()
    -- Those three reach an open popup only through their rows' onChange, and a profile switch
    -- writes no row, so without the re-apply the popup kept the outgoing profile's look until the
    -- next open.
    local NS, _, mock = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("scale", 1.5)
    H.Set("alpha", 0.5)
    H.Set("frame.width", 500)
    NS.addon:ShowFrame()
    local f = mock.frames["WhatGroupFrame"]
    assertTrue(f ~= nil, "the popup was built")
    assertEqual(f:GetScale(), 1.5)
    NS.addon.db:SetProfile("Alt")
    assertEqual(f:GetScale(), NS.C.scale, "scale from the fresh profile")
    assertEqual(f:GetAlpha(), NS.C.alpha, "alpha from the fresh profile")
    assertEqual((f:GetWidth()), NS.C.frame.width, "width from the fresh profile")
end)

test("profiles: a switch to a profile whose visibility is 'never' takes an open popup off screen", function()
    -- `visibility` reaches a built popup only through its row's onChange, and a profile event
    -- writes no row, so reloadProfile re-applies it from the incoming profile.
    -- red under: dropping ApplyFrameVisibility from reloadProfile.
    local NS, _, mock = T.bootAddon()
    NS.addon.db:SetProfile("hidden")
    NS.addon.Settings.Helpers.Set("visibility", "never")
    NS.addon.db:SetProfile("Default")
    NS.addon:ShowFrame()
    local f = mock.frames["WhatGroupFrame"]
    assertTrue(f ~= nil and f:IsShown(), "the popup is on screen under the 'always' profile")
    NS.addon.db:SetProfile("hidden")
    assertFalse(f:IsShown(), "the switch into the 'never' profile took it off screen")
end)

test("profiles: switching to a disabled profile stands the addon down, and back brings it up", function()
    -- The enable flag is profile-scoped, so the latch is re-synced from the incoming profile.
    -- red under: the profile callback only ever releasing HOLD_DISABLED (a switch INTO a disabled
    -- profile leaves the addon up), or never re-reading `enabled` at all (the switch back leaves it
    -- down). Unticking `enabled` on "off" stands the addon down through the row's own onChange, not
    -- the profile latch, so the case leaves "off" and re-enters it: only that second switch into an
    -- already-disabled profile proves the latch follows the incoming profile downwards.
    local NS = T.enableAddon()
    NS.addon.db:SetProfile("off")
    NS.addon.Settings.Helpers.Set("enabled", false)
    NS.addon.db:SetProfile("Default")
    assertFalse(NS.IsStoodDown(), "the enabled one stood it back up")
    NS.addon.db:SetProfile("off")
    assertTrue(NS.IsStoodDown(), "switching into the disabled profile stood the addon down")
    NS.addon.db:SetProfile("Default")
    assertFalse(NS.IsStoodDown(), "and switching out of it stood it back up again")
end)

-- ---------------------------------------------------------------------------
-- The Reset all settings tooltip names the equivalence (options-ui-§12)
-- ---------------------------------------------------------------------------

test("profiles: the Reset all settings tooltip says it is Profiles -> Reset Profile", function()
    -- The descriptor's `resetProfile` + `profilesPage` pick the library's wording; without them the
    -- tooltip claims "every setting in this addon", which overstates a reset of one profile.
    local _, _, mock = T.enableAddon()
    open(mock, mock.frames["WhatGroupGeneralPanel"])
    local button
    for _, w in ipairs(mock.aceWidgets) do
        if w.type == "Button" and w.text == "Reset all settings" then button = w end
    end
    assertTrue(button ~= nil, "the reset button is drawn")
    local tip = mock.GameTooltip
    tip.__lines = {}
    button:Fire("OnEnter")
    local body = table.concat(tip.__lines or {}, "\n")
    local want = T.LibStub("LibKa0s-Options-1.0").STRINGS.RESET_ALL_TIP_PROFILES_PAGE
    assertEqual(body, want)
end)

-- ---------------------------------------------------------------------------
-- The reset veto (options-ui-§3, options-ui-§12)
-- ---------------------------------------------------------------------------

test("profiles: ONE named veto keeps the Profiles page and every profile row out of the reset walk", function()
    -- The global reset is db:ResetProfile(), so the row walk is left with the session-only rows
    -- alone, and never a Profiles row: resetting those deletes profiles. Named once and read by both
    -- the descriptor's skipRestoreAll and the host's own session sweep.
    -- red under: a veto that lets a profile row through, or one that vetoes a session-only row.
    local NS = T.enableAddon()
    local S = NS.addon.Settings
    local veto = S.VetoedFromResetAll
    assertTrue(type(veto) == "function", "the veto is published")
    assertTrue(veto({ page = "profiles", sessionOnly = true }), "a Profiles row is always vetoed")
    local session = 0
    for _, def in ipairs(S.Schema) do
        assertEqual(veto(def) and true or false, not def.sessionOnly, def.path)
        if def.sessionOnly then session = session + 1 end
    end
    assertEqual(session, 2, "the console and test mode are what the walk keeps")
end)

-- options-ui-§12's testing MUST: prove the blast radius, not the mechanism. docs/profiles.md claims
-- the global reset "never touches another profile or the profile list"; this is that claim, driven
-- through `/wg resetall` and the popup's OnAccept, the path a player takes.
-- red under: RestoreAllDefaults wiping sv.profiles or walking every profile, deleting the active
-- profile, or switching back to "Default" as part of the reset.
test("profiles: /wg resetall resets the active profile and leaves the list and the other profile alone", function()
    local NS, env = T.enableAddon()
    local db, H = NS.addon.db, NS.addon.Settings.Helpers
    H.Set("notify.delay", 5)
    db:SetProfile("Alt")
    H.Set("notify.delay", 7)
    NS.addon:OnSlashCommand("resetall")
    env.StaticPopupDialogs["WHATGROUP_RESET_ALL"].OnAccept()
    assertEqual(db:GetCurrentProfile(), "Alt", "still on the profile that was reset")
    local names = {}
    for _, name in ipairs(db:GetProfiles({})) do names[#names + 1] = name end
    table.sort(names)
    assertEqual(table.concat(names, ","), "Alt,Default", "the profile list is unchanged")
    assertEqual(H.Get("notify.delay"), NS.C.notify.delay, "the active profile is back to its defaults")
    db:SetProfile("Default")
    assertEqual(H.Get("notify.delay"), 5, "and the other profile kept its value")
end)
