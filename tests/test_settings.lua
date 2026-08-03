-- tests/test_settings.lua — schema defaults, validation, Get/Set, reset.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertNil = T.test, T.assertEqual, T.assertNil

test("settings: BuildDefaults threads profile + global defaults", function()
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults()
    assertEqual(d.profile.enabled, true)
    assertEqual(d.profile.notify.delay, 0)
    assertEqual(d.profile.notify.enabled, true)
    assertEqual(d.profile.frame.autoShow, true)
    assertEqual(d.global.schemaVersion, 1)
end)

test("settings: defaults source from NS.C (defaults/Profile.lua, WG-24)", function()
    local NS = T.newAddon()
    assertEqual(type(NS.C), "table")
    assertEqual(NS.C.enabled, true)
    assertEqual(NS.C.notify.delay, 0)
    -- BuildDefaults threads the NS.C values through unchanged.
    local d = NS.addon.Settings.BuildDefaults()
    assertEqual(d.profile.enabled, NS.C.enabled)
    assertEqual(d.profile.notify.delay, NS.C.notify.delay)
end)

test("settings: BuildDefaults seeds an empty global.windows table (WG-26)", function()
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults()
    assertEqual(type(d.global.windows), "table")
end)

test("settings: debug is not a persisted schema row (WG-12)", function()
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults()
    assertNil(d.profile.debug)
    assertNil(NS.addon.Settings.Helpers.FindSchema("debug"))
end)

test("settings: ValidateSchema reports zero errors", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 0)
end)

test("settings: Get/Set round-trips through db.profile", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("notify.delay", 3.0)
    assertEqual(H.Get("notify.delay"), 3.0)
end)

test("settings: RestoreAllDefaults resets a changed value", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("notify.delay", 7.0)
    H.RestoreAllDefaults()
    assertEqual(H.Get("notify.delay"), 0)
end)

test("settings: RestoreAllDefaults prunes orphaned profile keys (F1)", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    -- Simulate a key left behind by a removed/renamed schema row or a
    -- hand-edited SavedVariables file, both at the top level and nested.
    NS.addon.db.profile.legacyOrphan = "stale"
    NS.addon.db.profile.notify.oldKey = 42
    H.RestoreAllDefaults()
    assertNil(NS.addon.db.profile.legacyOrphan)
    assertNil(NS.addon.db.profile.notify.oldKey)
    -- Known keys are still restored to their defaults.
    assertEqual(H.Get("notify.delay"), 0)
    assertEqual(H.Get("enabled"), true)
end)

test("settings: RestoreAllDefaults deep-copies table defaults (F2)", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    local S = NS.addon.Settings.Schema
    local template = { nested = { a = 1 } }
    S[#S + 1] = { section = "x", group = "X", path = "tableRow",
                  type = "bool", label = "t", default = template }
    H.RestoreAllDefaults()
    -- Mutating the profile copy must not reach back into the schema default.
    H.Get("tableRow").nested.a = 999
    assertEqual(template.nested.a, 1)
end)

test("settings: RestoreAllDefaults skips per-row onChange (F3)", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    local S = NS.addon.Settings.Schema
    local calls = 0
    S[#S + 1] = { section = "x", group = "X", path = "probe",
                  type = "bool", label = "p", default = true,
                  onChange = function() calls = calls + 1 end }
    H.RestoreAllDefaults()
    assertEqual(calls, 0)
end)

test("settings: enabled=false onChange wipes capture", function()
    local NS = T.bootAddon()
    NS.addon.pendingInfo = { title = "x" }
    NS.addon.Settings.Helpers.Set("enabled", false)
    assertNil(NS.addon.pendingInfo)
end)

-- ---------------------------------------------------------------------------
-- Schema shape
-- ---------------------------------------------------------------------------

local assertTrue, assertFalse = T.assertTrue, T.assertFalse

test("settings: every schema row declares the fields the panel and CLI need", function()
    local NS = T.newAddon()
    for i, def in ipairs(NS.addon.Settings.Schema) do
        local where = "row #" .. i .. " (" .. tostring(def.path) .. ")"
        assertEqual(type(def.path), "string", where .. " path")
        assertEqual(type(def.section), "string", where .. " section")
        assertEqual(type(def.group), "string", where .. " group")
        assertEqual(type(def.label), "string", where .. " label")
        assertTrue(def.type == "bool" or def.type == "number", where .. " type")
        assertTrue(def.default ~= nil, where .. " default")
    end
end)

