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

test("compat: the harness answers a learned spell through C_SpellBook, not the global", function()
    -- The mock models both readers (#15). With the global gone the answer can only have come
    -- from the rung the ladder asks first, so the learned/unlearned cases measure that rung.
    local NS, env, mock = T.newAddon()
    mock.knownSpells[99] = true
    env.IsSpellKnown = nil
    assertEqual(NS.Compat.IsSpellKnown(99), true)
    assertEqual(NS.Compat.IsSpellKnown(12345), false)
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
-- forever". Treating it as a cooldown would gray the button out during any cast.
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
    env.C_SpellBook = nil                        -- so the global rung is the one asked
    env.IsSpellKnown = function() return 1 end   -- a truthy non-boolean
    assertEqual(NS.Compat.IsSpellKnown(1), true)
end)

test("compat: IsSpellKnown returns false when the API is missing", function()
    local NS, env = T.newAddon()
    env.C_SpellBook = nil   -- both readers, or the modern rung answers and the case tests nothing
    env.IsSpellKnown = nil
    assertEqual(NS.Compat.IsSpellKnown(1), false)
end)

-- The IsSpellKnown ladder: C_SpellBook.IsSpellKnown, then the bare global, then false. The rung
-- was built from Blizzard's generated API documentation on live (SpellBookDocumentation.lua,
-- `IsSpellKnown(spellID, spellBank = "Player") -> isKnown`), not from an in-client observation;
-- docs/smoke-tests.md § 7a is where the two APIs are checked to agree.
test("compat: IsSpellKnown asks C_SpellBook first when both APIs exist", function()
    local NS, env = T.newAddon()
    local calls, argc, firstArg = {}, nil, nil
    env.C_SpellBook = { IsSpellKnown = function(...)
        calls[#calls + 1] = "C_SpellBook"
        argc, firstArg = select("#", ...), ...
        return true
    end }
    env.IsSpellKnown = function() calls[#calls + 1] = "global" return false end
    assertEqual(NS.Compat.IsSpellKnown(42), true)
    assertEqual(table.concat(calls, ","), "C_SpellBook",
        "the global is the fallback, not a second opinion")
    assertEqual(firstArg, 42)
    assertEqual(argc, 1, "spellBank is left to its documented default (Player)")
end)

test("compat: IsSpellKnown takes a false from C_SpellBook as the answer", function()
    local NS, env = T.newAddon()
    env.C_SpellBook = { IsSpellKnown = function() return false end }
    env.IsSpellKnown = function() return true end
    assertEqual(NS.Compat.IsSpellKnown(42), false,
        "falling through on false would make the ladder 'either says yes' and hide a disagreement")
end)

test("compat: IsSpellKnown uses the global when C_SpellBook or its member is absent", function()
    local NS, env = T.newAddon()
    env.IsSpellKnown = function(id) return id == 7 end
    env.C_SpellBook = nil
    assertEqual(NS.Compat.IsSpellKnown(7), true)
    assertEqual(NS.Compat.IsSpellKnown(8), false)
    env.C_SpellBook = {}   -- the namespace without the member: a mid-migration client
    assertEqual(NS.Compat.IsSpellKnown(7), true)
end)

test("compat: IsSpellKnown returns false when neither API exists", function()
    local NS, env = T.newAddon()
    env.C_SpellBook = nil
    env.IsSpellKnown = nil
    assertEqual(NS.Compat.IsSpellKnown(7), false)
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

-- The chat-link path: Blizzard's `addon` link type, whose registered handler re-raises the click
-- as EventRegistry's "SetItemRef" event (ItemRefHandlersShared.lua:278-281 at 12.1.0). Both halves
-- have to be there, because a link of that type with nothing to hear the event is a dead link.
test("compat: AddOnLinkType answers Blizzard's addon link type", function()
    local NS = T.newAddon()
    assertEqual(NS.Compat.AddOnLinkType(), "addon")
end)

test("compat: AddOnLinkType is nil without LinkTypes.AddOn", function()
    local NS, env = T.newAddon()
    env.LinkTypes = {}
    assertNil(NS.Compat.AddOnLinkType())
    env.LinkTypes = nil
    assertNil(NS.Compat.AddOnLinkType())
end)

test("compat: AddOnLinkType is nil without EventRegistry:RegisterCallback", function()
    local NS, env = T.newAddon()
    env.EventRegistry = {}
    assertNil(NS.Compat.AddOnLinkType(), "the registry without the member")
    env.EventRegistry = nil
    assertNil(NS.Compat.AddOnLinkType())
end)

test("compat: Compat is the sole namespace the addon reads variant APIs through", function()
    local NS = T.newAddon()
    for _, fn in ipairs({ "GetSpellName", "GetSpellTexture", "GetSpellLink", "IsSpellKnown",
                          "GetActivityInfoTable", "AddOnLinkType" }) do
        assertEqual(type(NS.Compat[fn]), "function", "NS.Compat." .. fn .. " is missing")
    end
end)

-- ---------------------------------------------------------------------------
-- Characterization: what the cooldown shims hand their callers (LibKa0s v1.55.0 adoption)
-- ---------------------------------------------------------------------------
--
-- Written BEFORE core/Compat.lua moved its spell readers onto LibKa0s-Compat-1.0, and green against
-- the host's own ladders, so the move is held to "behaves the same" rather than "still runs".
-- GetSpellCooldownTimes is spread straight into Cooldown:SetCooldown (modules/Frame.lua), whose
-- THIRD parameter is modRate, so its arity is part of what it answers: a third value would be read
-- as a rate.

local function pack(...) return { n = select("#", ...), ... } end

test("compat: GetSpellCooldownTimes hands SetCooldown exactly two values on every rung", function()
    local NS, env, mock = T.newAddon()
    mock.spellCooldowns[445269] =
        { startTime = 9000, duration = 28800, isEnabled = true, modRate = 0.5 }
    local r = pack(NS.Compat.GetSpellCooldownTimes(445269))
    assertEqual(r.n, 2, "modern rung: start and duration, never modRate")
    assertEqual(r[1], 9000)
    assertEqual(r[2], 28800)

    r = pack(NS.Compat.GetSpellCooldownTimes(1))           -- no cooldown table: the client's nil
    assertEqual(r.n, 2)
    assertEqual(r[1], 0)
    assertEqual(r[2], 0)

    env.C_Spell = nil
    env.GetSpellCooldown = function() return 5, 10, 1, 0.5 end
    r = pack(NS.Compat.GetSpellCooldownTimes(1))
    assertEqual(r.n, 2, "legacy rung: the global's enabled flag and modRate are dropped")
    assertEqual(r[1], 5)
    assertEqual(r[2], 10)

    env.GetSpellCooldown = function() return nil end
    r = pack(NS.Compat.GetSpellCooldownTimes(1))
    assertEqual(r.n, 2)
    assertEqual(r[1], 0)
    assertEqual(r[2], 0)

    env.GetSpellCooldown = nil
    r = pack(NS.Compat.GetSpellCooldownTimes(1))
    assertEqual(r.n, 2, "no rung at all")
    assertEqual(r[1], 0)
    assertEqual(r[2], 0)
end)

test("compat: GetSpellCooldownRemaining reads a legacy isEnabled of 0 as disabled, 1 and nil as enabled",
     function()
    local NS, env, mock = T.newAddon()
    mock.now = 10000
    env.C_Spell = nil
    local enabled
    env.GetSpellCooldown = function() return 9000, 28800, enabled, 1 end
    enabled = 0
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
    enabled = 1
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 27800)
    enabled = nil
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 27800)
end)

test("compat: GetSpellCooldownRemaining reads a modern table with no isEnabled as enabled", function()
    local NS, _, mock = T.newAddon()
    mock.now = 10000
    mock.spellCooldowns[445269] = { startTime = 9000, duration = 28800 }
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 27800)
end)

