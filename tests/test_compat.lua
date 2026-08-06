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

test("compat: GetSpellCooldownRemaining is 0 for a spell that is ready", function()
    local NS = T.newAddon()
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
end)

test("compat: GetSpellCooldownRemaining counts down from start + duration", function()
    local NS, _, mock = T.newAddon()
    mock.now = 10000
    mock.spellCooldowns[445269] =
        { startTime = 9000, duration = 28800, isEnabled = true, modRate = 1 }
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 27800)
end)

test("compat: GetSpellCooldownRemaining is 0 once the cooldown has elapsed", function()
    local NS, _, mock = T.newAddon()
    mock.now = 40000
    mock.spellCooldowns[445269] =
        { startTime = 9000, duration = 28800, isEnabled = true, modRate = 1 }
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0,
        "an expired cooldown must never report negative remaining")
end)

-- The GCD is a cooldown by the API's reckoning, so without this floor every teleport would read
-- "on cooldown" for 1.5s after any unrelated cast — a flicker on a spell whose real cooldown is
-- eight hours.
test("compat: GetSpellCooldownRemaining ignores a global-cooldown-length window", function()
    local NS, _, mock = T.newAddon()
    mock.now = 10000
    mock.spellCooldowns[445269] =
        { startTime = 9999.5, duration = 1.5, isEnabled = true, modRate = 1 }
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
end)

-- isEnabled = false means "do not draw a cooldown" (the spell is mid-cast), not "unusable
-- forever". Treating it as a cooldown would grey the button out during any cast.
test("compat: GetSpellCooldownRemaining reports 0 when the cooldown is disabled", function()
    local NS, _, mock = T.newAddon()
    mock.now = 10000
    mock.spellCooldowns[445269] =
        { startTime = 9000, duration = 28800, isEnabled = false, modRate = 1 }
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
end)

test("compat: GetSpellCooldownRemaining returns 0 when the API is missing", function()
    local NS, env = T.newAddon()
    env.C_Spell.GetSpellCooldown = nil
    env.GetSpellCooldown = nil
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
end)

test("compat: GetActivityInfoTable passes the table through", function()
    local NS, _, mock = T.newAddon()
    mock.activities[500] = { mapID = 2652, fullName = "The Stonevault" }
    assertEqual(NS.Compat.GetActivityInfoTable(500).mapID, 2652)
end)

-- ---------------------------------------------------------------------------
-- Legacy fallbacks — every shim must degrade rather than throw when the
-- modern C_Spell namespace is missing or returns nil. Simulated by removing
-- C_Spell from the mock env, which is exactly what an older client looks like.
-- ---------------------------------------------------------------------------

test("compat: GetSpellName falls back to the legacy GetSpellInfo global", function()
    local NS, env = T.newAddon()
    env.C_Spell = nil
    env.GetSpellInfo = function(id) return "Legacy " .. id end
    assertEqual(NS.Compat.GetSpellName(5), "Legacy 5")
end)

test("compat: GetSpellName falls through when the modern API returns nil", function()
    local NS, env = T.newAddon()
    env.C_Spell = { GetSpellName = function() return nil end }
    env.GetSpellInfo = function(id) return "Legacy " .. id end
    assertEqual(NS.Compat.GetSpellName(5), "Legacy 5",
        "a nil from the modern API is not an answer")
end)

test("compat: GetSpellName returns nil when no API exists at all", function()
    local NS, env = T.newAddon()
    env.C_Spell = nil
    env.GetSpellInfo = nil
    assertNil(NS.Compat.GetSpellName(5))
end)

test("compat: GetSpellTexture falls back to the legacy global", function()
    local NS, env = T.newAddon()
    env.C_Spell = nil
    env.GetSpellTexture = function() return 999 end
    assertEqual(NS.Compat.GetSpellTexture(1), 999)
end)

test("compat: GetSpellTexture returns nil with no API (the caller supplies a default)", function()
    local NS, env = T.newAddon()
    env.C_Spell = nil
    env.GetSpellTexture = nil
    assertNil(NS.Compat.GetSpellTexture(1))
end)

test("compat: GetSpellLink returns nil with no API (the caller renders plain text)", function()
    local NS, env = T.newAddon()
    env.C_Spell = nil
    assertNil(NS.Compat.GetSpellLink(1))
end)

test("compat: IsSpellKnown normalizes to a plain boolean", function()
    local NS, env = T.newAddon()
    env.IsSpellKnown = function() return 1 end   -- a truthy non-boolean
    assertEqual(NS.Compat.IsSpellKnown(1), true)
end)

test("compat: IsSpellKnown returns false when the API is missing", function()
    local NS, env = T.newAddon()
    env.IsSpellKnown = nil
    assertEqual(NS.Compat.IsSpellKnown(1), false)
end)

test("compat: GetActivityInfoTable returns nil for an unknown activity", function()
    local NS = T.newAddon()
    assertNil(NS.Compat.GetActivityInfoTable(999999))
end)

test("compat: GetActivityInfoTable returns nil when C_LFGList is absent", function()
    local NS, env = T.newAddon()
    env.C_LFGList = nil
    assertNil(NS.Compat.GetActivityInfoTable(500))
end)

test("compat: Compat is the sole namespace the addon reads variant APIs through", function()
    local NS = T.newAddon()
    for _, fn in ipairs({ "GetSpellName", "GetSpellTexture",
                          "GetSpellLink", "IsSpellKnown", "GetActivityInfoTable" }) do
        assertEqual(type(NS.Compat[fn]), "function", "NS.Compat." .. fn .. " is missing")
    end
end)
