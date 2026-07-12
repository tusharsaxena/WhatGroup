-- tests/loader.lua
-- Headless source loader (§14A.1).
--
-- Loads each addon source in TOC order, binds it to the mock environment
-- with setfenv, and invokes it as `chunk(addonName, NS)` — reproducing the
-- `local addonName, NS = ...` header the WoW client provides at load. The
-- SAME NS table is threaded through every file, exactly like the shared
-- private namespace in-game.

-- @param env       table   the mock environment from wow_mock.build()
-- @param files     table   absolute paths of the addon sources, TOC order
-- @param addonName string  the addon folder name ("WhatGroup")
-- @return NS        table   the populated private namespace
local function loadAddon(env, files, addonName)
    local NS = {}
    for _, path in ipairs(files) do
        local chunk, err = loadfile(path)
        if not chunk then
            error("loader: failed to load " .. path .. ": " .. tostring(err))
        end
        setfenv(chunk, env)
        chunk(addonName, NS)
    end
    return NS
end

return loadAddon
