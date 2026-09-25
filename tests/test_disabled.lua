-- tests/test_disabled.lua — the stand-down conformance suite (slash-commands-§7 MUST).
--
-- WHAT THIS SUITE IS FOR, AND WHAT IT REFUSES TO BE.
--
-- Eleven addons in this collection implemented "disabled" as a DRAW GATE: the frames go away, the
-- registrations stay, and the client goes on walking the addon's registration list on every event
-- it registered for, building the argument frame, entering Lua and running the comparison that
-- decides to leave. WhatGroup was one of them -- two reads of `db.profile.enabled`, at
-- OnApplyToGroup and at the `inviteaccepted` arm, and four events that never went anywhere.
--
-- From the outside a draw gate is INDISTINGUISHABLE from an addon that genuinely stood down, which
-- is how the shape survived eleven audits. A suite written against a handler's early return cannot
-- tell the two apart, because an early return is exactly what a draw gate does: such a suite
-- CERTIFIES the thing it exists to catch. So every assertion below is on the REGISTRATION SET, the
-- LIVE TIMER SET, the SHOWN-FRAME SET, the SavedVariables diff and the printed lines -- the kit's
-- five recording surfaces (tests/_kit/mock_record.lua) -- and never on what a function returned.
--
-- `__fire` ON A FRAME REACHES ITS OnEvent WHETHER OR NOT IT EVER REGISTERED, so a case that only
-- fires an event can pass against broken code. Step 6 fires at the LIVE set (nothing, if the
-- stand-down worked) and then fires UNCONDITIONALLY at the handlers anyway, which is what proves a
-- survivor would have been caught rather than that the harness went quiet.
--
-- Step 7 is the slash surface and IT IS NOT THE STAND-DOWN. Steps 1-6 and 10 are. A green step 7
-- says nothing whatsoever about whether this addon is inert.

local T = _G.WHATGROUP_TEST
local test         = T.test
local assertEqual  = T.assertEqual
local assertTrue   = T.assertTrue
local assertFalse  = T.assertFalse
local assertNil    = T.assertNil

local NAME = "WhatGroup"

-- ---------------------------------------------------------------------------
-- Surveys — every one reads THROUGH the mock, never through the addon
-- ---------------------------------------------------------------------------

--- The registration set as a sorted array of stable keys, so two snapshots compare as text rather
--- than as two tables of frame references in somebody else's hash order.
local function regKeys(mock)
    local out = {}
    for _, r in ipairs(mock.__registrations()) do
        out[#out + 1] = ("%s|%s|%s|%s"):format(
            tostring(r.target == nil and "?" or (r.target.__seq or tostring(r.target))),
            r.kind, r.event, tostring(r.unit))
    end
    table.sort(out)
    return out
end

