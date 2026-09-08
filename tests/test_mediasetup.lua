-- tests/test_mediasetup.lua — core/MediaSetup.lua, the LibKa0s-Media-1.0 seam.
--
-- THE CASE THAT EARNS THIS FILE is the catalog cross-check. The art and the monospace face this
-- addon draws with now live in ANOTHER REPO, and they are asked for by plain string. If the library
-- renames a mark, or a re-vendor drops a file, or this addon asks for a name that was never
-- shipped, the answer is nil — and nil, on this seam, is a control that is silently, permanently
-- absent. A texture that does not load draws nothing and raises nothing, so nothing else in this
-- suite can see it and no amount of green says otherwise.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertNil, fail =
    T.test, T.assertEqual, T.assertTrue, T.assertNil, T.fail

local VENDORED = "Interface\\AddOns\\WhatGroup\\libs\\LibKa0s\\media\\"

-- Every icon name this addon's own source hands to NS.Icon. One entry today — the mark beside the
-- popup's footer Close button — and the list is the thing to extend when a second appears, so the
-- cross-check below keeps covering all of them rather than the first one written.
local DRAWN = { "close" }

-- The library files that ARE the payload, for the degraded case. Core.lua absent means every other
-- major returns before LibStub:NewLibrary too, which makes this the whole-library-missing scenario
-- rather than a Media-only one.
local NO_LIBKA0S = {
    "libs/LibKa0s/Core.lua", "libs/LibKa0s/Env.lua", "libs/LibKa0s/Pool.lua",
    "libs/LibKa0s/Item.lua", "libs/LibKa0s/Media.lua", "libs/LibKa0s/Widgets.lua",
    "libs/LibKa0s/DebugLog.lua",
    "libs/LibKa0s/Slash.lua", "libs/LibKa0s/Options.lua", "libs/LibKa0s/OptionsWidgets.lua",
    "libs/LibKa0s/OptionsScroll.lua", "libs/LibKa0s/Perf.lua", "libs/LibKa0s/PerfPanel.lua",
}

-- ---------------------------------------------------------------------------
-- The seam
-- ---------------------------------------------------------------------------

test("mediasetup: NS.Icon answers the vendored path, EXTENSIONLESS", function()
    -- Extensionless is not a preference. The client appends `.tga` itself, and a path that already
    -- carries it is one of the spellings that draws nothing at all.
    local NS = T.newAddon()
    assertEqual(NS.Icon("close"), VENDORED .. "icons\\close")
end)

test("mediasetup: an icon the library does not ship answers nil", function()
    -- nil is a value a caller can branch on; a plausible path to a texture that is not there is
    -- not. A caller that asks for an icon the catalog does not carry draws nothing.
    local NS = T.newAddon()
    assertNil(NS.Icon("nosuchicon"))
end)

test("mediasetup: NS.MediaFont answers the vendored face, and only for a face it ships", function()
    local NS = T.newAddon()
    assertEqual(NS.MediaFont("JetBrains Mono"), VENDORED .. "fonts\\JetBrainsMono-Regular.ttf")
    assertNil(NS.MediaFont("Comic Sans"))
end)

test("mediasetup: the face this addon names is the face the library registers", function()
    -- Two names for one thing, in two repos: NS.FONT_MONO_NAME is what this addon asks for and
    -- what LibSharedMedia stores, and the library's FONTS is what actually gets registered. A key
    -- nobody registered renders silently in Blizzard's proportional fallback, which is the exact
    -- outcome shipping a monospace face was meant to prevent.
    local NS, env = T.newAddon()
    local Media = env.LibStub("LibKa0s-Media-1.0", true)
    assertTrue(Media ~= nil, "the vendored library did not register LibKa0s-Media-1.0")
    assertTrue(Media.FONTS[NS.FONT_MONO_NAME] ~= nil,
        "FONT_MONO_NAME is '" .. tostring(NS.FONT_MONO_NAME)
        .. "', which the library's FONTS does not carry")
    assertEqual(NS.FONT_MONO, NS.MediaFont(NS.FONT_MONO_NAME))
end)

local function source(rel)
    local fh = io.open((T.root or ".") .. "/" .. rel, "rb")
    if not fh then return nil end
    local body = fh:read("*a")
    fh:close()
    return body
end

