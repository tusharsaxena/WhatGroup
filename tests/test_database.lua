-- tests/test_database.lua — schemaVersion seeding + migration idempotency.
local T = _G.WHATGROUP_TEST
local test, assertEqual = T.test, T.assertEqual

test("database: fresh DB lands at schemaVersion 1", function()
    local NS = T.bootAddon()
    assertEqual(NS.SCHEMA_VERSION, 1)
    assertEqual(NS.addon.db.global.schemaVersion, 1)
end)

test("database: RunMigrations is idempotent", function()
    local NS = T.bootAddon()
    NS.addon:RunMigrations()
    NS.addon:RunMigrations()
    assertEqual(NS.addon.db.global.schemaVersion, 1)
end)

test("database: RunMigrations re-seeds a missing schemaVersion", function()
    local NS = T.bootAddon()
    NS.addon.db.global.schemaVersion = nil
    NS.addon:RunMigrations()
    assertEqual(NS.addon.db.global.schemaVersion, 1)
end)

local assertTrue, assertNil = T.assertTrue, T.assertNil

test("database: BuildDefaults seeds global.schemaVersion from NS.SCHEMA_VERSION", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Settings.BuildDefaults().global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: RunMigrations before the db exists is a no-op", function()
    local NS = T.newAddon()   -- no OnInitialize
    local ok = pcall(function() NS.addon:RunMigrations() end)
    assertTrue(ok, "the migration seam must be safe to call pre-login")
end)

test("database: an older saved DB is stepped up to the current version", function()
    local NS = T.bootAddon()
    NS.addon.db.global.schemaVersion = 0
    NS.addon:RunMigrations()
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: a version move is logged, a no-op migration is silent (debug-logging-§8)", function()
    local NS = T.bootAddon()
    NS.State.debug = true

    local before = #NS.DebugLog.buffer
    NS.addon:RunMigrations()          -- already current
    assertEqual(#NS.DebugLog.buffer, before, "a fresh/current DB stays silent")

    NS.addon.db.global.schemaVersion = 0
    NS.addon:RunMigrations()
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last:find("[Migrate]", 1, true) ~= nil, "a real move is logged")
    assertTrue(last:find("v0 -> v1", 1, true) ~= nil, "the line names both versions")
end)

test("database: migrations run before any profile read (OnInitialize order)", function()
    local NS = T.bootAddon()
    -- OnInitialize calls AceDB:New then RunMigrations immediately; by the time
    -- the test can observe the db, the version is already reconciled.
    assertEqual(NS.addon.db.global.schemaVersion, NS.SCHEMA_VERSION)
end)

test("database: the profile is untouched by a migration pass", function()
    local NS = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 6)
    NS.addon.db.global.schemaVersion = 0
    NS.addon:RunMigrations()
    assertEqual(NS.addon.Settings.Helpers.Get("notify.delay"), 6)
end)
