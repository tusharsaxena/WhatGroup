-- tests/test_library_lines.lua — the lines LibKa0s writes into THIS addon's debug log (v1.65.0).
--
-- Since LibKa0s v1.65.0 the library's modules log their own refusals and edges through the host's
-- gated sink, the `debug(tag, message)` field of each descriptor (debug-logging-§4, §8): Slash its
-- dispatcher's refusals (`[Cmd]`), Lifecycle its stand-down / stand-up edges (`[Lifecycle]`, pinned in
-- tests/test_debuglog.lua beside the teardown lines they head), Options its combat lock and
-- registration park (`[Cfg]`), and Launcher its registration state (`[Launcher]`), held in the
-- console's at-enable queue. These cases pin two things per line: that it LANDS here, which a
-- descriptor missing `debug` would silently stop, and that it lands ONCE, which a host line
-- duplicating it would break. The console's change gate (`D.DebugOnce`) and at-enable queue
-- (`D.DebugAtEnable`), which replaced this addon's own memo and its gated-off load-time line, are
-- pinned at the end.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function countLogged(NS, needle)
    local n = 0
    for _, line in ipairs(NS.DebugLog.buffer) do
        if line:find(needle, 1, true) then n = n + 1 end
    end
    return n
end

local function indexOf(NS, needle)
    for i, line in ipairs(NS.DebugLog.buffer) do
        if line:find(needle, 1, true) then return i end
    end
end

-- ── Slash minor 18: the dispatcher's refusals ────────────────────────────────────────────────

test("library lines: an unknown verb writes the library's [Cmd] refusal, once", function()
    -- red under: dropping `debug` from settings/Slash.lua's descriptor.
    local NS = T.enableAddon()
    NS.State.debug = true
    NS.addon:OnSlashCommand("nope")
    assertEqual(countLogged(NS, "[Cmd] refused nope: unknown verb"), 1)
end)

test("library lines: a feature verb refused by the disabled gate is one [Cmd] line", function()
    -- The gate is the library's (Slash minor 13), so `show`'s handler never runs and its own
    -- `/wg show refused` line is not written beside it.
    local NS = T.enableAddon()
    NS.addon:OnSlashCommand("disable")
    NS.State.debug = true
    NS.addon:OnSlashCommand("show")
    assertEqual(countLogged(NS, "[Cmd] refused show: disabled"), 1)
    assertEqual(countLogged(NS, "refused"), 1, "and no host line beside it")
end)

test("library lines: a set the parser refuses writes one [Cmd] line naming the path", function()
    local NS = T.enableAddon()
    NS.State.debug = true
    NS.addon:OnSlashCommand("set notify.showLeader banana")
    assertEqual(countLogged(NS, "[Cmd] refused set notify.showLeader: parse"), 1)
end)

test("library lines: a profile switch refused in combat writes one [Cmd] line", function()
    local NS, _, mock = T.enableAddon()
    NS.addon.db:SetProfile("Alt")
    NS.addon.db:SetProfile("Default")
    NS.State.debug = true
    mock.combat = true
    NS.addon:OnSlashCommand("profile Alt")
    assertEqual(countLogged(NS, "[Cmd] refused profile Alt: in combat"), 1)
end)

-- ── Options: the registration park ───────────────────────────────────────────────────────────

test("library lines: a registration parked in combat logs the park and the flush, once each", function()
    -- red under: dropping `debug` from settings/OptionsSetup.lua's descriptor.
    local NS, env, mock = T.bootAddon()
    NS.State.debug = true
    mock.combat = true
    NS.addon.Settings.Register()
    assertEqual(countLogged(NS, "[Cfg] register parked (in combat)"), 1)
    mock.combat = false
    env.LibStub("LibKa0s-Options-1.0").__parkFrame.__fire("OnEvent", "PLAYER_REGEN_ENABLED")
    assertEqual(countLogged(NS, "[Cfg] register flushed (combat ended)"), 1)
end)

-- ── the at-enable queue: state lines written while logging is off ────────────────────────────

test("library lines: the launcher's registration lands the first time logging is turned on", function()
    -- red under: dropping `debugAtEnable` from core/LauncherSetup.lua -- Register runs at OnEnable
    -- with the session-only flag off, so through `debug` the line never landed.
    local NS = T.enableAddon()
    assertEqual(countLogged(NS, "[Launcher] registered"), 0, "gated off at login")
    NS.DebugLog:SetEnabled(true)
    assertEqual(countLogged(NS, "[Launcher] registered"), 1, "written on the enable edge")
    assertTrue(indexOf(NS, "[Launcher] registered") > indexOf(NS, "[Init]"),
        "after the bracket and the [Init] summary")
    NS.DebugLog:SetEnabled(false)
    NS.DebugLog:SetEnabled(true)
    assertEqual(countLogged(NS, "[Launcher] registered"), 1, "one-shot: a second enable repeats nothing")
end)

test("library lines: the login migration's [Migrate] line lands the first time logging is turned on", function()
    -- red under: core/Database.lua writing it through NS.Debug, gated off at OnInitialize.
    local NS = T.bootAddon()
    assertEqual(countLogged(NS, "[Migrate]"), 0, "gated off at load")
    NS.DebugLog:SetEnabled(true)
    assertEqual(countLogged(NS, "[Migrate] v0 -> v" .. NS.SCHEMA_VERSION), 1)
end)

-- ── the change gate: re-armed by Clear ───────────────────────────────────────────────────────

test("library lines: a caught error logged once is logged again after a Clear", function()
    -- red under: NS.DebugErrorOnce keeping its own memo, which a Clear never re-armed -- a cleared
    -- console then stayed silent about a site still raising on every event.
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.DebugErrorOnce("Capture", "site", "boom")
    NS.DebugErrorOnce("Capture", "site", "boom")
    assertEqual(countLogged(NS, "[Capture] site: boom"), 1, "once per distinct error")
    NS.DebugLog:Clear()
    NS.DebugErrorOnce("Capture", "site", "boom")
    assertEqual(countLogged(NS, "[Capture] site: boom"), 1, "and again after a Clear")
end)