test("mediasetup: the LSM registration is the library's, made at file load", function()
    -- Asserted against the SOURCE because the mock leaves LibSharedMedia unregistered on purpose
    -- (it exercises the silent-lookup branch), so there is no registry here to read back.
    --
    -- Two halves, and both matter. It has to be at LOAD, not at PLAYER_LOGIN: core/WhatGroup.lua
    -- names the face at load too, so deferring would open a window in which a default named a key
    -- LSM had never heard of. And it has to be the LIBRARY's call, not this addon's own: six Ka0s
    -- addons registering "JetBrains Mono" at six different paths is the collision the move exists
    -- to remove, and one call now points all of them at one set of bytes.
    -- red under: the old `LSM:Register("font", "JetBrains Mono", NS.FONT_MONO)` coming back.
    local src = source("core/MediaSetup.lua")
    assertTrue(src ~= nil, "core/MediaSetup.lua is readable")
    local body = src:gsub("%-%-[^\r\n]*", "")
    assertTrue(body:match("Media%.RegisterLSM%s*%(%s*addonName%s*%)") ~= nil,
        "MediaSetup must register through the library, passing the addon FOLDER name")
    assertTrue(body:match("function%s+NS%.Icon") ~= nil and body:match("Media%.Icon") ~= nil,
        "and it must publish the icon seam")

    local wg = source("core/WhatGroup.lua"):gsub("%-%-[^\r\n]*", "")
    assertTrue(wg:match("LSM:Register") == nil,
        "core/WhatGroup.lua must not register a private copy of the face any more")
end)

-- ---------------------------------------------------------------------------
-- The catalog, against what this addon actually asks for
-- ---------------------------------------------------------------------------

test("mediasetup: every icon this addon draws is one the library ships", function()
    -- The names are string literals in this addon and the catalog is in another repo. A rename on
    -- either side answers nil, and nil draws nothing.
    local NS, env = T.newAddon()
    local Media = env.LibStub("LibKa0s-Media-1.0", true)
    local known = {}
    for _, name in ipairs(Media.ICONS) do known[name] = true end

    for _, name in ipairs(DRAWN) do
        assertTrue(known[name] == true,
            "this addon draws '" .. name .. "', which LibKa0s-Media does not ship")
        assertTrue(NS.Icon(name) ~= nil, "NS.Icon answered nil for " .. name)
    end
end)

