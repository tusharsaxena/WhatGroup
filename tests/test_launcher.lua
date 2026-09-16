-- tests/test_launcher.lua — the launcher (launcher-§1..§5): ONE LibDataBroker object, registered
-- twice, wearing this addon's own logo, answering a left click with the group popup and a right
-- click with the settings panel.
--
-- What is pinned here is the WIRING, because everything else about the object is
-- LibKa0s-Launcher-1.0's and is tested where it lives. Three things nothing else can see:
--
--   * that the two registrations really are ONE object (two objects with two OnClicks is the same
--     feature written twice, anti-pattern #81, and both would pass a behavioral assertion);
--   * that the LEFT click drives the addon's REAL popup seam rather than a copy of it -- the rung
--     is (a), the group popup, and the standard's ADDONS.md is where that is recorded;
--   * that the icon file the object names is on disk and in the ONE format the client will draw --
--     a wrong format here draws nothing and raises nothing, which is anti-pattern #82's subtler
--     half and is exactly what no gate would otherwise report.
local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue, assertFalse, assertNil =
    T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local NAME = "WhatGroup"
local ICON = "Interface\\AddOns\\WhatGroup\\media\\logos\\whatgroup.logo.128.tga"
local ICON_FILE = "media/logos/whatgroup.logo.128.tga"

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local body = f:read("*a")
    f:close()
    return body
end

-- A fully booted addon whose launcher has registered, plus the one broker object.
local function launched()
    local NS, mock = T.enableAddon()
    return NS, mock, mock.ldbObjects[NAME]
end

local function popup(mock) return mock.frames["WhatGroupFrame"] end

local function onScreen(mock)
    local f = popup(mock)
    return f ~= nil and f:IsShown() and f:GetAlpha() > 0
end

-- The General settings page, built the way the client builds it: Show the panel (which fires
-- OnShow), then let the next frame run -- settings/OptionsSetup.lua defers the render one C_Timer
-- hop, out of Blizzard's secure-execute chain. Spelled out here rather than reached across from
-- tests/test_panel.lua, which keeps its own copy: a suite importing another suite's locals would
-- couple two files that have no other relationship.
local function openGeneral()
    local NS, env, mock = T.enableAddon()
    mock.frames["WhatGroupGeneralPanel"]:Show()
    mock.fireCTimers()
    return NS, env, mock
end

local function widget(mock, widgetType, labelText)
    return mock.findWidget(function(w)
        return w.type == widgetType and (w.labelText == labelText or w.text == labelText)
    end)
end

-- ---------------------------------------------------------------------------
-- One object, registered twice (launcher-§1)
-- ---------------------------------------------------------------------------

test("launcher: it registers at login, and the broker object IS the minimap button's", function()
    -- red under: a second NewDataObject for the button, or registering only one of the two.
    local NS, mock, object = launched()
    assertTrue(NS.Launcher:IsRegistered(), "the launcher reports itself wired")
    assertTrue(object ~= nil, "a LibDataBroker object exists under the folder name")
    assertEqual(mock.minimapButtons[NAME].object, object,
        "LibDBIcon holds the SAME table LibDataBroker does -- one object, two registrations")
    assertEqual(NS.Launcher:Object(), object, "and it is the one the instance publishes")
end)

test("launcher: the object is a launcher, named for the FOLDER, wearing this addon's logo",
function()
    -- `type` is read by a broker display to decide what to draw: "data source" promises a `text`
    -- value that updates, which this object does not have, and a display handed the wrong type
    -- draws an empty value cell beside the icon forever.
    --
    -- The NAME is the folder, and it is not cosmetic: LibDBIcon keys the button's saved POSITION by
    -- it, so a second spelling drops the angle the player dragged the button to.
    -- red under: type = "data source", a hand-typed name, or a Blizzard icon path.
    local _, mock, object = launched()
    assertEqual(object.type, "launcher")
    assertEqual(object.icon, ICON)
    assertTrue(mock.minimapButtons[NAME] ~= nil, "registered under the folder name")
    assertNil(object.icon:match("^Interface\\Icons"), "never a borrowed Blizzard icon")
end)

test("launcher: the label is the BRAND NAME in plain text (launcher-§1)", function()
    -- What a broker display prints beside the icon, and it prints it beside the other ten Ka0s
    -- addons: `Ka0s <Name>` is what makes the collection read as one collection in Titan Panel
    -- rather than as eleven addons that happen to be installed together (standard v2.54.0).
    -- red under: an ad-hoc spelling (`WhatGroup`, `What Group`), or the folder name.
    local _, _, object = launched()
    assertEqual(object.label, "Ka0s WhatGroup")
    assertNil(object.label:match("|"), "no escape sequence of any kind")
    assertTrue(object.label ~= NAME, "the folder name is the registration NAME, not the label")
end)

test("launcher: the label is NOT wired to the TOC Title", function()
    -- The two agree letter for letter today, which is why reading the Title lasted -- and is
    -- exactly why a behavioral case is the only way to tell them apart. A `## Title` MAY carry
    -- colour escapes and one in the collection does, so a label sourced from it splatters that
    -- addon's row across a broker list in which every other row is plain text.
    -- red under: `label = NS.Meta("Title")`.
    local _, mock = T.enableAddon{ mock = function(m)
        m.metadata.Title = "Ka0s |cffff0000W|cffff9900h|cffffff00at|rGroup"
    end }
    assertEqual(mock.ldbObjects[NAME].label, "Ka0s WhatGroup",
        "the label ignored a Title carrying colour escapes")
end)

test("launcher: the name is the FOLDER this copy loaded from, not a hand-typed literal", function()
    -- The same distinction core/MediaSetup.lua's addonName argument makes, and the only way it is
    -- observable: load the addon as another folder and both the registration and the texture path
    -- have to follow.
    -- red under: name = "WhatGroup" typed out in core/LauncherSetup.lua.
    local _, mock = T.enableAddon{ addonName = "WhatGroupCopy" }
    assertTrue(mock.ldbObjects["WhatGroupCopy"] ~= nil, "registered under the folder it loaded as")
    assertEqual(mock.ldbObjects["WhatGroupCopy"].icon,
        "Interface\\AddOns\\WhatGroupCopy\\media\\logos\\whatgroupcopy.logo.128.tga")
end)

test("launcher: Register is idempotent -- a second call builds no second button", function()
    -- A host may call it from OnInitialize and again from a login handler, and LibDBIcon's Register
    -- on a name it already holds would otherwise draw a second button over the first.
    -- red under: dropping the `if object and iconLib then return true end` guard.
    local NS, mock, object = launched()
    local button = mock.minimapButtons[NAME]
    assertTrue(NS.Launcher:Register(), "a repeat call still reports wired")
    assertEqual(mock.ldbObjects[NAME], object, "the same object")
    assertEqual(mock.minimapButtons[NAME], button, "and the same button")
end)

-- ---------------------------------------------------------------------------
-- The icon file (launcher-§4, layout-§4)
-- ---------------------------------------------------------------------------

test("launcher: the icon file exists and is an uncompressed 32-bit TGA", function()
    -- THE CASE THAT CANNOT BE REPLACED BY A GREEN CLIENT. An RLE-compressed or 24-bit TGA loads as
    -- nothing at icon size: the button draws empty, the AddOns list draws empty, and no error is
    -- raised anywhere, so a launcher adopted with the wrong file is strictly worse than one not
    -- adopted at all (launcher-§5).
    -- red under: saving the file without convert("RGBA"), or hand-editing it.
    local body = readFile(ICON_FILE)
    assertTrue(body ~= nil, ICON_FILE .. " is missing -- the button would draw nothing")
    assertEqual(body:byte(3), 2, "TGA image type 2 (uncompressed true-color)")
    assertEqual(body:byte(17), 32, "32 bits per pixel")
    local width  = body:byte(13) + body:byte(14) * 256
    local height = body:byte(15) + body:byte(16) * 256
    assertEqual(width, 128, "128 wide")
    assertEqual(height, 128, "128 high")
end)

test("launcher: the TOC's IconTexture is the same file the object wears", function()
    -- One file is the addon's face in three places -- the AddOns list, the minimap and a broker
    -- display -- so a player who has seen the addon once recognizes it in all three.
    -- red under: the TOC keeping the file id 134149 it carried before the launcher landed.
    local toc = readFile("WhatGroup.toc")
    local declared = toc:match("##%s*IconTexture:%s*([^\r\n]+)")
    assertEqual(declared, ICON)
    assertNil(declared:match("^%d+$"), "never a numeric file id")
end)

-- ---------------------------------------------------------------------------
-- The click rule (launcher-§2) -- WhatGroup is on rung (a)
-- ---------------------------------------------------------------------------

test("launcher: LEFT-click toggles the group popup, through the addon's own seam", function()
    -- RUNG (a): the popup is the primary window, so the left button spends itself on it and the
    -- panel keeps the right button. The click drives WhatGroup:ToggleFrame -- the same seam the
    -- Close button and ESC close the popup with -- so the launcher holds no copy of "is it up".
    -- red under: onClick opening the settings panel (rung (c) behavior, which would make a skipped
    -- rule look like a choice), or a second show/hide implementation on the object.
    local NS, mock, object = launched()
    NS.addon.pendingInfo = { title = "Stonevault", leaderName = "Testadin", fullName = "The Stonevault",
                             shortName = "", playstyleString = "", generalPlaystyle = 0,
                             activityID = 2516, mapID = 2652 }
    object.OnClick(nil, "LeftButton")
    assertTrue(onScreen(mock), "the popup opens")
    object.OnClick(nil, "LeftButton")
    assertFalse(onScreen(mock), "and the same click closes it again")
end)

test("launcher: a LEFT-click dismissal ends test mode, as the Close button does", function()
    -- A click that takes the popup off screen is a player dismissal in the full sense, so the Test
    -- mode checkbox must not stay ticked over a popup that is gone.
    -- red under: ToggleFrame calling hidePopup directly instead of the shared dismissPopup body.
    local NS, mock, object = launched()
    local H = NS.addon.Settings.Helpers
    H.Set("state.testMode", true)
    assertTrue(onScreen(mock), "test mode put the popup up")
    object.OnClick(nil, "LeftButton")
    assertFalse(onScreen(mock), "the click put it away")
    assertFalse(H.Get("state.testMode"), "and test mode went with it")
end)

test("launcher: RIGHT-click opens the settings panel", function()
    -- Always, on every addon, whatever rung its left click sits on -- which is what lets rung (a)
    -- spend the left button on the popup at all.
    -- red under: the right button toggling the popup too, or doing nothing.
    local NS, mock, object = launched()
    local before = #mock.openedTo
    object.OnClick(nil, "RightButton")
    assertEqual(#mock.openedTo, before + 1, "the settings category was opened")
    assertFalse(onScreen(mock), "and the popup stayed shut")
    assertTrue(NS.addon.OpenSettings ~= nil, "through the addon's own opener, not a copy of it")
end)

-- ---------------------------------------------------------------------------
-- The visibility row (launcher-§3)
-- ---------------------------------------------------------------------------

test("launcher: the Minimap button row is stored, global, and LibDBIcon's OWN hide key", function()
    -- One boolean, in the GLOBAL store, and it is the key LibDBIcon itself writes from its own
    -- right-click menu. A parallel `minimap.show` would be a second copy of one state.
    -- red under: sessionOnly on the row, a profile-scoped path, or a second key beside `hide`.
    local NS = T.enableAddon()
    local row = NS.addon.Settings.Helpers.FindSchema("global.minimap.hide")
    assertTrue(row ~= nil, "the row exists")
    assertEqual(row.label, "Minimap button")
    assertEqual(row.type, "bool")
    assertEqual(row.default, true, "the row's sense is SHOWN")
    assertNil(row.sessionOnly, "stored: a button the player hid stays hidden across a reload")
    assertEqual(NS.addon.db.global.minimap.hide, false, "seeded in the GLOBAL store")
    assertNil(NS.addon.db.profile.global, "and nothing like it in the profile")
end)

test("launcher: the row's get/set invert, and the button follows immediately", function()
    -- The row says SHOWN, the stored key says hidden, and the inversion is the host's -- at the
    -- single write seam, so the checkbox, `/wg set` and `/wg reset` all invert with it. The Show /
    -- Hide call is what stops the button waiting for a reload.
    -- red under: storing the row's value uninverted, or writing the key without telling LibDBIcon.
    local NS, mock = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    assertTrue(H.Get("global.minimap.hide"), "shown by default")
    assertTrue(mock.minimapButtons[NAME].shown)

    H.Set("global.minimap.hide", false)
    assertEqual(NS.addon.db.global.minimap.hide, true, "the STORED key says hidden")
    assertFalse(H.Get("global.minimap.hide"), "and the row reads not-shown")
    assertFalse(mock.minimapButtons[NAME].shown, "the button went away now, not at the next reload")

    H.Set("global.minimap.hide", true)
    assertEqual(NS.addon.db.global.minimap.hide, false)
    assertTrue(mock.minimapButtons[NAME].shown, "and came back")
end)

-- ---------------------------------------------------------------------------
-- Surviving a reset (launcher-§3, as amended in standard v2.54.0)
-- ---------------------------------------------------------------------------
--
-- THE PROPERTY, NOT THE DERIVATION. The section used to argue the row could not be reached: `Reset
-- all settings` is a profile reset, the table is global, therefore it is safe. That premise is not
-- universal -- an addon with no `profile` section at all resets its global store wholesale -- and
-- the argument was only ever about that one control, so a page-scoped **Defaults** button walking
-- every Master-controls row that carries a `default` walked straight past it. Two adoptions found
-- this independently.
--
-- The rule is stated now instead: whether the button is shown is a per-installation display
-- preference, the same class of thing as the ANGLE the player dragged it to, which LibDBIcon keeps
-- in the very same table and which no reset touches. It survives BOTH resets.
--
-- NEITHER OF THE TWO REACHED SHAPES IS THIS ADDON'S, and the three cases below run the real resets
-- rather than asserting that. WhatGroup has a genuine `db.profile`, and `Helpers.RestoreAllDefaults`
-- (settings/Schema.lua) is `db:ResetProfile()` -- which AceDB confines to the active profile --
-- plus a sweep narrowed to `sessionOnly` rows. The minimap row is neither a profile row nor
-- `sessionOnly`, so neither half addresses it. And General's **Defaults** button is not the
-- library's row-walking `RestoreDefaults`: settings/Panel.lua parks `ctx.panel.defaultsOnClick` on
-- the WHATGROUP_RESET_ALL popup, which both the library's header button and Blizzard's own footer
-- control resolve through, so that button IS *Reset all settings*. No row is exempted anywhere,
-- because nothing reaches the row to exempt it from.
--
-- Every case moves a PROFILE row off its default in the same act and asserts it came back, so a
-- reset that quietly did nothing cannot pass for one the minimap row survived.

local DELAY = "notify.delay"

-- A hidden button and a dirty profile row, ready for a reset to be run at them.
local function hiddenAndDirty(NS, H)
    H.Set("global.minimap.hide", false)
    H.Set(DELAY, 6)
    assertEqual(NS.addon.db.global.minimap.hide, true, "the player hid it")
end

local function assertSurvived(NS, mock, H)
    assertEqual(H.Get(DELAY), 0, "the profile row really was reset")
    assertEqual(NS.addon.db.global.minimap.hide, true, "the STORED key still says hidden")
    assertFalse(H.Get("global.minimap.hide"), "the row still reads not-shown")
    assertFalse(mock.minimapButtons[NAME].shown, "and the button did not come back")
end

test("launcher: a button the player hid survives Reset all settings (options-ui-§12)", function()
    -- The verb form, the shortest route to the one body all three surfaces share.
    -- red under: moving the table under db.profile, or the sessionOnly sweep widening to the
    -- global rows.
    local NS, env, mock = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    hiddenAndDirty(NS, H)
    NS.addon:OnSlashCommand("resetall")
    env.StaticPopupDialogs["WHATGROUP_RESET_ALL"].OnAccept()
    assertSurvived(NS, mock, H)
end)

test("launcher: a button the player hid survives the General page's Defaults button", function()
    -- The shape that surprised Ka0s Consumable Master: a page Defaults button that walks every
    -- Master-controls row with a `default` rewrites `minimap.hide` back to shown, profile boundary
    -- or no profile boundary. This addon's button is not that walk, and the only way to say so is
    -- to click it.
    -- red under: dropping `ctx.panel.defaultsOnClick`, which leaves the library's own
    -- `RestoreDefaults("general")` -- it walks `rowsForPage`, which here is the WHOLE schema, and it
    -- has no veto seam at all.
    local NS, env, mock = openGeneral()
    local H = NS.addon.Settings.Helpers
    hiddenAndDirty(NS, H)
    widget(mock, "Button", "Defaults"):Fire("OnClick")
    env.StaticPopupDialogs["WHATGROUP_RESET_ALL"].OnAccept()
    assertSurvived(NS, mock, H)
end)

test("launcher: a button the player hid survives the Master controls reset button", function()
    -- The third surface, and the one a player is likeliest to reach: the composed button pair at
    -- the foot of the first tab (options-ui-§15). Same body -- and this case exists because "same
    -- body" is a claim about code, not about behavior.
    -- red under: settings/Panel.lua's `onResetAll` reaching a row walk instead of the popup.
    local NS, env, mock = openGeneral()
    local H = NS.addon.Settings.Helpers
    hiddenAndDirty(NS, H)
    widget(mock, "Button", "Reset all settings"):Fire("OnClick")
    env.StaticPopupDialogs["WHATGROUP_RESET_ALL"].OnAccept()
    assertSurvived(NS, mock, H)
end)

test("launcher: LibDBIcon's own writes into the table are not disturbed", function()
    -- `minimapPos` is the library's key in the library's table, written when the player drags the
    -- button. Nothing here addresses it, and the row's set must not flatten it.
    -- red under: the write seam replacing the whole `minimap` table instead of one key.
    local NS = T.enableAddon()
    NS.addon.db.global.minimap.minimapPos = 217.5
    NS.addon.Settings.Helpers.Set("global.minimap.hide", false)
    assertEqual(NS.addon.db.global.minimap.minimapPos, 217.5, "the dragged angle survived")
end)

-- ---------------------------------------------------------------------------
-- Degradation (testing-§8)
-- ---------------------------------------------------------------------------

local NO_BROKERS = function(mock)
    mock.__libs["LibDataBroker-1.1"] = nil
    mock.__libs["LibDBIcon-1.0"] = nil
end

test("launcher: an install with neither broker library loads, and says so once", function()
    -- Both are OptionalDeps and both are resolved with the silent flag at Register time, so the
    -- addon must come up without a button rather than not come up.
    -- red under: a hard LibStub lookup in core/LauncherSetup.lua, or an unguarded Register.
    local NS, mock = T.enableAddon{ mock = NO_BROKERS }
    assertFalse(NS.Launcher:IsRegistered(), "nothing to register against")
    assertNil(NS.Launcher:Object())
    local said = 0
    for _, line in ipairs(mock.prints) do
        if line:find("LibDataBroker", 1, true) then said = said + 1 end
    end
    assertEqual(said, 1, "one honest line naming the missing library")
end)

test("launcher: with no LibDBIcon the broker plugin still registers", function()
    -- A broker display shows what it chooses to show and needs no minimap button, so losing one
    -- library must not lose the other.
    -- red under: registering the object only after LibDBIcon resolves.
    local NS, mock = T.enableAddon{ mock = function(m) m.__libs["LibDBIcon-1.0"] = nil end }
    assertTrue(mock.ldbObjects[NAME] ~= nil, "the broker object is there")
    assertFalse(NS.Launcher:IsRegistered(), "but the button is not, and it says so")
    assertNil(mock.minimapButtons[NAME])
end)

test("launcher: the row still stores with no broker library at all", function()
    -- The checkbox must not silently lose the player's choice on an install with no button to move:
    -- the write seam updates the store itself and only then asks the launcher to act.
    -- red under: the seam delegating the WRITE to LibDBIcon.
    local NS = T.enableAddon{ mock = NO_BROKERS }
    local H = NS.addon.Settings.Helpers
    H.Set("global.minimap.hide", false)
    assertEqual(NS.addon.db.global.minimap.hide, true)
    assertFalse(H.Get("global.minimap.hide"))
end)

test("launcher: with LibKa0s absent the seam still answers every member", function()
    -- The degradation stub every core/ setup file carries. The one thing that still works is the
    -- stored flag, because the write seam calls SetShown on every tick of the checkbox.
    -- red under: core/LauncherSetup.lua returning early without publishing NS.Launcher.
    local NS = T.enableAddon{ skip = { "libs/LibKa0s/Launcher.lua" } }
    assertTrue(NS.Launcher ~= nil, "the namespace member exists on the degraded path too")
    assertFalse(NS.Launcher:Register())
    assertFalse(NS.Launcher:IsRegistered())
    assertNil(NS.Launcher:Object())
    assertTrue(NS.Launcher:IsShown(), "shown, from the store rather than from a button")
    NS.Launcher:SetShown(false)
    assertEqual(NS.addon.db.global.minimap.hide, true, "and the store still moves")
end)
