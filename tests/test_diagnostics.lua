-- tests/test_diagnostics.lua — WhatGroup's own sections of the diagnostics report (debug-logging-§14).
--
-- The dispatcher half of the rule (both forms, while disabled, append, ungated, the markers, `diag`
-- not running it) is the kit's shared case, tests/_kit/test_diagnostics_contract.lua, wired to this
-- addon's dispatcher through Kit.diagnostics in tests/run.lua. What one report writes around the
-- sections is the library's own suite's business. This file is what is left: the sections
-- modules/Diagnostics.lua writes (DX-WG), and the STD-19 cases the kit leaves to the addon: a raising
-- section costs one line, an over-cap report ends truncated then end marker, a secret-like value
-- does not raise, and the library-absent stub answers both forms with the collection's line.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local BEGIN = "[Diag] ==== Ka0s WhatGroup diagnostics begin ===="

--- Run the report through `/wg diagnostics` and answer the report's own lines, begin to end.
local function report(NS, input)
    NS.addon:OnSlashCommand(input or "diagnostics")
    local buf, first = NS.DebugLog.buffer, nil
    for i = #buf, 1, -1 do
        if buf[i]:find(BEGIN, 1, true) then first = i break end
    end
    assertTrue(first ~= nil, "a report was written")
    local out = {}
    for i = first, #buf do out[#out + 1] = buf[i] end
    return out
end

local function has(lines, needle)
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then return true end end
    return false
end

local function count(lines, needle)
    local n = 0
    for _, l in ipairs(lines) do if l:find(needle, 1, true) then n = n + 1 end end
    return n
end

