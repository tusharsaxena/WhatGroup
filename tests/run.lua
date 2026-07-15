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
    "Compat.lua", "Locale.lua", "Database.lua", "DebugLog.lua",
    "TeleportSpells.lua", "WhatGroup.lua", "WhatGroup_Settings.lua",
    "WhatGroup_Frame.lua",
}

-- Non-executing inventory mode (§5): `lua tests/run.lua --list` loads every
-- suite, prints docs/test-cases.md's body to stdout, and exits without running.
local listMode = false
for _, a in ipairs(arg or {}) do
    if a == "--list" then listMode = true end
end

-- ---- micro-framework ------------------------------------------------------

local passed, failed = 0, 0
local failedNames = {}

-- Stamped to the suite file currently being dofile'd so each registered case
-- carries its origin suite (§5). `cases` is the ordered registry --list reads.
local currentSuite
local cases = {}

local function test(name, fn)
    cases[#cases + 1] = { name = name, suite = currentSuite }
    if listMode then return end   -- --list registers but never executes
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
    "test_labels", "test_capture", "test_debuglog",
}

if not listMode then
    print("WhatGroup headless tests")
    print("========================")
end
for _, s in ipairs(SUITES) do
    currentSuite = s .. ".lua"
    if not listMode then print("[" .. s .. "]") end
    dofile(here .. "/" .. s .. ".lua")
end

-- --list: emit the generated inventory (docs/test-cases.md body) and exit,
-- grouped in SUITES (load) order with per-suite and grand totals (§5).
if listMode then
    local order, byS, count = {}, {}, {}
    for _, c in ipairs(cases) do
        if not byS[c.suite] then byS[c.suite] = {}; count[c.suite] = 0; order[#order + 1] = c.suite end
        byS[c.suite][#byS[c.suite] + 1] = c.name
        count[c.suite] = count[c.suite] + 1
    end
    print("# Test Cases")
    print("")
    print("_Generated — do not hand-edit, regenerate with "
          .. "`lua tests/run.lua --list > docs/test-cases.md`._")
    for _, s in ipairs(order) do
        print("")
        print(string.format("### %s (%d)", s, count[s]))
        for _, name in ipairs(byS[s]) do print("- " .. name) end
    end
    print("")
    print("## Totals")
    print("")
    print("| Suite | Count |")
    print("| --- | --- |")
    for _, s in ipairs(order) do
        print(string.format("| %s | %d |", s, count[s]))
    end
    print(string.format("| **Total** | **%d** |", #cases))
    os.exit(0)
end

print("========================")
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then
    print("FAILED: " .. table.concat(failedNames, ", "))
    os.exit(1)
end
os.exit(0)
