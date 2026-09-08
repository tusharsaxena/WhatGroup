-- tests/test_surface_parity.lua — every degradation stub carries the whole live surface.
--
-- WhatGroup adopts four LibKa0s seams — Core, DebugLog, Slash and Options — and each of the four
-- setup files carries a degradation stub for the install where libs/LibKa0s is missing. A stub is a
-- second implementation of somebody else's surface, so it drifts the moment the library grows a
-- member the host starts calling: the live path stays green and the degraded path raises in exactly
-- the install the stub exists for.
--
-- The member-by-member cases in tests/test_libka0s.lua each pin the members somebody thought of.
-- These four pin the SET: every key the live surface carries is present on the degraded one, and a
-- key that is a function live is a function degraded — the `H.Foo = UI and UI.Foo` shape leaves
-- `false` in place, and a "is the key set?" check waves that through while the call site still
-- raises.
--
-- Two rules the cases follow, both testing-§8:
--
--   * The degraded arm comes from a REAL LOAD with the library's files omitted (`skip = NO_LIBKA0S`
--     below), never from hand-stubbing the member under test — a hand-stub asserts the test
--     author's typing rather than the shipped file (anti-patterns #56).
--   * Where a member is live-only on purpose it is named in the `ignore` set WITH the rule that
--     makes it so, because a deliberate omission and a bug otherwise read identically.
--
-- THE THREE LIBRARY-BACKED SEAMS CALL THE KIT'S BY-NAME FORM — assertSurfaceParity(stub, major,
-- ignore), new at kit 15 and vendored by M4-01. What it changes is which keys of the live half get
-- walked: the by-name form compares only `Kit.publicMembers`, which drops LibStub's own MAJOR,
-- MINOR and MODULES and every `__`-prefixed key. Those are the library talking to itself across its
-- own file boundaries — `__bannerBand`, `__layoutTabs`, `__tabPlacement`, `__print` — and a stub is
-- obliged to carry none of them. Under the four-argument form this file's Options case had to
-- exempt `__print` BY HAND, one line added by the v1.27.0 re-vendor, and that list would have grown
-- once per re-vendor that added an internal. libs/LibKa0s/Options.lua's own comment at `O.__print`
-- states the rule the kit now enforces on our behalf.
--
-- WHERE THE LIVE HALF COMES FROM, and why it is not the obvious place. tests/run.lua registers it
-- with `Kit.setSurfaceSource`, naming three INSTANCES — what `lib:New(descriptor)` returned. It has
-- to: `Kit.expose` auto-wires the mock's LibStub, which answers the LIBRARY TABLE for a major, and
-- none of this addon's three stubs mirrors a library table. Left to the auto-wiring,
-- "LibKa0s-Options-1.0" resolves a four-member table (LAYOUT, New, PatchAlwaysShowScrollbar,
-- STRINGS) and this file goes red for three reasons that have nothing to do with any stub.
--
-- Core stays on the FOUR-ARGUMENT form, and that is not an oversight. Core is not a major's surface
-- at all as this addon consumes it: core/CoreSetup.lua hangs its members on NS itself, so the
-- namespace IS the seam's surface and there is no name to look a live half up under.

local T = _G.WHATGROUP_TEST
local test = T.test

