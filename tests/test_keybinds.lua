-- tests/test_keybinds.lua — item 015: the Show window key binding's own section on Options ->
-- Keybindings, and the General page's Keybindings tab.
--
-- launcher-§6 (standard v2.88.0) files every binding in this addon's OWN category,
-- BINDING_HEADER_WHATGROUP, with no header= (a header inside a category draws as a blank spacer
-- row), so Options -> Keybindings shows a "Ka0s WhatGroup" section. options-ui-§20 adds the General
-- page's LAST tab, drawn by LibKa0s from NS.BINDINGS, editing the client's one binding store.
--
-- What is pinned here is the host's half: the file, the one table, the labels, where the tab sits,
-- and that this page's own tab reaches the client's store both ways and refuses in combat. The
-- capture, slot, conflict, sync-debounce and never-touches-SettingsPanel mechanics are the
-- library's cases (tests/test_options_keybinds*.lua in LibKa0s, testing-§8) and are not repeated.
--
-- The binding API is the kit's tests/_kit/mock_bindings.lua, which tests/wow_mock.lua installs on
-- every mock. Every case builds its own instance, so a case that presses a key through
-- Kit.keybindThroughTab names that instance's mock first (T.useBindingMock, tests/run.lua).

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local COMMAND = "CLICK WhatGroupTogglePopup:LeftButton"
local LABEL   = "Toggle group popup"

-- A view over the two tables a loaded chunk's globals land in: a `rawset(_G, ...)` reaches the mock
-- (the sandbox's own `_G`), and a plain global assignment reaches the real _G through the kit
-- loader's __newindex. The client has one table; this reads both, mock first, as the sandbox does.
local function globalsOf(mock)
    return setmetatable({}, { __index = function(_, k)
        local v = rawget(mock, k)
        if v ~= nil then return v end
        return rawget(_G, k)
    end })
end

-- The strip's buttons are CreateFrame Buttons in the page's chrome band, not AceGUI widgets. Last
-- match wins: a tab click rebuilds the strip and the stale buttons stay in the mock's ledger.
local function tabButton(mock, label)
    local found
    for _, f in ipairs(mock.frames) do
        if f.__kind == "Button" and f.__text == label then found = f end
    end
    return found
end

--- Open General the way the client does (Show fires OnShow, then the next frame), answering the
--- instance and the strip's tab keys, read off the page's own RenderTabbedSchema call.
local function openGeneral()
    local NS, _, mock = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    local real, keys = H.RenderTabbedSchema, nil
    H.RenderTabbedSchema = function(...)
        local groups, drawn = real(...)
        keys = drawn
        return groups, drawn
    end
    local ok, err = pcall(function()
        mock.frames["WhatGroupGeneralPanel"]:Show()
        mock.fireCTimers()
    end)
    H.RenderTabbedSchema = real
    if not ok then error(err, 0) end
    return NS, mock, keys
end

--- Open General and click its Keybindings tab, answering the row records the library drew, spied
--- off the instance's KeybindRows (the tab's render looks it up at call time).
local function keybindRows()
    local NS, mock = openGeneral()
    local H = NS.addon.Settings.Helpers
    local real, rows = H.KeybindRows, nil
    H.KeybindRows = function(...)
        rows = real(...)
        return rows
    end
    local ok, err = pcall(function()
        local b = tabButton(mock, "Keybindings")
        assertTrue(b ~= nil, "the General strip has no Keybindings tab")
        b.__fire("OnClick")
    end)
    H.KeybindRows = real
    if not ok then error(err, 0) end
    assertTrue(type(rows) == "table", "the Keybindings tab drew no rows")
    T.useBindingMock(mock)
    return NS, mock, rows
end

local function slotText(row, slot)
    local w = row.slots[slot]
    return w.text or (w.GetText and w:GetText())
end

local function statusText(row)
    local s = row.status
    return s.text or (s.GetText and s:GetText())
end

-- ── Bindings.xml and NS.BINDINGS (launcher-§6) ───────────────────────────────────────────────

