-- tests/test_libka0s.lua — the LibKa0s seams this addon owns: that the vendored library actually
-- registers, that each descriptor is well-formed, that the degraded install answers rather than
-- errors, and the `L`-trap guards (testing-§8).
--
-- The library's own behavior is tested where it lives. What is pinned here is the WIRING, and
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
-- Core (core/CoreSetup.lua)
-- ---------------------------------------------------------------------------

test("core: the published seams ARE the library's, not a lookalike", function()
    -- Identity, not behavior. Two implementations that agree today is exactly the drift the
    -- extraction exists to end, and a behavioral assertion cannot tell them apart.
    local NS, env = T.newAddon()
    local core = env.LibStub("LibKa0s-Core-1.0", true)
    assertEqual(NS.SafeToString, core.SafeToString)
    assertEqual(NS.IsConcatSafe, core.IsConcatSafe)
    assertEqual(NS.SKIN, core.SKIN, "the skin table is shared, never copied")
    assertEqual(NS.ApplySkin, core.ApplySkin)
end)

test("core: the close button is the library's, told which addon folder is asking", function()
    -- The one seam in core/CoreSetup.lua that is WRAPPED rather than bound, and the argument is
    -- the whole point: LibKa0s draws this collection's `close` mark only when it can build a
    -- texture path, and being vendored it cannot work out which folder it was copied into. A
    -- two-of-three passthrough builds a perfectly good button drawing a multiplication sign, so
    -- nothing errors and nothing goes red — this is the only witness (anti-patterns #64).
    -- red under: NS.MakeCloseButton = lib.MakeCloseButton.
    local NS, env = T.newAddon()
    local core = env.LibStub("LibKa0s-Core-1.0", true)
    local seen, real = nil, core.MakeCloseButton
    core.MakeCloseButton = function(_, _, name) seen = name; return nil end
    NS.MakeCloseButton(env.UIParent, function() end)
    core.MakeCloseButton = real

    assertEqual(seen, "WhatGroup",
        "the library was not told which addon FOLDER to build the texture path from")
end)

test("core: ApplySkin stays a bare bind, so its optional override survives", function()
    -- Guarding the line above the wrapper. `ApplySkin(frame, skin)` takes a per-window override,
    -- and wrapping it to one argument while adding the close-button wrapper beside it would be the
    -- same defect on the next line.
    local NS, env = T.newAddon()
    local core = env.LibStub("LibKa0s-Core-1.0", true)
    assertEqual(NS.ApplySkin, core.ApplySkin)
end)

test("core: the printer emits <prefix><space><body> as one line", function()
    -- The byte-level half of the formatter handover. The old seam called
    -- `print(NS.PREFIX, body)` and let the client join the two; Core composes the line itself and
    -- hands it to the sink, so this pins that the composed bytes are the same.
    local NS, _, mock = T.newAddon()
    NS.Print("   - Group:", "My Group")
    assertEqual(mock.prints[#mock.prints], NS.PREFIX .. " " .. "   - Group: My Group")
end)

test("core: the prefix is read at CALL time, not captured at load", function()
    -- core/CoreSetup.lua loads before core/WhatGroup.lua defines NS.PREFIX, so the string form
    -- would have captured nil forever. Move the constant and the next line must move with it.
    local NS, _, mock = T.newAddon()
    NS.PREFIX = "|cff00FF00[XX]|r"
    NS.Print("after")
    assertEqual(mock.prints[#mock.prints], "|cff00FF00[XX]|r after")
end)

test("core: the sink is the Lua global print, so the harness can see chat output", function()
    -- Core defaults to DEFAULT_CHAT_FRAME:AddMessage. This addon has always printed through the
    -- global, and the mock captures the global — without the explicit `sink` every chat assertion
    -- in this suite would go silent while still passing.
    local NS, _, mock = T.newAddon()
    local before = #mock.prints
    NS.Print("routed")
    assertEqual(#mock.prints, before + 1, "the line landed in the global-print capture")
end)

-- ---------------------------------------------------------------------------
-- DebugLog (core/DebugLogSetup.lua)
-- ---------------------------------------------------------------------------

test("debuglog: the console is the library's instance, and the sink is bound bare", function()
    local NS = T.newAddon()
    assertEqual(type(NS.DebugLog.SetEnabled), "function", "the instance surface is there")
    assertEqual(NS.Debug, NS.DebugLog.Debug,
        "NS.Debug must BE the instance's plain function, not a wrapper — ~20 call sites bind it")
end)

test("debuglog: the library is told the FOLDER name, not just the frame name", function()
    -- Two fields, two questions, one string in this addon. `name` seeds the frame globals below;
    -- `addonName` is what the library builds a TEXTURE PATH from, which is what turns the
    -- console's close, clear and copy controls from a multiplication sign and two words into this
    -- collection's marks — on the copy window too. Asserted against the SOURCE because the
    -- descriptor is not published back, and because the appearance it produces is not something a
    -- headless run can see.
    -- red under: dropping the key and letting the console keep its words.
    local src = readFile("core/DebugLogSetup.lua")
    assertTrue(src ~= nil, "core/DebugLogSetup.lua is readable")
    local body = src:gsub("%-%-[^\r\n]*", "")
    assertTrue(body:match("addonName%s*=%s*addonName") ~= nil,
        "the descriptor does not pass addonName, so both console windows draw the fallback glyph")
end)

test("debuglog: the descriptor keeps the frame globals the old console used", function()
    -- A rename here is invisible until a player's Esc stops closing the window or /framestack
    -- attributes it to nobody.
    local NS, _, mock = T.newAddon()
    NS.DebugLog:Show()
    assertTrue(mock.frames["WhatGroupDebugWindow"] ~= nil, "the console window keeps its name")
    NS.DebugLog:ShowCopy()
    assertTrue(mock.frames["WhatGroupDebugCopyWindow"] ~= nil, "and so does the copy window")
    assertTrue(mock.frames["WhatGroupDebugCopyScroll"] ~= nil, "and its scroll frame")
end)

test("debuglog: the composed window title is unchanged", function()
    -- The library appends its own " — Debug" to the descriptor's `title`, so this is the byte-level
    -- check that the two halves still compose to what the hand-written console rendered.
    local NS, _, mock = T.newAddon()
    NS.DebugLog:Show()
    assertEqual(mock.frames["WhatGroupDebugWindow"].titleText, "Ka0s WhatGroup \226\128\148 Debug")
end)

test("debuglog: the flag stays the addon's — the library never keeps a copy", function()
    local NS = T.newAddon()
    NS.State.debug = false
    NS.DebugLog:SetEnabled(true)
    assertTrue(NS.State.debug, "SetEnabled wrote through to NS.State.debug")
    assertTrue(NS.DebugLog:IsEnabled(), "and IsEnabled reads the same flag")
    NS.State.debug = false
    assertFalse(NS.DebugLog:IsEnabled(), "a write straight to the flag is seen too")
end)

test("debuglog: the [Init] summary is the addon's, reached through the descriptor", function()
    local NS = T.bootAddon()
    NS.State.debug = false
    NS.DebugLog:SetEnabled(true)
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertEqual(last:find("[Init]", 1, true) ~= nil, true, "the enable path ends with [Init]")
    assertTrue(last:find(NS.addon:InitSummary(), 1, true) ~= nil,
        "and the line IS this addon's summary, not a library default")
end)

test("debuglog: the console's user-visible strings resolve to prose, not to their own keys", function()
    -- The rendered half of the `L` trap, for the one adopted module that can express it and does
    -- render a real library string. Reached through a REAL accessor: a case that guards on
    -- `if label then` passes vacuously when the accessor does not exist.
    --
    -- red under: `L = { CHECKBOX_LABEL = "CHECKBOX_LABEL" }` on the descriptor. Note that
    -- `L = NS.L` alone does NOT redden this one — DebugLog's resolver has used `rawget` since
    -- minor 3, so a metatable-backed table falls through correctly and the trap is invisible from
    -- the rendered end on this copy. The SOURCE guard above is what catches that spelling; this
    -- case guards what the user actually sees, and would go red the day the resolver changed or
    -- the accessor stopped answering.
    local NS = T.newAddon()
    local spec = NS.DebugLog:ConsoleCheckbox()
    assertEqual(type(spec.label), "string", "ConsoleCheckbox really returns a label")
    assertEqual(type(spec.tooltip), "string", "and a tooltip")
    -- No English label is SCREAMING_SNAKE_CASE. A resolved string is prose; an unresolved one is
    -- the key.
    assertNil(spec.label:match("^[A-Z][A-Z0-9_]+$"), "label rendered as a raw key: " .. spec.label)
    assertNil(spec.tooltip:match("^[A-Z][A-Z0-9_]+$"),
        "tooltip rendered as a raw key: " .. spec.tooltip)
    -- Non-vacuity: couple it to the library's own value, so the case fails if the accessor ever
    -- stops answering rather than passing on an empty string.
    local _, env = T.newAddon()
    local lib = env.LibStub("LibKa0s-DebugLog-1.0", true)
    assertEqual(spec.label, lib.STRINGS.CHECKBOX_LABEL)
    assertTrue(spec.tooltip:find("/wg debug", 1, true) ~= nil,
        "the tooltip is composed from the descriptor's own slash")
end)

test("debuglog: the gated sink survives a format its arguments cannot satisfy (WG-22)", function()
    -- The library gained this at DebugLog minor 7, driven by this addon: `%d` handed the
    -- stringified sentinel used to raise inside the sink. Pinned here as well as upstream, because
    -- it is the behavior WhatGroup's own hand-written sink guaranteed and would otherwise have
    -- lost on adoption.
    local NS = T.newAddon()
    NS.State.debug = true
    local ok = pcall(function() NS.Debug("Capture", "n=%d", {}) end)
    assertTrue(ok, "NS.Debug must not propagate a format error")
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last:find("<secret>", 1, true) ~= nil, "and the value degrades to the sentinel")
end)

-- ---------------------------------------------------------------------------
-- Options (settings/OptionsSetup.lua)
-- ---------------------------------------------------------------------------

test("options: Settings.Helpers IS the library instance, decorated in place", function()
    -- Identity, not resemblance, and this is the case options-ui-§1 exists for. RenderRows resolves
    -- O.RenderField from the INSTANCE at call time, so a host table that merely copied the
    -- library's members across would give a test a member nobody calls.
    -- red under: build a fresh table in settings/OptionsSetup.lua and copy the library's members
    -- into it instead of moving the host's onto the instance.
    local NS, _, mock = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    local seen = 0
    local realRenderField = H.RenderField
    H.RenderField = function(...) seen = seen + 1; return realRenderField(...) end
    local panel = mock.frames["WhatGroupGeneralPanel"]
    panel:Show()
    mock.fireCTimers()
    assertTrue(seen > 0,
        "the flow engine did not go through the member on the published table")
    -- Once per row OF THE OPEN TAB, not once per schema row: the page is tabbed (options-ui-§13)
    -- and renders one group at a time, so the whole-schema count would be asserting widgets that
    -- were never asked for. General is the group the strip opens on -- its first in declaration
    -- order -- which is what makes this a fixed number rather than "whatever rendered".
    local onFirstTab = 0
    local firstGroup = NS.addon.Settings.Schema[1].group
    for _, def in ipairs(NS.addon.Settings.Schema) do
        if def.group == firstGroup then onFirstTab = onFirstTab + 1 end
    end
    assertEqual(seen, onFirstTab, "once per row of the tab the page opens on")
end)

test("options: the host's data seams survived the move onto the instance", function()
    local NS = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    for _, member in ipairs({
        "Get", "RawSet", "Set", "FindSchema", "ValidateSchema", "ApplyDefault",
        "RestoreAllDefaults", "RefreshAll", "InlineButton", "BuildMainContent",
    }) do
        assertEqual(type(H[member]), "function", "lost the host member " .. member)
    end
    for _, member in ipairs({
        "CreatePanel", "EnsureScroll", "ClearScroll", "Section", "AddSpacer", "AttachTooltip",
        "RenderField", "RenderRows", "RenderSchema", "SessionCheckbox", "SetRenderer",
        "RegisterOptionsPage", "CreateOptionsPanel", "OpenOptionsPanel", "RefreshScalars",
        "RefreshAllPanels", "PatchAlwaysShowScrollbar", "__panelFor",
    }) do
        assertEqual(type(H[member]), "function", "the library member " .. member .. " is missing")
    end
end)

test("options: the host's RestoreAllDefaults deliberately overrides the library's", function()
    -- Both sides define the name and the HOST's has to win: it wipes db.profile before re-threading
    -- (which is what drops an orphaned key) and coalesces the per-row [Set] lines into one [Reset].
    -- Copying only where the instance was nil silently gave the library's, and the suite said so.
    local NS = T.bootAddon()
    NS.addon.db.profile.stale = "orphan"
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertNil(NS.addon.db.profile.stale, "the library's row-by-row form would have left this")
end)

test("options: a panel write takes the addon's single write seam", function()
    -- options-ui-§1: a checkbox must take exactly the path `/wg set` takes — same [Set] debug line,
    -- same row onChange, same refresh — or there are two behaviors and only one gets tested.
    local NS, _, mock = T.enableAddon()
    NS.State.debug = true
    local panel = mock.frames["WhatGroupGeneralPanel"]
    panel:Show()
    mock.fireCTimers()
    -- On the Chat tab, so the strip has to be clicked first. The tab buttons are CreateFrame
    -- Buttons in the page's chrome band, not AceGUI widgets, which is why this reaches into
    -- mock.frames rather than through findWidget.
    for _, f in ipairs(mock.frames) do
        if f.__kind == "Button" and f.__text == "Chat" then f.__fire("OnClick") end
    end
    local cb = mock.findWidget(function(w)
        return w.type == "CheckBox" and w.labelText == "Leader"
    end)
    cb:Fire("OnValueChanged", false)
    assertEqual(NS.addon.db.profile.notify.showLeader, false, "the value landed")
    assertTrue(NS.DebugLog:FindLine("[Set] notify.showLeader = false") ~= nil,
        "and it produced the same [Set] trace a slash write does")
end)

test("options: no layout constant is restated in this addon's own source", function()
    -- options-ui-§8: a host copy of a library constant is the copy that goes stale. Where a bespoke
    -- widget needs one, it is read off the instance (Helpers.ROW_VSPACER), never written down.
    local NS = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    assertEqual(H.ROW_VSPACER, 8)
    assertEqual(H.SECTION_HEADING_H, 26)
    assertEqual(H.BUTTON_PAIR_REL, 0.492)
    for _, path in ipairs({ "settings/Panel.lua", "settings/OptionsSetup.lua" }) do
        local src = readFile(path)
        for _, name in ipairs({
            "PADDING_X", "HEADER_TOP", "HEADER_HEIGHT", "DEFAULTS_W",
            "SECTION_TOP_SPACER", "SECTION_BOTTOM_SPACER", "SECTION_HEADING_H", "ROW_VSPACER",
        }) do
            assertNil(src:match("local%s+" .. name .. "%s*="),
                path .. " restates the library layout constant " .. name)
        end
    end
end)

test("options: the panel body still builds on the NEXT frame, not inside OnShow", function()
    -- The one adapter this adoption needed. LibKa0s-Options-1.0's SetRenderer calls the renderer —
    -- and EnsureDefaultsButton — synchronously inside its own OnShow; this addon wraps both on the
    -- instance so neither creates an AceGUI frame inside a secure-execute chain, which is the fix
    -- docs/midnight-quirks.md records and the contract tests/test_panel.lua has pinned since.
    -- red under: drop the C_Timer.After wrappers in settings/OptionsSetup.lua.
    local _, _, mock = T.enableAddon()
    local panel = mock.frames["WhatGroupGeneralPanel"]
    panel:Show()
    assertEqual(#mock.aceWidgets, 0,
        "OnShow built nothing — not the page body and not the Defaults button")
    assertTrue(#mock.timers > 0, "a next-frame hop is queued instead")
    mock.fireCTimers()
    assertTrue(#mock.aceWidgets > 0, "and the widgets appear on the next frame")
end)

-- ---------------------------------------------------------------------------
-- Slash (settings/Slash.lua)
-- ---------------------------------------------------------------------------
--
-- Every case below asserts BYTES. Four formatters changed hands here — the help header, the
-- command row, the `key = value` pair and the value renderer — and "does it still run" is exactly
-- the question that cannot see a formatter drift.

test("slash: the help header is the library's, with this addon's alias sentence", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:OnSlashCommand("help")
    assertEqual(mock.prints[1],
        NS.PREFIX .. " v" .. NS.addon.VERSION ..
        " \226\128\148 slash commands (|cFFFFFF00/whatgroup|r is an alias for |cFFFFFF00/wg|r)")
end)

test("slash: a help row is the one command-row formatter, indented two spaces", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:OnSlashCommand("help")
    local first = NS.addon.COMMANDS[1]
    assertEqual(mock.prints[2],
        NS.PREFIX .. "   |cFFFFFF00/wg " .. first[1] .. "|r \226\128\148 |cFFFFFFFF"
        .. first[2] .. "|r")
end)

test("slash: the landing page renders the SAME rows, un-indented (convergence #2)", function()
    -- The convergence itself. This panel used to carry a second formatter for the same data —
    -- double spaces around the em dash, the dash white-wrapped, the description bare. Asserting
    -- that the two differ by exactly the indent is what makes a future divergence impossible to
    -- introduce quietly.
    local NS = T.bootAddon()
    local Sl = NS.SlashCommands
    local help, landing = Sl:HelpRows(), Sl:LandingRows()
    assertEqual(#help, #NS.addon.COMMANDS)
    assertEqual(#landing, #help)
    for i = 1, #help do
        assertEqual(help[i], "  " .. landing[i], "row " .. i .. " differs by more than the indent")
    end
end)

test("slash: the landing page draws those rows and nothing of its own", function()
    local NS, _, mock = T.enableAddon()
    local main = mock.frames["WhatGroupParentPanel"]
    main:Show()
    mock.fireCTimers()
    for _, line in ipairs(NS.SlashCommands:LandingRows()) do
        local found = mock.findWidget(function(w) return w.type == "Label" and w.text == line end)
        assertTrue(found ~= nil, "the landing page is missing the row: " .. line)
    end
end)

test("slash: `list` renders through the shared key/value formatter", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:OnSlashCommand("get enabled")
    assertEqual(mock.prints[#mock.prints],
        NS.PREFIX .. " |cFFFFFF00enabled|r = |cFFFFFFFFtrue|r")
end)

test("slash: a number row still renders through its schema `fmt`", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.Settings.Helpers.Set("notify.delay", 2.5)
    NS.addon:OnSlashCommand("get notify.delay")
    assertEqual(mock.prints[#mock.prints],
        NS.PREFIX .. " |cFFFFFF00notify.delay|r = |cFFFFFFFF2.5s|r")
end)

test("slash: `toggle` survived the adoption, through the descriptor's parse adapter", function()
    -- The library's parseBool knows true/false/on/off/1/0/yes/no and nothing else. `toggle` is this
    -- addon's own grammar and a shipped verb, so it is handled in a `parse` adapter
    -- (slash-commands-§6) rather than dropped — and everything else still delegates, so the
    -- clamping and the enum validation stay the library's.
    local NS = T.bootAddon()
    local H = NS.addon.Settings.Helpers
    NS.addon:OnSlashCommand("set notify.showLeader toggle")
    assertEqual(H.Get("notify.showLeader"), false)
    NS.addon:OnSlashCommand("set notify.showLeader toggle")
    assertEqual(H.Get("notify.showLeader"), true)
end)

test("slash: the descriptor's L overrides exactly one string and nothing else", function()
    -- A PLAIN one-key table, and the rendered proof that it resolved: the library's own ERR_BOOL
    -- lists yes/no, ours names `toggle`, and every OTHER string still comes from the library.
    -- red under: drop the `L` table from the descriptor.
    local NS, env, mock = T.bootAddon()
    local lib = env.LibStub("LibKa0s-Slash-1.0", true)
    local Sl = NS.SlashCommands
    assertEqual(Sl:Text("ERR_BOOL"), "expected true/false/on/off/1/0/toggle")
    assertTrue(Sl:Text("ERR_BOOL") ~= lib.STRINGS.ERR_BOOL, "the override really took")
    assertEqual(Sl:Text("ERR_NUMBER"), lib.STRINGS.ERR_NUMBER, "and nothing else was overridden")
    -- Reached through the real path, not just the accessor.
    NS.addon:OnSlashCommand("set notify.showLeader maybe")
    assertEqual(mock.prints[#mock.prints], NS.PREFIX .. "   expected true/false/on/off/1/0/toggle")
end)

test("slash: every user-visible CLI string resolves to prose, not to its own key", function()
    -- The rendered half of the `L` trap for this module. No English message is
    -- SCREAMING_SNAKE_CASE, so a key that reached the screen is a key that never resolved.
    local NS, env = T.bootAddon()
    local lib = env.LibStub("LibKa0s-Slash-1.0", true)
    local Sl = NS.SlashCommands
    local checked = 0
    for key in pairs(lib.STRINGS) do
        local rendered = Sl:Text(key)
        assertEqual(type(rendered), "string", key .. " did not resolve to a string")
        assertNil(rendered:match("^[A-Z][A-Z0-9_]+$"),
            key .. " rendered as a raw key: " .. rendered)
        checked = checked + 1
    end
    assertTrue(checked >= 20, "the whole string table was walked, not an empty one")
end)

-- ---------------------------------------------------------------------------
-- The degraded install — the library genuinely absent
-- ---------------------------------------------------------------------------
--
-- Loaded with the file MISSING, never by hand-stubbing the namespace member under test
-- (testing-§8). Core.lua absent means every other major returns before LibStub:NewLibrary too, so
-- this is the whole-library-missing scenario as well as the Core one.

local NO_LIBKA0S = {
    "libs/LibKa0s/Core.lua", "libs/LibKa0s/Env.lua", "libs/LibKa0s/Pool.lua",
    "libs/LibKa0s/Item.lua", "libs/LibKa0s/Media.lua", "libs/LibKa0s/Widgets.lua",
    "libs/LibKa0s/DebugLog.lua", "libs/LibKa0s/Slash.lua",
    "libs/LibKa0s/Options.lua", "libs/LibKa0s/OptionsWidgets.lua",
    "libs/LibKa0s/OptionsCompose.lua",
    "libs/LibKa0s/OptionsScroll.lua", "libs/LibKa0s/Perf.lua", "libs/LibKa0s/PerfPanel.lua",
}

test("degraded: the addon loads with LibKa0s absent", function()
    local NS, env = T.newAddon{ skip = NO_LIBKA0S }
    assertNil(env.LibStub("LibKa0s-Core-1.0", true), "the library really is absent")
    assertEqual(type(NS.Print), "function", "the printer still answers")
    assertEqual(type(NS.SafeToString), "function", "the stringifier still answers")
end)

test("degraded: the cause clause is published on BOTH paths", function()
    -- Every later seam appends its own consequence to this one sentence, so it has to exist even
    -- when the library is present.
    local withLib = T.newAddon()
    local withOut = T.newAddon{ skip = NO_LIBKA0S }
    assertEqual(withLib.LIBKA0S_MISSING, withOut.LIBKA0S_MISSING)
    assertTrue(withLib.LIBKA0S_MISSING:find("LibKa0s", 1, true) ~= nil, "it names the library")
    assertTrue(withLib.LIBKA0S_MISSING:find("libs/LibKa0s", 1, true) ~= nil,
        "and where it was expected")
end)

test("degraded: the printer announces the absence exactly ONCE, then prints normally", function()
    local NS, _, mock = T.newAddon{ skip = NO_LIBKA0S }
    NS.Print("first")
    NS.Print("second")
    NS.Print("third")
    local notices = 0
    for _, line in ipairs(mock.prints) do
        if line:find("running on reduced built-in fallbacks", 1, true) then notices = notices + 1 end
    end
    assertEqual(notices, 1, "one notice, not one per line and not none")
    assertTrue(mock.prints[1]:find(NS.LIBKA0S_MISSING, 1, true) ~= nil,
        "the notice carries the shared cause clause verbatim")
    assertTrue(mock.prints[#mock.prints]:find("third", 1, true) ~= nil,
        "and the line the user asked for still lands")
end)

test("degraded: the fallback printer still degrades a secret in place", function()
    local NS, _, mock = T.newAddon{ skip = NO_LIBKA0S }
    NS.Print("value:", {})
    assertTrue(mock.prints[#mock.prints]:find("<secret>", 1, true) ~= nil)
end)

test("degraded: every DebugLog member the addon calls still answers", function()
    -- The stub has to cover the whole surface, not the members that happened to be convenient:
    -- `/wg debug`, the panel's console checkbox and every NS.Debug trace site reach it.
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    for _, member in ipairs({
        "Add", "Debug", "Clear", "Show", "Hide", "Toggle", "IsShown", "IsEnabled",
        "RefreshHeader", "ShowCopy", "UpdateScrollBar", "UpdateStatus", "BufferSize",
        "LastLine", "FindLine", "CopyText", "MakeCloseButton", "SetEnabled", "ConsoleCheckbox",
        "Text",
    }) do
        assertEqual(type(NS.DebugLog[member]), "function", "the stub does not answer " .. member)
    end
    assertEqual(type(NS.DebugLog.buffer), "table", "and the buffer every test reads is present")
    assertEqual(NS.Debug, NS.DebugLog.Debug, "the sink is still bound bare")
end)

test("degraded: the console stub copies NO library formatter", function()
    -- debug-logging-§3: hand-copying the exact color codes whose seven-way drift the extraction
    -- exists to end is the one duplicate the standard most specifically forbids. The stub must not
    -- carry FormatPlain/FormatColored at all.
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    assertNil(NS.DebugLog.FormatPlain, "the stub must not reimplement the plain formatter")
    assertNil(NS.DebugLog.FormatColored, "nor the colored one")
    local src = readFile("core/DebugLogSetup.lua")
    assertNil(src:match("6f8faf"), "no console color code may appear in the seam file")
    assertNil(src:match("c9a66b"), "nor the tag color")
end)

test("degraded: every HAND-WRITTEN schema row survives the options library's absence (options-ui-§1)",
function()
    -- The MUST behind the load-completing stub, and it has to be MEASURED rather than reasoned
    -- about: a page file that touched a helper inside a schema-row literal at file load would raise
    -- with the member nil, its rows would never register, and a third of the schema would vanish —
    -- taking list/get/set/reset and the profile defaults with it, silently.
    --
    -- It used to compare the two ROW COUNTS outright, and that stopped being the right assertion
    -- when the Master controls block became composed (options-ui-§15): those six rows are the
    -- library's to emit, so they are legitimately absent when the library is. What is NOT allowed
    -- to change is everything else — settings/Schema.lua's own rows, in order — and the case is
    -- narrowed to exactly that rather than relaxed to a count that would wave a real half-load
    -- through.
    --
    -- red under: settings/Schema.lua calling any Helpers member inside a row literal (the rows
    -- after it vanish), or settings/Panel.lua splicing the composed block anywhere but the head.
    local full    = T.newAddon()
    local without = T.newAddon{ skip = NO_LIBKA0S }
    assertTrue(#full.addon.Settings.Schema > 0, "there is a schema to compare")

    local composed = 0
    for _, row in ipairs(full.addon.Settings.Schema) do
        if row.group == "Master controls" then composed = composed + 1 end
    end
    assertTrue(composed > 0, "the composed block is in the full schema")
    assertEqual(#without.addon.Settings.Schema, #full.addon.Settings.Schema - composed,
        "exactly the composed block is missing — nothing else")

    for i = 1, #without.addon.Settings.Schema do
        assertEqual(without.addon.Settings.Schema[i].path,
                    full.addon.Settings.Schema[i + composed].path, "row " .. i .. " differs")
    end
end)

test("degraded: the STORED profile is the same shape with the library absent", function()
    -- The half of the case above that the row counts used to carry. A composed row is a row the
    -- degraded load does not have, so a schema-only BuildDefaults would hand AceDB a profile with
    -- no `enabled` key at all — which reads as false and turns the addon off for exactly the
    -- install that is already missing a library. settings/Schema.lua seeds from defaults/Profile.lua
    -- first for this reason, and this is the assertion that says so.
    --
    -- red under: BuildDefaults dropping the NS.C seed and walking the schema alone.
    local full    = T.newAddon()
    local without = T.newAddon{ skip = NO_LIBKA0S }
    local a = full.addon.Settings.BuildDefaults().profile
    local b = without.addon.Settings.BuildDefaults().profile

    local function sameShape(x, y, where)
        for k, v in pairs(x) do
            if type(v) == "table" then
                assertEqual(type(y[k]), "table", where .. k .. " is a table on both paths")
                sameShape(v, y[k], where .. k .. ".")
            else
                assertEqual(y[k], v, where .. k)
            end
        end
    end
    sameShape(a, b, "")
    sameShape(b, a, "")
end)

test("degraded: the settings stub carries no widget maker and no layout constant", function()
    -- options-ui-§1 forbids both outright: hand-copying the code whose drift the extraction ended
    -- is anti-patterns #47, and a host copy of a library constant is the copy that goes stale.
    local NS = T.newAddon{ skip = NO_LIBKA0S }
    local H = NS.addon.Settings.Helpers
    assertNil(H.ROW_VSPACER, "the stub must not carry the library's layout constants")
    assertNil(H.SECTION_HEADING_H)
    assertNil(H.BUTTON_PAIR_REL)
    -- The chrome band's three, added when the tabbed page landed. Named individually rather than
    -- left to the parity case's ignore list: that list says "live-only on purpose", this says
    -- "and here is the assertion that catches somebody copying the number in".
    assertNil(H.CHROME_GAP, "nor the chrome band's")
    assertNil(H.TAB_H)
    assertNil(H.BANNER_H)
    local src = readFile("settings/OptionsSetup.lua")
    local stub = src:match("if not lib then(.-)\r?\nend\r?\n")
    assertTrue(stub ~= nil, "the degraded branch is findable")
    assertNil(stub:match("AceGUI"), "the stub creates no widget")
    assertNil(stub:match("SetRelativeWidth"), "nor lays one out")
end)

test("degraded: the settings panel explains itself once at load and once per config", function()
    local NS, _, mock = T.newAddon{ skip = NO_LIBKA0S }
    NS.addon:OnInitialize()
    NS.addon:OnEnable()          -- CreateOptionsPanel: the load-time notice
    NS.addon:OnSlashCommand("config")
    NS.addon:OnSlashCommand("config")
    local notices = 0
    for _, line in ipairs(mock.prints) do
        if line:find("settings panel is unavailable", 1, true) then notices = notices + 1 end
    end
    assertEqual(notices, 2,
        "once at load, once for the verb the user actually typed — and never again")
end)

test("degraded: `/wg debug on` still moves the flag and explains the missing window ONCE", function()
    -- The flag is ours, so it must keep working; the WINDOW is what is lost, and one announce per
    -- entry point is what keeps `/wg debug` from going silent after `/wg debug on` spent the token.
    local NS, _, mock = T.newAddon{ skip = NO_LIBKA0S }
    NS.addon:OnSlashCommand("debug on")
    assertTrue(NS.State.debug, "the session flag still flips")
    NS.addon:OnSlashCommand("debug on")
    NS.addon:OnSlashCommand("debug")
    NS.addon:OnSlashCommand("debug")
    local notices = 0
    for _, line in ipairs(mock.prints) do
        if line:find("debug console window is unavailable", 1, true) then notices = notices + 1 end
    end
    assertEqual(notices, 2, "once for the enable path, once for the window path — never more")
    for _, line in ipairs(mock.prints) do
        if line:find("debug console window is unavailable", 1, true) then
            assertTrue(line:find(NS.LIBKA0S_MISSING, 1, true) ~= nil,
                "and each explains the absence through the shared cause clause")
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Stub-surface parity — the whole member set, per adopted seam (testing-§8)
-- ---------------------------------------------------------------------------
--
-- The member-by-member cases above each pin the members somebody thought of. `assertSurfaceParity`
-- pins the SET: every key the live surface carries is present on the degraded one, and a key that
-- is a function live is a function degraded — the `H.Foo = UI and UI.Foo` shape leaves `false` in
-- place, and a "is the key set?" check waves that through while the call site still raises.
--
-- Both arms come from a real load — the degraded one from the PARTIAL FILE LIST above
-- (`skip = NO_LIBKA0S`), never from hand-stubbing the member under test, or the case would be
-- asserting the test's own typing (anti-patterns #56).
--
-- Each `ignore` entry below is a member that is live-only ON PURPOSE, with the rule that makes it
-- so. An omission that is not in one of these lists is a defect.

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

test("parity: the DebugLog stub carries the whole live surface", function()
    -- Live surface produced by: grep -nE "^function log[.:]|^ *log\.[A-Za-z]" libs/LibKa0s/DebugLog.lua
    local live = T.newAddon()
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(live.DebugLog, degraded.DebugLog, "NS.DebugLog stub", {
        -- debug-logging-§3: the stub must NOT carry the formatters — hand-copying the color codes
        -- whose seven-way drift the extraction exists to end is the one duplicate the standard
        -- most specifically forbids. Pinned as an absence by the "copies NO library formatter"
        -- case above; named here so the omission reads as a decision, not as a gap.
        "FormatPlain", "FormatColored",
    })
end)

test("parity: the Slash stub carries the whole live surface", function()
    -- Live surface produced by: grep -nE "^function Sl[.:]|^ *Sl\.[A-Z]" libs/LibKa0s/Slash.lua
    -- Nothing is ignored: slash-commands-§1 keeps every host-owned verb working on the degraded
    -- path, so the CLI seam degrades in what it ANSWERS, never in what it exposes.
    local live = T.newAddon()
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(live.SlashCommands, degraded.SlashCommands, "NS.SlashCommands stub")
end)

test("parity: the Options helpers stub carries the whole live surface", function()
    -- Live surface produced by: grep -nE "^function O[.:]|^ *O\.[A-Z_]" libs/LibKa0s/Options.lua
    local live = T.newAddon()
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(live.addon.Settings.Helpers, degraded.addon.Settings.Helpers,
        "Settings.Helpers stub", {
        -- options-ui-§1 / §8: the layout scalars must not be carried into the stub and must not be
        -- copied by a host anywhere — a host copy is the copy that goes stale. Every consumer of
        -- them in settings/Panel.lua sits behind a maker that is a no-op on this path.
        -- CHROME_GAP / TAB_H / BANNER_H arrived with the tabbed page and the banner
        -- (options-ui-§13 / §14) and are the same kind of thing: scalars the library publishes so
        -- a host drawing BESPOKE chrome can measure its own band. This addon draws none -- its one
        -- page hands the whole strip to RenderTabbedSchema -- so nothing here reads them, degraded
        -- or live.
        "PADDING_X", "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL",
        "CHROME_GAP", "TAB_H", "BANNER_H",
        -- The widget factory itself. settings/Panel.lua:40 and :163 read it and return early when
        -- it is nil, and both sites only run inside the page builder, which never runs degraded.
        "AceGUI",
        -- Library-internal renderers this addon never calls: it builds its landing page from its
        -- own settings/Panel.lua and has no TextRow call site, and `RestoreDefaults` on the
        -- instance is the library's per-page verb, a different one from the host's bulk
        -- `RestoreAllDefaults` (settings/OptionsSetup.lua:201).
        "BuildLandingPage", "TextRow", "RestoreDefaults",
        -- The composers' published DATA (OptionsCompose). They are value sets and one sentence of
        -- wording, and copying them into the stub is the same mistake copying a layout scalar is:
        -- the composer exists precisely so nine addons cannot each hold their own spelling of the
        -- visibility enum or the class-colour note. No host reads one -- O.MasterControls stamps
        -- them onto the rows it emits -- so the stub answers the five composer FUNCTIONS and
        -- carries none of their data.
        "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_VALUES", "VISIBILITY_SORT",
        "MASTER_GROUP", "CLASS_COLOR_NOTE",
    })
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
    for prefix, value in src:gmatch("([%w]*)%s-[%s,{]L%s*=%s*([^\r\n]+)") do
        -- `local L = NS.L` is the file's own upvalue for the locale table, not a descriptor field.
        -- Excluding it by the `local` keyword is what the reference sweep does too.
        if prefix ~= "local" then
            local rest = value:match("^NS%.L%s*(.-)%s*$") or value:match("^L%s*(.-)%s*$")
            if rest and not rest:match("^and%f[%W]") then return value end
        end
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
    assertNil(offendingL("local L = NS.L\nlocal x = 1"),
        "a file's own locale upvalue is not a descriptor field")
    assertTrue(offendingL("local L = NS.L\nlocal d = { L = NS.L }") ~= nil,
        "and excluding it must not hide a real offender in the same file")
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
