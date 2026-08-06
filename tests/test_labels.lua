-- tests/test_labels.lua — group-type / playstyle labels + teleport pick.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

test("labels: GetGroupTypeLabel Mythic+", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ isMythicPlus = true }), "Mythic+")
end)

test("labels: GetGroupTypeLabel Dungeon by categoryID", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ categoryID = 1 }), "Dungeon")
end)

test("labels: GetGroupTypeLabel Raid by player count", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ maxNumPlayers = 20 }), "Raid")
end)

test("labels: GetGroupTypeLabel fallback Group", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({}), "Group")
end)

test("labels: GetPlaystyleLabel prefers playstyleString", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetPlaystyleLabel({ playstyleString = "Custom" }), "Custom")
end)

test("labels: GetPlaystyleLabel enum lookup when string empty", function()
    local NS, env = T.newAddon()
    local ps = env.Enum.LFGEntryGeneralPlaystyle.FunSerious
    assertEqual(
        NS.addon.Labels.GetPlaystyleLabel({ playstyleString = "", generalPlaystyle = ps }),
        "Fun (Serious)")
end)

test("teleport: GetTeleportSpell picks the known spell from a list", function()
    local NS, _, mock = T.newAddon()
    NS.TeleportSpells[9999] = { 111, 222 }
    mock.knownSpells[222] = true
    local sid, known = NS.addon:GetTeleportSpell(nil, 9999)
    assertEqual(sid, 222)
    assertTrue(known)
end)

test("teleport: GetTeleportSpell returns first + false when none known", function()
    local NS = T.newAddon()
    NS.TeleportSpells[8888] = { 333, 444 }
    local sid, known = NS.addon:GetTeleportSpell(nil, 8888)
    assertEqual(sid, 333)
    assertFalse(known)
end)

test("teleport: GetTeleportSpell nil when no mapping", function()
    local NS = T.newAddon()
    assertNil(NS.addon:GetTeleportSpell(nil, 123456))
end)

-- ---------------------------------------------------------------------------
-- GetGroupTypeLabel — the full branch ladder, in precedence order
-- ---------------------------------------------------------------------------

test("labels: GetGroupTypeLabel Raid (Current)", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ isCurrentRaid = true }), "Raid (Current)")
end)

test("labels: GetGroupTypeLabel Heroic Raid", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ isHeroicRaid = true }), "Heroic Raid")
end)

test("labels: GetGroupTypeLabel PvP by categoryID 2", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ categoryID = 2 }), "PvP")
end)

test("labels: GetGroupTypeLabel Dungeon by a small player count", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ maxNumPlayers = 5 }), "Dungeon")
end)

test("labels: GetGroupTypeLabel treats exactly 10 players as a Raid", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ maxNumPlayers = 10 }), "Raid")
end)

test("labels: GetGroupTypeLabel treats 9 players as a Dungeon", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ maxNumPlayers = 9 }), "Dungeon")
end)

test("labels: GetGroupTypeLabel falls back to Group at zero players", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ maxNumPlayers = 0 }), "Group")
end)

test("labels: Mythic+ outranks every other signal", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({
        isMythicPlus = true, isCurrentRaid = true, categoryID = 2, maxNumPlayers = 20,
    }), "Mythic+")
end)

test("labels: the raid flags outrank categoryID", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ isCurrentRaid = true, categoryID = 1 }),
        "Raid (Current)")
end)

test("labels: categoryID outranks the player count", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetGroupTypeLabel({ categoryID = 2, maxNumPlayers = 20 }), "PvP")
end)

-- ---------------------------------------------------------------------------
-- GetPlaystyleLabel
-- ---------------------------------------------------------------------------

test("labels: every playstyle enum maps to its Blizzard-localized wording", function()
    local NS, env = T.newAddon()
    local E = env.Enum.LFGEntryGeneralPlaystyle
    local want = {
        [E.Learning]   = "Learning",
        [E.FunRelaxed] = "Fun (Relaxed)",
        [E.FunSerious] = "Fun (Serious)",
        [E.Expert]     = "Expert",
    }
    for enum, label in pairs(want) do
        assertEqual(NS.addon.Labels.GetPlaystyleLabel({
            playstyleString = "", generalPlaystyle = enum }), label)
    end
end)

test("labels: playstyle None (0) has no label", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetPlaystyleLabel({
        playstyleString = "", generalPlaystyle = 0 }), "")
end)

test("labels: an unmapped playstyle enum yields an empty label, not nil", function()
    local NS = T.newAddon()
    assertEqual(NS.addon.Labels.GetPlaystyleLabel({
        playstyleString = "", generalPlaystyle = 99 }), "")
end)

