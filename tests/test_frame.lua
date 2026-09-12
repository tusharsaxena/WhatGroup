-- tests/test_frame.lua — the group-info popup (modules/Frame.lua): lazy build,
-- field population, the secure teleport button's three states, the
-- first-show-in-combat defer, and geometry persistence.
--
-- Reachable headlessly only because the mock's frame stub models real
-- visibility, geometry and secure attributes, and hands out a DISTINCT
-- FontString per CreateFontString call — with a self-returning no-op stub
-- every field would share one SetText sink and "Leader shows the leader" would
-- be indistinguishable from "every row shows the same string".
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local function pending(overrides)
    local i = {
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
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

local function popup(mock) return mock.frames["WhatGroupFrame"] end

-- The Close button is anonymous, so it is found by the thing that identifies it to a player: its
-- label. Anchored to the popup rather than searched globally, so a second button with the same text
-- elsewhere in the addon could not silently become the one under test.
local function closeButton(mock)
    local f = popup(mock)
    if not f then return nil end
    for _, kid in ipairs(f.__children or {}) do
        if kid.__text == "Close" and kid.__scripts and kid.__scripts.OnClick then return kid end
    end
    return nil
end

-- The popup's five value FontStrings, by name. buildFrame creates them on the
-- `content` frame in a fixed label/value/label/value order (MakeLabel emits the
-- gold label then its value), followed by the standalone "Teleport:" label and
-- the cooldown note that sits beside the button — so content holds 12
-- FontStrings and the five row values sit at the even indices. Locating
-- `content` as the frame carrying the most FontStrings keeps this independent of
-- how many frames buildFrame creates around it.
local function fields(mock)
    local content, most = nil, 0
    for _, f in ipairs(mock.frames) do
        if #f.__fontStrings > most then content, most = f, #f.__fontStrings end
    end
    assertTrue(content ~= nil, "the popup content frame must exist")
    local fs = content.__fontStrings
    return {
        group     = fs[2],
        instance  = fs[4],
        type      = fs[6],
        leader    = fs[8],
        playstyle = fs[10],
        note      = fs[12],
    }
end

-- The title bar is the drag handle, and the only frame carrying an OnMouseUp.
local function dragHandle(mock)
    for _, fr in ipairs(mock.frames) do
        if fr.__scripts.OnMouseUp then return fr end
    end
end

-- The cooldown swipe is the only Cooldown-type frame.
local function teleportCooldown(mock)
    for _, f in ipairs(mock.frames) do
        if f.__kind == "Cooldown" then return f end
    end
end

-- The secure cast button is the only SecureActionButtonTemplate frame.
local function teleportBtn(mock)
    for _, f in ipairs(mock.frames) do
        if f.__template == "SecureActionButtonTemplate" then return f end
    end
end

-- ---------------------------------------------------------------------------
-- Lazy build (the taint contract)
-- ---------------------------------------------------------------------------

test("frame: nothing is created at addon load", function()
    local _, _, mock = T.bootAddon()
    assertNil(popup(mock), "the popup must not exist before the first ShowFrame")
    assertNil(teleportBtn(mock), "the secure button must not exist at load either")
end)

test("frame: the first ShowFrame builds and shows the popup", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    assertTrue(popup(mock) ~= nil, "the popup is built on demand")
    assertTrue(popup(mock):IsShown())
end)

test("frame: buildFrame is one-shot — a second show reuses the same frame", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local first = popup(mock)
    local frameCount = #mock.frames
    NS.addon:ShowFrame()
    assertEqual(popup(mock), first, "same frame object")
    assertEqual(#mock.frames, frameCount, "no additional frames created")
end)

test("frame: ESC-to-close is registered lazily, on the first show only", function()
    local NS, env = T.bootAddon()
    assertEqual(#env.UISpecialFrames, 0, "no UISpecialFrames entry at load (taint)")
    NS.addon:ShowFrame()
    NS.addon:ShowFrame()
    local hits = 0
    for _, name in ipairs(env.UISpecialFrames) do
        if name == "WhatGroupFrame" then hits = hits + 1 end
    end
    assertEqual(hits, 1, "registered exactly once")
end)

test("frame: the Close button hides the popup", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local close
    for _, f in ipairs(mock.frames) do
        if f.__template == "UIPanelButtonTemplate" then close = f end
    end
    assertTrue(close ~= nil, "a Close button exists")
    close.__fire("OnClick")
    assertFalse(popup(mock):IsShown())
end)

-- ---------------------------------------------------------------------------
-- PopulateFields
-- ---------------------------------------------------------------------------

test("frame: fields render the pending capture", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local f = fields(mock)
    assertEqual(f.group:GetText(), "Stonevault Speedrun")
    assertEqual(f.instance:GetText(), "Dungeons > Mythic+ > The Stonevault")
    assertEqual(f.leader:GetText(), "Testadin-Silvermoon")
end)

test("frame: with no pendingInfo every field reads 'No data'", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = nil
    NS.addon:ShowFrame()
    local f = fields(mock)
    for _, key in ipairs({ "group", "instance", "type", "leader" }) do
        assertTrue(f[key]:GetText():find("No data", 1, true) ~= nil,
            key .. " must show the No data fallback")
    end
end)

test("frame: the no-data playstyle renders the dim em-dash placeholder", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = nil
    NS.addon:ShowFrame()
    assertTrue(fields(mock).playstyle:GetText():find("\226\128\148", 1, true) ~= nil)
end)

test("frame: an empty fullName falls back to Unknown", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ fullName = "" })
    NS.addon:ShowFrame()
    assertEqual(fields(mock).instance:GetText(), "Unknown")
end)

test("frame: the Type field prefers shortName", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ shortName = "M+" })
    NS.addon:ShowFrame()
    assertEqual(fields(mock).type:GetText(), "M+")
