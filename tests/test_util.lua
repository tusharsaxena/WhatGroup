-- tests/test_util.lua — the secret-safe stringifier / chat printer seam
-- (WG-22) and the standalone-window geometry helpers (WG-26), all defined in
-- core/Util.lua.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

test("util: SafeToString handles nil / booleans / strings / numbers", function()
    local NS = T.newAddon()
    assertEqual(NS.SafeToString(nil), "nil")
    assertEqual(NS.SafeToString(true), "true")
    assertEqual(NS.SafeToString(false), "false")
    assertEqual(NS.SafeToString("hi"), "hi")
    assertEqual(NS.SafeToString(42), "42")
end)

test("util: SafeToString yields <secret> for a value that raises in concat", function()
    local NS = T.newAddon()
    -- A table raises inside table.concat in every Lua version, exactly as a
    -- combat-protected "secret" would; the seam must degrade to "<secret>"
    -- rather than let the raise propagate.
    assertEqual(NS.SafeToString({}), "<secret>")
end)

test("util: IsConcatSafe true for scalars, false for a raising value", function()
    local NS = T.newAddon()
    assertTrue(NS.IsConcatSafe("x"))
    assertTrue(NS.IsConcatSafe(7))
    assertFalse(NS.IsConcatSafe({}))
end)