local function baseInfo(overrides)
    local i = {
        name = "Keys", leaderName = "Testadin", numMembers = 3, voiceChat = "Discord",
        generalPlaystyle = 0, playstyleString = "", age = 0, activityIDs = { 500 },
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

-- Pit of Saron: a real row of defaults/TeleportSpells.lua, keyed by mapID.
local POS_MAP, POS_SPELL = 658, 1254555

-- ---------------------------------------------------------------------------
-- Identity and settings
-- ---------------------------------------------------------------------------

test("diagnostics: the host identity names schema, profile, enabled, stood-down, holds, test mode", function()
    local NS = T.enableAddon()
    local lines = report(NS)
    assertTrue(has(lines, "schema stored=1 code=1"), "both schema versions")
    assertTrue(has(lines, "profile=Default"), "the active AceDB profile")
    assertTrue(has(lines, "enabled=true stoodDown=false"), "stored switch and the latch")
    assertTrue(has(lines, "holds -"), "no lifecycle hold while up")
    assertTrue(has(lines, "testMode=false"), "test mode")
end)

test("diagnostics: always-print rows print at default, a changed row prints path = value (default)", function()
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("set notify.delay 5")
    local lines = report(NS)
    assertTrue(has(lines, "notify.delay = 5 (0)"), "the changed row with its default")
    assertTrue(has(lines, "enabled = true (true)"), "enabled always prints")
    assertTrue(has(lines, "notify.enabled = true (true)"), "notify.enabled always prints")
    assertTrue(has(lines, "frame.autoShow = true (true)"), "frame.autoShow always prints")
    assertFalse(has(lines, "notify.showLeader ="), "an untouched row stays out")
    assertFalse(has(lines, "state.testMode ="), "a session-only row stays out")
end)

-- ---------------------------------------------------------------------------
-- Stood down: the report runs, and reads without acting
-- ---------------------------------------------------------------------------

test("diagnostics: stood down, the runtime sections say so and the header shows the hold", function()
    local NS = T.enableAddon()
    NS.addon.Settings.Helpers.Set("enabled", false)
    local lines = report(NS, "debug diagnostics")
    assertTrue(has(lines, "enabled=false stoodDown=true"), "the header shows the state")
    assertTrue(has(lines, "holds disabled"), "and names the hold")
    assertTrue(has(lines, "capture: stood down, runtime state released"),
        "the capture section says why it is empty rather than printing nothing")
    assertTrue(has(lines, "GROUP_ROSTER_UPDATE=no"), "the events read unregistered")
end)

test("diagnostics: the report reads and never acts: no registration, hold, timer or save", function()
    -- STD-05. red under: a section that calls ShowFrame, arms a timer or takes a hold.
    local NS, _, mock = T.enableAddon()
    NS.addon.Settings.Helpers.Set("enabled", false)
    local regs, timers = #mock.__registrations(), #mock.__timers()
    local holds = table.concat(NS.Lifecycle:Holds(), ",")
    mock.__resetSvWrites()
    report(NS)
    assertEqual(#mock.__registrations(), regs, "no event registered")
    assertEqual(#mock.__timers(), timers, "no timer armed")
    assertEqual(table.concat(NS.Lifecycle:Holds(), ","), holds, "no hold taken or released")
    assertEqual(#mock.__svWrites(), 0, "nothing written to SavedVariables")
    assertTrue(NS.IsStoodDown(), "and the addon is still down")
end)

-- ---------------------------------------------------------------------------
-- Registration, group, applications, pending info
-- ---------------------------------------------------------------------------

test("diagnostics: registration health names every event and the chat-link route", function()
    local NS = T.enableAddon()
    local lines = report(NS)
    assertTrue(has(lines, "GROUP_ROSTER_UPDATE=yes"))
    assertTrue(has(lines, "LFG_LIST_APPLICATION_STATUS_UPDATED=yes"))
    assertTrue(has(lines, "PLAYER_REGEN_DISABLED=yes"))
    assertTrue(has(lines, "chat link route: EventRegistry addon link"))
    assertTrue(has(lines, "rejected events -"), "and the refused list, empty")
end)

test("diagnostics: the client's applications print beside the capture tables", function()
    local NS, _, mock = T.enableAddon()
    mock.searchResults[100] = baseInfo()
    mock.activities[500] = { fullName = "Pit of Saron", mapID = POS_MAP }
    mock.applications[100] = 100
    mock.C_LFGList.GetApplications = function() return { 100 } end
    NS.addon:OnApplyToGroup(100)
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")
    local lines = report(NS)
    assertTrue(has(lines, "client applications: 100=applied"), "the client's own view")
    assertTrue(has(lines, "pendingApplications: 100=Keys"), "the capture it paired with")
    assertTrue(has(lines, "capturesByResult: -"), "and nothing left waiting on a search result")
end)

test("diagnostics: pending info prints leader, voice chat and title, and the notify timer", function()
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = { title = "Keys", leaderName = "Testadin", voiceChat = "Discord",
                             activityID = 500, mapID = POS_MAP, fullName = "Pit of Saron" }
    mock.inGroup = true
    NS.addon:_TryFireJoinNotify("test")
    local lines = report(NS)
    assertTrue(has(lines, "pending: title=Keys leader=Testadin voiceChat=Discord"))
    assertTrue(has(lines, "notified=true"), "notify already fired for it")
    assertTrue(has(lines, "notify timer armed=true"), "and its timer is pending")
    assertTrue(has(lines, "group: inGroup=true"))
end)

-- ---------------------------------------------------------------------------
-- Teleport resolution
-- ---------------------------------------------------------------------------

test("diagnostics: teleport resolution names the spell, known flag, table entry and cooldown", function()
    local NS, _, mock = T.enableAddon()
    mock.knownSpells[POS_SPELL] = true
    mock.now = 1000
    mock.spellCooldowns[POS_SPELL] = { startTime = 900, duration = 300, isEnabled = true, modRate = 1 }
    NS.addon.pendingInfo = { title = "Keys", activityID = 500, mapID = POS_MAP }
    local lines = report(NS)
    assertTrue(has(lines, "teleport: spell=" .. POS_SPELL .. " known=true entry=true"))
    assertTrue(has(lines, "cooldown start=900 duration=300"), "the raw readable pair")
end)

test("diagnostics: an unreadable cooldown is named, never computed on", function()
    -- A table stands in for a secret: `+` and `<` raise on it, as they do on a secret number.
    -- red under: calling Compat.GetSpellCooldownRemaining, which does arithmetic unguarded.
    local NS, _, mock = T.enableAddon()
    mock.knownSpells[POS_SPELL] = true
    mock.spellCooldowns[POS_SPELL] = { startTime = {}, duration = {}, isEnabled = true, modRate = 1 }
    NS.addon.pendingInfo = { title = "Keys", activityID = 500, mapID = POS_MAP }
    local ok = pcall(report, NS)
    assertTrue(ok, "the report did not raise")
    local lines = report(NS)
    assertTrue(has(lines, "cooldown unreadable"))
    assertEqual(count(lines, "failed:"), 0, "and no section failed on it")
end)

test("diagnostics: no pending group reads as such, not as an empty teleport", function()
    local NS = T.enableAddon()
    assertTrue(has(report(NS), "teleport: no pending group"))
end)

-- ---------------------------------------------------------------------------
-- Popup
-- ---------------------------------------------------------------------------

test("diagnostics: an unbuilt popup reads `not built`, and the report never builds it", function()
    -- red under: a section calling ShowFrame or any builder, which creates the secure button.
    local NS, _, mock = T.enableAddon()
    local lines = report(NS)
    assertTrue(has(lines, "popup: not built"))
    assertNil(mock.frames["WhatGroupFrame"], "the popup, and with it the secure button, was not created")
end)

test("diagnostics: a built popup prints its state, the saved point and the live point", function()
    local NS = T.enableAddon()
    NS.addon.pendingInfo = { title = "Keys", activityID = 500, mapID = POS_MAP }
    NS.addon:ShowFrame()
    local lines = report(NS)
    assertTrue(has(lines, "popup: built=true shown=true"))
    assertTrue(has(lines, "popup saved point -"), "no saved point until a drag")
    assertTrue(has(lines, "popup live point CENTER"), "the live anchor")
end)

test("diagnostics: the launcher line", function()
    local NS = T.enableAddon()
    assertTrue(has(report(NS), "launcher: registered="))
end)

-- ---------------------------------------------------------------------------
-- STD-19's addon-side cases
-- ---------------------------------------------------------------------------

test("diagnostics: a raising section costs exactly one line, and the report still ends", function()
    -- red under: sections run outside the library's per-section pcall.
    local NS = T.enableAddon()
    NS.FrameSnapshot = function() error("boom") end
    local lines = report(NS)
    assertEqual(count(lines, "section popup failed:"), 1, "one line for the raise")
    assertTrue(has(lines, "launcher: registered="), "the section after it still ran")
    assertTrue(lines[#lines]:find("diagnostics end:", 1, true) ~= nil, "and the end marker is last")
end)

test("diagnostics: an over-cap report ends `truncated`, then the end marker", function()
    local NS = T.enableAddon()
    NS.DebugLog:RunDiagnostics({ maxLines = 8 })
    local buf = NS.DebugLog.buffer
    assertTrue(buf[#buf - 1]:find("truncated:", 1, true) ~= nil, "the truncated line")
    assertTrue(buf[#buf]:find("diagnostics end: 8 line(s)", 1, true) ~= nil, "then the end marker")
end)

test("diagnostics: a secret-like pending value degrades in place instead of raising", function()
    local NS = T.enableAddon()
    NS.addon.pendingInfo = { title = {}, leaderName = {}, voiceChat = "" }
    local ok, lines = pcall(report, NS)
    assertTrue(ok, "the report did not raise")
    assertTrue(has(lines, "<secret>"), "the value reads as the sentinel")
    assertEqual(count(lines, "failed:"), 0, "and no section failed on it")
end)

test("diagnostics: one localized chat line names the count and Copy", function()
    local NS, _, mock = T.enableAddon()
    local mark = #mock.prints
    local lines = report(NS)
    assertEqual(#mock.prints - mark, 1, "exactly one chat line")
    assertTrue(mock.prints[#mock.prints]:find(
        "Diagnostic report written to the debug console: " .. #lines .. " lines. Use Copy to share it.",
        1, true) ~= nil)
end)

test("diagnostics: without LibKa0s-DebugLog both forms print the library-absent line, writing nothing", function()
    local NS, _, mock = T.enableAddon{
        skip = { "libs/LibKa0s/DebugLog.lua", "libs/LibKa0s/DebugLogDiagnostics.lua" },
    }
    for _, form in ipairs({ "diagnostics", "debug diagnostics" }) do
        local mark = #mock.prints
        NS.addon:OnSlashCommand(form)
        assertEqual(#mock.prints - mark, 1, form .. " answers one line")
        assertTrue(mock.prints[#mock.prints]:find(
            "/wg diagnostics is unavailable: the LibKa0s library did not load.", 1, true) ~= nil)
    end
    assertEqual(#NS.DebugLog.buffer, 0, "and nothing was written")
end)
