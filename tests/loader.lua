-- tests/loader.lua
--
-- The instance factory: builds one fully ISOLATED WhatGroup in a fresh mock environment and hands
-- back `(NS, env, mock)` — where `env` and `mock` are the same table, because tests/wow_mock.lua
-- points `_G` back at itself (testing-§1).
--
-- Everything about the environment comes from the shared kit — `Loader.makeEnv` builds the sandbox
-- and `Loader.tocFiles` derives the addon's own file list from WhatGroup.toc (testing-§9). What
-- stays here is ISOLATION, which the kit has no mode for and this repo needs: nearly every case
-- calls `newAddon()`/`bootAddon()`/`enableAddon()` for a fresh addon, because file-local state
-- (captureQueue, pendingApplications, notifiedFor, the popup frame) would otherwise leak between
-- cases and a broken wipe would look like a working one.
--
-- Chunks are COMPILED ONCE and re-run per instance: `loadfile` over twenty-one files, three
-- hundred-odd times, dominates the run otherwise, and re-executing a cached chunk against a fresh
-- environment is exactly as faithful — the client compiles each file once too.

local Loader = dofile("tests/_kit/loader.lua")

-- Every file of libs/LibKa0s/LibKa0s.xml, in XML order. Spelled out because a vendored library is
-- pulled in through its own .xml, which `tocFiles` cannot see, and because a module whose sibling
-- is missing returns before LibStub:NewLibrary and leaves the host measuring its own fallback stub
-- (testing-§9, anti-patterns #48).
local LIBKA0S = {
    "libs/LibKa0s/Core.lua",
    "libs/LibKa0s/DebugLog.lua",
    "libs/LibKa0s/Slash.lua",
    "libs/LibKa0s/Options.lua",
    "libs/LibKa0s/OptionsWidgets.lua",
    "libs/LibKa0s/OptionsScroll.lua",
    "libs/LibKa0s/Perf.lua",
    "libs/LibKa0s/PerfPanel.lua",
}

-- Returns a loader closure bound to the repo root + the mock builder.
return function(root, mockBuilder)
    local function abs(rel) return root .. "/" .. rel end

    -- The addon's own files, in TOC order, derived rather than restated.
    local tocFiles = Loader.tocFiles(abs("WhatGroup.toc"))

    local sources = {}
    for _, rel in ipairs(LIBKA0S) do sources[#sources + 1] = { path = rel, lib = true } end
    for _, rel in ipairs(tocFiles) do sources[#sources + 1] = { path = rel, lib = false } end

    local compiled = {}
    local function chunkFor(rel)
        local c = compiled[rel]
        if c == nil then
            local err
            c, err = loadfile(abs(rel))
            if not c then
                error(("loadfile(%s) failed: %s"):format(rel, tostring(err)))
            end
            compiled[rel] = c
        end
        return c
    end

    --- Build one instance.
    ---
    --- opts.skip = { "<relative path>", ... } omits those files, which is how the degraded-install
    --- cases load the addon with the library genuinely ABSENT rather than by hand-stubbing the
    --- namespace member under test (testing-§8).
    ---
    --- opts.mock = function(mock) end runs against the fresh environment BEFORE any source is
    --- loaded, for the client-shape scenarios a post-hoc assignment cannot reach.
    local function build(opts)
        opts = opts or {}
        local skipSet = {}
        for _, rel in ipairs(opts.skip or {}) do skipSet[rel] = true end

        local mock = mockBuilder()
        if type(opts.mock) == "function" then opts.mock(mock) end
        local env = Loader.makeEnv(mock)
        local NS  = {}

        -- The kit's AceDB fake resolves a SavedVariables NAME against the REAL _G, so a previous
        -- instance's saved table would otherwise be adopted by this one.
        _G.WhatGroupDB = nil

        for _, src in ipairs(sources) do
            if not skipSet[src.path] then
                local chunk = chunkFor(src.path)
                setfenv(chunk, env)
                if src.lib then chunk() else chunk("WhatGroup", NS) end
            end
        end

        return NS, mock, mock
    end

    -- A callable table, so what the factory actually fed the loader is published beside it and
    -- tests/test_harness.lua can pin the derivation against a fresh read of the TOC (testing-§9).
    return setmetatable({
        sources  = sources,
        tocFiles = tocFiles,
        libFiles = LIBKA0S,
        root     = root,
    }, { __call = function(_, opts) return build(opts) end })
end