--- RAW `frame:RegisterEvent` REGISTRATIONS, surveyed out of this repo's own frame stub.
---
--- The kit's `__registrations()` walks the frames the KIT built, and tests/wow_mock.lua builds its
--- own richer stub for this addon (protection, anchors, attributes), so the kit's survey cannot see
--- them. The stub records on `RegisterEvent` and REMOVES on `UnregisterEvent` /
--- `UnregisterAllEvents` (tests/wow_mock.lua), which is the half that makes the assertion
--- falsifiable in the useful direction: a registry that only ever grew would report a perfectly
--- torn-down addon as still watching everything.
---
--- modules/Frame.lua makes NONE since its two combat-end replays moved onto a queue the addon's own
--- AceEvent PLAYER_REGEN_ENABLED handler drains (WHATGROUP-A-08). The survey stays as the regression
--- guard: a raw registration brought back would be invisible to an AceEvent-only survey.
local function rawRegs(mock)
    local out = {}
    for _, f in ipairs(mock.frames) do
        for event in pairs(f.__events or {}) do
            out[#out + 1] = "frame:" .. event .. "@" .. tostring(f.__name or f.__kind)
        end
    end
    table.sort(out)
    return out
end

--- THE WHOLE REGISTRATION SET: AceEvent, message and bucket registrations and the EventRegistry
--- callbacks from the kit's survey, plus this repo's raw frame registrations. Nothing here is a
--- handler return value.
---
--- The chat link's click route is an `EventRegistry:RegisterCallback("SetItemRef", …, owner)`. It
--- has a real unregister, so slash-commands-§7's hooksecurefunc carve-out does not cover it: a
--- stood-down addon must hold no callback there. The kit's registry (revision 26) reports each
--- live owner as a `{ kind = "callback", event, owner }` row, so it reads `callback:SetItemRef`
--- here, once per owner: a callback that stacked a second owner would show up twice.
local function regNames(mock)
    local out = {}
    for _, r in ipairs(mock.__registrations()) do out[#out + 1] = r.kind .. ":" .. r.event end
    for _, r in ipairs(rawRegs(mock)) do out[#out + 1] = r end
    table.sort(out)
    return out
end

local function joined(list) return table.concat(list, ", ") end

--- ON SCREEN, for the frames this addon actually puts there. The stub starts every frame `__shown`
--- (the client's own default for a freshly created frame), so "every shown frame" would sweep in
--- tooltips and widget scaffolding nothing ever displayed. What is asked instead is the honest
--- question: is the popup, or its ESC proxy, visible to the player. A popup soft-hidden at alpha 0
--- in combat is still `IsShown()` and still invisible, so both halves are read.
local function visibleFrames(mock)
    local out = {}
    for _, name in ipairs({ "WhatGroupFrame", "WhatGroupFrameEscape" }) do
        local f = mock.frames[name]
        if f and f:IsShown() and f:GetAlpha() > 0 then out[#out + 1] = f end
    end
    return out
end

--- Bring the addon up ENABLED and doing something: a capture waiting, the popup on screen through
--- test mode, and the launcher registered. An addon asleep at the baseline would pass every later
--- assertion trivially, which step 1 exists to forbid.
local function up()
    local NS, _, mock = T.enableAddon()
    return NS, mock
end

local function helpers(NS) return NS.addon.Settings.Helpers end

--- Disable through THE SINGLE WRITE SEAM -- the route the checkbox and the verb both take -- and
--- never by calling NS.StandDown directly. A test that called the teardown by hand would pass over
--- an addon whose checkbox was wired to nothing at all.
local function switchOff(NS) helpers(NS).Set("enabled", false) end
local function switchOn(NS)  helpers(NS).Set("enabled", true)  end

-- ---------------------------------------------------------------------------
-- 1. Baseline
-- ---------------------------------------------------------------------------

test("disabled 1: enabled, the addon holds a NON-EMPTY registration set", function()
    -- The premise of every assertion after this one. An addon that registers nothing when it is
    -- running would satisfy "registers nothing when it is off" for free.
    local _, mock = up()
    local R_on = regNames(mock)
    assertTrue(#R_on > 0, "the enabled addon watches something: " .. joined(R_on))
    assertEqual(joined(R_on),
        "callback:SetItemRef, event:GROUP_ROSTER_UPDATE, event:LFG_LIST_APPLICATION_STATUS_UPDATED, "
        .. "event:PLAYER_REGEN_DISABLED, event:PLAYER_REGEN_ENABLED",
        "and these four events plus the chat-link callback are what it watches")
end)

-- ---------------------------------------------------------------------------
-- 2 + 3. Disable through the seam; the registration set is EMPTY
-- ---------------------------------------------------------------------------

test("disabled 3: the registration set is EMPTY, by count and by name", function()
    -- THE ASSERTION THE WHOLE SUITE EXISTS FOR, and the one that reddens a draw gate. It is
    -- deliberately not "call a handler and assert it returned early" -- that is the draw gate
    -- passing its own test.
    -- red under: drop the four UnregisterEvent calls in core/WhatGroup.lua's NS.StandDown; the
    -- addon still ignores every event and this case still fails, which is the point.
    -- red under: dropping the EventRegistry:UnregisterCallback in NS.StandDown
    local NS, mock = up()
    switchOff(NS)
    local R_off = regNames(mock)
    assertEqual(#R_off, 0, "still watching: " .. joined(R_off))
end)

test("disabled 3: the write seam is the route — the checkbox and the verb reach the same latch",
function()
    -- Three surfaces over ONE value (slash-commands-§2's no-second-switch rule): the Master
    -- controls checkbox writes through Helpers.Set, `/wg disable` writes through Helpers.Set, and
    -- both land on the latch's `disabled` hold. Pinned here because the suite's own `switchOff`
    -- uses the first, and a reader is entitled to know the second is not a different mechanism.
    -- red under: wiring the verb to db.profile.enabled directly, or to a second teardown path.
    local NS, mock = up()
    NS.addon:OnSlashCommand("disable")
    assertEqual(#regNames(mock), 0, "the verb stands the addon down too")
    assertTrue(NS.Lifecycle:IsHeld(NS.HOLD_DISABLED), "through the same named hold")
end)

test("disabled: no raw frame registration exists at any point, in combat or out", function()
    -- Both combat-end replays in modules/Frame.lua -- the first show deferred past combat and the
    -- teleport configure deferred past combat -- wait in its combat-end queue, which the addon's own
    -- AceEvent PLAYER_REGEN_ENABLED handler drains. Nothing is left for a private frame to watch, so
    -- the raw survey reads empty enabled, mid-defer and after; it stays as the regression guard.
    -- red under: a frame:RegisterEvent in modules/Frame.lua
    local NS, mock = up()
    assertEqual(joined(rawRegs(mock)), "", "enabled, out of combat")
    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "L", fullName = "F",
                             shortName = "", playstyleString = "", generalPlaystyle = 0 }
    mock.combat = true
    NS.addon:ShowFrame()          -- never built: the first show is deferred
    assertEqual(joined(rawRegs(mock)), "", "a combat first-show defer")
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(mock.frames["WhatGroupFrame"]:IsShown(), "the deferred show landed")
    mock.combat = true
    NS.addon:ShowFrame()          -- shown, so the fields refill and the teleport configure defers
    assertEqual(joined(rawRegs(mock)), "", "a combat teleport defer")
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(joined(rawRegs(mock)), "", "after combat")
end)

-- ---------------------------------------------------------------------------
-- 4. Nothing is left armed
-- ---------------------------------------------------------------------------

test("disabled 4: no timer, ticker or OnUpdate survives, and none is armed afterwards", function()
    -- The notify timer is the one this addon can actually leave running: a join schedules it on
    -- `notify.delay`, and a coalescing timer that wakes up to find nothing to paint is the single
    -- most expensive shape slash-commands-§7 exists to kill.
    -- red under: drop the WipeCapture call from NS.StandDown -- the AceTimer handle stays armed and
    -- mock.__timers() still answers non-empty.
    local NS, mock = up()
    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "Testadin",
                             fullName = "The Stonevault", shortName = "", playstyleString = "",
                             generalPlaystyle = 0 }
    helpers(NS).Set("notify.delay", 8)
    mock.inGroup = true
    NS.addon:_TryFireJoinNotify("inviteaccepted")
    assertTrue(#mock.__timers() > 0, "a notify timer is armed while the addon is running")

    switchOff(NS)
    assertEqual(#mock.__timers(), 0, "nothing is still going to wake up")

    -- And nothing re-arms for the rest of the run: fire everything the enabled addon watched.
    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "LFG_LIST_APPLICATION_STATUS_UPDATED",
                             "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        mock.__fire(event)
    end
    assertEqual(#mock.__timers(), 0, "and none was armed by anything that arrived afterwards")
end)

-- ---------------------------------------------------------------------------
-- 5. Every frame that was shown is hidden
-- ---------------------------------------------------------------------------

test("disabled 5: every frame shown while enabled is hidden, and the show ladder answers no",
function()
    -- BOTH HALVES. Hiding imperatively is not enough and never was: hidden frames come back, and a
    -- combat transition or a settings change re-shows the popup behind the switch's back. So the
    -- gate is at the SOURCE (modules/Frame.lua's visibilityAllows) and the second half of this case
    -- proves it by asking the addon to show the popup again after the switch is off.
    -- red under: delete the NS.IsStoodDown rung from visibilityAllows; the first half still passes
    -- on the imperative hide and the second half reddens.
    local NS, mock = up()
    NS.addon:OnSlashCommand("test on")
    local F_on = visibleFrames(mock)
    assertEqual(#F_on, 2, "the popup AND its ESC proxy are on screen while the addon is running")

    switchOff(NS)
    assertEqual(#visibleFrames(mock), 0, "every one of them is off screen")

    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "L", fullName = "F",
                             shortName = "", playstyleString = "", generalPlaystyle = 0 }
    -- EACH ROUTE TO THE SCREEN, CHECKED ON ITS OWN. Checked together they mask each other: a
    -- toggle after a show closes what the show opened, and the pair then passes over an addon whose
    -- ladder has no stand-down rung at all.
    NS.addon:ShowFrame()
    assertEqual(#visibleFrames(mock), 0, "ShowFrame did not bring it back")
    NS.addon:ApplyFrameVisibility(false)
    assertEqual(#visibleFrames(mock), 0, "nor did a combat edge")
    NS.addon:ToggleFrame()
    assertEqual(#visibleFrames(mock), 0, "nor did the launcher's toggle seam")
    NS.addon:OnSlashCommand("test on")
    assertEqual(#visibleFrames(mock), 0, "nor did test mode")
end)

-- ---------------------------------------------------------------------------
-- 6. Fire everything anyway: no write, no line, no frame
-- ---------------------------------------------------------------------------

test("disabled 6: firing every event it used to watch writes nothing, says nothing, shows nothing",
function()
    -- THE FALSIFICATION STEP. `__fire` walks the LIVE set, which is empty if the stand-down worked,
    -- so on its own "nothing happened" would be a claim about the harness. `__fireUnconditional`
    -- reaches the handler methods anyway -- they are still on the addon table, which is precisely
    -- the survivor this is here to catch -- and a draw gate that merely early-returns is measured
    -- by whether it wrote, printed or drew.
    --
    -- The combat-entry event is named explicitly, because that is the one an addon in this
    -- collection used to answer with a SavedVariables write and a chat line WHILE DISABLED, and the
    -- player's evidence that the addon is off is the absence of exactly that line.
    -- red under: drop the NS.IsStoodDown gate from OnApplyToGroup -- the hook is a hooksecurefunc
    -- and cannot be unregistered, so the gate IS the stand-down there and this case is its test.
    local NS, mock = up()
    switchOff(NS)

    mock.__resetSvWrites()
    local marked = #mock.prints
    local shownBefore = #visibleFrames(mock)

    mock.searchResults[100] = { name = "Bait", leaderName = "L", numMembers = 1,
                                activityIDs = { 500 } }
    mock.activities[500] = { fullName = "F", mapID = 111 }

    for _, event in ipairs({ "GROUP_ROSTER_UPDATE", "LFG_LIST_APPLICATION_STATUS_UPDATED",
                             "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        assertEqual(mock.__fire(event), 0, event .. " reached nobody")
    end

    -- Now reach the handlers the client can no longer reach, and the two one-way hooks with them.
    mock.__fireUnconditional(NS.addon, "GROUP_ROSTER_UPDATE", "GROUP_ROSTER_UPDATE")
    mock.__fireUnconditional(NS.addon, "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_DISABLED")
    mock.__fireUnconditional(NS.addon, "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_ENABLED")
    NS.addon:OnApplyToGroup(100)
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "applied")
    NS.addon:LFG_LIST_APPLICATION_STATUS_UPDATED("evt", 100, "inviteaccepted")

    local writes = mock.__svWrites()
    local paths = {}
    for _, w in ipairs(writes) do paths[#paths + 1] = w.path end
    assertEqual(#writes, 0, "zero SavedVariables writes, got: " .. joined(paths))
    assertEqual(#mock.prints - marked, 0, "zero printed lines")
    assertEqual(#visibleFrames(mock), shownBefore, "zero frames shown")
    assertNil(NS.addon.pendingInfo, "and nothing was captured")
end)

-- ---------------------------------------------------------------------------
-- 7. The slash surface — NOT the stand-down (slash-commands-§7, v2.57.0)
-- ---------------------------------------------------------------------------

test("disabled 7: every reserved verb answers normally, and the bare /wg opens the panel", function()
    -- THE REVERSAL, PINNED. The standard narrowed this surface to `enable` and `help` at v2.56.0
    -- and reversed it at v2.57.0: `/wg` on a disabled addon answering with a refusal instead of
    -- opening the panel is a rule that hides the off switch. So the whole reserved set is live, and
    -- the case that settled it -- the bare verb -- is the last assertion here.
    -- red under: passing a narrowed `liveVerbs` to lib:New in settings/Slash.lua.
    local NS, mock = up()
    switchOff(NS)
    local H = helpers(NS)

    local function lines(input)
        local mark = #mock.prints
        NS.addon:OnSlashCommand(input)
        local out = {}
        for i = mark + 1, #mock.prints do out[#out + 1] = mock.prints[i] end
        return out
    end
    local function anyLine(ls, needle)
        for _, l in ipairs(ls) do if l:find(needle, 1, true) then return true end end
        return false
    end
    local REFUSAL = "WhatGroup is disabled"

    assertTrue(anyLine(lines("version"), "v" .. NS.addon.VERSION), "version prints")
    assertTrue(#lines("list") > 1, "list reads the schema")
    assertTrue(anyLine(lines("get notify.delay"), "notify.delay"), "get reads a setting")
    lines("set notify.delay 7")
    assertEqual(H.Get("notify.delay"), 7, "set REPAIRS a setting while the addon is off")
    lines("reset notify.delay")
    assertEqual(H.Get("notify.delay"), NS.C.notify.delay, "reset restores its default")
    assertFalse(anyLine(lines("debug on"), REFUSAL), "debug is a diagnostic, not a feature")
    NS.addon:OnSlashCommand("debug off")

    -- `help` prints the index IN FULL -- the player has to be able to SEE `enable` in it -- with
    -- the one line under the header as a statement about the index rather than a refusal of help.
    local help = lines("help")
    assertTrue(#help > #NS.addon.COMMANDS, "the whole index prints")
    assertTrue(anyLine(help, "enable"), "including the way back")

    -- A TYPO is not a refusal: the addon genuinely did not understand, so it says so.
    assertTrue(anyLine(lines("wibble"), "unknown command"), "a misspelling is answered as one")

    -- A RESERVED VERB THIS ADDON NEVER REGISTERED answers the same in both states (Slash 14).
    -- `perf` is reserved collection-wide but registered when wired, and WhatGroup declines the
    -- Perf major, so `perf` is simply not one of its commands -- there is nothing here for the
    -- stand-down to refuse. Slash 13 answered it with the refusal line while off and `unknown
    -- command` while on, which made the disabled state look like it had swallowed a command the
    -- addon never had; this addon was one of the five that reported it.
    -- red under: restoring the `isDown and liveVerbs[cmd]` refusal branch in libs/LibKa0s/Slash.lua.
    assertTrue(anyLine(lines("perf"), "unknown command"),
        "an unregistered reserved verb is answered as unknown, not as refused")
    assertTrue(#lines("perf") > #NS.addon.COMMANDS,
        "and the whole index prints with it, never a lone refusal line")

    -- THE CASE THAT SETTLED THE REVERSAL.
    local opened = #mock.openedTo
    NS.addon:OnSlashCommand("")
    assertTrue(#mock.openedTo > opened, "the bare /wg opens the settings panel")
    NS.addon:OnSlashCommand("config")
    assertTrue(#mock.openedTo > opened + 1, "and so does `config`")
end)

test("disabled 7: each FEATURE verb answers exactly one refusal line and reaches no write seam",
function()
    -- This addon TAKES slash-commands-§2's SHOULD, and there are two verbs in scope: `show` and `test`, the two
    -- that put the popup on screen. Pinned so the choice cannot drift silently -- an addon that
    -- declined the SHOULD would assert the opposite here, and either is conformant.
    --
    -- LOCK AND UNLOCK ARE NOT AMONG THEM. slash-commands-§8 is a MAY; this addon has lock
    -- functionality as a CHECKBOX ONLY and registers no verbs for it, which the section names
    -- explicitly as the case the MAY exists to leave alone. Declining a MAY owes no deviation row.
    -- red under: letting `show` fall through to ShowFrame, or printing a second explanatory line.
    local NS, mock = up()
    switchOff(NS)
    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "L", fullName = "F",
                             shortName = "", playstyleString = "", generalPlaystyle = 0 }
    mock.__resetSvWrites()

    for _, verb in ipairs({ "show", "test on", "test notify" }) do
        local mark = #mock.prints
        NS.addon:OnSlashCommand(verb)
        assertEqual(#mock.prints - mark, 1, verb .. " answers on exactly one line")
        assertTrue(mock.prints[#mock.prints]:find("WhatGroup is disabled", 1, true) ~= nil,
            verb .. " says the addon is standing down")
        assertTrue(mock.prints[#mock.prints]:find("/wg enable", 1, true) ~= nil,
            verb .. " names the verb that undoes the state")
    end
    assertEqual(#mock.__svWrites(), 0, "and no refusal reached a write seam")
    assertFalse(helpers(NS).Get("state.testMode"), "test mode never started")

    -- lock/unlock: reserved collection-wide, registered by nobody here.
    for _, entry in ipairs(NS.addon.COMMANDS) do
        assertTrue(entry[1] ~= "lock" and entry[1] ~= "unlock",
            "this addon's lock is a checkbox, not a verb (slash-commands-§8 MAY)")
    end
end)

-- ---------------------------------------------------------------------------
-- 8. The launcher (launcher-§2, slash-commands-§7)
-- ---------------------------------------------------------------------------

test("disabled 8: left-click opens the panel; right-click's menu grays every feature entry",
function()
    -- launcher-§2 (standard v2.67.0, LibKa0s-Launcher-1.0 minor 4): neither button is refused
    -- while disabled. The left opens the settings panel, which is setup. The right opens the
    -- options menu, where Enabled stays live -- it is how the addon comes back -- and Locked, Test
    -- mode and Show window are grayed, because each drives a feature. Neither click writes.
    -- red under: an isEnabled that does not read the latch, or a host gate on either button.
    local NS, mock = up()
    switchOff(NS)
    local object = mock.ldbObjects[NAME]
    assertTrue(object ~= nil, "the broker object survives the stand-down")

    mock.__resetSvWrites()
    local mark, shown, opened = #mock.prints, #visibleFrames(mock), #mock.openedTo
    object.OnClick(mock.UIParent, "LeftButton")
    assertEqual(#mock.openedTo, opened + 1, "left-click opens the panel, in either state")
    assertEqual(#mock.prints - mark, 0, "and prints no refusal")

    object.OnClick(mock.UIParent, "RightButton")
    local menu = mock.menu.last
    assertTrue(menu ~= nil, "right-click opens the options menu")
    assertTrue(menu:Find("Enabled").enabled, "Enabled stays live")
    for _, entry in ipairs({ "Locked", "Test mode", "Show window" }) do
        assertFalse(menu:Find(entry).enabled, entry .. " is grayed while disabled")
        menu:Click(entry)
    end
    assertEqual(#mock.__svWrites(), 0, "a click on a disabled addon writes NOTHING")
    assertEqual(#visibleFrames(mock), shown, "and shows nothing")
    assertFalse(helpers(NS).Get("state.testMode"), "test mode never started")
end)

-- ---------------------------------------------------------------------------
-- 9. Re-enable, from CURRENT state
-- ---------------------------------------------------------------------------

test("disabled 9: re-enabling restores the registration set exactly", function()
    -- red under: rebuilding from a snapshot taken on the way down, forgetting one of the four, or
    -- not re-registering the chat-link callback in NS.StandUp.
    local NS, mock = up()
    local R_on, N_on = regKeys(mock), regNames(mock)
    assertTrue(joined(N_on):find("callback:SetItemRef", 1, true) ~= nil, "the callback is in the set")
    switchOff(NS)
    assertEqual(#regKeys(mock), 0)
    assertEqual(#regNames(mock), 0)
    switchOn(NS)
    assertEqual(joined(regKeys(mock)), joined(R_on), "the same set, not a subset and not a superset")
    assertEqual(joined(regNames(mock)), joined(N_on), "callback:SetItemRef included, exactly once")
end)

test("disabled 9: a setting changed WHILE DISABLED is what the rebuild reflects", function()
    -- performance-§6's restore-from-current-state rule, which this latch inherits in full. The
    -- schema CLI answers while the addon is off, so this is not a hypothetical: `set` is one of the
    -- twelve verbs v2.57.0 restored precisely so a player can repair settings from there.
    -- red under: caching db.profile on the way down and re-reading the cache on the way up.
    local NS, mock = up()
    switchOff(NS)
    NS.addon:OnSlashCommand("set visibility never")
    assertEqual(helpers(NS).Get("visibility"), "never")
    switchOn(NS)
    assertEqual(#regKeys(mock), 5, "it stood back up")
    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "L", fullName = "F",
                             shortName = "", playstyleString = "", generalPlaystyle = 0 }
    NS.addon:ShowFrame()
    local f = mock.frames["WhatGroupFrame"]
    assertFalse(f ~= nil and f:IsShown() and f:GetAlpha() > 0,
        "and it came back honoring the setting changed while it was off, not the old one")
end)

-- ---------------------------------------------------------------------------
-- 10. The latch — two holds, and releasing one is not a stand-up
-- ---------------------------------------------------------------------------

test("disabled 10: releasing the perf hold does NOT resurrect an addon `disabled` still holds down",
function()
    -- THE TRAP, AND IT IS REACHABLE: `/wg disable` is a live verb, so a player can switch the addon
    -- off DURING a suspended perf arm, and `/wg enable` is live too. A resume that called a bare
    -- stand-up would bring the addon back mid-capture and silently ruin the run. There is no
    -- `:StandUp()` member on the latch at all, and its absence is the feature.
    -- red under: replace the two NS.Lifecycle:Set calls with a boolean and a direct NS.StandUp() --
    -- the release below then re-registers all four events under a player who disabled the addon.
    local NS, mock = up()

    NS.Lifecycle:Hold(NS.HOLD_PERF)
    assertEqual(#regKeys(mock), 0, "the perf hold alone stands it down")
    switchOff(NS)
    NS.Lifecycle:Release(NS.HOLD_PERF)
    assertEqual(#regKeys(mock), 0, "still down: `disabled` is still held")
    assertTrue(NS.Lifecycle:IsHeld(NS.HOLD_DISABLED))

    switchOn(NS)
    assertEqual(#regKeys(mock), 5, "and only the LAST release stands it up")
end)

test("disabled 10: the other order — disabled first, perf released last", function()
    -- Hold order is irrelevant to the latch, and asserting only one order would leave the
    -- interesting half of the four-state space untested.
    -- red under: any implementation that tracks "why we are down" as a single value.
    local NS, mock = up()

    switchOff(NS)
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    switchOn(NS)
    assertEqual(#regKeys(mock), 0, "still down: the perf hold outlived the player's switch")
    assertEqual(joined(NS.Lifecycle:Holds()), "perf", "and it is the only one left")

    NS.Lifecycle:Release(NS.HOLD_PERF)
    assertEqual(#regKeys(mock), 5, "now it stands up")
    assertEqual(#NS.Lifecycle:Holds(), 0)
end)

test("disabled 10: the latch persists nothing", function()
    -- `perf` is session-only (performance-§6) and `disabled` is the STORED enable path rather than
    -- a second copy of it, so a hold set that reached SavedVariables would be a second switch to
    -- keep in step with the first.
    -- red under: writing the hold set, or a `standDown` that stores why it went down.
    local NS, mock = up()
    mock.__resetSvWrites()
    NS.Lifecycle:Hold(NS.HOLD_PERF)
    NS.Lifecycle:Release(NS.HOLD_PERF)
    assertEqual(#mock.__svWrites(), 0, "a perf hold and its release wrote nothing to disk")
end)

-- ---------------------------------------------------------------------------
-- What MUST survive, because it is SETUP and not a feature
-- ---------------------------------------------------------------------------

test("disabled: the chat command, the panel, the db callbacks and the launcher all survive",
function()
    -- The short, named exempt list. Every one of these is setup: it comes up on load in either
    -- state and stays up, and without it the switch only goes one way.
    -- red under: unregistering `/wg`, dropping COMMANDS, or tearing the settings category down.
    local NS, mock = up()
    switchOff(NS)

    -- Through the LIBRARY'S OWN registry, the table AceConsole really keeps, so this is the
    -- registration the client would dispatch from rather than a flag the addon set for itself.
    local console = mock.__libs["AceConsole-3.0"]
    assertTrue(console.commands["wg"] ~= nil, "the chat command is still registered")
    assertTrue(console.commands["whatgroup"] ~= nil, "and so is its alias")
    assertTrue(#NS.addon.COMMANDS > 0, "and the COMMANDS table is still there")
    assertTrue(NS.addon.db ~= nil, "the AceDB handle survives")
    assertTrue(NS.addon.Settings.Helpers.Get("enabled") == false, "and the single write seam reads")
    assertTrue(mock.ldbObjects[NAME] ~= nil, "the launcher registration survives")
    assertTrue(NS.Launcher:IsShown(), "and the button stays on the minimap (launcher-§3)")
end)

test("disabled: a profile switch that flips `enabled` is re-evaluated, both ways", function()
    -- AceDB's profile callbacks are on the survives list for exactly this: a switch can flip the
    -- stored path with no checkbox clicked and no verb typed, and an addon that dropped those
    -- callbacks would come up in the wrong state and stay there until a `/reload`.
    -- red under: removing the NS.Lifecycle:Set / :Reevaluate pair from reloadProfile.
    local NS, mock = up()
    NS.addon.db:SetProfile("off-profile")
    NS.addon.Settings.Helpers.Set("enabled", false)
    assertEqual(#regKeys(mock), 0)

    NS.addon.db:SetProfile("Default")
    assertTrue(NS.addon.Settings.Helpers.Get("enabled"), "the default profile is enabled")
    assertEqual(#regKeys(mock), 5, "so the switch brought it back up")
end)

-- ---------------------------------------------------------------------------
-- Secure work under lockdown (slash-commands-§7's pending completion)
-- ---------------------------------------------------------------------------

test("disabled: a stand-down in combat holds the protected Hide pending, and one event with it",
function()
    -- The popup parents a SecureActionButtonTemplate button, so Hide on it -- and on every ancestor
    -- -- is refused under lockdown. Attempting it anyway is strictly worse than deferring: the frame
    -- does not hide either way and the player additionally gets a red error naming this addon. So
    -- the stand-down takes the alpha-0 route and keeps PLAYER_REGEN_ENABLED, which is the ONE
    -- registration slash-commands-§7 permits a disabled addon to hold -- and releases it the moment
    -- it fires.
    -- red under: dropping the UnregisterEvent at the top of OnDisabledCombatEnded, which leaves a
    -- disabled addon watching an event it owes nothing to for the rest of the session.
    local NS, mock = up()
    NS.addon:OnSlashCommand("test on")
    local f = mock.frames["WhatGroupFrame"]
    assertTrue(f ~= nil and f:IsShown(), "the popup is up")

    mock.combat = true
    switchOff(NS)

    assertEqual(joined(regNames(mock)), "event:PLAYER_REGEN_ENABLED",
        "exactly one registration, and it is the pending completion")
    assertEqual(f:GetAlpha(), 0, "the popup is invisible, the real Hide owed to the next edge")

    mock.combat = false
    mock.__fire("PLAYER_REGEN_ENABLED")
    assertEqual(#regNames(mock), 0, "the debt is settled and the last registration is gone")
    assertFalse(f:IsShown(), "and the popup is genuinely hidden, not merely transparent")
end)
