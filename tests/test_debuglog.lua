-- tests/test_debuglog.lua — debug console: pure formatters, font constant,
-- and the /wg debug window-vs-flag semantics (debug-logging-§2, debug-logging-§3, debug-logging-§5).
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function debugCmd(NS, rest)
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "debug" then return c[3](rest) end
    end
    error("no debug command")
end

test("debuglog: FONT_MONO points at the library payload's JetBrains Mono TTF", function()
    -- The face moved out of this addon's media/fonts/ and into the LibKa0s payload, so the path it
    -- names now runs through libs/LibKa0s/. A FONT path keeps its extension, unlike an icon path —
    -- SetFont is handed the file, not a texture name the client completes.
    local NS = T.newAddon()
    assertTrue(type(NS.FONT_MONO) == "string", "FONT_MONO must be a string")
    assertTrue(NS.FONT_MONO:match("libs\\LibKa0s\\media\\fonts\\JetBrainsMono.-%.ttf$") ~= nil,
        "FONT_MONO must point into the vendored library payload, not at a local copy: "
        .. tostring(NS.FONT_MONO))
end)

-- debug-logging-§2's fetch-failure fallback (WG-A-13). The font the LIBRARY actually applied is
-- read off the console's own log region rather than off the descriptor, because the descriptor is
-- not published back — and the region is what the player sees. Driving the failure needs it set
-- BEFORE any source loads (`opts.mock`), since the descriptor resolves the path at file load.
local function consoleLogFont(NS, mock)
    debugCmd(NS, "")                      -- bare toggle: opens the window, building the frame
    for _, f in ipairs(mock.frames) do
        if f.__kind == "ScrollingMessageFrame" and f.__font then return f.__font[1] end
    end
end

test("debuglog: the console renders in the vendored TTF when the client can fetch it", function()
    local NS, _, mock = T.newAddon()
    assertEqual(consoleLogFont(NS, mock), NS.FONT_MONO)
end)

test("debuglog: a TTF the client cannot fetch falls back to a Blizzard font (debug-logging-§2)",
function()
    -- Still the THIRD rung, not the second: the library answers the payload path, this addon's own
    -- `or _G.STANDARD_TEXT_FONT` catches a missing library, and ARIALN catches the case neither can
    -- see — a path that exists and will not load. Named against the library's own catalog rather
    -- than spelled out, so a re-vendor that moves the payload moves this with it.
    local vendored = "Interface\\AddOns\\WhatGroup\\libs\\LibKa0s\\media\\fonts\\"
        .. "JetBrainsMono-Regular.ttf"
    local NS, _, mock = T.newAddon{ mock = function(m) m.fontFetchFails[vendored] = true end }
    assertEqual(NS.FONT_MONO, vendored, "the constant is unchanged — only what is HANDED OVER")
    assertEqual(consoleLogFont(NS, mock), "Fonts\\ARIALN.TTF",
        "a silent SetFont failure must not leave the console in a proportional font")
end)

test("debuglog: FormatPlain wraps the tag in brackets, single-space separators", function()
    local NS = T.newAddon()
    assertEqual(NS.DebugLog.FormatPlain("15:04:43", "Capture", "title=X"),
        "15:04:43 | [Capture] title=X")
end)

test("debuglog: FormatPlain tolerates a nil tag", function()
    local NS = T.newAddon()
    assertEqual(NS.DebugLog.FormatPlain("15:04:43", nil, "hi"), "15:04:43 | [] hi")
end)

test("debuglog: FormatColored colors timestamp + tag; pipe and content default", function()
    local NS = T.newAddon()
    assertEqual(NS.DebugLog.FormatColored("15:04:43", "Capture", "title=X"),
        "|cff6f8faf15:04:43|r || |cffc9a66b[Capture]|r title=X")
end)

test("debuglog: /wg debug on enables session state", function()
    local NS = T.newAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    assertTrue(NS.State.debug == true, "state should be on")
end)

