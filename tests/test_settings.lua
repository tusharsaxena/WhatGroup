-- tests/test_settings.lua — schema defaults, validation, Get/Set, reset.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertNil, assertTrue = T.test, T.assertEqual, T.assertNil, T.assertTrue

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
    -- The row has to exist BEFORE the db does: a reset is `db:ResetProfile()` now
    -- (options-ui-§12), so what it restores is AceDB's defaults table, and that is built from the
    -- schema at AceDB:New time. Appending a row afterwards -- which is what this case used to do --
    -- describes nothing the client can produce, because every real row is declared at load.
    local NS = T.newAddon()
    local S = NS.addon.Settings.Schema
    S[#S + 1] = { section = "x", group = "X", path = "tableRow",
                  type = "bool", label = "t", default = { nested = { a = 1 } } }
    -- The db is built HERE, after the row exists, because BuildDefaults reads the schema.
    NS.addon:OnInitialize()
    local H = NS.addon.Settings.Helpers

    local template
    for _, def in ipairs(S) do if def.path == "tableRow" then template = def.default end end
    assertTrue(type(template) == "table", "the fixture row is missing")

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

test("settings: a write creates the intermediate tables it walks through", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("deep.nested.value", 7)
    assertEqual(NS.addon.db.profile.deep.nested.value, 7)
end)

-- savedvariables-§2 — A READ DOES NOT WRITE. The write path above still
-- materializes, and must; this pins that the read path does not. A Get that
-- grows db.profile one empty table per segment turns every typo'd path into a
-- permanent empty branch in SavedVariables, and leaves the next read unable to
-- tell that typo from real-but-empty data.
test("settings: Get on an unknown deep path returns nil and creates no table", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    assertNil(H.Get("brandnew.deep.leaf"), "an unknown path reads as nil")
    assertNil(NS.addon.db.profile.brandnew, "the read materialized a parent table")
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

-- ---------------------------------------------------------------------------
-- The page/tab partition (options-ui-§13)
-- ---------------------------------------------------------------------------

--- The page's tabs, in the order the strip draws them, and how many controls each holds.
--- STATED HERE rather than derived from the schema the assertion reads, so a row that drifts
--- into another tab is a NAMED failure rather than a shorter list that still agrees with itself.
---
--- One page, so one entry. WhatGroup registers a single settings sub-page ("general"); every row
--- carries `section` for `/wg list` and `group` for the tab, and no row is hidden.
local PARTITION = {
    general = { { "General", 2 }, { "Chat", 7 }, { "Popup", 3 } },
}

test("settings: the page's tabs are the designed ones, in order, at the designed size",
function()
    -- red under: moving a row to another tab, reordering a group, splitting a group's run (which
    -- RenderTabbedSchema would draw as a second tab of the same name), or adding a row without
    -- deciding which tab it belongs on.
    local NS = T.newAddon()
    for _, expected in pairs(PARTITION) do
        local order, counts, seen = {}, {}, {}
        for _, row in ipairs(NS.addon.Settings.Schema) do
            local g = row.group or "?"
            if not seen[g] then
                seen[g] = true
                order[#order + 1] = g
            end
            counts[g] = (counts[g] or 0) + 1
        end

        local wantNames = {}
        for i, pair in ipairs(expected) do wantNames[i] = pair[1] end
        assertEqual(table.concat(order, " | "), table.concat(wantNames, " | "), "tab order")
        for _, pair in ipairs(expected) do
            assertEqual(counts[pair[1]], pair[2], pair[1] .. ": control count")
        end
    end
end)

test("settings: no tab holds fewer than two controls", function()
    -- A tab over one control is a click that reveals a single checkbox. Nothing is exempt here:
    -- every tab on this page is schema rows all the way down, and the two bespoke controls the
    -- page draws (the Test button and the session-only Debug console checkbox) both sit on
    -- General, which already carries two stored rows of its own.
    -- red under: a tab losing rows until one is left, or a new one-row group.
    local NS = T.newAddon()
    local counts = {}
    for _, row in ipairs(NS.addon.Settings.Schema) do
        counts[row.group] = (counts[row.group] or 0) + 1
    end
    for group, n in pairs(counts) do
        assertTrue(n >= 2, group .. " holds only " .. n)
    end
end)

test("settings: every row's group is one of the designed tabs", function()
    -- The partition case above pins the counts; this one pins the NAMES, so a typo'd group on a
    -- new row reads as "Popupp is not a tab" rather than as a count that happens to still add up.
    local NS = T.newAddon()
    local known = { General = true, Chat = true, Popup = true }
    for _, row in ipairs(NS.addon.Settings.Schema) do
        assertTrue(known[row.group] == true, row.path .. " is filed under " .. tostring(row.group))
    end
end)

-- ---------------------------------------------------------------------------
-- The popup's promoted size (frame.width / frame.height)
-- ---------------------------------------------------------------------------

test("settings: the popup size defaults are the literals they replaced", function()
    -- modules/Frame.lua's FRAME_WIDTH / FRAME_HEIGHT were 420 and 260. A default that is not the
    -- number it replaced would silently resize every existing install's popup.
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults()
    assertEqual(d.profile.frame.width, 420)
    assertEqual(d.profile.frame.height, 260)
    assertEqual(NS.C.frame.width, 420, "and the value itself lives in defaults/Profile.lua")
    assertEqual(NS.C.frame.height, 260)
end)

test("settings: the size sliders cannot travel outside the frame's own clamp", function()
    -- The clamp lives in modules/Frame.lua because SavedVariables and `/wg set` both bypass the
    -- slider. The slider's bounds must agree with it, or dragging to either end would produce a
    -- value the popup then silently corrects.
    local NS = T.newAddon()
    local H = NS.addon.Settings.Helpers
    local w, h = H.FindSchema("frame.width"), H.FindSchema("frame.height")
    assertEqual(w.min, 320); assertEqual(w.max, 700); assertEqual(w.step, 10)
    assertEqual(h.min, 200); assertEqual(h.max, 520); assertEqual(h.step, 10)
end)
