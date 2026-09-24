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
-- if a LibStub were reachable it would be the wrong answer: five of this addon's
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
--
-- LibKa0s-Compat-1.0 is one of the two rows that ARE a library table: core/Compat.lua wires the library's
-- own members onto NS.Compat rather than building an instance, so its live half is what the live
-- load's LibStub answers for the name (LibKa0s docs/api/Compat/version-1-docs.md, "How a host wires
-- it" -- a runner with a table map has to add the row, or the by-name call cannot resolve it).
local surfaceNS, surfaceMock = loadAddon()
Kit.setSurfaceSource{
    ["LibKa0s-DebugLog-1.0"] = surfaceNS.DebugLog,
    ["LibKa0s-Slash-1.0"]    = surfaceNS.SlashCommands,
    ["LibKa0s-Options-1.0"]  = surfaceNS.addon.Settings.Helpers,
    ["LibKa0s-Compat-1.0"]   = surfaceMock.LibStub("LibKa0s-Compat-1.0", true),
    -- Two more INSTANCES, for the same reason as the first three: core/LauncherSetup.lua and
    -- core/LifecycleSetup.lua each publish what `lib:New(descriptor)` returned, and their stubs
    -- mirror that instance, not the library table.
    ["LibKa0s-Launcher-1.0"]  = surfaceNS.Launcher,
    ["LibKa0s-Lifecycle-1.0"] = surfaceNS.Lifecycle,
    -- A library table too, for the same reason: settings/SchemaSetup.lua's HostSchemaStub stands in
    -- for the LIBRARY (its SplitPath / Read / Write / SameValue / New), so the by-name parity case
    -- compares it against what LibStub answers. The instance-vs-stub pair is the kit's two-table
    -- form and needs no row here (LibKa0s docs/api/Schema/version-2-docs.md, "Pinning it").
    ["LibKa0s-Schema-1.0"]   = surfaceMock.LibStub("LibKa0s-Schema-1.0", true),
}

-- The shared table every suite reaches through `_G.WHATGROUP_TEST`. Kit.expose merges `test` and
-- the kit assertions in beside this repo's own keys, so no suite file changed when the harness
-- moved onto the kit.
--
-- `LibStub` is the surface load's, handed over so Kit.expose records it as
-- `assertLibraryConstant`'s fallback. The surface map above answers INSTANCES, and a lib-level
-- constant such as LibKa0s-Slash-1.0's DISABLED_LINE_FORMAT is not on an instance; without the
-- fallback the by-name read reddens with "carries no member". The source map is already set, so
-- expose leaves it alone.
_G.WHATGROUP_TEST = Kit.expose{
    newAddon    = newAddon,
    bootAddon   = bootAddon,
    enableAddon = enableAddon,
    loadAddon   = loadAddon,
    root        = root,
    LibStub     = surfaceMock.LibStub,
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
        "test_frame_secure",
        "test_panel",
        "test_testmode",
        "test_launcher",
        "test_lifecycle",
        "test_debuglog",
        "test_docmap",
        "test_lintconfig",
        "test_doc_structure",
        "test_register",
        "test_disabled",
        "test_vendor_sync",
        -- The kit has shipped one suite of its own since revision 15: the working-tree
        -- line-ending gate, over every path `git ls-files` reports. It lives where the rest
        -- of the kit lives rather than being re-typed into nine repositories, so it is
        -- declared with its own `dir`. Kit.assertSuiteInventory fails the run until it is
        -- declared, so it cannot arrive with a re-vendor and then quietly run nothing.
        { name = "test_eol", dir = "tests/_kit/" },
        -- The US-English prose gate (localization-5) is the kit's too, since revision 24. It
        -- was declared here as a bare "test_prose", which wired a hand-written copy under
        -- tests/ and left this one loading zero cases; the copy is gone, and the per-file,
        -- per-word waivers it carried live in tests/prose_waivers.lua, which this suite reads.
        { name = "test_prose", dir = "tests/_kit/" },
        -- The layout-1 cap gate, new in kit revision 25: every authored .lua file against the
        -- 1500-line cap, held to the census under docs/ARCHITECTURE.md's deviations register.
        -- No Kit.layoutCap opts: the census is in the default hub and nothing here is generated.
        { name = "test_layout_cap", dir = "tests/_kit/" },
    },
}