test("debuglog: /wg debug off disables session state", function()
    local NS = T.newAddon()
    NS.State.debug = true
    debugCmd(NS, "off")
    assertTrue(NS.State.debug == false, "state should be off")
end)

test("debuglog: /wg debug (no arg) toggles the window, not the state", function()
    local NS = T.newAddon()
    NS.State.debug = true
    debugCmd(NS, "")
    assertTrue(NS.State.debug == true, "bare toggle must not change state")
    NS.State.debug = false
    debugCmd(NS, "")
    assertTrue(NS.State.debug == false, "bare toggle must not change state")
end)

test("debuglog: header toggle click flips debug state", function()
    local NS = T.newAddon()
    NS.State.debug = false
    NS.DebugLog:Show()
    local click = NS.DebugLog._toggleClickForTest
    assertTrue(type(click) == "function", "toggle click closure must be exposed")
    click(); assertTrue(NS.State.debug == true, "click should turn state on")
    click(); assertTrue(NS.State.debug == false, "second click should turn state off")
end)

test("debuglog: enabling writes a '[Debug] logging enabled' console line", function()
    local NS = T.newAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    -- The enable path appends the bracket line and THEN a [Init] state snapshot
    -- (debug-logging-§8), so assert containment rather than last-line.
    local found = false
    for _, line in ipairs(NS.DebugLog.buffer) do
        if line:find("[Debug] logging enabled", 1, true) then found = true end
    end
    assertTrue(found, "enabling should log '[Debug] logging enabled'")
end)