test("keybinds: Bindings.xml files every binding in the addon's own category, labeled, brand-titled",
function()
    -- red under: category="ADDONS", a header= (a blank spacer row in the client's list), a default=
    -- key, a name that differs from NS.BINDINGS, an empty label, or a category global that is not
    -- the brand constant.
    rawset(_G, "BINDING_HEADER_WHATGROUP", nil)
    local NS, _, mock = T.newAddon()
    local list = T.assertBindingsXml("Bindings.xml", {
        category = "BINDING_HEADER_WHATGROUP",
        commands = NS.BINDINGS,
        brand    = NS.BRAND_NAME,
        globals  = globalsOf(mock),
        labels   = { [COMMAND] = LABEL },
    })
    assertEqual(#list, 1, "one binding")
    assertEqual(list[1].name, COMMAND, "the binding NAME never changes: saved keys survive")
    assertEqual(NS.BRAND_NAME, "Ka0s WhatGroup", "the brand (launcher-§1)")
end)

test("keybinds: NS.BINDINGS is the one table, Show window first, each with a localized tooltip",
function()
    local NS, _, mock = T.newAddon()
    assertEqual(#NS.BINDINGS, 1)
    assertEqual(NS.BINDINGS[1].command, COMMAND, "the Show window binding is first")
    assertEqual(NS.BINDINGS[1].command, NS.TOGGLE_COMMAND, "built from the button's own name")
    for _, b in ipairs(NS.BINDINGS) do
        assertTrue(type(b.tooltip) == "string" and b.tooltip ~= "", b.command .. " has no tooltip")
    end
    assertEqual(NS.BINDINGS[1].tooltip, NS.L["Shows or hides the group popup."],
        "the tooltip comes through L")
    assertEqual(rawget(mock, "BINDING_NAME_" .. COMMAND), NS.L[LABEL], "the label comes through L")
end)

-- ── The General page's Keybindings tab (options-ui-§20) ──────────────────────────────────────

test("keybinds: the General strip ENDS in Keybindings, after every schema tab", function()
    -- red under: no opts.tabs entry, a `before` that pulls it forward, or a relabeled tab.
    local NS, mock, keys = openGeneral()
    assertTrue(type(keys) == "table" and #keys > 0, "General drew no tab strip")
    assertEqual(table.concat(keys, " | "), "Master controls | Notifications | Keybindings",
        "the strip, in order")
    assertEqual(keys[1], NS.addon.Settings.Helpers.MASTER_GROUP, "Master controls stays first")
    assertTrue(tabButton(mock, "Keybindings") ~= nil, "labeled exactly Keybindings")
end)

test("keybinds: the tab's rows are NS.BINDINGS in order, labeled with the BINDING_NAME_ text",
function()
    local NS, mock, rows = keybindRows()
    assertEqual(#rows, #NS.BINDINGS, "one row per binding")
    for i, b in ipairs(NS.BINDINGS) do
        assertEqual(rows[i].command, b.command, "row " .. i .. " follows NS.BINDINGS")
        local label = rows[i].label
        assertEqual(label.text or label:GetText(), rawget(mock, "BINDING_NAME_" .. b.command),
            "row " .. i .. " shows the client's label, not one of the addon's own")
        assertEqual(#rows[i].slots, 1, "one key button per row (OptionsKeybinds minor 4)")
        assertTrue(rows[i].clear ~= nil, "row " .. i .. " has its Clear button")
    end
end)

test("keybinds: a key bound through the tab is the client's key (GetBindingKey), saved to the set in force",
function()
    local _, mock, rows = keybindRows()
    assertNil(mock.GetBindingKey(COMMAND), "starts unbound")
    local status = T.keybindThroughTab(rows[1], 1, "K", { ctrl = true })
    assertEqual(mock.GetBindingKey(COMMAND), "CTRL-K", "the tab wrote the client's store")
    assertEqual(status, mock.KEY_BOUND, "the outcome line, in the client's words")
    assertEqual(mock.__savedBindingSets[#mock.__savedBindingSets], mock.GetCurrentBindingSet(),
        "saved to the set in force")
end)

test("keybinds: a key set on the client's page shows in the tab after UPDATE_BINDINGS", function()
    -- The other direction of OWNER_SCOPE 015's sync: Options -> Keybindings calls SetBinding, which
    -- fires UPDATE_BINDINGS, and the tab repaints from GetBindingKey on the next frame.
    local _, mock, rows = keybindRows()
    assertFalse(slotText(rows[1], 1) == "F7", "starts without the key")
    mock.SetBinding("F7", COMMAND)
    assertFalse(slotText(rows[1], 1) == "F7", "repainted before the event: the case proves nothing")
    local lib = mock.LibStub("LibKa0s-Options-1.0")
    lib.__keybindEventFrame.__fire("OnEvent", "UPDATE_BINDINGS")
    mock.fireCTimers()
    assertEqual(slotText(rows[1], 1), "F7", "the tab shows the key the client's page set")
end)

test("keybinds: a second key, set on the client's page, reads '<key> +1' on the one key button",
function()
    -- The owner's follow-up to 015: the tab binds slot 1 only; a second key comes from Options ->
    -- Keybindings and is counted on the button, never dropped from view.
    local _, mock, rows = keybindRows()
    T.keybindThroughTab(rows[1], 1, "F5")
    local status = T.keybindThroughTab(rows[1], 2, "F6")
    assertEqual(status, mock.KEY_BOUND, "the second key is the client's KEY_BOUND line")
    local a, b = mock.GetBindingKey(COMMAND)
    assertEqual(a, "F5", "slot 1 is the key the button bound")
    assertEqual(b, "F6", "slot 2 holds the second key")
    assertEqual(slotText(rows[1], 1), "F5 +1", "the button counts the second key")
end)

test("keybinds: in combat the tab refuses, and no binding is written or saved", function()
    -- A left click on a slot is the player's first step (Kit.keybindThroughTab's too), and in
    -- combat the library refuses it before any capture starts, so there is no listener for a key to
    -- reach. Clear is refused the same way.
    local _, mock, rows = keybindRows()
    mock.bindKey("F8", COMMAND)
    mock.combat = true
    local ok, err = pcall(function()
        rows[1].slots[1]:__fire("OnClick", "LeftButton")
        rows[1].clear:__fire("OnClick", "LeftButton")
    end)
    mock.combat = false
    assertTrue(ok, tostring(err))
    assertEqual(mock.GetBindingKey(COMMAND), "F8", "Clear removed a key in combat")
    assertEqual(#mock.__bindingWrites, 0, "SetBinding was called in combat")
    assertEqual(#mock.__bindingRefusals, 0, "a binding API call was even attempted in combat")
    assertEqual(#mock.__savedBindingSets, 0, "SaveBindings was called in combat")
    local lib = mock.LibStub("LibKa0s-Options-1.0")
    local listener = lib.__keybindListener
    assertFalse(listener ~= nil and listener:IsShown(), "a capture started in combat")
    assertEqual(statusText(rows[1]), lib.KEYBIND_STRINGS.COMBAT, "the outcome line says why")
end)