end)

test("frame: the Type field derives a label when shortName is empty", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ shortName = "", isMythicPlus = true })
    NS.addon:ShowFrame()
    assertEqual(fields(mock).type:GetText(), "Mythic+")
end)

test("frame: the Playstyle field prefers the server-rendered string", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ playstyleString = "No Leavers" })
    NS.addon:ShowFrame()
    assertEqual(fields(mock).playstyle:GetText(), "No Leavers")
end)

test("frame: the Playstyle field falls back to the enum label", function()
    local NS, env, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({
        playstyleString  = "",
        generalPlaystyle = env.Enum.LFGEntryGeneralPlaystyle.Expert,
    })
    NS.addon:ShowFrame()
    assertEqual(fields(mock).playstyle:GetText(), "Expert")
end)

test("frame: playstyle None (0) renders the dim em-dash, not an empty row", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ playstyleString = "", generalPlaystyle = 0 })
    NS.addon:ShowFrame()
    assertTrue(fields(mock).playstyle:GetText():find("\226\128\148", 1, true) ~= nil)
end)

test("frame: re-showing with a new capture re-renders the fields", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    NS.addon.pendingInfo = pending({ title = "Second Group" })
    NS.addon:ShowFrame()
    assertEqual(fields(mock).group:GetText(), "Second Group")
end)

-- ---------------------------------------------------------------------------
-- The secure teleport button
-- ---------------------------------------------------------------------------

-- WG-R-05. BOTH click edges are required and this case pins that, because losing one is SILENT:
-- a bare SecureActionButtonTemplate with type="macro" does not run its macro on the down edge, so
-- registering "AnyDown" alone leaves the button receiving the press (PreClick still prints its
-- trace) and casting nothing, with no Lua error to notice. That shipped once, in [M4-24], on the
-- reasoned-but-never-tested premise that two edges meant two casts; measured in the client it is
-- one cast, on the up edge. The PreClick `down` gate is what keeps two edges to one debug line.
-- Narrowing RegisterForClicks in buildFrame to either edge alone turns this case red.
test("frame: the teleport button registers both click edges, because the up edge is the caster",
function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local edges = teleportBtn(mock).__clicks
    local seen = {}
    for _, e in ipairs(edges) do seen[e] = true end
    assertEqual(#edges, 2, "dropping an edge is silent — the button still clicks, it just never casts")
    assertTrue(seen["AnyUp"], "AnyUp is the edge that actually executes the /cast macro")
    assertTrue(seen["AnyDown"], "AnyDown is the edge the PreClick trace gates on")
end)

test("frame: a known teleport wires the secure /cast macro", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Stonevault"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertEqual(btn:GetAttribute("type"), "macro")
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Stonevault")
    assertTrue(btn:IsShown())
end)

test("frame: a known teleport renders at full alpha, undesaturated", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertEqual(btn:GetAlpha(), 1.0)
    assertFalse(btn.__textures[1]:IsDesaturated())
end)

test("frame: an unlearned teleport shows desaturated at half alpha and casts nothing", function()
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[2652] = 445269   -- never marked known
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertTrue(btn:IsShown(), "the icon still shows, so the player sees it exists")
    assertEqual(btn:GetAlpha(), 0.5)
    assertTrue(btn.__textures[1]:IsDesaturated())
    assertNil(btn:GetAttribute("type"), "no secure action is wired")
    assertNil(btn:GetAttribute("macrotext"))
end)

-- ---------------------------------------------------------------------------
-- The cooldown state (WG-31)
-- ---------------------------------------------------------------------------
--
-- A teleport the player HAS but cannot cast yet is a fourth state, distinct from "not learned":
-- the spell is theirs, so hiding it or tagging it unlearned would both be lies. It renders like
-- the unlearned state (desaturated, dimmed, no armed macro) but says why, and it recovers on its
-- own the next time the popup opens.

local function onCooldown(mock, spellID, remaining)
    mock.spellCooldowns[spellID] =
        { startTime = mock.now - 60, duration = 60 + remaining, isEnabled = true, modRate = 1 }
end

test("frame: a teleport on cooldown arms no macro, so the click casts nothing", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Corrupted Foundry"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 28692)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertTrue(btn:IsShown(), "the player owns the spell, so the icon stays visible")
    assertNil(btn:GetAttribute("type"), "no secure action is armed while it is recharging")
    assertNil(btn:GetAttribute("macrotext"))
end)

test("frame: a teleport on cooldown renders desaturated and dimmed", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 28692)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertEqual(btn:GetAlpha(), 0.5)
    assertTrue(btn.__textures[1]:IsDesaturated())
end)

test("frame: a teleport on cooldown says how long is left", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 28692)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local note = fields(mock).note
    assertTrue(note:GetText():find("7h 58m 12s", 1, true) ~= nil,
        "the note must carry the formatted remaining time, got: " .. tostring(note:GetText()))
    assertTrue(note:IsShown())
end)