test("debuglog: enabling debug appends the [Init] session summary after the bracket (debug-logging-§5)", function()
    local NS = T.bootAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    local buf = NS.DebugLog.buffer
    local last = buf[#buf]
    assertTrue(last and last:find("[Init]", 1, true) ~= nil,
        "the on path must end with the [Init] summary, after the bracket line")
    -- Identity content: addon/version, schema, profile (debug-logging-§5).
    assertTrue(last:find("WhatGroup v", 1, true) ~= nil, "carries addon + version")
    assertTrue(last:find("schema v", 1, true) ~= nil, "carries schema version")
    assertTrue(last:find("profile 'Default'", 1, true) ~= nil, "carries active profile")
    -- Order: the bracket line comes immediately before the [Init] line.
    assertTrue(buf[#buf - 1]:find("[Debug] logging enabled", 1, true) ~= nil,
        "[Init] follows the enable bracket line")
end)

test("debuglog: [Init] fires only on enable, not on disable (debug-logging-§5)", function()
    local NS = T.bootAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    local afterOn = #NS.DebugLog.buffer
    debugCmd(NS, "off")
    for i = afterOn + 1, #NS.DebugLog.buffer do
        assertTrue(NS.DebugLog.buffer[i]:find("[Init]", 1, true) == nil,
            "disable must not emit an [Init] line")
    end
end)

test("debuglog: disabling still appends a '[Debug] logging disabled' line", function()
    local NS = T.newAddon()
    NS.State.debug = true
    local before = #NS.DebugLog.buffer
    debugCmd(NS, "off")
    assertTrue(#NS.DebugLog.buffer > before, "disabling should still append a console line")
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last and last:find("[Debug] logging disabled", 1, true) ~= nil,
        "disabling should log '[Debug] logging disabled'")
end)

test("debuglog: NS.Debug survives an unsafe format arg without raising (WG-22)", function()
    local NS = T.newAddon()
    NS.State.debug = true
    -- `%d` with a table raises in string.format in every Lua version, exactly
    -- as a combat-protected secret would; the sink must catch it and still land
    -- a line with "<secret>" instead of freezing the caller.
    local ok = pcall(function() NS.Debug("Capture", "n=%d", {}) end)
    assertTrue(ok, "NS.Debug must not propagate a format error")
    local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
    assertTrue(last and last:find("<secret>", 1, true) ~= nil,
        "the unsafe value degrades to <secret> in the logged line")
end)

test("debuglog: NS.Debug is a no-op (no console write) when debug is off", function()
    local NS = T.newAddon()
    NS.State.debug = false
    local before = #NS.DebugLog.buffer
    NS.Debug("Capture", "should not append")
    assertEqual(#NS.DebugLog.buffer, before)
end)

test("debuglog: debug-logging-§11 scrollbar + line-counter sync is a safe no-op under the mock", function()
    -- Anti-pattern #41 failure mode: the sync raises on first open (e.g. by
    -- calling the nil C getters GetNumLinesDisplayed / GetCurrentScroll). The
    -- mock's stub frame returns non-numbers from the scroll getters, so the
    -- guarded mixin path MUST no-op rather than throw. Building the frame (Show)
    -- and driving it via Add/Clear exercises every sync call site.
    local NS = T.newAddon()
    assertTrue(type(NS.DebugLog.UpdateScrollBar) == "function", "UpdateScrollBar must exist")
    assertTrue(type(NS.DebugLog.UpdateStatus) == "function", "UpdateStatus must exist")
    local ok = pcall(function()
        NS.DebugLog:Show()                -- builds the debug-logging-§11 scrollbar + status bar + initial sync
        NS.DebugLog:UpdateScrollBar()
        NS.DebugLog:UpdateStatus()
        NS.DebugLog:Add("Test", "a line")
        NS.DebugLog:Clear()
    end)
    assertTrue(ok, "the debug-logging-§11 sync path must not raise under the headless mock")
end)

-- ── message coverage / coalescing (debug-logging-§8, debug-logging-§9, debug-logging-§10) ────────────────

-- Count buffer lines containing a literal fragment (plain-text buffer, no colors).
local function countLines(NS, fragment)
    local n = 0
    for _, line in ipairs(NS.DebugLog.buffer) do
        if line:find(fragment, 1, true) then n = n + 1 end
    end
    return n
end

test("debuglog: settings change logs one [Set] line at the write seam (debug-logging-§10)", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    local before = countLines(NS, "[Set]")
    NS.addon.Settings.Helpers.Set("notify.delay", 3.0)
    assertEqual(countLines(NS, "[Set]") - before, 1, "exactly one [Set] line")
    assertTrue(countLines(NS, "notify.delay = 3") >= 1, "line shows path = value")
end)

-- Move two profile rows off their defaults, one number and one bool, so a reset has exactly two rows
-- whose stored value it changes. Every other row is still at its default and must not be counted.
local function dirtyTwoRows(NS)
    local H = NS.addon.Settings.Helpers
    H.Set("notify.delay", 3)
    H.Set("notify.showLeader", not H.Get("notify.showLeader"))
end

test("debuglog: RestoreAllDefaults logs one [Set] reset profile line counting the rows it changed (debug-logging-§10)", function()
    local NS = T.bootAddon()
    dirtyTwoRows(NS)
    NS.State.debug = true
    local setBefore = countLines(NS, "[Set]")
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(countLines(NS, "[Set]") - setBefore, 1, "one [Set] line for the whole reset, none per row")
    assertEqual(countLines(NS, "[Reset]"), 0, "the tag is [Set], never [Reset]")
    -- The reset is one db:ResetProfile() (options-ui-§12), which is wholesale replacement and not a
    -- write through the helper, so debug-logging-§10 has the OnProfileReset handler log it once. The
    -- count is included because it is cheap: RestoreAllDefaults compares each profile row with its
    -- default just before the reset, so N is the rows whose stored value the reset CHANGES, and a row
    -- already at its default is not counted. The reset also empties keys no schema row names (an
    -- orphan from a removed row). The line counts rows, and such a key is not one, so it is not in N.
    -- The sessionOnly row the function then restores by hand lives outside the db, and stays muted.
    assertEqual(countLines(NS, "[Set] reset profile 'Default' to defaults (2 rows)"), 1,
        "the line names the profile and the two rows it changed")
end)

test("debuglog: RestoreAllDefaults on a pristine profile counts 0 rows (debug-logging-§10)", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    local setBefore = countLines(NS, "[Set]")
    NS.addon.Settings.Helpers.RestoreAllDefaults()
    assertEqual(countLines(NS, "[Set]") - setBefore, 1, "still exactly one line")
    assertEqual(countLines(NS, "[Set] reset profile 'Default' to defaults (0 rows)"), 1,
        "every row was already at its default, so none is counted")
end)

test("debuglog: a profile reset from outside the helper is logged once, without a count (debug-logging-§10)", function()
    -- The line belongs to the profile-event handler, not to RestoreAllDefaults, so a reset driven
    -- straight at the db (AceDBOptions, a /run) is logged too, and only once. Nothing counted the
    -- changed rows before that reset, and debug-logging-§10 lets the line omit a count that is not cheap to know.
    local NS = T.bootAddon()
    dirtyTwoRows(NS)
    NS.State.debug = true
    local before = countLines(NS, "[Set]")
    NS.addon.db:ResetProfile()
    assertEqual(countLines(NS, "[Set]") - before, 1, "exactly one [Set] line")
    assertEqual(countLines(NS, "[Set] reset profile 'Default' to defaults"), 1, "and it is the reset line")
    assertEqual(countLines(NS, "to defaults ("), 0, "with no count it cannot vouch for")
end)

-- The descriptor's bulk bracket. Unreached in the live build: the host's RestoreAllDefaults
-- overrides the library's, and the Defaults button goes through the popup rather than the library's
-- per-page RestoreDefaults. It is wired anyway, so a future caller of either logs to debug-logging-§10.
test("debuglog: the library's page reset is one [Set] line counting the rows it changed (debug-logging-§10)", function()
    local NS = T.bootAddon()
    dirtyTwoRows(NS)
    NS.State.debug = true
    local H = NS.addon.Settings.Helpers
    local before = countLines(NS, "[Set]")
    H.RestoreDefaults("general")
    assertEqual(countLines(NS, "[Set]") - before, 1, "one line for the page, no per-row [Set]")
    -- The library walks every row of the page and its `count` says so. N is the host's own tally of
    -- the writes that changed a stored value: the two dirtied rows.
    assertEqual(countLines(NS, "[Set] reset general: 2 rows"), 1,
        "the line names the act, the page and the rows changed")
    H.Set("notify.delay", 2)
    assertEqual(countLines(NS, "[Set]") - before, 2, "the mute is released when the bracket closes")
end)

test("debuglog: an all-default page reset logs 0 rows, not a line per row (debug-logging-§10)", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    local before = countLines(NS, "[Set]")
    NS.addon.Settings.Helpers.RestoreDefaults("general")
    assertEqual(countLines(NS, "[Set]") - before, 1, "one line")
    assertEqual(countLines(NS, "[Set] reset general: 0 rows"), 1, "nothing changed, so N is 0")
end)

test("debuglog: the bulk bracket adds no line when the act reset the profile (debug-logging-§10)", function()
    -- info.profileReset means the OnProfileReset handler has logged the reset already, and debug-logging-§10 forbids
    -- a second line. The rows written inside the bracket stay muted, and the mute still lifts.
    local NS = T.bootAddon()
    NS.State.debug = true
    local H, Bulk = NS.addon.Settings.Helpers, NS.addon.Settings.Bulk
    local before = countLines(NS, "[Set]")
    Bulk.begin("reset", "all")
    H.Set("notify.delay", 2)
    Bulk.finish("reset", "all", 1, nil, { profileReset = true })
    assertEqual(countLines(NS, "[Set]") - before, 0, "muted inside, and no bulk line")
    H.Set("notify.delay", 3)
    assertEqual(countLines(NS, "[Set]") - before, 1, "the mute is released")
end)

test("debuglog: a nested bracket logs once, at the outermost close, with the summed tally (debug-logging-§10)", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    local H, Bulk = NS.addon.Settings.Helpers, NS.addon.Settings.Bulk
    local before = countLines(NS, "[Set]")
    Bulk.begin("reset", "general")
    H.Set("notify.delay", 2)
    Bulk.begin("reset", "inner")
    H.Set("notify.showLeader", not H.Get("notify.showLeader"))
    H.Set("notify.delay", 2)                            -- no change: not counted
    Bulk.finish("reset", "inner", 2, nil, { profileReset = false })
    assertEqual(countLines(NS, "[Set]") - before, 0, "the inner close logs nothing")
    Bulk.finish("reset", "general", 1, nil, { profileReset = false })
    assertEqual(countLines(NS, "[Set]") - before, 1, "one line, at the outermost close")
    assertEqual(countLines(NS, "[Set] reset general: 2 rows"), 1, "named by the outer act, tallies summed")
end)

test("debuglog: a nested bracket that reset the profile silences the outer line (debug-logging-§10)", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    local Bulk = NS.addon.Settings.Bulk
    local before = countLines(NS, "[Set]")
    Bulk.begin("reset", "general")
    Bulk.begin("reset", "all")
    Bulk.finish("reset", "all", 0, nil, { profileReset = true })
    Bulk.finish("reset", "general", 0, nil, { profileReset = false })
    assertEqual(countLines(NS, "[Set]") - before, 0, "the profile handler's line is the only one")
end)

test("debuglog: a bracket that closes on an error still logs its tally and unmutes (debug-logging-§10)", function()
    -- The library calls bulkEnd once even when a row raised, then re-raises. The host logs the rows
    -- changed so far, and a mute that stuck would silence every later write.
    local NS = T.bootAddon()
    NS.State.debug = true
    local H, Bulk = NS.addon.Settings.Helpers, NS.addon.Settings.Bulk
    local before = countLines(NS, "[Set]")
    Bulk.begin("reset", "general")
    H.Set("notify.delay", 2)
    Bulk.finish("reset", "general", 1, "boom", { profileReset = false })
    assertEqual(countLines(NS, "[Set] reset general: 1 rows (stopped by an error)"), 1,
        "the rows changed before the error, and the line says the act did not finish")
    H.Set("notify.delay", 3)
    assertEqual(countLines(NS, "[Set]") - before, 2, "the mute is released")
end)

-- A row whose write raises. The debug-console row is the one row whose storage is a set() the test
-- can reach, so the raise comes out of the real seam's store rather than a stub of the seam under test.
local function raisingConsoleRow(NS)
    NS.DebugLog.ConsoleCheckbox = function()
        return { get = function() return false end, set = function() error("boom", 0) end }
    end
end

test("debuglog: a write that raises inside a bracket is not counted (debug-logging-§10)", function()
    -- The tally is the rows whose stored value CHANGED. A write that raised changed nothing, so it
    -- must not reach N, even though the row was off its new value when the write began.
    local NS = T.bootAddon()
    NS.State.debug = true
    local H, Bulk = NS.addon.Settings.Helpers, NS.addon.Settings.Bulk
    raisingConsoleRow(NS)
    local before = countLines(NS, "[Set]")
    Bulk.begin("reset", "general")
    local ok, err = pcall(H.Set, "state.debugConsole", true)
    Bulk.finish("reset", "general", 1, err, { profileReset = false })
    assertTrue(not ok, "the write raised")
    assertEqual(countLines(NS, "[Set]") - before, 1, "one line for the act")
    assertEqual(countLines(NS, "[Set] reset general: 0 rows (stopped by an error)"), 1,
        "the raising write is not in N, and the line carries the failure marker")
end)

test("debuglog: a profile reset that raises logs one marked line and re-raises (debug-logging-§10)", function()
    -- The error came before AceDB fired OnProfileReset, so the handler never logged. The reset path
    -- logs the act's one line itself, marked, with no count: nothing says how many rows it changed.
    local NS = T.bootAddon()
    dirtyTwoRows(NS)
    NS.State.debug = true
    local db = NS.addon.db
    local real = db.ResetProfile
    db.ResetProfile = function() error("boom", 0) end
    local before = countLines(NS, "[Set]")
    local ok, err = pcall(NS.addon.Settings.Helpers.RestoreAllDefaults)
    db.ResetProfile = real
    assertTrue(not ok, "the error is re-raised")
    assertEqual(err, "boom", "unchanged")
    assertEqual(countLines(NS, "[Set]") - before, 1, "exactly one line")
    assertEqual(countLines(NS, "[Set] reset profile 'Default' to defaults (stopped by an error)"), 1,
        "the reset line, marked, without a count")
end)

test("debuglog: a profile reset that raises leaves no count for a later reset (debug-logging-§10)", function()
    -- RestoreAllDefaults counts before it resets. If the reset raises, that count must not survive
    -- for some later, unrelated reset to claim: the later reset below changed no row it counted.
    local NS = T.bootAddon()
    dirtyTwoRows(NS)
    local db = NS.addon.db
    local real = db.ResetProfile
    db.ResetProfile = function() error("boom", 0) end
    pcall(NS.addon.Settings.Helpers.RestoreAllDefaults)
    db.ResetProfile = real
    NS.State.debug = true
    local before = countLines(NS, "[Set]")
    db:ResetProfile()
    assertEqual(countLines(NS, "[Set]") - before, 1, "one line for the foreign reset")
    assertEqual(countLines(NS, "rows)"), 0, "and it carries no count")
end)

test("debuglog: a profile reset inside an open bracket silences the bracket (debug-logging-§10)", function()
    -- The profile-event handler's line stands for the whole act. Without the silence the bracket's
    -- close would add a second line for the same act.
    local NS = T.bootAddon()
    NS.State.debug = true
    local H, Bulk = NS.addon.Settings.Helpers, NS.addon.Settings.Bulk
    local before = countLines(NS, "[Set]")
    Bulk.begin("reset", "general")
    H.Set("notify.delay", 3)
    NS.addon.db:ResetProfile()
    Bulk.finish("reset", "general", 1, nil, { profileReset = false })
    assertEqual(countLines(NS, "[Set]") - before, 1, "one line")
    assertEqual(countLines(NS, "[Set] reset profile 'Default' to defaults"), 1, "the handler's")
    assertEqual(countLines(NS, "[Set] reset general"), 0, "and no bracket line")
end)

test("debuglog: a profile copy logs one [Set] copied line naming the source (debug-logging-§10)", function()
    -- Real AceDB fires OnProfileCopied(event, db, sourceProfileKey), so the handler is called with
    -- exactly that. Through kit revision 17 the AceDB mock passed the CURRENT profile key there,
    -- the destination; since revision 18 it passes the source, as AceDB does.
    local NS = T.bootAddon()
    NS.State.debug = true
    local before = countLines(NS, "[Set]")
    NS.addon:OnProfileCopied("OnProfileCopied", NS.addon.db, "Alt")
    assertEqual(countLines(NS, "[Set]") - before, 1, "one line")
    assertEqual(countLines(NS, "[Set] copied profile 'Alt' \226\134\146 'Default'"), 1,
        "worded by the event: source, then the active profile it landed in")
end)

test("debuglog: InitSummary leads with the debug-logging-§5 identity fields, then runtime state", function()
    local NS = T.bootAddon()
    local s = NS.addon:InitSummary()
    -- Standard-mandated identity prefix (name/version/schema/profile) comes first.
    assertEqual(s:sub(1, #("WhatGroup v" .. NS.addon.VERSION .. ", schema v1, profile 'Default'")),
        "WhatGroup v" .. NS.addon.VERSION .. ", schema v1, profile 'Default'")
    -- Runtime state appended on the same one line.
    for _, frag in ipairs({ "enabled=true", "notify.delay=0s", "autoShow=true",
                            "inGroup=false", "hasPending=false" }) do
        assertTrue(s:find(frag, 1, true) ~= nil, "summary carries " .. frag)
    end
end)

test("debuglog: enable ack is color-coded green/red matching the header (debug-logging-§5)", function()
    -- The chat ack routes through NS.Print (prefixed). Assert the state word
    -- carries the mandated color codes: ON 40ff40, OFF ff4040.
    local NS, _, mock = T.newAddon()
    NS.State.debug = false
    debugCmd(NS, "on")
    local onAck = mock.prints[#mock.prints]
    assertTrue(onAck:find("|cff40ff40ON|r", 1, true) ~= nil, "ON ack is green 40ff40")
    debugCmd(NS, "off")
    local offAck = mock.prints[#mock.prints]
    assertTrue(offAck:find("|cffff4040OFF|r", 1, true) ~= nil, "OFF ack is red ff4040")
end)

-- ── call-site wording pins (debug-logging-§4) ───────────────────────────────
--
-- Each case below pins one NS.Debug call site's WHOLE rendered line, byte for byte. The sites used
-- to build the message before the call (`"appID=" .. tostring(appID)`), which debug-logging-§4
-- forbids: it allocates on every event with the console off, and the values skip the sink's
-- safeToString. They now pass a format and the raw values. These went green on the old wording
-- first, so a rewrite that changes one character of a line turns its case red.
--
-- `logged` compares against the part of a buffer line after the timestamp, so a pin is the tag in
-- brackets plus the message, exactly as the console shows it.
local ARROW = "\226\134\146"

local function logged(NS, expected)
    for _, line in ipairs(NS.DebugLog.buffer) do
        if line:match("^%d%d:%d%d:%d%d | (.*)$") == expected then return true end
    end
    return false
end

local function assertLogged(NS, expected)
    local tail = {}
    local buf = NS.DebugLog.buffer
    for i = math.max(1, #buf - 5), #buf do tail[#tail + 1] = buf[i] end
    assertTrue(logged(NS, expected),
        "expected the line '" .. expected .. "'; the buffer ends with:\n  " .. table.concat(tail, "\n  "))
end

-- A search result shaped like tests/test_capture.lua's, so the Apply and Invite lines have a
-- capture to name.
local function searchResult(name, activityID)
    return {
        name = name, leaderName = "L", numMembers = 3, voiceChat = "",
        generalPlaystyle = 0, playstyleString = "", age = 0, activityIDs = { activityID },
    }
end

local function pendingCapture(overrides)
    local i = {
        title = "Stonevault Speedrun", leaderName = "Testadin-Silvermoon", numMembers = 3,
        voiceChat = "", age = 0, activityIDs = { 2516 }, activityID = 2516,
        fullName = "Dungeons > Mythic+ > The Stonevault", activityName = "The Stonevault",
        maxNumPlayers = 5, isMythicPlus = true, isCurrentRaid = false, isHeroicRaid = false,
        categoryID = 1, mapID = 2652, generalPlaystyle = 3, playstyleString = "", shortName = "",
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

test("debuglog: pin — a vanished search result logs the [Capture] nil line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon:CaptureGroupInfo(42)
    assertLogged(NS, "[Capture] GetSearchResultInfo returned nil for id=42")
end)

test("debuglog: pin — an apply logs the [Apply] captured line", function()
    local NS, _, mock = T.bootAddon()
    NS.State.debug = true
    mock.searchResults[100] = searchResult("Queued", 500)
    mock.activities[500] = { fullName = "Q", mapID = 111 }
    NS.addon:OnApplyToGroup(100)
    assertLogged(NS, '[Apply] id=100 captured "Queued" (activity=500 map=111 m+=false)')
end)

test("debuglog: pin — every application status logs the [LFG] appID/status line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")
    assertLogged(NS, "[LFG] appID=100 status=applied")
end)

test("debuglog: pin — an accepted invite with a capture logs the [Invite] line naming it", function()
    local NS, _, mock = T.bootAddon()
    NS.State.debug = true
    mock.searchResults[100] = searchResult("Queued", 500)
    mock.activities[500] = { fullName = "Q", mapID = 111 }
    NS.addon:OnApplyToGroup(100)
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")
    mock.searchResults[100] = searchResult("Fresh", 501)
    mock.activities[501] = { fullName = "F", mapID = 222 }
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")
    assertLogged(NS, '[Invite] accepted appID=100 ' .. ARROW .. ' "Fresh" map=222 (source=fresh)')
end)

test("debuglog: pin — an accepted invite with no capture logs the [Invite] no-capture line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")
    assertLogged(NS, "[Invite] accepted appID=100 " .. ARROW .. " no capture")
end)

test("debuglog: pin — a roster transition logs the [Roster] line", function()
    local NS, _, mock = T.bootAddon()
    NS.State.debug = true
    mock.inGroup = true
    NS.addon:GROUP_ROSTER_UPDATE()
    assertLogged(NS, "[Roster] inGroup=true wasInGroup=false hasPending=false")
end)

test("debuglog: pin — the details link logs the [ChatLink] click line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon:OnSetItemRef()
    assertLogged(NS, "[ChatLink] clicked hasPending=false")
end)

test("debuglog: pin — an accepted invite with nothing pending logs the [Notify] skip line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon:_TryFireJoinNotify("inviteaccepted")
    assertLogged(NS, "[Notify] skip: no pendingInfo (inviteaccepted)")
end)

test("debuglog: pin — a scheduled join notify logs the [Notify] scheduling line", function()
    local NS, _, mock = T.bootAddon()
    NS.State.debug = true
    NS.addon.Settings.Helpers.Set("notify.delay", 2.5)
    mock.inGroup = true
    NS.addon.pendingInfo = pendingCapture()
    NS.addon:_TryFireJoinNotify("inviteaccepted")
    assertLogged(NS, "[Notify] scheduling in 2.5s (inviteaccepted)")
end)

test("debuglog: pin — a wipe with a reason and something in flight logs the [Capture] wiped line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon.pendingInfo = pendingCapture()
    NS.addon:WipeCapture("master switch off")
    assertLogged(NS, "[Capture] wiped (master switch off)")
end)

test("debuglog: pin — /wg test notify logs the [Test] injection line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon:RunTest()
    assertLogged(NS, '[Test] synthetic capture injected "' .. NS.addon:SampleInfo().title .. '"')
end)

test("debuglog: pin — showing a capture logs the [Frame] popup-shown and teleport lines", function()
    local NS, _, mock = T.bootAddon()
    NS.State.debug = true
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pendingCapture()
    NS.addon:ShowFrame()
    assertLogged(NS, '[Frame] popup shown "Stonevault Speedrun" map=2652')
    assertLogged(NS, "[Frame] teleport spellID=445269 known=true (activity=2516 map=2652)")
end)

test("debuglog: pin — showing with no capture logs the [Frame] fallback and nil teleport lines", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon:ShowFrame()
    assertLogged(NS, "[Frame] popup shown (no pendingInfo " .. ARROW .. " 'No data' fallbacks)")
    assertLogged(NS, "[Frame] teleport spellID=nil known=nil (activity=nil map=nil)")
end)

test("debuglog: pin — a show the visibility gate withholds logs the [Frame] not-shown line", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon:ShowFrame()
    assertLogged(NS, "[Frame] popup built but not shown: visibility = inCombat")
end)

test("debuglog: pin — unticking test mode logs the [Test] off line with its reason", function()
    local NS = T.bootAddon()
    NS.State.debug = true
    NS.addon.Settings.Helpers.Set("state.testMode", true)
    NS.addon.Settings.Helpers.Set("state.testMode", false)
    assertLogged(NS, "[Test] test mode off (unticked)")
end)