test("settings: schema paths are unique", function()
    local NS = T.newAddon()
    local seen = {}
    for _, def in ipairs(NS.addon.Settings.Schema) do
        assertNil(seen[def.path], "duplicate schema path: " .. tostring(def.path))
        seen[def.path] = true
    end
end)

test("settings: every schema row carries a tooltip", function()
    local NS = T.newAddon()
    for _, def in ipairs(NS.addon.Settings.Schema) do
        assertEqual(type(def.tooltip), "string", "no tooltip for " .. def.path)
        assertTrue(#def.tooltip > 0, "empty tooltip for " .. def.path)
    end
end)

test("settings: every number row declares min, max and step", function()
    local NS = T.newAddon()
    for _, def in ipairs(NS.addon.Settings.Schema) do
        if def.type == "number" then
            assertEqual(type(def.min), "number", def.path .. " min")
            assertEqual(type(def.max), "number", def.path .. " max")
            assertEqual(type(def.step), "number", def.path .. " step")
            assertTrue(def.min <= def.default and def.default <= def.max,
                def.path .. " default sits outside its own bounds")
        end
    end
end)

test("settings: ValidateSchema counts each defect on a broken row", function()
    local NS, _, mock = T.newAddon()
    local S = NS.addon.Settings.Schema
    S[#S + 1] = { type = "color", label = 42 }   -- no path, bad type/section/group/label
    local mark = #mock.prints
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 5,
        "path, type, section, group and label are each reported")
    assertTrue(#mock.prints > mark, "and each defect is printed for the author")
end)

test("settings: ValidateSchema reports a non-table row", function()
    local NS = T.newAddon()
    local S = NS.addon.Settings.Schema
    S[#S + 1] = "not a row"
    assertEqual(NS.addon.Settings.Helpers.ValidateSchema(), 1)
end)

test("settings: a broken row does not stop the panel registering", function()
    local NS, _, mock = T.bootAddon()
    local S = NS.addon.Settings.Schema
    S[#S + 1] = { type = "color", label = 42 }
    NS.addon.Settings.Register()
    assertEqual(#mock.categories, 2,
        "a bad row is an author bug: report it, but still ship the panel")
end)

-- ---------------------------------------------------------------------------
-- BuildDefaults
-- ---------------------------------------------------------------------------

test("settings: BuildDefaults nests dotted paths into real subtables", function()
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults()
    assertEqual(type(d.profile.notify), "table")
    assertEqual(type(d.profile.frame), "table")
    assertNil(d.profile["notify.delay"], "the dotted key itself must not be stored flat")
end)

test("settings: BuildDefaults covers every schema row", function()
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults()
    local function dig(path)
        local node = d.profile
        for part in path:gmatch("[^.]+") do
            if type(node) ~= "table" then return nil end
            node = node[part]
        end
        return node
    end
    for _, def in ipairs(NS.addon.Settings.Schema) do
        assertTrue(dig(def.path) ~= nil, "BuildDefaults skipped " .. def.path)
    end
end)

test("settings: BuildDefaults deep-copies table defaults", function()
    local NS = T.newAddon()
    local S = NS.addon.Settings.Schema
    local template = { list = { 1, 2, 3 } }
    S[#S + 1] = { section = "x", group = "X", path = "tbl", type = "bool",
                  label = "t", default = template }
    local d = NS.addon.Settings.BuildDefaults()
    d.profile.tbl.list[1] = 99
    assertEqual(template.list[1], 1, "the canonical default must not be aliased")
end)

test("settings: BuildDefaults is a fresh table each call", function()
    local NS = T.newAddon()
    local a = NS.addon.Settings.BuildDefaults()
    local b = NS.addon.Settings.BuildDefaults()
    a.profile.enabled = false
    assertEqual(b.profile.enabled, true)
end)

-- ---------------------------------------------------------------------------
-- Get / Set / RawSet
-- ---------------------------------------------------------------------------

test("settings: Get returns nil before the db exists", function()
    local NS = T.newAddon()   -- no OnInitialize
    assertNil(NS.addon.Settings.Helpers.Get("enabled"))
end)

test("settings: Set before the db exists is a harmless no-op", function()
    local NS = T.newAddon()
    local ok = pcall(function() NS.addon.Settings.Helpers.Set("enabled", false) end)
    assertTrue(ok)
end)

test("settings: Resolve creates the intermediate tables it walks through", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("deep.nested.value", 7)
    assertEqual(NS.addon.db.profile.deep.nested.value, 7)
end)

test("settings: Resolve replaces a non-table intermediate", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    NS.addon.db.profile.notify = "corrupted"   -- e.g. a hand-edited SavedVariables
    H.Set("notify.delay", 2)
    assertEqual(NS.addon.db.profile.notify.delay, 2)
end)

test("settings: RawSet writes without firing onChange", function()
    local NS = T.bootAddon()
    NS.addon.pendingInfo = { title = "in flight" }
    NS.addon.Settings.Helpers.RawSet("enabled", false)
    assertEqual(NS.addon.db.profile.enabled, false)
    assertTrue(NS.addon.pendingInfo ~= nil, "the master-switch side effect is skipped")
end)

test("settings: Set skipOnChange suppresses the side effect", function()
    local NS = T.bootAddon()
    NS.addon.pendingInfo = { title = "in flight" }
    NS.addon.Settings.Helpers.Set("enabled", false, { skipOnChange = true })
    assertTrue(NS.addon.pendingInfo ~= nil)
end)

test("settings: a throwing onChange is caught and reported, not propagated", function()
    local NS, _, mock = T.bootAddon()
    local S = NS.addon.Settings.Schema
    S[#S + 1] = { section = "x", group = "X", path = "boom", type = "bool",
                  label = "b", default = false,
                  onChange = function() error("onChange exploded") end }
    local ok = pcall(function() NS.addon.Settings.Helpers.Set("boom", true) end)
    assertTrue(ok, "a broken onChange must not break the write")
    assertEqual(NS.addon.Settings.Helpers.Get("boom"), true, "the value still landed")
    assertTrue(mock.prints[#mock.prints]:find("onChange for boom failed", 1, true) ~= nil)
end)

test("settings: Set on a path with no schema row still writes", function()
    local NS = T.bootAddon()
    NS.addon.Settings.Helpers.Set("adhoc", 5)
    assertEqual(NS.addon.Settings.Helpers.Get("adhoc"), 5)
end)

test("settings: FindSchema matches on the exact path", function()
    local NS = T.newAddon()
    local H = NS.addon.Settings.Helpers
    assertEqual(H.FindSchema("notify.delay").type, "number")
    assertNil(H.FindSchema("notify"), "a path prefix is not a row")
    assertNil(H.FindSchema("notify.delay.extra"))
end)

-- ---------------------------------------------------------------------------
-- RestoreDefaults / RefreshAll
-- ---------------------------------------------------------------------------

test("settings: RestoreAllDefaults restores every schema row", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    for _, def in ipairs(NS.addon.Settings.Schema) do
        H.Set(def.path, def.type == "bool" and not def.default or 9)
    end
    H.RestoreAllDefaults()
    for _, def in ipairs(NS.addon.Settings.Schema) do
        assertEqual(H.Get(def.path), def.default, def.path .. " was not restored")
    end
end)

test("settings: RestoreAllDefaults leaves db.global untouched", function()
    local NS = T.bootAddon()
    NS.addon.db.global.windows.popup = { point = "CENTER", relPoint = "CENTER", x = 1, y = 2 }
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(NS.addon.db.global.schemaVersion, 1)
    assertTrue(NS.addon.db.global.windows.popup ~= nil,
        "window geometry is account-wide and survives a profile reset")
end)

-- The refresher registry is LibKa0s-Options-1.0's now, and PER-CTX rather than per-addon: every
-- widget maker appends its updater closure to the ctx it drew into, and a re-render reassigns the
-- list so a released widget's closure cannot outlive it (options-ui-§11). A probe pushed onto a
-- live ctx.refreshers is therefore exactly what a rendered widget looks like to RefreshScalars.
--
-- The page has to be SHOWN. The library refuses to refresh an off-screen page and flags it dirty
-- instead, which is the whole point of the two-tier split — so `panel:Show()` (which fires OnShow
-- the way the client does) is part of the setup rather than an incidental detail.
local function probedPanel()
    local NS, _, mock = T.enableAddon()
    local panel = mock.frames["WhatGroupGeneralPanel"]
    panel:Show()
    mock.fireCTimers()
    local ctx = NS.addon.Settings.Helpers.__panelFor("general")
    local runs = { n = 0 }
    ctx.refreshers[#ctx.refreshers + 1] = function() runs.n = runs.n + 1 end
    return NS, ctx, mock, runs
end

test("settings: RefreshAll runs every refresher on the open page, in registration order", function()
    local NS, ctx, _, runs = probedPanel()
    local order = {}
    for _, key in ipairs({ "a", "b", "c" }) do
        ctx.refreshers[#ctx.refreshers + 1] = function() order[#order + 1] = key end
    end
    NS.addon.Settings.Helpers.RefreshAll()
    assertEqual(table.concat(order, ","), "a,b,c")
    assertEqual(runs.n, 1)
end)

test("settings: a throwing refresher does not abort the sweep", function()
    -- Each refresher is pcall'd individually, so one dead widget cannot take the rest of the UI
    -- down with it.
    local NS, ctx = probedPanel()
    local ran = false
    ctx.refreshers[#ctx.refreshers + 1] = function() error("refresher exploded") end
    ctx.refreshers[#ctx.refreshers + 1] = function() ran = true end
    NS.addon.Settings.Helpers.RefreshAll()
    assertTrue(ran, "a broken refresher must not abort the sweep")
end)

test("settings: a hidden page is not refreshed — it is flagged dirty (options-ui-§11)", function()
    -- The other half of the two-tier split, and the reason RefreshAll is cheap: refreshing pages
    -- nobody is looking at is what anti-patterns #39 is about.
    local NS, ctx, _, runs = probedPanel()
    ctx.panel:Hide()
    NS.addon.Settings.Helpers.RefreshAll()
    assertEqual(runs.n, 0, "an off-screen page runs no refreshers")
    assertTrue(ctx._dirty, "it is marked dirty instead, to re-render on its next show")
end)

test("settings: Set skipRefresh suppresses the widget re-sync", function()
    local NS, _, _, runs = probedPanel()
    NS.addon.Settings.Helpers.Set("notify.delay", 1, { skipRefresh = true })
    assertEqual(runs.n, 0)
    NS.addon.Settings.Helpers.Set("notify.delay", 2)
    assertEqual(runs.n, 1)
end)

test("settings: RestoreAllDefaults refreshes once, not once per row", function()
    local NS, _, _, runs = probedPanel()
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(runs.n, 1, "one reconcile after the loop, not N")
end)

-- ---------------------------------------------------------------------------
-- The reset confirmation popup
-- ---------------------------------------------------------------------------

test("settings: EnsureResetPopup is idempotent", function()
    local NS, env = T.bootAddon()
    NS.addon.Settings.EnsureResetPopup()
    local first = env.StaticPopupDialogs["WHATGROUP_RESET_ALL"]
    NS.addon.Settings.EnsureResetPopup()
    assertEqual(env.StaticPopupDialogs["WHATGROUP_RESET_ALL"], first)
end)

test("settings: the reset dialog is a blocking, escapable confirmation", function()
    local NS, env = T.bootAddon()
    NS.addon.Settings.EnsureResetPopup()
    local d = env.StaticPopupDialogs["WHATGROUP_RESET_ALL"]
    assertEqual(d.timeout, 0, "an irreversible action must not time out into a default")
    assertTrue(d.hideOnEscape)
    assertTrue(d.whileDead)
    assertEqual(d.button1, "Yes")
    assertEqual(d.button2, "No")
    assertEqual(type(d.OnAccept), "function")
end)

test("settings: accepting the reset dialog acknowledges in chat", function()
    local NS, env, mock = T.bootAddon()
    NS.addon.Settings.EnsureResetPopup()
    env.StaticPopupDialogs["WHATGROUP_RESET_ALL"].OnAccept()
    assertTrue(mock.prints[#mock.prints]:find("reset to defaults", 1, true) ~= nil)
end)
