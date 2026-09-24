-- core/Database.lua
-- SavedVariables schema version + migration runner.
--
-- Establishes the migration seam from day one (toc-file-§2 / savedvariables-§1). AceDB stores
-- the persisted schema version in `db.global.schemaVersion`. `NS:RunMigrations()` is called once
-- from OnInitialize immediately after `AceDB:New`, before any code reads the profile, so a future
-- breaking change to the profile shape has a single, ordered, idempotent place to upgrade old
-- saved data.
--
-- THE DECLARED DEFAULT IS 0, NOT NS.SCHEMA_VERSION. Settings.BuildDefaults declares
-- `global.schemaVersion = 0`, the pre-versioning value. AceDB's removeDefaults strips a stored
-- value equal to its default at logout, so a default equal to the current version would never
-- reach the SavedVariables file, and the first real bump would read its own new default back as
-- the stored version and skip its step for every existing user. With 0 declared, the stamp the
-- runner writes always differs from the default and persists.
--
-- STEPS. `NS.MIGRATIONS[N]` takes the store from N-1 to N and receives the AceDB handle. 0 -> 1 is
-- the no-op stamp. Every step MUST be idempotent against a fresh default profile: a fresh install
-- also starts at 0 and walks every step. WhatGroup has no profile-scoped step today; the first one
-- MUST walk every stored profile through the raw `db.sv.profiles` (WhatGroupDB.profiles), not only
-- the active `db.profile`, because a profile nobody has switched to since would otherwise stay on
-- the old shape with the stamp already past it.

local _, NS = ...

-- Bump when the persisted profile shape changes in a way that needs a step in NS.MIGRATIONS.
NS.SCHEMA_VERSION = 1

NS.MIGRATIONS = {
    [1] = function(_db) end,  -- 0 -> 1: the stamp itself; nothing to reshape
}

-- Idempotent: safe to call on every login and after every profile switch. The stamp advances
-- only past a step that returned; a raising step propagates and leaves the stamp at the last
-- completed version, so the next login retries it.
function NS:RunMigrations()
    local g = self.db and self.db.global
    if not g then return end

    local from = g.schemaVersion or 0
    local v = from
    while v < NS.SCHEMA_VERSION do
        local step = NS.MIGRATIONS[v + 1]
        if step then step(self.db) end
        v = v + 1
        g.schemaVersion = v
    end

    -- Lifecycle coverage (debug-logging-§8): log only when a migration actually moved the
    -- version — an already-current DB stays silent.
    if from ~= g.schemaVersion and NS.Debug then
        NS.Debug("Migrate", "v%s -> v%s", from, g.schemaVersion)
    end
end