test("compat: GetSpellCooldownRemaining is 0 for a cooldown table with no start or duration", function()
    local NS, _, mock = T.newAddon()
    mock.spellCooldowns[445269] = { isEnabled = true }
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
    mock.spellCooldowns[445269] = { startTime = 9000, isEnabled = true }
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
end)

test("compat: GetSpellName and GetSpellTexture answer the popup's numeric teleport ids", function()
    -- What modules/Frame.lua reads for the teleport button: a localized name for the /cast macro and
    -- an icon file id. The ids come from defaults/TeleportSpells.lua, so they are always numbers.
    local NS, _, mock = T.newAddon()
    mock.spellNames[445269] = "Path of the Corrupted Foundry"
    assertEqual(NS.Compat.GetSpellName(445269), "Path of the Corrupted Foundry")
    assertEqual(NS.Compat.GetSpellTexture(445269), 100000 + 445269)
end)

-- ---------------------------------------------------------------------------
-- LibKa0s-Compat-1.0: what the adoption changed, pinned
-- ---------------------------------------------------------------------------

test("compat: GetSpellName and GetSpellTexture ARE LibKa0s-Compat-1.0's members", function()
    -- Delegation by identity, not by wrapper: a second body here would be the copy the major exists
    -- to retire, and would drift from it the way the nine copies did.
    local NS, env = T.newAddon()
    local lib = env.LibStub("LibKa0s-Compat-1.0", true)
    assertTrue(lib ~= nil, "the harness loads the library")
    assertEqual(NS.Compat.GetSpellName, lib.GetSpellName)
    assertEqual(NS.Compat.GetSpellTexture, lib.GetSpellTexture)
end)

