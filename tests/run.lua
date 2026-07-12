#!/usr/bin/env lua
-- tests/run.lua
-- Headless test runner + micro-framework (§14A.1).
--
-- Usage:  lua tests/run.lua        (from the repo root)
--
-- Loads every addon source in TOC order under the WoW mock, exposes the
-- framework + a fresh-addon factory to suites via _G.WHATGROUP_TEST, runs
-- each suite under pcall, prints PASS/FAIL, and exits non-zero on any
-- failure so the commit gate (§14A) can enforce green.

local here    = (arg and arg[0] and arg[0]:match("^(.*)[/\\][^/\\]*$")) or "."
local repo    = here .. "/.."
package.path  = here .. "/?.lua;" .. package.path

local build     = dofile(here .. "/wow_mock.lua")
local loadAddon = dofile(here .. "/loader.lua")

-- Addon sources, TOC load order (libs are mocked, not loaded).
local SOURCES = {
    "Compat.lua", "Locale.lua", "Database.lua", "TeleportSpells.lua",
    "WhatGroup.lua", "WhatGroup_Settings.lua", "WhatGroup_Frame.lua",
}

-- ---- micro-framework ------------------------------------------------------

local passed, failed = 0, 0
local failedNames = {}

local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("  PASS  " .. name)
    else
        failed = failed + 1
        failedNames[#failedNames + 1] = name
        print("  FAIL  " .. name)
        print("        " .. tostring(err))
    end
end

local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assertEqual") .. ": expected <" .. tostring(expected)
              .. "> got <" .. tostring(actual) .. ">", 2)
    end
end

local function assertTrue(v, msg)
    if not v then error((msg or "assertTrue") .. ": got <" .. tostring(v) .. ">", 2) end
end

local function assertFalse(v, msg)
    if v then error((msg or "assertFalse") .. ": got <" .. tostring(v) .. ">", 2) end
end

local function assertNil(v, msg)
    if v ~= nil then error((msg or "assertNil") .. ": got <" .. tostring(v) .. ">", 2) end
end

-- Build a fresh addon (fresh env + mock + NS) for a single test. Returns
-- (NS, env, mock). Fresh per call so file-local state (captureQueue,
-- pendingApplications, notifyGen, …) never leaks across tests.
local function newAddon()
    local env, mock = build()
    local files = {}
    for _, f in ipairs(SOURCES) do files[#files + 1] = repo .. "/" .. f end
    local NS = loadAddon(env, files, "WhatGroup")
    return NS, env, mock
end

-- Fresh addon that has also run OnInitialize (db built, migrations run).
local function bootAddon()
    local NS, env, mock = newAddon()
    NS.addon:OnInitialize()
    return NS, env, mock
end

_G.WHATGROUP_TEST = {
    test         = test,
    assertEqual  = assertEqual,
    assertTrue   = assertTrue,
    assertFalse  = assertFalse,
    assertNil    = assertNil,
    newAddon     = newAddon,
    bootAddon    = bootAddon,
}

-- ---- suites ---------------------------------------------------------------

local SUITES = {
    "test_compat", "test_database", "test_settings",
    "test_labels", "test_capture",
}

print("WhatGroup headless tests")
print("========================")
for _, s in ipairs(SUITES) do
    print("[" .. s .. "]")
    dofile(here .. "/" .. s .. ".lua")
end

print("========================")
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
    print("FAILED: " .. table.concat(failedNames, ", "))
    os.exit(1)
end
os.exit(0)
