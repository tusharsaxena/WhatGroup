-- tests/test_libka0s.lua — the LibKa0s seams this addon owns: that the vendored library actually
-- registers, that each descriptor is well-formed, that the degraded install answers rather than
-- errors, and the `L`-trap guards (testing-§8).
--
-- The library's own behaviour is tested where it lives. What is pinned here is the WIRING, and
-- above all the two things nothing else can see: that the modules are really present (a seam
-- measuring its own fallback stub is green and proves nothing), and that no descriptor was handed
-- this addon's locale table.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

-- Every file the addon's own source may hand a descriptor to a LibKa0s module from. The `L`-trap
-- source guard below sweeps exactly these.
local SEAM_FILES = {
    "core/CoreSetup.lua",
    "core/DebugLogSetup.lua",
    "settings/OptionsSetup.lua",
    "settings/Slash.lua",
}

-- ---------------------------------------------------------------------------
-- The vendored library is really there
-- ---------------------------------------------------------------------------

test("libka0s: every vendored major registers under LibStub", function()
    local _, env = T.newAddon()
    for _, major in ipairs({
        "LibKa0s-Core-1.0", "LibKa0s-DebugLog-1.0", "LibKa0s-Slash-1.0",
        "LibKa0s-Options-1.0", "LibKa0s-Perf-1.0",
    }) do
        assertTrue(env.LibStub(major, true) ~= nil, major .. " did not register")
    end
end)

test("libka0s: MODULES names every file of every major, at a positive integer minor", function()
    local _, env = T.newAddon()
    local expected = {
        ["LibKa0s-Core-1.0"]     = { "Core" },
        ["LibKa0s-DebugLog-1.0"] = { "DebugLog" },
        ["LibKa0s-Slash-1.0"]    = { "Slash" },
        ["LibKa0s-Options-1.0"]  = { "Options", "OptionsWidgets", "OptionsScroll" },
        ["LibKa0s-Perf-1.0"]     = { "Perf", "PerfPanel" },
    }
    for major, files in pairs(expected) do
        local lib = env.LibStub(major, true)
        assertTrue(type(lib.MODULES) == "table", major .. " has no MODULES registry")
        for _, file in ipairs(files) do
            local minor = lib.MODULES[file]
            assertEqual(type(minor), "number", major .. " does not report " .. file)
            assertTrue(minor > 0 and minor == math.floor(minor),
                major .. "." .. file .. " minor must be a positive integer")
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The `L` trap — the source guard
-- ---------------------------------------------------------------------------
--
-- A descriptor field is not observable after `lib:New` returns, so the only way to see a locale
-- table handed to one is to read the seam files. The obvious pattern is wrong:
--
--     L = NS.L                     -- the table itself                        OFFENDER
--     L = NS.L or { ... }          -- NS.L is always truthy, so: the table    OFFENDER
--     L = NS.L and { ... } or nil  -- evaluates to the plain table            fine
--
-- so the matcher keys on what the expression EVALUATES TO — flag any `L =` whose value starts with
-- the locale table unless the next token is `and`.

local function offendingL(src)
    for value in src:gmatch("[%s,{]L%s*=%s*([^\r\n]+)") do
        local rest = value:match("^NS%.L%s*(.-)%s*$") or value:match("^L%s*(.-)%s*$")
        if rest and not rest:match("^and%f[%W]") then return value end
    end
    return nil
end

test("libka0s: the L-trap matcher flags the table and the `or` spelling, not the `and` one", function()
    -- A matcher nothing tests can be narrowed back to a single anchored form while still reporting
    -- green, which is exactly how it got there. Drive it against all three spellings.
    assertTrue(offendingL("local d = { L = NS.L }") ~= nil, "the bare table must be flagged")
    assertTrue(offendingL('local d = { L = NS.L or { A = "a" } }') ~= nil,
        "the `or` spelling still evaluates to the locale table")
    assertNil(offendingL('local d = { L = NS.L and { A = "a" } or nil }'),
        "the `and` spelling evaluates to the plain table and is legitimate")
    assertNil(offendingL('local d = { L = { ERR_BOOL = "expected" } }'),
        "a plain literal table is the contract")
end)

test("libka0s: no seam file hands a descriptor this addon's locale table (the L trap)", function()
    for _, path in ipairs(SEAM_FILES) do
        local src = readFile(path)
        if src then
            local bad = offendingL(src)
            assertNil(bad, path .. " hands a descriptor NS.L: " .. tostring(bad))
        end
    end
end)

-- ---------------------------------------------------------------------------
-- The two majors that CANNOT express the trap — library tripwires
-- ---------------------------------------------------------------------------
--
-- Core ships no STRINGS and reads no descriptor `L`; Options ships STRINGS but reads no descriptor
-- `L`. A rendered assertion for either is a case that cannot fail — worse than no case, because it
-- reads as coverage. These two stand in for it, and each goes red the day the module grows one.

test("libka0s: Core has no STRINGS and reads no descriptor L (tripwire)", function()
    local _, env = T.newAddon()
    local core = env.LibStub("LibKa0s-Core-1.0", true)
    assertNil(core.STRINGS, "Core grew a STRINGS table; the L trap now applies to it")
    local src = readFile("libs/LibKa0s/Core.lua")
    assertTrue(src ~= nil, "the vendored Core.lua is readable")
    assertNil(src:match("lib%.STRINGS"), "Core.lua now defines STRINGS")
    assertNil(src:match("d%.L"), "Core.lua now reads a descriptor L")
end)

test("libka0s: Options reads no descriptor L (tripwire)", function()
    -- Options DOES ship a STRINGS table, so the "STRINGS is absent" half does not transfer and
    -- asserting it would fail on a module that is behaving correctly. The source half alone is the
    -- tripwire, and the settings panel is where a raw SCREAMING_SNAKE key is most visible.
    local src = readFile("libs/LibKa0s/Options.lua")
    assertTrue(src ~= nil, "the vendored Options.lua is readable")
    assertNil(src:match("d%.L"), "Options.lua now reads a descriptor L")
    local widgets = readFile("libs/LibKa0s/OptionsWidgets.lua")
    assertTrue(widgets ~= nil, "the vendored OptionsWidgets.lua is readable")
    assertNil(widgets:match("d%.L"), "OptionsWidgets.lua now reads a descriptor L")
end)
