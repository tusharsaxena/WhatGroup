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
-- also starts at 0 and walks every step. A profile-scoped step (step 2 is the first) MUST walk every
-- stored profile through the raw `db.sv.profiles` (WhatGroupDB.profiles), not only
-- the active `db.profile`, because a profile nobody has switched to since would otherwise stay on
-- the old shape with the stamp already past it.

local _, NS = ...

-- Bump when the persisted profile shape changes in a way that needs a step in NS.MIGRATIONS.
NS.SCHEMA_VERSION = 2

-- The shipped faces LibKa0s retired, each to its successor (R3-FRIZ; LibKa0s R3-L7).
local RETIRED_FONTS = { ["Ka0s Friz Quadrata TT"] = "Ka0s Ubuntu" }

--- Moves every string naming a retired face, at any depth of `t`, to its successor. Answers how many moved.
function NS.RetireFonts(t)
    local n = 0
    for k, v in pairs(t) do
        if type(v) == "table" then
            n = n + NS.RetireFonts(v)
        elseif RETIRED_FONTS[v] then
            t[k], n = RETIRED_FONTS[v], n + 1
        end
    end
    return n
end

NS.MIGRATIONS = {
    [1] = function(_db) end,  -- 0 -> 1: the stamp itself; nothing to reshape
    -- 1 -> 2 (R3-FRIZ): LibKa0s v1.85.0 deleted Ka0s Friz Quadrata TT (R3-L7) and WoW Default draws Ka0s
    -- Ubuntu (R3-L6). A stored pick of the deleted face (the skin's Font override) moves to Ka0s Ubuntu
    -- in every stored profile; Blizzard's own "Friz Quadrata TT" stays.
    [2] = function(db)
        local profiles = db and db.sv and db.sv.profiles
        if type(profiles) ~= "table" then return end
        for _, p in pairs(profiles) do
            if type(p) == "table" then NS.RetireFonts(p) end
        end
    end,
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
    -- version — an already-current DB stays silent. Through the console's at-enable queue
    -- (DebugLogGates, LibKa0s v1.65.0): the login run is at OnInitialize, with the session-only flag
    -- still off, so a plain NS.Debug line never landed; held, it is written the first time logging
    -- is turned on. A run with logging already on (a profile switch) writes at once.
    local D = NS.DebugLog
    if from ~= g.schemaVersion and D and D.DebugAtEnable then
        D.DebugAtEnable("Migrate", "v%s -> v%s", from, g.schemaVersion)
    end
end
