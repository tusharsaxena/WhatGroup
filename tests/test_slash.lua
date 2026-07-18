-- tests/test_slash.lua — slash surface: the standalone version verb (WG-29)
-- and the colon-free help header (WG-19), driven through the COMMANDS table.
local T = _G.WHATGROUP_TEST
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse

local function runCmd(NS, name, rest)
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == name then return c[3](NS.addon, rest) end
    end
    error("no command: " .. tostring(name))
end

test("slash: COMMANDS has a standalone version verb (WG-29)", function()
    local NS = T.newAddon()
    local found = false
    for _, c in ipairs(NS.addon.COMMANDS) do
        if c[1] == "version" then found = true end
    end
    assertTrue(found, "a 'version' command row must exist")
end)

test("slash: /wg version prints [WG] v<version> on its own line (WG-29)", function()
    local NS, _, mock = T.bootAddon()
    runCmd(NS, "version")
    local line = mock.prints[#mock.prints]
    assertTrue(line:find(NS.PREFIX, 1, true) ~= nil, "carries the [WG] tag")
    assertTrue(line:find("v" .. NS.addon.VERSION, 1, true) ~= nil,
        "shows v<version> (TOC metadata, falling back to the constant)")
end)

test("slash: help header has no trailing colon (WG-19)", function()
    local NS, _, mock = T.newAddon()
    runCmd(NS, "help")
    local header
    for _, line in ipairs(mock.prints) do
        if line:find("slash commands", 1, true) then header = line; break end
    end
    assertTrue(header ~= nil, "help header was printed")
    assertFalse(header:match(":%s*$") ~= nil, "header must not end in a trailing colon")
end)