test("mediasetup: every icon this addon draws has a file in the vendored copy", function()
    -- The library's own suite checks its catalog against its own directory. This checks the COPY:
    -- a re-vendor that dropped a file, or a packaging step that filtered media/ out, leaves a
    -- catalog naming art this build does not carry.
    local root = (T.root or ".") .. "/libs/LibKa0s/media/icons/"
    local missing = {}
    for _, name in ipairs(DRAWN) do
        local fh = io.open(root .. name .. ".tga", "rb")
        if fh then fh:close() else missing[#missing + 1] = name end
    end
    assertEqual(table.concat(missing, ", "), "")
end)

test("mediasetup: the whole catalog has a file in the vendored copy", function()
    -- Wider than the case above and for a different failure: this one catches a partial re-vendor
    -- before the addon happens to ask for the file that went missing.
    local _, env = T.newAddon()
    local Media = env.LibStub("LibKa0s-Media-1.0", true)
    local root = (T.root or ".") .. "/libs/LibKa0s/media/icons/"
    local missing = {}
    for _, name in ipairs(Media.ICONS) do
        local fh = io.open(root .. name .. ".tga", "rb")
        if fh then fh:close() else missing[#missing + 1] = name end
    end
    assertEqual(table.concat(missing, ", "), "")
end)

-- Every path git tracks under media/, forward-slash and repo-relative.
--
-- Tracked rather than on-disk, deliberately: what a build ships is what the repo carries, and an
-- uncommitted file in a working tree is not in anybody's package. And it FAILS RATHER THAN PASSES
-- when it cannot look — an empty listing from a broken pipe is indistinguishable from a clean
-- media/, so a gate that treats "no result" as "nothing found" goes quiet exactly when it is
-- needed. This repo tracks six files under media/; zero is never the truth.
local function trackedMedia()
    if not io.popen then
        fail("io.popen is unavailable, so the tracked media set cannot be read")
    end
    local pipe = io.popen("git -C '" .. (T.root or ".") .. "' ls-files -z -- media/")
    if not pipe then fail("could not start `git ls-files`") end
    local blob = pipe:read("*a") or ""
    pipe:close()
    local paths, start = {}, 1
    while true do
        local i = blob:find("\0", start, true)
        if not i then break end
        if i > start then paths[#paths + 1] = blob:sub(start, i - 1):gsub("\\", "/") end
        start = i + 1
    end
    if #paths == 0 then
        fail("`git ls-files -- media/` reported nothing tracked, which cannot be true here")
    end
    return paths
end

test("mediasetup: this addon ships no private copy of the shared art (anti-patterns #63)", function()
    -- The whole point of the move. media/logos/ and media/screenshots/ stay — the brand TGA the
    -- settings landing page draws is this addon's own and is sanctioned — but media/fonts/ is gone
    -- and must not come back: two copies of a font is two licenses to track and two provenance
    -- stories, and the second copy is the one that goes stale.
    --
    -- Scanned, not spelled out. The path this case used to stat by hand was
    -- media/fonts/JetBrainsMono-Regular.ttf and nothing else, so the ONE arrangement it could see
    -- was a re-added copy of the same face under the same name — a second face, the same face
    -- under another basename, or a private duplicate of a catalog icon all walked past a green
    -- case whose title promised to have looked.
    --
    -- Red under either mutation:
    --   `git add`ing media/fonts/JetBrainsMono-Regular.ttf back →
    --     "media/ carries a private font face; media/fonts/ is the library's payload now
    --      (expected , got media/fonts/JetBrainsMono-Regular.ttf)"
    --   `git add`ing a copy of a catalog mark, e.g. media/logos/close.tga →
    --     "media/ carries a private copy of a catalog icon; the catalog is the library's
    --      (expected , got media/logos/close.tga (\"close\"))"
    local _, env = T.newAddon()
    local Media = env.LibStub("LibKa0s-Media-1.0", true)
    local catalog = {}
    for _, name in ipairs(Media.ICONS) do catalog[name:lower()] = true end

    local fonts, icons = {}, {}
    for _, path in ipairs(trackedMedia()) do
        local lower = path:lower()
        if lower:match("%.ttf$") or lower:match("%.otf$") then
            fonts[#fonts + 1] = path
        end
        -- The catalog is keyed by extensionless name and the art ships as .tga, so compare on the
        -- basename with its extension taken off. A LOGO that happens to share a mark's name is
        -- still a duplicate of that mark by every test the client applies, which is why the check
        -- is over the whole of media/ rather than a subdirectory of it.
        local base = lower:match("([^/]+)%.%w+$")
        if base and catalog[base] then
            icons[#icons + 1] = path .. ' ("' .. base .. '")'
        end
    end

    assertEqual(table.concat(fonts, ", "), "",
        "media/ carries a private font face; media/fonts/ is the library's payload now")
    assertEqual(table.concat(icons, ", "), "",
        "media/ carries a private copy of a catalog icon; the catalog is the library's")
end)

-- ---------------------------------------------------------------------------
-- Degraded
-- ---------------------------------------------------------------------------

test("mediasetup: with no library there is no art and no face, and that is not an error", function()
    -- The art is INSIDE the payload that is missing, so a degraded install has none of it. Both
    -- seams still ANSWER — they just answer nil, which is what sends the footer button back to the
    -- plain word it drew before and the console to the client's own face.
    local NS, env = T.newAddon{ skip = NO_LIBKA0S }
    assertNil(env.LibStub("LibKa0s-Media-1.0", true), "the library really is absent")
    assertEqual(type(NS.Icon), "function", "the seam still answers")
    assertEqual(type(NS.MediaFont), "function")
    assertNil(NS.Icon("close"))
    assertNil(NS.MediaFont("JetBrains Mono"))
end)

test("mediasetup: a degraded install still gets a REAL font, never nil and never a dead path",
function()
    -- SetFont accepts a path to a file that is not there, fails to load it, and the text simply
    -- does not draw. The library also validates the console descriptor's `font` as a string at
    -- :New time. So the fallback has to be a face the client definitely has.
    local NS, env = T.newAddon{ skip = NO_LIBKA0S }
    assertEqual(NS.FONT_MONO, env.STANDARD_TEXT_FONT)
    assertTrue(type(NS.FONT_MONO) == "string" and NS.FONT_MONO ~= "",
        "FONT_MONO must never be nil — the console would refuse to build")
end)
