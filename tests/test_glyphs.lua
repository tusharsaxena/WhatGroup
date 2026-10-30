-- tests/test_glyphs.lua — the display-glyph guard over this addon's own Lua (LibKa0s v1.82.0, kit
-- revision 45's tests/_kit/glyphs.lua; WG-02 of Ka0sAddonsCommonTasks
-- docs/2026-10-30-SKIN_FONTS_AND_FEEDBACK, Addendum 07, ruling D-19).
--
-- Ten skins draw this addon's text in a dozen faces, and a character one of them lacks is a box in
-- that skin only (BankLedger's footer "Database ≈ 1.6 MB" read "Database [] 1.6 MB" under Obsidian,
-- since Expressway has no U+2248). So every string literal in a tracked .lua file outside libs/ and
-- tests/ carries only characters every shipped face draws (the kit's safe set, read from their
-- cmaps). A string drawn in the mono role would carry a `glyph: mono` marker, and one never drawn a
-- `glyph: data` marker; the debug console's lines are skipped by the kit (they draw in mono too).
--
-- When the guard landed it found nothing to fix: the addon's only non-ASCII display character is
-- the em dash (U+2014: the popup's "—" placeholder, the locale strings' separators), which is in the
-- safe set, and its → arrows sit in comments and NS.Debug calls, which the kit does not scan.

local T = _G.WHATGROUP_TEST
local test = T.test

test("glyphs: display strings use only characters every shipped skin face draws", function()
    -- red under: a ≈, →, ▼ or ▲ (or any other character outside the kit's safe set) in a string the
    -- addon paints in a skin face.
    T.assertDisplayGlyphs{ label = "WhatGroup" }
end)
