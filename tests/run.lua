#!/usr/bin/env lua
-- tests/run.lua
--
-- Headless test runner for Ka0s WhatGroup, on the shared LibKa0s test kit (testing-§1).
-- Everything generic — the case registry, the assertions, the runner, the `--list` inventory
-- renderer, the sandboxed source loader and the TOC reader — comes from tests/_kit/ and is never
-- edited here. What stays is what is genuinely this addon's: the instance factory
-- (tests/loader.lua), the mock extender (tests/wow_mock.lua), the three lifecycle factories below,
-- the surface source tests/test_surface_parity.lua resolves its live half through, and the ordered
-- suite list.
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

-- Where Kit.assertSurfaceParity's by-name form looks the LIVE half up (kit 15, vendored by M4-01).
--
-- Registered explicitly, and the explicitness is doing two jobs at once. `Kit.expose` auto-wires a
-- LibStub off the exposed table for a repo whose stubs mirror LIBRARY TABLES; this runner exposes
-- factories rather than a built addon, so nothing is auto-wired and every by-name case in
-- tests/test_surface_parity.lua fails outright with "no surface source is registered" — which is
-- the kit's deliberate bargain, an unresolvable name reddens rather than silently passing. And even
-- if a LibStub were reachable it would be the wrong answer: all three of this addon's
-- library-backed stubs mirror an INSTANCE — what `lib:New(descriptor)` returned — and
-- "LibKa0s-Options-1.0" resolves to the four-member library table (LAYOUT, New,
-- PatchAlwaysShowScrollbar, STRINGS), not to the surface settings/Panel.lua calls.
--
-- ONE extra addon load, at runner start, used for nothing but reading member names off. It is not
-- handed to any case and no case mutates it, so the per-case isolation the factories above exist
-- for is untouched — and it is why this file's live half carries no test seams stamped on by a
-- suite that ran earlier.
--
-- Set BEFORE Kit.expose, which is what makes it stick: expose registers a source only when none is
-- registered yet, precisely so a runner like this one keeps its own.
local surfaceNS = loadAddon()
Kit.setSurfaceSource{
    ["LibKa0s-DebugLog-1.0"] = surfaceNS.DebugLog,
    ["LibKa0s-Slash-1.0"]    = surfaceNS.SlashCommands,
    ["LibKa0s-Options-1.0"]  = surfaceNS.addon.Settings.Helpers,
}

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
--
-- What holds this list honest is `Kit.assertSuiteInventory` (tests/_kit/framework.lua), which
-- Kit.run calls on `dir` and `suites` BEFORE it loads a single file, in both directions: a name
-- here with no file on disk, and a tests/*.lua on disk with no name here. It is not called from a
-- case anywhere in this repo, and there is no reason to add one — the runner-level call already
-- aborts the run with a non-zero exit, which is strictly earlier and strictly louder than a FAIL
-- line among 545 PASSes. The reason it is worth SAYING is that the pin is invisible: nothing in
-- this file names it, `grep assertSuiteInventory tests/` outside the kit finds nothing, and a
-- reader who concludes the list is unpinned goes and pins it a second time.
--
-- Both directions, seen red (M4-19):
--   delete the "test_util" entry below →
--     `tests/test_util.lua exists but is not declared in the suites list ... it is running zero
--      cases today`
--   rename tests/test_util.lua →
--     `tests/test_util.lua is declared in the suites list (position 6) but is not on disk`
Kit.run{
    dir    = "tests/",
    suites = {
        "test_harness",
        "test_libka0s",
        "test_surface_parity",
        "test_mediasetup",
        "test_envsetup",
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
        "test_docmap",
        "test_doc_structure",
        "test_vendor_sync",
        -- The kit has shipped one suite of its own since revision 15: the working-tree
        -- line-ending gate, over every path `git ls-files` reports. It lives where the rest
        -- of the kit lives rather than being re-typed into nine repositories, so it is
        -- declared with its own `dir`. Kit.assertSuiteInventory fails the run until it is
        -- declared, so it cannot arrive with a re-vendor and then quietly run nothing.
        { name = "test_eol", dir = "tests/_kit/" },
    },
}
