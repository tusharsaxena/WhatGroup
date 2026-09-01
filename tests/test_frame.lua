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
    local NS, env, mock = T.bootAddon()
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
    assertEqual(mock.fireAceTimers(), 1, "exactly one repeating timer is armed")
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
    assertEqual(mock.fireAceTimers(), 0,
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
    assertEqual(mock.fireAceTimers(), 1, "each show must replace the ticker, never stack one")
end)

test("frame: a ready teleport arms no ticker at all", function()
    local NS, _, mock = T.bootAddon()
    mock.spellNames[445269] = "Path of the Corrupted Foundry"
    mock.knownSpells[445269] = true
    NS.TeleportSpells[2652] = 445269
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    assertEqual(mock.fireAceTimers(), 0, "nothing to count down")
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
    mock.fireAceTimers()

    local btn = teleportBtn(mock)
    assertEqual(btn:GetAttribute("macrotext"), "/cast Path of the Corrupted Foundry",
        "the popup must become usable without being closed and re-opened")
    assertEqual(btn:GetAlpha(), 1.0)
    assertFalse(btn.__textures[1]:IsDesaturated())
    assertFalse(fields(mock).note:IsShown())
    assertEqual(mock.fireAceTimers(), 0, "and the ticker stops itself once there is nothing left")
end)

-- The note carries BOTH reasons a teleport is unusable, in the same place, so the popup never just
-- greys out and says nothing.
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
test("frame: an unlearned teleport is never labelled as on cooldown", function()
    local NS, _, mock = T.bootAddon()
    NS.TeleportSpells[2652] = 445269   -- never marked known
    onCooldown(mock, 445269, 28692)
    NS.addon.pendingInfo = pending({ mapID = 2652 })
    NS.addon:ShowFrame()
    local note = fields(mock).note
    assertTrue(note:GetText():find("not learned", 1, true) ~= nil)
    assertNil(note:GetText():find("7h 58m", 1, true))
    assertEqual(mock.fireAceTimers(), 0, "and it arms no countdown for a spell they cannot cast")
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

test("frame: once built, showing during combat is allowed", function()
    local NS, _, mock = T.bootAddon()
    NS.addon.pendingInfo = pending()
    NS.addon:ShowFrame()          -- build out of combat
    popup(mock):Hide()
    mock.combat = true
    NS.addon:ShowFrame()
    assertTrue(popup(mock):IsShown(), "no defer needed once the frame exists")
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
    local titleBar
    for _, fr in ipairs(mock.frames) do
        if fr.__scripts.OnMouseUp then titleBar = fr end
    end
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
