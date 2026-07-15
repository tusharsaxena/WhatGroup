-- core/Database.lua
-- SavedVariables schema version + migration runner.
--
-- Establishes the migration seam from day one (§2.2 / §5.1). AceDB stores
-- the persisted schema version in `db.global.schemaVersion` (seeded by
-- Settings.BuildDefaults). `NS:RunMigrations()` is called once from
-- OnInitialize immediately after `AceDB:New`, before any code reads the
-- profile, so a future breaking change to the profile shape has a single,
-- ordered, idempotent place to upgrade old saved data.

local addonName, NS = ...

-- Bump when the persisted profile shape changes in a way that needs a
-- migration step below. Settings.BuildDefaults threads this into
-- `global.schemaVersion` for fresh databases.
NS.SCHEMA_VERSION = 1

-- Idempotent: safe to call on every login. A fresh DB arrives with
-- schemaVersion already defaulted to NS.SCHEMA_VERSION; an old DB is
-- stepped forward one version at a time. The body is intentionally empty
-- today — the seam exists so the first real migration lands here instead
-- of being retrofitted under pressure.
function NS:RunMigrations()
    local g = self.db and self.db.global
    if not g then return end

    g.schemaVersion = g.schemaVersion or NS.SCHEMA_VERSION

    local from = g.schemaVersion

    -- while g.schemaVersion < NS.SCHEMA_VERSION do
    --     if g.schemaVersion == 1 then
    --         -- migrate 1 -> 2 here
    --     end
    --     g.schemaVersion = g.schemaVersion + 1
    -- end

    g.schemaVersion = NS.SCHEMA_VERSION

    -- Lifecycle coverage (§8): log only when a migration actually moved the
    -- version — a fresh/already-current DB stays silent.
    if from ~= g.schemaVersion and NS.Debug then
        NS.Debug("Migrate", "v" .. tostring(from) .. " -> v" .. tostring(g.schemaVersion))
    end
end