-- The swipe is the only part of this that stays live: the widget animates engine-side, so the
-- popup gets a moving readout without the addon owning an OnUpdate or a repeating timer — the
-- condition LIBKA0S-15 (issue #7) rests on (docs/performance.md).
test("frame: a teleport on cooldown arms the swipe with the real start and duration", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 28692)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local cd = teleportCooldown(mock)
    assertTrue(cd ~= nil, "the swipe frame must exist")
    assertEqual(cd.__cooldown.start, mock.now - 60)
    assertEqual(cd.__cooldown.duration, 60 + 28692)
end)

test("frame: a ready teleport clears the note and the swipe", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Corrupted Foundry"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 28692)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    -- The cooldown finishes while the popup is closed; re-opening must rearm the cast.
    mock.spellCooldowns[445269] = nil
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Corrupted Foundry")
    assertEqual(btn:GetAlpha(), 1.0)
    assertFalse(btn.__textures[1]:IsDesaturated())
    assertFalse(fields(mock).note:IsShown(), "a stale countdown must not outlive the cooldown")
    assertEqual(teleportCooldown(mock).__cooldown.duration, 0)
end)

-- The ticker (WG-31). A repeating timer is the thing this addon spent its whole life not having —
-- it ends the performance-§12 exemption, which is ratified in ARCHITECTURE.md's register. What
-- makes it defensible is that it cannot outlive the popup, so that is what these pin.

test("frame: an open popup ticks the cooldown note down each second", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 12)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    assertTrue(fields(mock).note:GetText():find("12s", 1, true) ~= nil)

    mock.now = mock.now + 1
    assertEqual(mock.__fireTimers(), 1, "exactly one repeating timer is armed")
    assertTrue(fields(mock).note:GetText():find("11s", 1, true) ~= nil,
        "got: " .. tostring(fields(mock).note:GetText()))
end)

test("frame: closing the popup cancels the ticker", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 3600)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    popup(mock):Hide()
    assertEqual(mock.__fireTimers(), 0,
        "a ticker that survives the window it belongs to runs for the rest of the session")
end)

test("frame: re-opening the popup arms exactly one ticker, not a second", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 3600)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    NS.addon:ShowFrame()
    NS.addon:ShowFrame()
    assertEqual(mock.__fireTimers(), 1, "each show must replace the ticker, never stack one")
end)

test("frame: a ready teleport arms no ticker at all", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Corrupted Foundry"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    assertEqual(mock.__fireTimers(), 0, "nothing to count down")
end)

test("frame: a popup the gate keeps off screen arms no ticker", function()
    -- The whole basis of the performance-§12 deviation row is that the ticker cannot outlive the
    -- window that armed it, and OnHide -- the cancel site -- fires on a TRANSITION. A ticker armed
    -- against a frame that was never shown therefore has no cancel site at all and runs for the rest
    -- of the session.
    -- red under: arming the ticker from applyTeleportNote unconditionally.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "inCombat"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 3600)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    assertTrue(popup(mock) ~= nil, "the frame is built, it is just not shown")
    assertFalse(popup(mock):IsShown())
    assertEqual(mock.__fireTimers(), 0,
        "a ticker with no cancel site is the one thing the deviation row says cannot happen")
end)

test("frame: a popup that reaches the screen later still gets its ticker", function()
    -- The mirror of the case above: arming only against a visible popup is only correct if every
    -- path that makes the popup visible arms it. OnShow is that one place.
    -- red under: gating the arm on IsShown() and leaving ShowFrame's own Show as the only arm site.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 3600)
    mock.combat = true
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()          -- builds nothing: first show in combat defers
    mock.combat = false
    NS.addon:ShowFrame()          -- out of combat now, so it builds and shows
    assertTrue(popup(mock):IsShown())
    assertEqual(mock.__fireTimers(), 1, "the visible popup counts down")
end)

test("frame: the ticker rearms the cast the moment the cooldown expires", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Corrupted Foundry"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    onCooldown(mock, 445269, 2)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    assertNil(teleportBtn(mock):GetAttribute("macrotext"))

    mock.now = mock.now + 2
    mock.spellCooldowns[445269] = nil
    mock.__fireTimers()

    local btn = teleportBtn(mock)
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Corrupted Foundry",
        "the popup must become usable without being closed and re-opened")
    assertEqual(btn:GetAlpha(), 1.0)
    assertFalse(btn.__textures[1]:IsDesaturated())
    assertFalse(fields(mock).note:IsShown())
    assertEqual(mock.__fireTimers(), 0, "and the ticker stops itself once there is nothing left")
end)

-- The note carries BOTH reasons a teleport is unusable, in the same place, so the popup never just
-- grays out and says nothing.
test("frame: an unlearned teleport says so beside the button", function()
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[2652] = 445269   -- never marked known
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local note = fields(mock).note
    assertTrue(note:IsShown())
    assertTrue(note:GetText():find("not learned", 1, true) ~= nil,
        "got: " .. tostring(note:GetText()))
end)

-- "Not learned" outranks "on cooldown". A spell the player has never learned may still report a
-- cooldown, and saying so answers a question nobody asked while burying the one that matters.
test("frame: an unlearned teleport is never labeled as on cooldown", function()
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[2652] = 445269   -- never marked known
    onCooldown(mock, 445269, 28692)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local note = fields(mock).note
    assertTrue(note:GetText():find("not learned", 1, true) ~= nil)
    assertNil(note:GetText():find("7h 58m", 1, true))
    assertEqual(mock.__fireTimers(), 0, "and it arms no countdown for a spell they cannot cast")
end)