-- The degraded arm's file list, DERIVED rather than restated: tests/loader.lua publishes the
-- LibKa0s.xml load order it feeds the sandbox, and skipping all of it is the whole-library-missing
-- scenario. Core.lua absent would be enough on its own — every other major returns before
-- LibStub:NewLibrary once its sibling is gone — but naming the list from the loader means a file
-- added to the vendored library joins this skip on the re-vendor commit rather than on the day
-- somebody notices (anti-patterns #48).
local NO_LIBKA0S = T.loadAddon.libFiles

-- ---------------------------------------------------------------------------
-- Core — the namespace itself
-- ---------------------------------------------------------------------------

test("parity: the Core seam's whole namespace surface survives the library's absence", function()
    -- Live surface produced by: grep -nE "^NS\.[A-Za-z_]+ *=|^function NS\." core/CoreSetup.lua
    -- Core publishes into NS itself rather than onto an instance, so the namespace IS the seam's
    -- surface — and comparing the whole of it also catches a later seam quietly dropping a key.
    local live = T.newAddon()
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(live, degraded, "the addon namespace (Core seam)")
    -- NS.Util is the printer half: `print` is ~40 call sites, `format` has none yet, which is
    -- exactly why its absence would go unnoticed without this.
    T.assertSurfaceParity(live.Util, degraded.Util, "NS.Util (Core printer seam)")
end)

-- ---------------------------------------------------------------------------
-- DebugLog
-- ---------------------------------------------------------------------------

test("parity: the DebugLog stub carries the whole live surface", function()
    -- The live half is the LibKa0s-DebugLog-1.0 instance core/DebugLogSetup.lua:120 builds, which
    -- tests/run.lua registers under that name. Read off the built instance rather than off the
    -- library file, which is the same list as
    --   grep -nE "^function log[.:]|^ *log\.[A-Za-z]" libs/LibKa0s/DebugLog.lua
    -- without a parser.
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(degraded.DebugLog, "LibKa0s-DebugLog-1.0", {
        -- debug-logging-§3: the stub must NOT carry the formatters — hand-copying the color codes
        -- whose seven-way drift the extraction exists to end is the one duplicate the standard
        -- most specifically forbids. Pinned as an absence by tests/test_libka0s.lua's "the console
        -- stub copies NO library formatter" case; named here so the omission reads as a decision.
        "FormatPlain", "FormatColored",
    })
end)

-- ---------------------------------------------------------------------------
-- Slash
-- ---------------------------------------------------------------------------

test("parity: the Slash stub carries the whole live surface", function()
    -- The live half is the LibKa0s-Slash-1.0 instance settings/Slash.lua:147 builds, registered
    -- under that name by tests/run.lua.
    --
    -- Nothing is ignored, and the empty list is the assertion: slash-commands-§1 keeps every
    -- host-owned verb working on the degraded path, so the CLI seam degrades in what it ANSWERS,
    -- never in what it exposes.
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(degraded.SlashCommands, "LibKa0s-Slash-1.0")
end)

-- ---------------------------------------------------------------------------
-- Options
-- ---------------------------------------------------------------------------

test("parity: the Options helpers stub carries the whole live surface", function()
    -- The live half is the LibKa0s-Options-1.0 instance settings/OptionsSetup.lua:153 builds and
    -- publishes as Settings.Helpers with the host's data seams copied onto it, registered under
    -- that name by tests/run.lua.
    --   grep -n "Helpers\.[A-Za-z_]" core modules settings   names the addon's call sites.
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(degraded.addon.Settings.Helpers, "LibKa0s-Options-1.0", {
        -- options-ui-§1 / §8: the layout scalars must not be carried into the stub and must not be
        -- copied by a host anywhere — a host copy is the copy that goes stale. Every consumer of
        -- them in settings/Panel.lua sits behind a maker that is a no-op on this path.
        -- CHROME_GAP / TAB_H / BANNER_H arrived with the tabbed page and the banner
        -- (options-ui-§13 / §14) and are the same kind of thing: scalars the library publishes so
        -- a host drawing BESPOKE chrome can measure its own band. This addon draws none — its one
        -- page hands the whole strip to RenderTabbedSchema — so nothing here reads them, degraded
        -- or live.
        "PADDING_X", "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL",
        "CHROME_GAP", "TAB_H", "BANNER_H",
        -- The widget factory itself. settings/Panel.lua:40 and :163 read it and return early when
        -- it is nil, and both sites only run inside the page builder, which never runs degraded.
        "AceGUI",
        -- Library-internal renderers this addon never calls: it builds its landing page from its
        -- own settings/Panel.lua and has no TextRow call site, and `RestoreDefaults` on the
        -- instance is the library's per-page verb, a different one from the host's bulk
        -- `RestoreAllDefaults`.
        "BuildLandingPage", "TextRow", "RestoreDefaults",
        -- The composers' published DATA (OptionsCompose). They are value sets and one sentence of
        -- wording, and copying them into the stub is the same mistake copying a layout scalar is:
        -- the composer exists precisely so nine addons cannot each hold their own spelling of the
        -- visibility enum or the class-color note. So the stub answers the five composer
        -- FUNCTIONS and carries none of their data.
        --
        -- MASTER_GROUP is the one with a host reader: settings/Panel.lua keys its afterGroup hook
        -- off it instead of respelling the group name. It stays live-only anyway — the degraded
        -- path composes no master rows, so there is no group to key a hook to — and Panel guards
        -- the read for exactly that reason. tests/test_libka0s.lua's "the Master controls hook is
        -- keyed off the library's constant" case is what stops the guard becoming an `or`-fallback
        -- copy.
        "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_VALUES", "VISIBILITY_SORT",
        "MASTER_GROUP", "CLASS_COLOR_NOTE",
    })
end)
