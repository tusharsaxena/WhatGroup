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