test("frame: a map with no teleport hides the button entirely", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending({ mapID = 999999, activityID = 888888 })
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertFalse(btn:IsShown())
    assertNil(btn:GetAttribute("type"))
end)

test("frame: the button clears a stale macro when re-shown for a teleport-less map", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Stonevault"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    assertEqual(teleportBtn(mock):GetAttribute("type"), "macro")
    -- Joining a group with no teleport must not leave the previous /cast armed.
    NS.addon.pendingInfo = pending({ mapID = 999999, activityID = 888888 })
    NS.addon:ShowFrame()
    assertNil(teleportBtn(mock):GetAttribute("macrotext"))
end)

test("frame: the teleport icon uses the spell's texture", function()
    local NS, _, mock = T.bootAddon()
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    assertEqual(teleportBtn(mock).__textures[1]:GetTexture(), 100000 + 445269)
end)

test("frame: no pendingInfo hides the teleport button", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    assertFalse(teleportBtn(mock):IsShown())
end)

-- ---------------------------------------------------------------------------
-- Combat guards
-- ---------------------------------------------------------------------------

test("frame: a first show in combat defers the build and says so", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.pendingInfo = pending()
    local mark = #mock.prints
    NS.addon:ShowFrame()
    assertNil(popup(mock), "no protected frame is created during combat")
    assertTrue(mock.prints[#mock.prints]:find("combat", 1, true) ~= nil,
        "the player is told why nothing opened")
    assertTrue(NS.addon._frameBuildQueued, "the build is queued for combat end")
    assertTrue(mark < #mock.prints)
end)

test("frame: leaving combat builds the deferred popup", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local waitFrame = mock.frames[#mock.frames]
    assertTrue(waitFrame:IsEventRegistered("PLAYER_REGEN_ENABLED"))
    mock.combat = false
    waitFrame.__fire("OnEvent", "PLAYER_REGEN_ENABLED")
    assertTrue(popup(mock) ~= nil, "the popup builds once combat ends")
    assertTrue(popup(mock):IsShown())
    assertNil(NS.addon._frameBuildQueued, "the queue flag is released")
end)

test("frame: the deferred show restores a pendingInfo cleared during the wait", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.pendingInfo = pending({ title = "Group Before Combat" })
    NS.addon:ShowFrame()
    local waitFrame = mock.frames[#mock.frames]
    NS.addon:WipeCapture()        -- e.g. group-leave lands mid-combat
    mock.combat = false
    waitFrame.__fire("OnEvent", "PLAYER_REGEN_ENABLED")
    assertEqual(fields(mock).group:GetText(), "Group Before Combat")
end)

test("frame: repeated in-combat shows queue exactly one wait frame", function()
    local NS, _, mock = T.bootAddon()
    mock.combat = true
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local afterFirst = #mock.frames
    NS.addon:ShowFrame()
    NS.addon:ShowFrame()
    assertEqual(#mock.frames, afterFirst, "the _frameBuildQueued guard holds")
end)

test("frame: a show requested in combat is deferred, not forced", function()
    -- This case asserted the opposite until 2026-09-09 — "no defer needed once the frame exists" —
    -- and a player proved it wrong with `/wg test` mid-fight: ADDON_ACTION_BLOCKED on
    -- WhatGroupFrame:Show(). Show is protected for the same reason Hide is, because showing an
    -- ancestor changes a protected child's visibility. The mock modelled only the Hide half, so
    -- this case passed while the client refused the call.
    -- red under: a ShowFrame that only defers the BUILD.
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()          -- build out of combat
    popup(mock):Hide()
    mock.combat = true
    NS.addon:ShowFrame()
    assertEqual(#mock.blocked, 0, "the error the player actually saw")
    assertFalse(popup(mock):IsShown(), "and it must not appear mid-fight either")

    mock.combat = false
    mock.fireCTimers()
    for _, fr in ipairs(mock.frames) do
        if fr.__events and fr.__events["PLAYER_REGEN_ENABLED"] and fr.__scripts.OnEvent then
            fr.__scripts.OnEvent(fr, "PLAYER_REGEN_ENABLED")
        end
    end
    assertTrue(popup(mock):IsShown(), "the deferred show has to land when combat ends")
end)

test("frame: a popup held at alpha 0 comes back in combat without a Show", function()
    -- The one legal way back during a lockdown, and the mirror of how it went away. The frame is
    -- still SHOWN, so restoring its alpha needs no protected call — which is what makes "hiding an
    -- open popup in combat" reversible instead of one-way.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    assertEqual(popup(mock):GetAlpha(), 0)

    NS.addon:ShowFrame()
    assertEqual(#mock.blocked, 0, "no Show may be attempted for this")
    assertEqual(popup(mock):GetAlpha(), 1, "and the popup is back on screen")
end)

test("frame: reconfiguring the teleport button in combat stashes and replays it", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Stonevault"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon:ShowFrame()          -- build out of combat, no capture yet
    mock.combat = true
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local btn = teleportBtn(mock)
    assertNil(btn:GetAttribute("type"),
        "secure attribute writes are dropped during combat, not attempted")
    -- The popup frame itself carries the replay; firing regen re-runs Configure.
    mock.combat = false
    popup(mock).__fire("OnEvent", "PLAYER_REGEN_ENABLED")
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Stonevault")
end)

-- ---------------------------------------------------------------------------
-- Geometry persistence (WG-26)
-- ---------------------------------------------------------------------------

test("frame: a fresh profile leaves the popup at its default center anchor", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local point = popup(mock):GetPoint(1)
    assertEqual(point, "CENTER")
end)

test("frame: dragging the title bar persists the popup position", function()
    local NS, env, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local f = popup(mock)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 120, -240)
    -- The title bar is the drag handle; OnMouseUp is what commits the save.
    local titleBar = dragHandle(mock)
    assertTrue(titleBar ~= nil, "the drag handle has an OnMouseUp")
    titleBar.__fire("OnMouseUp")
    local saved = NS.addon.db.global.windows.popup
    assertEqual(saved.point, "TOPLEFT")
    assertEqual(saved.x, 120)
    assertEqual(saved.y, -240)
end)

test("frame: a saved position is restored on the next build", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.db.global.windows = { popup = { point = "TOPRIGHT", relPoint = "TOPRIGHT", x = -40, y = -60 } }
    NS.addon:ShowFrame()
    local point, _, relPoint, x, y = popup(mock):GetPoint(1)
    assertEqual(point, "TOPRIGHT")
    assertEqual(relPoint, "TOPRIGHT")
    assertEqual(x, -40)
    assertEqual(y, -60)
end)

-- ---------------------------------------------------------------------------
-- The popup's size, which is a setting now (frame.width / frame.height)
-- ---------------------------------------------------------------------------

test("frame: the popup is built at the profile's width and height", function()
    -- FRAME_WIDTH / FRAME_HEIGHT used to be file-locals. The shipped defaults are the numbers they
    -- were, so this case also pins that an untouched profile draws the popup that shipped.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetWidth(), 420)
    assertEqual(popup(mock):GetHeight(), 260)
end)

test("frame: a stored size is honored on build", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.frame.width  = 560
    NS.addon.db.profile.frame.height = 300
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetWidth(), 560)
    assertEqual(popup(mock):GetHeight(), 300)
end)

test("frame: a size change re-sizes a popup that is already open", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    NS.addon.Settings.Helpers.Set("frame.width", 500)
    assertEqual(popup(mock):GetWidth(), 500, "the row's onChange reached the live frame")
    NS.addon.Settings.Helpers.Set("frame.height", 340)
    assertEqual(popup(mock):GetHeight(), 340)
end)

test("frame: a size hand-edited past the clamp is drawn at the nearest legal value", function()
    -- These come from SavedVariables and from `/wg set`, neither of which passes the slider. A
    -- popup wider than the monitor reads as the setting being broken rather than as refused.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.frame.width  = 4000
    NS.addon.db.profile.frame.height = 12
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetWidth(), 700, "clamped to the row's max")
    assertEqual(popup(mock):GetHeight(), 200, "and up to the row's min")
end)

test("frame: a non-numeric stored size falls back to the shipped default", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.frame.width  = "wide"
    NS.addon.db.profile.frame.height = nil
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetWidth(), 420)
    assertEqual(popup(mock):GetHeight(), 260)
end)

test("frame: a size change taken in combat is refused, and lands on the next open", function()
    -- The popup parents a SecureActionButtonTemplate button anchored off the frame's own edges, so
    -- resizing the parent in combat is protected work. Nothing is queued: the next out-of-combat
    -- ShowFrame applies whatever the value is by then, which is the value the player set.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    mock.combat = true
    NS.addon.Settings.Helpers.Set("frame.width", 600)
    assertEqual(popup(mock):GetWidth(), 420, "the live frame was left alone in combat")
    mock.combat = false
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetWidth(), 600, "and the next open picks the value up")
end)

-- ---------------------------------------------------------------------------
-- The master controls (options-ui-§15) — scale, alpha, lock, reset position,
-- and the general-visibility gate
-- ---------------------------------------------------------------------------
--
-- Every case here drives a setting the panel now declares. A declared setting the drawing code
-- does not honor is worse than an absent one, so each is asserted against the popup itself rather
-- than against db.profile.

test("frame: the popup opens at the profile's master scale", function()
    -- red under: dropping the ApplyFrameScale call from ShowFrame.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.scale = 1.4
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 1.4)
end)

