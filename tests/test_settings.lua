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

test("settings: RestoreDefaults resets a changed value", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    H.Set("notify.delay", 7.0)
    H.RestoreDefaults()
    assertEqual(H.Get("notify.delay"), 0)
end)

test("settings: RestoreDefaults prunes orphaned profile keys (F1)", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    -- Simulate a key left behind by a removed/renamed schema row or a
    -- hand-edited SavedVariables file, both at the top level and nested.
    NS.addon.db.profile.legacyOrphan = "stale"
    NS.addon.db.profile.notify.oldKey = 42
    H.RestoreDefaults()
    assertNil(NS.addon.db.profile.legacyOrphan)
    assertNil(NS.addon.db.profile.notify.oldKey)
    -- Known keys are still restored to their defaults.
    assertEqual(H.Get("notify.delay"), 0)
    assertEqual(H.Get("enabled"), true)
end)

test("settings: RestoreDefaults deep-copies table defaults (F2)", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    local S = NS.addon.Settings.Schema
    local template = { nested = { a = 1 } }
    S[#S + 1] = { section = "x", group = "X", path = "tableRow",
                  type = "bool", label = "t", default = template }
    H.RestoreDefaults()
    -- Mutating the profile copy must not reach back into the schema default.
    H.Get("tableRow").nested.a = 999
    assertEqual(template.nested.a, 1)
end)

test("settings: RestoreDefaults skips per-row onChange (F3)", function()
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    local S = NS.addon.Settings.Schema
    local calls = 0
    S[#S + 1] = { section = "x", group = "X", path = "probe",
                  type = "bool", label = "p", default = true,
                  onChange = function() calls = calls + 1 end }
    H.RestoreDefaults()
    assertEqual(calls, 0)
end)

test("settings: enabled=false onChange wipes capture", function()
    local NS = T.bootAddon()
    NS.addon.pendingInfo = { title = "x" }
    NS.addon.Settings.Helpers.Set("enabled", false)
    assertNil(NS.addon.pendingInfo)
end)
