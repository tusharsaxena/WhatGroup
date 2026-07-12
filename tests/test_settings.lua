-- tests/test_settings.lua — schema defaults, validation, Get/Set, reset.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertNil = T.test, T.assertEqual, T.assertNil

test("settings: BuildDefaults threads profile + global defaults", function()
    local NS = T.newAddon()
    local d = NS.addon.Settings.BuildDefaults()
    assertEqual(d.profile.enabled, true)
    assertEqual(d.profile.notify.delay, 1.5)
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
    assertEqual(H.Get("notify.delay"), 1.5)
end)

test("settings: enabled=false onChange wipes capture", function()
    local NS = T.bootAddon()
    NS.addon.pendingInfo = { title = "x" }
    NS.addon.Settings.Helpers.Set("enabled", false)
    assertNil(NS.addon.pendingInfo)
end)