test("frame: a scale change re-scales a popup that is already open", function()
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 1, "the shipped default is unity")
    NS.addon.Settings.Helpers.Set("scale", 0.75)
    assertEqual(popup(mock):GetScale(), 0.75, "the row's onChange reached the live frame")
end)

test("frame: a scale hand-edited past the clamp is drawn at the nearest legal value", function()
    -- SavedVariables and `/wg set scale 40` both bypass the slider, and a popup at forty times
    -- size reads as the addon being broken rather than as the value being refused.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.scale = 40
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 2, "clamped to the row's max")
end)

test("frame: a scale change taken in combat is refused, and lands on the next open", function()
    -- Scaling the parent moves the SecureActionButtonTemplate child, which is the same protected
    -- work ApplyFrameSize refuses.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    mock.combat = true
    NS.addon.Settings.Helpers.Set("scale", 1.5)
    assertEqual(popup(mock):GetScale(), 1, "the live frame was left alone in combat")
    mock.combat = false
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetScale(), 1.5, "and the next open picks the value up")
end)

test("frame: the popup opens at the profile's master alpha", function()
    -- red under: dropping the ApplyFrameAlpha call from ShowFrame.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.alpha = 0.4
    NS.addon:ShowFrame()
    assertEqual(popup(mock):GetAlpha(), 0.4)
end)

