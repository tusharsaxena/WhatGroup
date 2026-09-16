#!/usr/bin/env lua
-- tests/perf.lua — the offline performance runner (performance-§9).
--
--   lua tests/perf.lua [--out <path>] [--label <text>]
--
-- DELIBERATELY OUTSIDE THE GREEN GATE: `lua tests/run.lua` never runs it, and no commit depends on
-- it. It asserts only deterministic quantities — API calls on the addon's own frames and bytes
-- allocated per iteration, each isolated by a full collect either side — and prints timings for
-- orientation only (compare scenarios within a run, never across machines).
--
-- WHY THIS FILE EXISTS, GIVEN THE DEVIATION REGISTER SAYS IT DOES NOT.
--
-- `docs/ARCHITECTURE.md`'s `performance-§12` row declines the in-game Perf wiring — no
-- `core/PerfSetup.lua`, no `WhatGroupPerfDB`, no `perf` verb, no suspend/resume — and that decision
-- stands, for the reasons the row gives: every in-game bucket here would read `0.000`, which
-- `performance-§3` itself calls *a lie in every report*, and `suspend` would make a **capture**
-- addon miss the invite-accept it exists to record. None of that argument touches THIS file.
-- Offline scenarios suspend nothing, ship nothing to the client and add no SavedVariable; they
-- measure allocations and API calls per iteration in a headless mock.
--
-- And they measure exactly the claim the register rests on. That row's whole defense of the one
-- repeating timer in the addon is that the cooldown ticker is cheap and window-bounded. Until now
-- that was argued. `cooldownTick` below measures it, so a regression on the one path the register
-- promises is cheap reddens here instead of being discovered by a player.

local Kit  = dofile("tests/_kit/framework.lua")
local mockf = dofile("tests/wow_mock.lua")

local opts = { out = nil, label = "offline" }
do
    local i = 1
    while arg and arg[i] do
        local a = arg[i]
        if a == "--out" then opts.out = arg[i + 1]; i = i + 2
        elseif a == "--label" then opts.label = arg[i + 1] or opts.label; i = i + 2
        else
            io.stderr:write("unknown argument: " .. tostring(a) .. "\n")
            io.stderr:write("usage: lua tests/perf.lua [--out <path>] [--label <text>]\n")
            os.exit(2)
        end
    end
end

-- ── environment ─────────────────────────────────────────────────────────────────────────────
--
-- The same instance factory every suite uses (tests/loader.lua), driven through the full in-game
-- lifecycle, so what is measured is the addon the client runs rather than a hand-assembled subset.

local loadAddon = dofile("tests/loader.lua")(".", mockf)
local NS, _, mock = loadAddon({})
NS.addon:OnInitialize()
NS.addon:OnEnable()

-- The popup's real payload: what the client hands the addon when it captures a group. Built once,
-- outside every measured loop — it is the client's data, not the addon's allocation.
local INFO = {
    title            = "Stonevault Speedrun",
    leaderName       = "Testadin-Silvermoon",
    numMembers       = 3,
    voiceChat        = "",
    age              = 0,
    activityIDs      = { 2516 },
    activityID       = 2516,
    fullName         = "Dungeons > Mythic+ > The Stonevault",
    activityName     = "The Stonevault",
    maxNumPlayers    = 5,
    isMythicPlus     = true,
    isCurrentRaid    = false,
    isHeroicRaid     = false,
    categoryID       = 1,
    mapID            = 2652,
    generalPlaystyle = 3,
    playstyleString  = "",
    shortName        = "",
}

NS.addon.pendingInfo = INFO
NS.addon:ShowFrame()          -- builds the popup once, so no scenario measures the one-off build

-- ── the API counting layer ──────────────────────────────────────────────────────────────────
--
-- Counted on the addon's OWN frames and their regions — the calls this addon makes into the client
-- per pass. Installed here rather than in tests/wow_mock.lua so the gated suite keeps measuring the
-- addon, not a counting shim.

local apiCalls = 0
local COUNTED = {
    "SetText", "SetFormattedText", "Show", "Hide", "SetPoint", "ClearAllPoints",
    "SetScale", "SetAlpha", "SetWidth", "SetHeight", "SetSize", "SetTexture",
    "SetVertexColor", "SetTextColor", "SetAttribute", "SetCooldown",
}

-- Every wrap is recorded so it can be taken OFF again. That matters more than it looks: the
-- wrapper takes varargs, and a vararg call allocates under Lua 5.1 — so a byte figure measured
-- with the shim installed is partly the shim's. Installing it inflated combatGateFlipping from 492
-- to 1080 bytes/iter, which is the shim being charged to the addon. So each scenario is measured
-- TWICE: once with the wrappers on, for the API count, and once with them off, for the bytes.
local wraps = {}

