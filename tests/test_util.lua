-- tests/test_util.lua — the secret-safe stringifier / chat printer seam
-- (WG-22) and the standalone-window geometry helpers (WG-26), all defined in
-- core/Util.lua.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse

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