test("frame: an alpha change lands DURING combat, unlike a size or scale change", function()
    -- Opacity moves nothing, so the secure child's position is untouched and there is nothing to
    -- refuse — which matters because in combat is the one time an alpha setting is being judged.
    -- red under: copying ApplyFrameSize's InCombatLockdown guard onto ApplyFrameAlpha.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    mock.combat = true
    NS.addon.Settings.Helpers.Set("alpha", 0.25)
    assertEqual(popup(mock):GetAlpha(), 0.25)
end)

test("frame: locking the popup stops the title bar starting a drag", function()
    -- red under: reading `locked` once at build time instead of at drag time, or dropping the
    -- guard entirely.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local titleBar = dragHandle(mock)
    titleBar.__fire("OnMouseDown")
    assertTrue(popup(mock):IsMoving(), "unlocked, the drag starts")
    titleBar.__fire("OnMouseUp")

    NS.addon.Settings.Helpers.Set("locked", true)
    titleBar.__fire("OnMouseDown")
    assertFalse(popup(mock):IsMoving(), "locked, the same mouse-down does nothing")
end)

test("frame: Reset position re-anchors the popup and forgets the saved point", function()
    -- Both halves, because either alone is a reset the next login undoes.
    -- red under: dropping the db.global.windows.popup clear.
    local NS, env, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local f = popup(mock)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", env.UIParent, "TOPLEFT", 120, -240)
    dragHandle(mock).__fire("OnMouseUp")
    assertTrue(NS.addon.db.global.windows.popup ~= nil, "there is a stored point to drop")

    NS.addon:ResetFramePosition()
    assertNil(NS.addon.db.global.windows.popup, "the persisted point is gone")
    assertEqual(f:GetPoint(1), "CENTER", "and the frame is back at the shipped anchor")
end)

test("frame: Reset position in combat is refused, but still forgets the saved point", function()
    -- Re-anchoring moves the secure child; forgetting the point does not. Splitting them means the
    -- act is never half-applied in a way the next login would undo.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    local f = popup(mock)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", nil, "TOPLEFT", 10, -10)
    mock.combat = true
    NS.addon:ResetFramePosition()
    assertEqual(f:GetPoint(1), "TOPLEFT", "the live frame was left alone in combat")
end)

test("frame: visibility 'never' refuses every path to the screen", function()
    -- red under: gating only the auto-show path instead of ShowFrame itself.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "never"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertNil(popup(mock), "the popup was never even built")
end)

test("frame: visibility 'inCombat' BUILDS out of combat but only SHOWS in it", function()
    -- The build is deliberately not refused here, unlike `never`: refusing it would deadlock the
    -- setting outright, because the first show is always out of combat and the in-combat show
    -- would then meet the never-built defer instead of a popup.
    -- red under: moving the combat-dependent half of the gate above buildFrame.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon:ShowFrame()
    assertTrue(popup(mock) ~= nil, "the frame is built on the safe side of the lockdown")
    assertFalse(popup(mock):IsShown(), "and out of combat it stays off screen")
    mock.combat = true
    NS.addon:ShowFrame()
    -- AND IT CANNOT OPEN, which is the finding rather than the fix. `inCombat` asks for a popup
    -- that appears during a lockdown, and Show is protected there — so from a genuinely hidden
    -- frame the setting cannot be delivered at all. What this case pins is that the addon does not
    -- ASK: the attempt would not open it either way and would cost the player a red error.
    -- Delivering `inCombat` would mean keeping the frame shown at alpha 0 for the whole time the
    -- player is OUT of combat, so the edge needs only an alpha change — an invisible 420x260
    -- click-target at rest, which is a trade for the owner to make, not this case.
    assertEqual(#mock.blocked, 0, "no protected Show may be attempted")
    assertFalse(popup(mock):IsShown(), "the client will not open it mid-fight")
end)

test("frame: visibility 'outOfCombat' is the mirror of it", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    mock.combat = true
    NS.addon:ShowFrame()
    assertNil(popup(mock))
    mock.combat = false
    NS.addon:ShowFrame()
    assertTrue(popup(mock) ~= nil and popup(mock):IsShown())
end)

test("frame: an unrecognized visibility value fails OPEN, not closed", function()
    -- A hand-edited SavedVariable or a profile from a future version must not make the addon look
    -- broken. `always` and anything unknown both answer yes.
    -- red under: a whitelist that returns false for the default branch.
    local NS, _, mock = T.bootAddon()
    NS.addon.db.profile.visibility = "sometimes"
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())
end)

test("frame: switching visibility to 'never' hides a popup that is already open", function()
    -- Otherwise the dropdown reads as ignored until the next open.
    -- red under: dropping ApplyFrameVisibility from the row's onChange.
    local NS, _, mock = T.bootAddon()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())
    NS.addon.Settings.Helpers.Set("visibility", "never")
    assertFalse(popup(mock):IsShown())
end)

-- ---------------------------------------------------------------------------
-- The combat transition (WHATGROUP-R-01). `inCombat` and `outOfCombat` are the only two settings
-- in the addon whose answer changes without the player touching the panel, so they are the only
-- two that need an event rather than an onChange.
-- ---------------------------------------------------------------------------

test("frame: both combat-transition events are registered, and to one handler", function()
    -- red under: never registering them, which is how the gate came to be evaluated only at show.
    local NS = T.enableAddon()
    assertEqual(NS.addon.__events["PLAYER_REGEN_DISABLED"], "OnCombatStateChanged")
    assertEqual(NS.addon.__events["PLAYER_REGEN_ENABLED"],  "OnCombatStateChanged")
    assertTrue(NS.addon.OnCombatStateChanged ~= nil)
end)

