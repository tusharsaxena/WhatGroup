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

local assertTrue = T.assertTrue

-- The declared default is the PRE-VERSIONING 0, never NS.SCHEMA_VERSION. AceDB's removeDefaults
-- strips a stored value equal to its default at logout, so a default equal to the current version
-- never reaches the SavedVariables file, and the first real bump would read the new default back as
-- the stored version and skip its own step.
test("database: defaults declare global.schemaVersion 0 (savedvariables-§1)", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Settings.BuildDefaults().global.schemaVersion, 0)
end)

-- Mirrors AceDB's logout strip (removeDefaults, AceDB-3.0.lua:134-178, run from :425) on the raw
-- SavedVariables table for the one key this case is about. The kit's AceDB fake strips a profile
-- on SetProfile but never models logout, so the case does it by hand.
local function logoutStrip(NS, sv)
    local declared = NS.addon.Settings.BuildDefaults().global.schemaVersion
    if sv.global.schemaVersion == declared then sv.global.schemaVersion = nil end
end

-- Re-boot from a saved table with a version bump and its step in place before OnInitialize runs,
-- the way the next release would load an existing user's file. The loader wipes _G.WhatGroupDB
-- as it builds, so the saved table is handed back after the build and before the init.
local function rebootWithStep(sv, version, steps)
    local NS = T.newAddon()
    _G.WhatGroupDB = sv
    NS.SCHEMA_VERSION = version
    for v, fn in pairs(steps) do NS.MIGRATIONS[v] = fn end
    NS.addon:OnInitialize()
    return NS
end

-- red under: the default equal to NS.SCHEMA_VERSION
test("database: the stamp survives AceDB's logout strip, so the first real migration runs", function()
    local first = T.bootAddon()
    local sv = _G.WhatGroupDB
    logoutStrip(first, sv)
    assertEqual(sv.global.schemaVersion, 1, "the stamp the runner wrote must outlive the logout strip")

    local NS = rebootWithStep(sv, 2, { [2] = function(db) db.global.__stepRan = true end })
    assertTrue(NS.addon.db.global.__stepRan == true, "the 1 -> 2 step must run for an existing user")
    assertEqual(NS.addon.db.global.schemaVersion, 2)
end)

test("database: a raising step leaves the stamp at the last completed version", function()
    local NS = T.bootAddon()
    local g = NS.addon.db.global
    g.schemaVersion = 0
    NS.SCHEMA_VERSION = 3
    local ranThird = false
    NS.MIGRATIONS[2] = function() error("step 2 failed") end
    NS.MIGRATIONS[3] = function() ranThird = true end
    local ok = pcall(function() NS.addon:RunMigrations() end)
    assertTrue(not ok, "a raising step propagates rather than being swallowed")
    assertEqual(g.schemaVersion, 1, "the stamp advances only past a step that returned")
    assertTrue(not ranThird, "no later step runs past a failed one")
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
