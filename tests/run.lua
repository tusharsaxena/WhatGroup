#!/usr/bin/env lua
-- tests/run.lua
--
-- Headless test runner for Ka0s WhatGroup, on the shared LibKa0s test kit (testing-§1).
-- Everything generic — the case registry, the assertions, the runner, the `--list` inventory
-- renderer, the sandboxed source loader and the TOC reader — comes from tests/_kit/ and is never
-- edited here. What stays is what is genuinely this addon's: the instance factory
-- (tests/loader.lua), the mock extender (tests/wow_mock.lua), the three lifecycle factories below
-- and the ordered suite list.
--
-- Run from the repo root:
--   lua tests/run.lua          -- run all suites (non-zero exit on failure)
--   lua tests/run.lua --list   -- print docs/test-cases.md's body; run nothing

local Kit  = dofile("tests/_kit/framework.lua")
local mock = dofile("tests/wow_mock.lua")

local root      = "."
local loadAddon = dofile("tests/loader.lua")(root, mock)

-- Build a fresh addon (fresh env + mock + NS) for a single test. Returns (NS, env, mock) — `env`
-- and `mock` are the same table. Fresh per call so file-local state (captureQueue,
-- pendingApplications, notifiedFor, the lazily-built popup) never leaks across cases.
local function newAddon(opts)
    return loadAddon(opts)
end

-- Fresh addon that has also run OnInitialize (db built, migrations run).
local function bootAddon(opts)
    local NS, env, m = newAddon(opts)
    NS.addon:OnInitialize()
    return NS, env, m
end

-- Fresh addon that has run the FULL in-game lifecycle: OnInitialize (ADDON_LOADED) then OnEnable
-- (PLAYER_LOGIN). OnEnable is what registers the events and the Settings canvas category, so suites
-- that exercise the panel or the event wiring start here rather than calling Settings.Register by
-- hand — that way the test drives the same entry point the client does.
local function enableAddon(opts)
    local NS, env, m = bootAddon(opts)
    NS.addon:OnEnable()
    return NS, env, m
end

-- The shared table every suite reaches through `_G.WHATGROUP_TEST`. Kit.expose merges `test` and
-- the kit assertions in beside this repo's own keys, so no suite file changed when the harness
-- moved onto the kit.
_G.WHATGROUP_TEST = Kit.expose{
    newAddon    = newAddon,
    bootAddon   = bootAddon,
    enableAddon = enableAddon,
    loadAddon   = loadAddon,
    root        = root,
}

-- Order is load-order-sensitive; keep it stable.
Kit.run{
    dir    = "tests/",
    suites = {
        "test_harness",
        "test_libka0s",
        "test_mediasetup",
        "test_util",
        "test_compat",
        "test_database",
        "test_settings",
        "test_slash",
        "test_labels",
        "test_capture",
        "test_notify",
        "test_frame",
        "test_panel",
        "test_lifecycle",
        "test_debuglog",
        "test_vendor_sync",
    },
}