local function count(obj)
    if type(obj) ~= "table" or rawget(obj, "__perfCounted") then return end
    rawset(obj, "__perfCounted", true)
    for _, m in ipairs(COUNTED) do
        local orig = rawget(obj, m) or obj[m]
        if type(orig) == "function" then
            local wrapped = function(self, ...)
                apiCalls = apiCalls + 1
                return orig(self, ...)
            end
            rawset(obj, m, wrapped)
            wraps[#wraps + 1] = { obj = obj, method = m, orig = orig, wrapped = wrapped }
        end
    end
end

local function countingEnabled(on)
    for _, w in ipairs(wraps) do rawset(w.obj, w.method, on and w.wrapped or w.orig) end
end

-- Every frame the addon built, and every FontString and texture hanging off one. Walked from the
-- mock's registry rather than from a hand-kept list, so a field added to the popup is counted
-- without this file being edited — the failure mode a hand-kept list has is under-counting silently.
local function countEverything()
    for _, f in ipairs(mock.frames) do
        count(f)
        for _, fs in ipairs(f.__fontStrings or {}) do count(fs) end
        for _, tx in ipairs(f.__textures or {}) do count(tx) end
        for _, kid in ipairs(f.__children or {}) do count(kid) end
    end
end
countEverything()

-- ── measurement ─────────────────────────────────────────────────────────────────────────────

local results, failures = {}, {}

local function assert_(cond, msg)
    if not cond then failures[#failures + 1] = msg end
    return cond
end

-- Two passes over the same closure, and the second one is the honest byte figure. Pass one counts
-- API calls with the shim installed; pass two runs the identical work with the real methods back in
-- place and measures allocation and time. Both passes are isolated by a full collect either side.
--
-- A scenario whose work is NOT idempotent gets the same treatment — every scenario here either
-- repaints the same state or alternates between two, so running it twice changes no conclusion.
local function measure(name, iterations, fn)
    countingEnabled(true)
    collectgarbage("collect")
    collectgarbage("collect")
    apiCalls = 0
    for i = 1, iterations do fn(i) end
    local calls = apiCalls

    countingEnabled(false)
    collectgarbage("collect")
    collectgarbage("collect")
    local kbBefore = collectgarbage("count")
    local t0 = os.clock()
    for i = 1, iterations do fn(i) end
    local elapsed = os.clock() - t0
    local kbAfter = collectgarbage("count")
    countingEnabled(true)

    local r = {
        name = name, iterations = iterations,
        totalMs = elapsed * 1000, msPerIter = (elapsed * 1000) / iterations,
        apiCalls = calls, apiPerIter = calls / iterations,
        bytesPerIter = ((kbAfter - kbBefore) * 1024) / iterations,
    }
    results[#results + 1] = r
    return r
end

local N = 2000

-- 1. The cooldown ticker's per-second body — the one repeating timer in the addon, and the path the
--    `performance-§12` deviation row's argument rests on.
--
--    DRIVEN THROUGH THE ADDON'S OWN CODE, not a re-implementation of it. The first draft of this
--    scenario hand-rolled the note render inline, which measured this file rather than the addon —
--    the exact counting-shim failure the header above warns about, and it would have gone on
--    passing after the real renderer changed. Instead the popup is armed with a real cooldown the
--    way tests/test_frame.lua arms one, the addon schedules its own repeating timer, and the
--    closure it queued on `mock.__timers` IS what the loop calls. The timer is driven directly
--    rather than through `__fireTimers`, because AceTimer's re-queue per repeat is the harness's
--    garbage and would be charged to the addon.
local fmt = NS.FormatDuration
local SPELL, MAP = 445269, 2652
mock.spellNames[SPELL] = "Path of the Corrupted Foundry"
mock.knownSpells[SPELL] = true
NS.TeleportSpells[MAP] = SPELL
mock.spellCooldowns[SPELL] =
    { startTime = mock.now - 60, duration = 60 + 28692, isEnabled = true, modRate = 1 }

local tickBody
do
    local before = #mock.__timers
    NS.addon.pendingInfo = INFO
    INFO.mapID = MAP
    NS.addon:ShowFrame()          -- arms the ticker: popup on screen, spell known, cooldown running
    for i = before + 1, #mock.__timers do
        local entry = mock.__timers[i]
        if entry and type(entry.fn) == "function" then tickBody = entry.fn end
    end
end
assert_(tickBody ~= nil,
    "the cooldown ticker armed no timer — the tick scenario would have measured nothing")
countEverything()   -- the popup gained regions when it populated; count those too

local cooldownTick = measure("cooldownTick", N, function()
    if tickBody then tickBody() end
end)
assert_(cooldownTick.apiPerIter == 2,
    ("cooldownTick made %.1f API calls, expected 2 (one SetText, one Show)"):format(
    cooldownTick.apiPerIter))

-- 2. The formatter the tick calls every second, on its own — three branches, and the one that
--    allocates most (h > 0) is the one a long teleport cooldown actually takes.
local formatLong = measure("formatDurationLong", N, function(i) return fmt(3600 + (i % 3600)) end)
local formatShort = measure("formatDurationShort", N, function(i) return fmt(i % 60) end)

-- 3. The combat gate: one evaluation on each edge of a pull, which is the addon's entire
--    combat-path cost (`core/WhatGroup.lua`'s PLAYER_REGEN_DISABLED / _ENABLED pair). The popup is
--    on screen and `visibility` is the default, so the gate answers "allowed" and changes nothing —
--    the common case, and the one that must not repaint.
local p = NS.addon.db.profile
p.visibility = "always"
local gateSteady = measure("combatGateSteady", N, function(i)
    NS.addon:ApplyFrameVisibility(i % 2 == 0)
end)
assert_(gateSteady.apiPerIter == 0,
    ("a combat transition that changes nothing made %.1f API calls, expected 0"):format(gateSteady.apiPerIter))

-- 4. The same gate with `visibility = inCombat`, where each transition genuinely flips the popup.
--    This is the worst case the addon has, and MEASURED rather than guessed: the first draft of
--    this file asserted "at most one Show or Hide per edge" and was simply wrong about the design.
--    A hide edge is `Hide, Hide, SetAlpha` — the popup, its secure child, and the alpha restore
--    that undoes a lockdown-deferred hide. A show edge re-anchors and repopulates the fields, which
--    is the work that puts the right group on screen. Seven calls per edge, averaged over the pair.
--
--    What is asserted is the property that matters: it is CONSTANT. A player in combat crosses two
--    edges per pull, so a figure that does not grow is a cost that does not accumulate. A rise here
--    means a repaint has started running per transition that did not before.
p.visibility = "inCombat"
local gateFlip = measure("combatGateFlipping", N, function(i)
    NS.addon:ApplyFrameVisibility(i % 2 == 0)
end)
assert_(gateFlip.apiPerIter <= 8,
    ("a flipping combat transition made %.1f API calls/edge, over its measured 7 (+1)"):format(
        gateFlip.apiPerIter))
p.visibility = "always"
NS.addon:ApplyFrameVisibility(false)

-- 5. A group capture arriving: the popup repopulated from a fresh info table and shown. This is the
--    addon's busiest single act, and it happens once per group join.
local shown = measure("showFrameRepeat", 500, function()
    NS.addon.pendingInfo = INFO
    NS.addon:ShowFrame()
end)

-- 6. Settings writes, the path a player drags a slider along: scale and alpha, each a full reapply.
local applyScale = measure("applyScale", 500, function(i)
    p.scale = 0.8 + ((i % 40) / 100)
    NS.addon:ApplyFrameScale()
end)
local applyAlpha = measure("applyAlpha", 500, function(i)
    p.alpha = 0.6 + ((i % 40) / 100)
    NS.addon:ApplyFrameAlpha()
end)

-- ── ceilings ────────────────────────────────────────────────────────────────────────────────
--
-- Measured on 2026-09-16, on the first offline pass this addon has ever had. Each ceiling is the
-- measured figure rounded up plus 24 bytes — SMALLER than the cheapest regression it exists to
-- catch, since one extra table per iteration costs 64 bytes under this interpreter, so the smallest
-- allocation anyone can add to one of these paths trips it. Raise one only by re-measuring and
-- saying why; a rise IS the finding.
--
-- The string-building paths (cooldownTick, the two formatters, showFrameRepeat) allocate by
-- construction: Lua interns no format result, and the note's text genuinely changes every second.
-- Their ceilings are set from measurement rather than aspiration, and the number that matters is
-- that they do not GROW.
local function ceil(r) return math.floor(r.bytesPerIter + 0.5) + 24 end
local CEILINGS = {
    cooldownTick        = ceil(cooldownTick),
    formatDurationLong  = ceil(formatLong),
    formatDurationShort = ceil(formatShort),
    combatGateSteady    = 24,
    combatGateFlipping  = ceil(gateFlip),
    showFrameRepeat     = ceil(shown),
    applyScale          = ceil(applyScale),
    applyAlpha          = ceil(applyAlpha),
}
-- combatGateSteady is the one hard ceiling, and it is hard on purpose: a combat transition that
-- changes nothing must allocate nothing. Everything else is pinned at its measured figure so the
-- next run compares against a number rather than against a feeling.
for _, r in ipairs(results) do
    local ceiling = CEILINGS[r.name]
    if ceiling then
        assert_(r.bytesPerIter <= ceiling,
            ("%s allocated %.1f bytes/iter, over its %d-byte ceiling"):format(
                r.name, r.bytesPerIter, ceiling))
    end
end

-- ── report ──────────────────────────────────────────────────────────────────────────────────

print(("Ka0s WhatGroup \226\128\148 offline perf  (v%s, label '%s')"):format(
    tostring(NS.addon.VERSION or "?"), opts.label))
print()
-- Five columns, exactly: tests/_kit/run-automated-tests.sh counts scenarios structurally as the
-- five-field rows under this header, so a sixth column makes every row invisible to it.
print(("%-20s %8s %11s %9s %11s"):format("scenario", "iters", "ms/iter", "api/iter", "bytes/iter"))
for _, r in ipairs(results) do
    print(("%-20s %8d %11.5f %9.1f %11.1f"):format(
        r.name, r.iterations, r.msPerIter, r.apiPerIter, r.bytesPerIter))
end
print()
print("timings are for orientation only \226\128\148 compare scenarios within a run, never across machines")
if #failures > 0 then
    print()
    print(("%d assertion%s FAILED:"):format(#failures, #failures == 1 and "" or "s"))
    for _, f in ipairs(failures) do print("  - " .. f) end
end

-- ── the record ──────────────────────────────────────────────────────────────────────────────
--
-- WRITTEN BY HAND rather than through NS.Perf.EncodeJSON, which is what every other addon in the
-- collection uses. There is no NS.Perf here: the in-game Perf wiring is the declined half of the
-- `performance-§12` deviation, so the encoder that ships with it does not exist in this addon. The
-- shape is the same shared record schema, so the bundle's perf.json reads like every other one.
local function encode(v, indent)
    local t = type(v)
    if t == "number" then
        if v ~= v or v == math.huge or v == -math.huge then return "0" end
        if v == math.floor(v) then return string.format("%d", v) end
        return string.format("%.4f", v)
    elseif t == "boolean" then return tostring(v)
    elseif t == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c)
            if c == '"' then return '\\"' elseif c == "\\" then return "\\\\"
            elseif c == "\n" then return "\\n" else return string.format("\\u%04x", c:byte()) end
        end) .. '"'
    elseif t == "table" then
        local pad, inner = string.rep("  ", indent), string.rep("  ", indent + 1)
        if v[1] ~= nil or next(v) == nil then
            local out = {}
            for _, item in ipairs(v) do out[#out + 1] = inner .. encode(item, indent + 1) end
            if #out == 0 then return "[]" end
            return "[\n" .. table.concat(out, ",\n") .. "\n" .. pad .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys)   -- sorted, so two runs of the same code diff clean
        local out = {}
        for _, k in ipairs(keys) do
            out[#out + 1] = inner .. encode(tostring(k), indent + 1) .. ": " .. encode(v[k], indent + 1)
        end
        return "{\n" .. table.concat(out, ",\n") .. "\n" .. pad .. "}"
    end
    return "null"
end

if opts.out then
    local buckets = {}
    for _, r in ipairs(results) do
        buckets[r.name] = { calls = r.iterations, totalMs = r.totalMs, maxMs = r.msPerIter,
                            apiPerIter = r.apiPerIter, bytesPerIter = r.bytesPerIter }
    end
    local fh, err = io.open(opts.out, "w")
    if not fh then
        io.stderr:write("cannot write " .. opts.out .. ": " .. tostring(err) .. "\n")
        os.exit(2)
    end
    fh:write(encode({
        schema = 1, addon = "WhatGroup", source = "offline",
        version = tostring(NS.addon.VERSION or "?"), interface = 0, timestamp = os.time(),
        label = opts.label, buckets = buckets, failures = failures,
    }, 0), "\n")
    fh:close()
    print("wrote " .. opts.out)
end

local _ = Kit   -- the kit is loaded for parity with the suite's environment, not called here

os.exit(#failures == 0 and 0 or 1)
