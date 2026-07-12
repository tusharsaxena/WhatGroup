-- tests/test_compat.lua — NS.Compat.* shims against the WoW mock.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

test("compat: GetSpellName returns the C_Spell name", function()
    local NS, _, mock = T.newAddon()
    mock.spellNames[42] = "Fireball"
    assertEqual(NS.Compat.GetSpellName(42), "Fireball")
end)

test("compat: GetSpellTexture is non-nil (caller supplies default)", function()
    local NS = T.newAddon()
    assertTrue(NS.Compat.GetSpellTexture(5) ~= nil)
end)

test("compat: GetSpellLink returns a hyperlink for the spell", function()
    local NS = T.newAddon()
    assertTrue(NS.Compat.GetSpellLink(7):find("Spell 7") ~= nil)
end)

test("compat: IsSpellKnown true when learned", function()
    local NS, _, mock = T.newAddon()
    mock.knownSpells[99] = true
    assertTrue(NS.Compat.IsSpellKnown(99))
end)

test("compat: IsSpellKnown false when not learned", function()
    local NS = T.newAddon()
    assertFalse(NS.Compat.IsSpellKnown(12345))
end)

test("compat: GetActivityInfoTable passes the table through", function()
    local NS, _, mock = T.newAddon()
    mock.activities[500] = { mapID = 2652, fullName = "The Stonevault" }
    assertEqual(NS.Compat.GetActivityInfoTable(500).mapID, 2652)
end)
