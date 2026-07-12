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