test("compat: GetSpellName falls through a plain empty string from the modern rung", function()
    -- A behavior the library brought (compat.md 8.6): "" is not an answer, so the next rung is
    -- asked. The host's own ladder returned the "" as the name.
    local NS, env = T.newAddon()
    env.C_Spell = { GetSpellName = function() return "" end }
    env.GetSpellInfo = function(id) return "Legacy " .. id end
    assertEqual(NS.Compat.GetSpellName(5), "Legacy 5")
end)

test("compat: GetSpellName reads C_Spell.GetSpellInfo's name when GetSpellName has none", function()
    local NS, env = T.newAddon()
    env.C_Spell = { GetSpellName = function() return nil end,
                    GetSpellInfo = function() return { name = "From Info" } end }
    env.GetSpellInfo = function() return "Legacy" end
    assertEqual(NS.Compat.GetSpellName(5), "From Info", "the middle rung comes before the global")
end)

test("compat: an id outside the spell domain answers the no-answer value without asking the client",
     function()
    local NS, env = T.newAddon()
    local calls = 0
    local function count() calls = calls + 1 end
    env.C_Spell = { GetSpellName = count, GetSpellInfo = count, GetSpellTexture = count,
                    GetSpellCooldown = count }
    assertNil(NS.Compat.GetSpellName(nil))
    assertNil(NS.Compat.GetSpellTexture({}))
    local r = pack(NS.Compat.GetSpellCooldownTimes(nil))
    assertEqual(r.n, 2)
    assertEqual(r[1], 0)
    assertEqual(r[2], 0)
    assertEqual(NS.Compat.GetSpellCooldownRemaining(false), 0)
    assertEqual(calls, 0, "no rung is called with a nil, a table or a boolean")
end)

test("compat: GetSpellTexture hands back one value when the client answers two", function()
    local NS, env = T.newAddon()
    env.C_Spell = { GetSpellTexture = function() return 7, 8 end }
    local r = pack(NS.Compat.GetSpellTexture(1))
    assertEqual(r.n, 1, "the original-icon return is dropped")
    assertEqual(r[1], 7)
end)

test("compat degraded: with LibKa0s absent the spell readers answer the library's absent values",
     function()
    -- The library genuinely ABSENT (its files skipped, testing-§8), never the member stubbed. The
    -- mock still carries every C_Spell rung, which is the point: the reader arm answers what the
    -- library documents for a client with no rung at all, and does not read the client itself.
    local NS, _, mock = T.newAddon{ skip = T.loadAddon.libFiles }
    mock.spellNames[445269] = "Path of the Corrupted Foundry"
    mock.now = 10000
    mock.spellCooldowns[445269] =
        { startTime = 9000, duration = 28800, isEnabled = true, modRate = 1 }
    assertNil(NS.Compat.GetSpellName(445269))
    assertNil(NS.Compat.GetSpellTexture(445269))
    local r = pack(NS.Compat.GetSpellCooldownTimes(445269))
    assertEqual(r.n, 2)
    assertEqual(r[1], 0)
    assertEqual(r[2], 0)
    assertEqual(NS.Compat.GetSpellCooldownRemaining(445269), 0)
    -- What stays this addon's own keeps answering from the client.
    mock.knownSpells[445269] = true
    assertEqual(NS.Compat.IsSpellKnown(445269), true)
    assertTrue(NS.Compat.GetSpellLink(445269):find("Spell 445269", 1, true) ~= nil)
    mock.activities[500] = { mapID = 2652 }
    assertEqual(NS.Compat.GetActivityInfoTable(500).mapID, 2652)
end)