test("labels: playstyleString wins even when the enum is also set", function()
    local NS, env = T.newAddon()
    assertEqual(NS.addon.Labels.GetPlaystyleLabel({
        playstyleString  = "Chill Run",
        generalPlaystyle = env.Enum.LFGEntryGeneralPlaystyle.Expert,
    }), "Chill Run")
end)

test("labels: a nil playstyleString falls through to the enum", function()
    local NS, env = T.newAddon()
    assertEqual(NS.addon.Labels.GetPlaystyleLabel({
        generalPlaystyle = env.Enum.LFGEntryGeneralPlaystyle.Learning }), "Learning")
end)

-- ---------------------------------------------------------------------------
-- GetTeleportSpell
-- ---------------------------------------------------------------------------

test("teleport: a scalar mapping returns (spellID, known) directly", function()
    local NS, _, mock = T.newAddon()
    NS.TeleportSpells[7777] = 555
    mock.knownSpells[555] = true
    local sid, known = NS.addon:GetTeleportSpell(nil, 7777)
    assertEqual(sid, 555)
    assertTrue(known)
end)

test("teleport: a scalar mapping the player has not learned reports known=false", function()
    local NS = T.newAddon()
    NS.TeleportSpells[7778] = 556
    local sid, known = NS.addon:GetTeleportSpell(nil, 7778)
    assertEqual(sid, 556)
    assertFalse(known)
end)

test("teleport: mapID takes precedence over activityID", function()
    local NS, _, mock = T.newAddon()
    NS.TeleportSpells[7779] = 111      -- mapID row
    NS.TeleportSpells[8889] = 222      -- activityID row
    mock.knownSpells[222] = true
    assertEqual(NS.addon:GetTeleportSpell(8889, 7779), 111)
end)

test("teleport: activityID is the fallback when the mapID is unmapped", function()
    local NS = T.newAddon()
    NS.TeleportSpells[8890] = 333
    assertEqual(NS.addon:GetTeleportSpell(8890, 999999), 333)
end)

test("teleport: a nil mapID and nil activityID resolve to nothing", function()
    local NS = T.newAddon()
    assertNil(NS.addon:GetTeleportSpell(nil, nil))
end)

test("teleport: the FIRST known spell in a candidate list wins", function()
    local NS, _, mock = T.newAddon()
    NS.TeleportSpells[7780] = { 10, 20, 30 }
    mock.knownSpells[20] = true
    mock.knownSpells[30] = true
    local sid, known = NS.addon:GetTeleportSpell(nil, 7780)
    assertEqual(sid, 20, "list order decides between two learned candidates")
    assertTrue(known)
end)

test("teleport: the shipped mapping table is keyed by numbers only", function()
    local NS = T.newAddon()
    local n = 0
    for k, v in pairs(NS.TeleportSpells) do
        assertEqual(type(k), "number", "TeleportSpells keys must be mapIDs")
        local t = type(v)
        assertTrue(t == "number" or t == "table",
            "a mapping is a spellID or a candidate list, got " .. t)
        n = n + 1
    end
    assertTrue(n > 0, "the shipped table must not be empty")
end)

-- The Midnight rows are the ones a name-based lookup gets wrong: "Path of the Fractured Core"
-- contains neither "Nexus-Point Xenas" nor anything else derivable from the dungeon, so the wiki
-- and Wowhead have both handed back a near-miss ID here (1254553, one digit off, is a different
-- spell named "Hero's Path"). These four are pinned against a spellbook dump — every learned
-- "Path of ..." with its spellID, read off a character that owns them.
test("teleport: the Midnight Keystone Hero rows match the spellbook-verified IDs", function()
    local NS = T.newAddon()
    for mapID, spellID in pairs({
        [2805] = 1254400,   -- Windrunner Spire    — Path of the Windrunners
        [2811] = 1254572,   -- Magisters' Terrace  — Path of Devoted Magistry
        [2874] = 1254559,   -- Maisara Caverns     — Path of Cavernous Depths
        [2915] = 1254563,   -- Nexus-Point Xenas   — Path of the Fractured Core
    }) do
        assertEqual(NS.TeleportSpells[mapID], spellID,
            "mapID " .. mapID .. " must map to its verified Keystone Hero spell")
    end
end)

-- Siege of Boralus shipped with an unconfirmed wiki ID as its only value, so a player holding the
-- real spell saw the same greyed-out row. The verified spell must stay FIRST: that is the entry
-- pickKnownSpell falls back to when the player knows neither candidate.
test("teleport: Siege of Boralus offers the spellbook-verified spell first", function()
    local NS = T.newAddon()
    assertEqual(NS.TeleportSpells[1822][1], 445418)
    local sid, known = NS.addon:GetTeleportSpell(nil, 1822)
    assertEqual(sid, 445418, "an unknown-to-this-player row falls back to the verified candidate")
    assertFalse(known)
end)