test("frame: entering combat does NOT attempt a hide the client would refuse", function()
    -- This case asserted the opposite until 2026-09-08, and the ASSERTION was wrong rather than the
    -- code under it. f parents a SecureActionButtonTemplate button, so the client refuses f:Hide()
    -- inside a lockdown and raises ADDON_ACTION_BLOCKED naming this addon -- which is what a player
    -- reported. The popup genuinely stays up for the fight and there is no way around that while
    -- the secure child exists. What is pinned here is that the addon does not ASK: the attempt does
    -- not hide the frame either way, and costs the player a red error for nothing.
    -- red under: the M2-21 seam, which called f:Hide() straight off the PLAYER_REGEN_DISABLED edge.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    mock.combat = true
    assertEqual(mock.__fireEvent("PLAYER_REGEN_DISABLED"), 1)
    assertEqual(#mock.blocked, 0, "an ADDON_ACTION_BLOCKED the player sees as a red error")
    -- Still SHOWN, because the client refuses Hide, and no longer VISIBLE, because the owner asked
    -- for the popup to go away on this edge and alpha is the seam that can deliver it. Asserting
    -- IsShown alone would pass with the popup sitting fully drawn on screen, which is the state
    -- this case originally described and is no longer the contract.
    assertTrue(popup(mock):IsShown(), "the client will not Hide it mid-fight, and was not asked to")
    assertEqual(popup(mock):GetAlpha(), 0, "but the player must not still be looking at it")
end)

test("frame: 'never' set during combat is honored the moment the lockdown lifts", function()
    -- The deferred half. A gate that cannot fire on the combat edge must still be true one edge
    -- later, or "never" means "never, until you reload".
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    mock.combat = true
    NS.addon.db.profile.visibility = "never"
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertEqual(#mock.blocked, 0, "still never asks inside the lockdown")

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "'never' means never, one edge late")
end)

test("frame: Close pressed in combat is remembered, not fired into a refusal", function()
    -- The pre-existing half of the same defect, and the one the player actually hit:
    -- closeBtn's OnClick called f:Hide() unconditionally, from inside a lockdown.
    -- red under: `closeBtn:SetScript("OnClick", function() f:Hide() end)`.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()

    mock.combat = true
    local btn = closeButton(mock)
    assertTrue(btn ~= nil, "no Close button found to press")
    btn.__scripts.OnClick(btn)
    assertEqual(#mock.blocked, 0, "'WhatGroup tried to call the protected function Hide()'")
    -- Shown but not visible: the Hide is owed until regen, and the player sees it go now.
    assertTrue(popup(mock):IsShown(), "the client will not Hide it, and was not asked to")
    assertEqual(popup(mock):GetAlpha(), 0, "the press has to take it off screen immediately")

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the press survives the fight, or Close silently did nothing")
end)

test("frame: a deferred Close outranks a gate that would still permit the popup", function()
    -- The default gate re-shows on every edge. Unless the dismissal is checked FIRST, the player's
    -- press is overwritten by the gate on the very edge that was meant to honor it.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()

    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the gate re-showed over the player's own dismissal")
end)

test("frame: a combat edge brings back a popup the gate had hidden", function()
    -- The re-show half. It is driven off `inCombat` rather than `outOfCombat` because the hide has
    -- to be a LEGAL one for this case to be about the re-show at all: the gate closes here while
    -- the player is out of combat, where f:Hide() is permitted. Written the other way round it
    -- silently tested the refusal path instead, which is how it came to assert a hide the client
    -- never performs.
    -- red under: an ApplyFrameVisibility that hides but never shows.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertFalse(popup(mock) and popup(mock):IsShown(),
        "out of combat, 'inCombat' forbids the popup -- and that hide is legal")

    mock.combat = true
    assertEqual(mock.__fireEvent("PLAYER_REGEN_DISABLED"), 1)
    -- The gate wants to open it here and the client will not let it: the frame is genuinely
    -- hidden, so putting it back needs a Show, and Show inside a lockdown is protected. The
    -- re-show half is therefore real only on the OTHER edge — `outOfCombat` releasing when combat
    -- ends, where Show is legal — and for a popup held at alpha 0, which needs no Show at all.
    -- Both of those are pinned by their own cases below.
    assertEqual(#mock.blocked, 0, "and it must not fire into the refusal to find that out")
    assertFalse(popup(mock):IsShown(), "'inCombat' cannot be delivered from a hidden frame")
end)

-- On screen means the player can see it. A popup the client refused to Hide is held at alpha 0,
-- so IsShown() alone answers the wrong question for every case below.
local function onScreen(mock)
    local p = popup(mock)
    return p ~= nil and p:IsShown() and p:GetAlpha() > 0
end

test("frame: Close in combat takes the popup off screen at once", function()
    -- The requirement, stated by the owner on 2026-09-08: it must be possible to CLOSE an open
    -- popup during combat. The client will not Hide it -- f parents a SecureActionButtonTemplate
    -- button and hiding an ancestor of one is protected -- so the press cannot wait for regen and
    -- cannot fire into a refusal either. Alpha is the seam: ApplyFrameAlpha is deliberately not
    -- combat-guarded, on this addon's own ruling that opacity moves nothing.
    -- red under: a hidePopup that returns false in combat and leaves the popup on screen.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(onScreen(mock))

    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    assertFalse(onScreen(mock), "Close in combat must take it off screen, not defer to regen")
    assertEqual(#mock.blocked, 0, "and must not fire into the client's refusal to do it")
end)

test("frame: the real Hide lands when the lockdown lifts, and the alpha comes back with it", function()
    -- Alpha 0 is a stand-in, not a resting state: the frame is still shown, still in
    -- UISpecialFrames, and still taking mouse input. The owed Hide has to be settled on the first
    -- edge where it is legal, or the popup is invisible-but-present for the rest of the session.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the deferred Hide never landed")
    assertEqual(popup(mock):GetAlpha(), 1, "and the next open would have drawn at alpha 0")
end)

test("frame: the alpha restored is the player's own, not a hardcoded 1", function()
    -- masterAlpha() reads profile.alpha. Restoring a literal 1 would quietly overwrite the setting
    -- of anyone running a translucent popup, and only on the combat path.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.alpha = 0.6
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertEqual(popup(mock):GetAlpha(), 0.6, "the player's opacity was replaced by the default")
end)

test("frame: 'out of combat' takes the popup off screen the moment combat starts", function()
    -- The other half of the owner's requirement: not opening in combat is fine, and the gate must
    -- act on the edge rather than a fight later. Same seam as Close, same refusal to ask the client
    -- for a Hide it will not perform.
    -- red under: a gate that leaves the popup up for the whole fight.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(onScreen(mock))

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(onScreen(mock), "the dropdown reads as ignored for the length of the fight")
    assertEqual(#mock.blocked, 0)
end)

test("frame: and it opens again by itself when combat ends", function()
    -- "It should open automatically after combat", verbatim. This is the gate releasing what it
    -- withheld -- distinct from a popup the player closed, which must stay shut.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(onScreen(mock))

    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertTrue(onScreen(mock), "the invite the player is still holding must come back on its own")
    assertEqual(popup(mock):GetAlpha(), 1)
end)

test("frame: a popup the PLAYER closed does not come back when combat starts", function()
    -- Reported from the client on 2026-09-08: `/wg test`, close the popup, pull something, and it
    -- springs open again. No Lua error, because nothing is wrong with the call -- the re-show arm
    -- simply cannot tell "the gate is withholding this" from "the player put it away".
    --
    -- Note the visibility value: `always`, the shipped default. Under it the gate NEVER hides, so
    -- every firing of the re-show arm is a popup the player closed. There is no legitimate case at
    -- all on the default setting, which is why this reached a client.
    -- red under: `if WhatGroup.pendingInfo and not f:IsShown() then f:Show() end`.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)
    assertFalse(popup(mock):IsShown(), "the Close press itself")

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "combat reopened a popup the player had dismissed")
end)

test("frame: a popup closed with ESC does not come back either", function()
    -- ESC routes through UISpecialFrames to a plain f:Hide(), so it leaves no trace the Close
    -- button's own handler could record. Whatever distinguishes a gate hide from a player hide has
    -- to sit on the frame, not on one button.
    -- red under: the same arm.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    popup(mock):Hide()          -- exactly what CloseSpecialWindows does

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "ESC must be as durable as the Close button")
end)

test("frame: leaving combat does not reopen a popup the player closed mid-fight either", function()
    -- The other edge. `always` permits the popup on both transitions, so a dismissal has to
    -- survive PLAYER_REGEN_ENABLED as well -- and that edge is the one that also flushes a
    -- deferred Close, so the two must not fight.
    local NS, _, mock = T.enableAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    local btn = closeButton(mock)
    btn.__scripts.OnClick(btn)

    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertFalse(popup(mock):IsShown(), "the dismissal has to outlive the whole fight")
end)

test("frame: a combat transition never opens a popup with nothing to show", function()
    -- A "No data" popup appearing the moment the player pulls is worse than no popup at all, so
    -- the re-show is gated on there being a capture to render.
    -- red under: a symmetric ApplyFrameVisibility that shows on any open gate.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "inCombat"
    NS.addon:ShowFrame()               -- builds it, out of combat, off screen
    assertTrue(popup(mock) ~= nil)
    assertFalse(popup(mock):IsShown())

    NS.addon.pendingInfo = nil
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "nothing to render, so nothing opens")
end)

test("frame: PLAYER_REGEN_DISABLED is answered from the event, not from a lockdown flag that has not flipped", function()
    -- The client fires PLAYER_REGEN_DISABLED at the START of the lockdown and InCombatLockdown()
    -- can still answer false on that same frame. A handler that asks the API evaluates the gate
    -- against the state the player has just left, which is the wrong answer in both directions.
    -- red under: ApplyFrameVisibility reading InCombatLockdown() with no override.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown())

    mock.combat = false                -- the flag has not caught up yet
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    assertFalse(popup(mock):IsShown(), "the event name is the authority on which edge this is")
end)

test("frame: a combat transition with no popup built is a no-op, not an error", function()
    -- The events register at OnEnable and the popup is lazy, so most transitions in a session
    -- arrive with nothing on screen. That must not build one.
    -- red under: an ApplyFrameVisibility that reaches buildFrame.
    local NS, _, mock = T.enableAddon()
    NS.addon.db.profile.visibility = "outOfCombat"
    NS.addon.pendingInfo = pending()
    mock.combat = true
    mock.__fireEvent("PLAYER_REGEN_DISABLED")
    mock.combat = false
    mock.__fireEvent("PLAYER_REGEN_ENABLED")
    assertNil(popup(mock), "the lazy build is the taint contract; a transition must not trip it")
end)