test("util: NS.Print prepends the [WG] prefix and stringifies each arg", function()
    local NS, _, mock = T.newAddon()
    NS.Print("   - Group:", "My Group")
    local line = mock.prints[#mock.prints]
    assertTrue(line:find(NS.PREFIX, 1, true) ~= nil, "carries the shared prefix")
    assertTrue(line:find("   - Group: My Group", 1, true) ~= nil, "joins label + value")
end)

test("util: NS.Print degrades a secret-like arg in place, never raising", function()
    local NS, _, mock = T.newAddon()
    NS.Print("value:", {})   -- would raise in a naive `..`/print path
    local line = mock.prints[#mock.prints]
    assertTrue(line:find("<secret>", 1, true) ~= nil, "secret degrades in-place")
end)

test("util: Windows.Save/Restore round-trips a frame point through db.global (WG-26)", function()
    local NS = T.bootAddon()
    -- Minimal fake frame: reports a real point, records SetPoint calls.
    local src = { GetPoint = function() return "CENTER", nil, "CENTER", 12, -34 end }
    NS.Windows.Save("popup", src)
    local saved = NS.addon.db.global.windows.popup
    assertEqual(saved.point, "CENTER")
    assertEqual(saved.x, 12)
    assertEqual(saved.y, -34)

    local dst = {
        ClearAllPoints = function() end,
        SetPoint = function(self, p, _rel, rp, x, y) self._set = { p, rp, x, y } end,
    }
    assertTrue(NS.Windows.Restore("popup", dst), "restore reports it applied a saved point")
    assertEqual(dst._set[1], "CENTER")
    assertEqual(dst._set[3], 12)
    assertEqual(dst._set[4], -34)
end)

test("util: Windows.Restore is a no-op when nothing is saved (WG-26)", function()
    local NS = T.bootAddon()
    local dst = { ClearAllPoints = function() end, SetPoint = function() end }
    assertFalse(NS.Windows.Restore("neverSaved", dst))
end)

-- ---------------------------------------------------------------------------
-- SafeToString / the print seam
-- ---------------------------------------------------------------------------

test("util: SafeToString renders a negative and a fractional number", function()
    local NS = T.newAddon()
    assertEqual(NS.SafeToString(-3), "-3")
    assertEqual(NS.SafeToString(1.5), "1.5")
end)

test("util: SafeToString degrades a function and a coroutine", function()
    local NS = T.newAddon()
    assertEqual(NS.SafeToString(print), "<secret>")
    assertEqual(NS.SafeToString(coroutine.create(function() end)), "<secret>")
end)

test("util: IsConcatSafe reports a boolean as unsafe", function()
    local NS = T.newAddon()
    -- A boolean raises inside table.concat, which is why SafeToString handles
    -- booleans explicitly BEFORE it ever probes.
    assertFalse(NS.IsConcatSafe(true))
    assertFalse(NS.IsConcatSafe(false))
end)

test("util: IsConcatSafe reports nil as safe (concat of an empty table)", function()
    local NS = T.newAddon()
    -- Pinning the ACTUAL semantics: `table.concat({nil})` concatenates a
    -- zero-length table and succeeds, so the probe says "safe" for nil. That is
    -- harmless only because SafeToString short-circuits nil before probing —
    -- this case exists so a future refactor that drops that short-circuit fails
    -- here instead of silently rendering nil as the empty string.
    assertTrue(NS.IsConcatSafe(nil))
    assertEqual(NS.SafeToString(nil), "nil")
end)

test("util: NS.Print with no arguments still prints the prefix", function()
    local NS, _, mock = T.newAddon()
    NS.Print()
    assertEqual(mock.prints[#mock.prints], NS.PREFIX .. " ")
end)

test("util: NS.Print joins several arguments with single spaces", function()
    local NS, _, mock = T.newAddon()
    NS.Print("a", "b", "c")
    assertTrue(mock.prints[#mock.prints]:find("a b c", 1, true) ~= nil)
end)

test("util: NS.Print stringifies nil and boolean arguments in place", function()
    local NS, _, mock = T.newAddon()
    NS.Print("v:", nil, false)
    assertTrue(mock.prints[#mock.prints]:find("v: nil false", 1, true) ~= nil)
end)

-- ---------------------------------------------------------------------------
-- Window geometry (WG-26)
-- ---------------------------------------------------------------------------

test("util: PointOf reads a frame's primary anchor", function()
    local NS = T.newAddon()
    local pt = NS.Windows.PointOf({
        GetPoint = function() return "TOPLEFT", nil, "TOPRIGHT", 5, -7 end })
    assertEqual(pt.point, "TOPLEFT")
    assertEqual(pt.relPoint, "TOPRIGHT")
    assertEqual(pt.x, 5)
    assertEqual(pt.y, -7)
end)

test("util: PointOf defaults relPoint to the point and offsets to zero", function()
    local NS = T.newAddon()
    local pt = NS.Windows.PointOf({ GetPoint = function() return "CENTER" end })
    assertEqual(pt.relPoint, "CENTER")
    assertEqual(pt.x, 0)
    assertEqual(pt.y, 0)
end)

test("util: PointOf returns nil for a frame with no anchor yet", function()
    local NS = T.newAddon()
    assertNil(NS.Windows.PointOf({ GetPoint = function() return nil end }))
end)

test("util: PointOf returns nil for nil or a non-frame", function()
    local NS = T.newAddon()
    assertNil(NS.Windows.PointOf(nil))
    assertNil(NS.Windows.PointOf({}))
end)

test("util: Save is a no-op before the db is ready", function()
    local NS = T.newAddon()   -- no OnInitialize
    local ok = pcall(function()
        NS.Windows.Save("popup", { GetPoint = function() return "CENTER", nil, "CENTER", 0, 0 end })
    end)
    assertTrue(ok, "a pre-login save must not index a nil db")
end)

test("util: Save skips a frame that has no anchor", function()
    local NS = T.bootAddon()
    NS.Windows.Save("popup", { GetPoint = function() return nil end })
    assertNil(NS.addon.db.global.windows.popup, "nothing is written for an unanchored frame")
end)

test("util: Save overwrites a previously stored point", function()
    local NS = T.bootAddon()
    NS.Windows.Save("popup", { GetPoint = function() return "CENTER", nil, "CENTER", 1, 1 end })
    NS.Windows.Save("popup", { GetPoint = function() return "TOP", nil, "TOP", 2, 2 end })
    assertEqual(NS.addon.db.global.windows.popup.point, "TOP")
end)

test("util: windows are stored under independent names", function()
    local NS = T.bootAddon()
    NS.Windows.Save("popup", { GetPoint = function() return "CENTER", nil, "CENTER", 1, 1 end })
    NS.Windows.Save("debug", { GetPoint = function() return "TOP", nil, "TOP", 2, 2 end })
    assertEqual(NS.addon.db.global.windows.popup.point, "CENTER")
    assertEqual(NS.addon.db.global.windows.debug.point, "TOP")
end)

test("util: Restore returns false for a frame that cannot be anchored", function()
    local NS = T.bootAddon()
    NS.addon.db.global.windows.popup = { point = "CENTER", relPoint = "CENTER", x = 0, y = 0 }
    assertFalse(NS.Windows.Restore("popup", {}))
    assertFalse(NS.Windows.Restore("popup", nil))
end)

test("util: Restore is a no-op before the db is ready", function()
    local NS = T.newAddon()
    assertFalse(NS.Windows.Restore("popup",
        { ClearAllPoints = function() end, SetPoint = function() end }))
end)

test("util: Restore clears existing anchors before applying the saved one", function()
    local NS = T.bootAddon()
    NS.addon.db.global.windows.popup = { point = "TOP", relPoint = "TOP", x = 3, y = 4 }
    local cleared = false
    NS.Windows.Restore("popup", {
        ClearAllPoints = function() cleared = true end,
        SetPoint = function() end,
    })
    assertTrue(cleared, "a stale anchor would otherwise fight the restored one")
end)

test("util: a Save/Restore round trip survives through the real frame stub", function()
    local NS, env, mock = T.bootAddon()
    local src = env.CreateFrame("Frame")
    src:SetPoint("BOTTOMLEFT", env.UIParent, "BOTTOMLEFT", 33, 44)
    NS.Windows.Save("roundtrip", src)

    local dst = env.CreateFrame("Frame")
    dst:SetPoint("CENTER", env.UIParent, "CENTER", 0, 0)
    assertTrue(NS.Windows.Restore("roundtrip", dst))
    local point, _, relPoint, x, y = dst:GetPoint(1)
    assertEqual(point, "BOTTOMLEFT")
    assertEqual(relPoint, "BOTTOMLEFT")
    assertEqual(x, 33)
    assertEqual(y, 44)
end)

-- ---------------------------------------------------------------------------
-- NS.FormatDuration — the cooldown readout's h/m/s renderer
-- ---------------------------------------------------------------------------

test("util: FormatDuration renders hours, minutes and seconds", function()
    local NS = T.newAddon()
    assertEqual(NS.FormatDuration(28692), "7h 58m 12s")
end)

-- Leading zero units are dropped rather than rendered as "0h": a 90-second cooldown reading
-- "0h 1m 30s" is noise, and the unit that matters is always the largest non-zero one.
test("util: FormatDuration drops units above the largest non-zero one", function()
    local NS = T.newAddon()
    assertEqual(NS.FormatDuration(3492), "58m 12s")
    assertEqual(NS.FormatDuration(12), "12s")
end)

-- Trailing zero units stay, so the string keeps a stable shape while it is on screen: an
-- exactly-two-hour cooldown reads "2h 0m 0s", not "2h".
test("util: FormatDuration keeps trailing zero units once a larger one is present", function()
    local NS = T.newAddon()
    assertEqual(NS.FormatDuration(7200), "2h 0m 0s")
    assertEqual(NS.FormatDuration(60), "1m 0s")
end)

-- The client hands back fractional seconds. Rounding UP means the readout never claims less time
-- than is left, so it never reads "0s" on a spell that is still refusing to cast.
test("util: FormatDuration rounds fractional seconds up", function()
    local NS = T.newAddon()
    assertEqual(NS.FormatDuration(11.2), "12s")
    assertEqual(NS.FormatDuration(0.1), "1s")
end)

test("util: FormatDuration renders a non-positive duration as 0s", function()
    local NS = T.newAddon()
    assertEqual(NS.FormatDuration(0), "0s")
    assertEqual(NS.FormatDuration(-5), "0s")
end)
