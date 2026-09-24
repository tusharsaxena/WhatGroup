-- tests/test_launcher.lua — the launcher (launcher-§1 to launcher-§5): ONE LibDataBroker object, registered
-- twice, wearing this addon's own logo, answering a left click with the settings panel and a right
-- click with the options menu.
--
-- What is pinned here is the WIRING, because everything else about the object is
-- LibKa0s-Launcher-1.0's and is tested where it lives. Three things nothing else can see:
--
--   * that the two registrations really are ONE object (two objects with two OnClicks is the same
--     feature written twice, anti-pattern #81, and both would pass a behavioral assertion);
--   * that each options-menu entry drives the addon's REAL verb body rather than a copy of it --
--     the four entries are the standard's ADDONS.md row for this addon;
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
    -- color escapes and one in the collection does, so a label sourced from it splatters that
    -- addon's row across a broker list in which every other row is plain text.
    -- red under: `label = NS.Meta("Title")`.
    local _, mock = T.enableAddon{ mock = function(m)
        m.metadata.Title = "Ka0s |cffff0000W|cffff9900h|cffffff00at|rGroup"
    end }
    assertEqual(mock.ldbObjects[NAME].label, "Ka0s WhatGroup",
        "the label ignored a Title carrying color escapes")
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
-- The click rule (launcher-§2, standard v2.67.0; LibKa0s-Launcher-1.0 minor 4)
-- ---------------------------------------------------------------------------
--
-- LEFT opens the settings panel, in either state. RIGHT opens the client's context menu, titled
-- with the label, with one checkbox per toggle this addon has -- all four here: Enabled, Locked,
-- Test mode, Show window (the standard's ADDONS.md row). The library owns the menu; what is pinned
-- here is that each entry reaches the SAME body the addon's slash verb runs, which is the only
-- thing that keeps the refusals, the combat rules and the chat acks one addon's rather than two.
-- The menu is driven through tests/mock_menu.lua, installed on every build by tests/wow_mock.lua.

local CAPTURE = { title = "Stonevault", leaderName = "Testadin", fullName = "The Stonevault",
                  shortName = "", playstyleString = "", generalPlaystyle = 0,
                  activityID = 2516, mapID = 2652 }

-- Right-click the one object and hand back the menu the library just built.
local function openMenu(mock, object)
    local opens = mock.menu.opens
    object.OnClick(mock.UIParent, "RightButton")
    assertEqual(mock.menu.opens, opens + 1, "the right click opened a context menu")
    return mock.menu.last
end

-- What a chat command printed, and what a menu click printed, on two fresh addons, so the two
-- can be compared line for line.
local function printedBy(fn)
    local NS, mock, object = launched()
    local mark = #mock.prints
    fn(NS, mock, object)
    local out = {}
    for i = mark + 1, #mock.prints do out[#out + 1] = mock.prints[i] end
    return out, NS, mock
end

test("launcher: LEFT-click opens the settings panel, and never the popup", function()
    -- One meaning for the left button on every addon (launcher-§2, v2.67.0): the rungs are gone,
    -- and the popup's toggle moved to the menu's Show window entry.
    -- red under: a descriptor still passing onClick (the library ignores it, so the source pin
    -- below is the half that reddens), or a host-side click route.
    local NS, mock, object = launched()
    NS.addon.pendingInfo = CAPTURE
    local before = #mock.openedTo
    object.OnClick(mock.UIParent, "LeftButton")
    assertEqual(#mock.openedTo, before + 1, "the settings category was opened")
    assertFalse(onScreen(mock), "and the popup stayed shut")
    assertEqual(mock.menu.opens, 0, "and no menu opened")
end)

test("launcher: LEFT-click opens the panel while disabled too, with no refusal line", function()
    -- The panel is setup, not a feature, and it is where a disabled addon is switched back on.
    -- red under: a host gate on the left click, or the retired disabledLine refusal.
    local NS, mock, object = launched()
    NS.addon.Settings.Helpers.Set("enabled", false)
    local before, mark = #mock.openedTo, #mock.prints
    object.OnClick(mock.UIParent, "LeftButton")
    assertEqual(#mock.openedTo, before + 1, "the panel opened")
    assertEqual(#mock.prints - mark, 0, "and nothing was printed")
end)

test("launcher: RIGHT-click opens a menu titled with the label, with all four entries in order",
function()
    -- WhatGroup has every state the menu can carry: the enabled row, the Lock frame row, the
    -- session Test mode, and a primary window -- the group popup. ADDONS.md records exactly
    -- these four; the library draws an entry only for a full accessor-and-toggle pair.
    -- red under: a missing pair (the entry vanishes), or the popup opening on a right click.
    local _, mock, object = launched()
    local menu = openMenu(mock, object)
    assertEqual(menu.titles[1], "Ka0s WhatGroup", "titled with the label")
    local texts = menu:Texts()
    assertEqual(table.concat(texts, " / "), "Enabled / Locked / Test mode / Show window")
    assertTrue(menu:Checked("Enabled"), "Enabled reads checked")
    assertFalse(menu:Checked("Locked"), "Locked reads unchecked on a fresh profile")
    assertFalse(menu:Checked("Test mode"), "Test mode reads off")
    assertFalse(menu:Checked("Show window"), "and the popup is not up")
    assertEqual(#mock.openedTo, 0, "the right click did not open the settings panel")
end)

test("launcher: the Enabled entry runs the /wg disable|enable body, ack and all", function()
    -- setEnabled(on) is runEnabled, the body both verbs call: the same Helpers.Set write, the
    -- same refusal handling and the same `enabled = false` ack line.
    -- red under: a setEnabled that writes db.profile.enabled directly (no ack), or one that
    -- routes through anything but the verb's body.
    local viaSlash = printedBy(function(NS) NS.addon:OnSlashCommand("disable") end)
    local viaMenu, NS, mock = printedBy(function(_, m, o) openMenu(m, o):Click("Enabled") end)
    assertTrue(#viaSlash > 0, "the verb acknowledges")
    assertEqual(table.concat(viaMenu, "\n"), table.concat(viaSlash, "\n"),
        "the menu prints exactly what /wg disable prints")
    assertFalse(NS.addon.db.profile.enabled, "the stored row moved")
    assertTrue(NS.IsStoodDown(), "and the addon stood down")

    -- And back on, from the menu of the now-disabled addon: Enabled is the one live entry.
    openMenu(mock, mock.ldbObjects[NAME]):Click("Enabled")
    assertTrue(NS.addon.db.profile.enabled, "the menu switched it back on")
    assertFalse(NS.IsStoodDown())
end)

test("launcher: the Locked entry runs `/wg set locked toggle`, the Lock frame row's write",
function()
    -- WhatGroup ships no `/wg lock` verb: the Lock frame row is written through the schema seam,
    -- and its CLI form is `/wg set locked toggle` (the host's own `toggle` grammar). The entry
    -- runs exactly that, so its ack is the CLI's `locked = true`.
    -- red under: a toggleLock writing db.profile.locked directly, or a second lock path.
    local viaSlash = printedBy(function(NS) NS.addon:OnSlashCommand("set locked toggle") end)
    local viaMenu, NS, mock = printedBy(function(_, m, o) openMenu(m, o):Click("Locked") end)
    assertTrue(#viaSlash > 0, "the CLI acknowledges")
    assertEqual(table.concat(viaMenu, "\n"), table.concat(viaSlash, "\n"),
        "the menu prints exactly what /wg set locked toggle prints")
    assertTrue(NS.addon.db.profile.locked, "the popup is locked")
    assertTrue(openMenu(mock, mock.ldbObjects[NAME]):Checked("Locked"), "and the next open says so")
    openMenu(mock, mock.ldbObjects[NAME]):Click("Locked")
    assertFalse(NS.addon.db.profile.locked, "a second click unlocks")
end)

test("launcher: the Test mode entry runs the bare /wg test body", function()
    -- runTest("") -- the toggle form of the verb, writing the session row through Helpers.Set, so
    -- the Master controls checkbox follows and the popup comes up on its sample group.
    -- red under: a toggleTestMode flipping NS.State.testMode directly (no popup, no checkbox).
    local viaSlash = printedBy(function(NS) NS.addon:OnSlashCommand("test") end)
    local viaMenu, NS, mock = printedBy(function(_, m, o) openMenu(m, o):Click("Test mode") end)
    assertEqual(table.concat(viaMenu, "\n"), table.concat(viaSlash, "\n"),
        "the menu prints exactly what /wg test prints")
    local H = NS.addon.Settings.Helpers
    assertTrue(H.Get("state.testMode"), "test mode is on")
    assertTrue(onScreen(mock), "and the popup is up on the sample group")
    openMenu(mock, mock.ldbObjects[NAME]):Click("Test mode")
    assertFalse(H.Get("state.testMode"), "a second click ends it")
end)

test("launcher: the Show window entry toggles the group popup through WhatGroup:ToggleFrame",
function()
    -- The popup is the primary window. The entry drives the same seam the Close button and ESC
    -- close it with, and its checkmark reads whether the popup is ON SCREEN (a popup soft-hidden
    -- at alpha 0 in combat is not).
    -- red under: a toggleWindow with its own show/hide, or an isWindowShown reading f:IsShown().
    local NS, mock, object = launched()
    NS.addon.pendingInfo = CAPTURE
    openMenu(mock, object):Click("Show window")
    assertTrue(onScreen(mock), "the popup opens")
    assertTrue(openMenu(mock, object):Checked("Show window"), "and the next open reads it up")
    openMenu(mock, object):Click("Show window")
    assertFalse(onScreen(mock), "the same entry closes it again")
    assertFalse(openMenu(mock, object):Checked("Show window"))
end)

test("launcher: a Show window dismissal ends test mode, as the Close button does", function()
    -- Closing the popup from the menu is a player dismissal in the full sense, so the Test mode
    -- checkbox must not stay ticked over a popup that is gone.
    -- red under: ToggleFrame calling hidePopup directly instead of the shared dismissPopup body.
    local NS, mock, object = launched()
    local H = NS.addon.Settings.Helpers
    H.Set("state.testMode", true)
    assertTrue(onScreen(mock), "test mode put the popup up")
    assertTrue(openMenu(mock, object):Checked("Show window"), "the menu reads it up")
    mock.menu.last:Click("Show window")
    assertFalse(onScreen(mock), "the click put it away")
    assertFalse(H.Get("state.testMode"), "and test mode went with it")
end)

test("launcher: while disabled only Enabled is live; the rest are grayed and call nothing",
function()
    -- Features refuse while disabled (slash-commands-§7), and the library says so in the entry's
    -- own text rather than in a tooltip the client would not raise over a grayed entry.
    -- red under: an isEnabled that does not read the latch (entries stay live).
    local NS, mock, object = launched()
    NS.addon.pendingInfo = CAPTURE
    NS.addon.Settings.Helpers.Set("enabled", false)
    local menu = openMenu(mock, object)
    assertEqual(table.concat(menu:Texts(), " / "),
        "Enabled / Locked (enable the addon first) / Test mode (enable the addon first) / "
        .. "Show window (enable the addon first)")
    assertFalse(menu:Checked("Enabled"), "Enabled reads unchecked")
    for _, entry in ipairs({ "Locked", "Test mode", "Show window" }) do
        assertFalse(menu:Find(entry).enabled, entry .. " is grayed")
        assertNil(menu:Click(entry), entry .. " cannot be clicked")
    end
    assertFalse(NS.addon.db.profile.locked, "nothing locked")
    assertFalse(NS.addon.Settings.Helpers.Get("state.testMode"), "no test mode")
    assertFalse(onScreen(mock), "and no popup")
end)

test("launcher: with no MenuUtil the right click falls back to the settings panel", function()
    -- A client without the 11.0 menu API (or one whose menu system failed to load) still gets
    -- every toggle, on the panel. The library's degraded path, observed from the host.
    -- red under: a host that builds a menu of its own when MenuUtil is absent.
    local _, mock, object = launched()
    mock.menu.remove()
    local before = #mock.openedTo
    object.OnClick(mock.UIParent, "RightButton")
    assertEqual(#mock.openedTo, before + 1, "the panel opened instead")
end)

test("launcher: the descriptor passes the four pairs to the verbs' seams, and no retired field",
function()
    -- Source pins for what behavior cannot tell apart: the library ignores the retired fields, so
    -- a leftover `onClick` would pass every case above and still be dead configuration
    -- (launcher-§5); and each toggle names its verb's body rather than a copy of it.
    -- red under: onClick / leftClickLabel / disabledLine / slash left in the descriptor, or a
    -- toggle that stops naming the verb seam.
    local src = readFile("core/LauncherSetup.lua")
    for _, retired in ipairs({ "onClick", "leftClickLabel", "disabledLine", "slash" }) do
        assertNil(src:find("\n%s*" .. retired .. "%s*="), retired .. " is not passed")
    end
    assertTrue(src:find("setEnabled%s*=%s*function%(on%)%s*NS%.addon:SlashEnabled%(on%)") ~= nil,
        "setEnabled is the /wg enable|disable body")
    assertTrue(src:find("toggleLock%s*=%s*function%(%)%s*NS%.addon:SlashToggleLock%(%)") ~= nil,
        "toggleLock is `/wg set locked toggle`")
    assertTrue(src:find("toggleTestMode%s*=%s*function%(%)%s*NS%.addon:SlashToggleTestMode%(%)")
        ~= nil, "toggleTestMode is the bare /wg test body")
    assertTrue(src:find("toggleWindow%s*=%s*function%(%)%s*NS%.addon:ToggleFrame%(%)") ~= nil,
        "toggleWindow is the popup's own toggle")
end)

-- ---------------------------------------------------------------------------
-- The status tooltip (launcher-§1, LibKa0s-Launcher-1.0 minor 3)
-- ---------------------------------------------------------------------------
--
-- The LIBRARY draws it; what is pinned here is what this addon HANDS it. WhatGroup has both
-- states the tooltip can report -- the popup's Lock frame row and its session-only Test mode -- so
-- both lines appear, read from the same stores the Master controls rows read. The two click hints
-- are the library's fixed pair since minor 4. The version is the TOC's. And no onTooltipShow: this
-- addon has no extra line worth a hover, so the block is the library's alone.

-- A GameTooltip stand-in that records its lines, and a reader that strips the status colors.
local function hover(object)
    local tt = { lines = {} }
    function tt:AddLine(text) self.lines[#self.lines + 1] = text end
    object.OnTooltipShow(tt)
    return tt.lines
end

local function plain(lines)
    local out = {}
    for i, l in ipairs(lines) do out[i] = (l:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end
    return out
end

local function assertLines(got, want, what)
    assertEqual(#got, #want, what .. ": line count (" .. table.concat(got, " / ") .. ")")
    for i = 1, #want do assertEqual(got[i], want[i], what .. ": line " .. i) end
end

test("launcher: the tooltip reads title, status, lock, test mode, then the two click hints", function()
    -- The fresh-login shape: enabled, unlocked, test mode off. Every line is the library's, drawn
    -- from this descriptor, and nothing is drawn twice.
    -- red under: no isLocked / isTestMode (lines missing), no version (a bare title), or an
    -- onTooltipShow drawing a title or hint of its own.
    local _, _, object = launched()
    assertLines(plain(hover(object)), {
        "Ka0s WhatGroup  v1.4.0",
        "Enabled: Yes",
        "Locked: No",
        "Test mode: Off",
        "Left-click: Open settings",
        "Right-click: Options menu",
    }, "fresh login")
end)

test("launcher: Locked and Test mode are read on every hover, from the rows' own stores", function()
    -- Never cached: the tooltip must agree with the Master controls checkboxes the moment they
    -- move. Lock frame is the profile's `locked`; Test mode is the session's `state.testMode`.
    -- red under: an accessor reading anything but those two stores, or a value captured at load.
    local NS, _, object = launched()
    local H = NS.addon.Settings.Helpers
    H.Set("locked", true)
    H.Set("state.testMode", true)
    local lines = hover(object)
    assertLines(plain(lines), {
        "Ka0s WhatGroup  v1.4.0",
        "Enabled: Yes",
        "Locked: Yes",
        "Test mode: On",
        "Left-click: Open settings",
        "Right-click: Options menu",
    }, "locked, test mode on")
    assertTrue(lines[3]:find("|cFF00FF00", 1, true) ~= nil, "Yes is green")
    H.Set("locked", false)
    H.Set("state.testMode", false)
    local again = plain(hover(object))
    assertEqual(again[3], "Locked: No", "the next hover sees the unlock")
    assertEqual(again[4], "Test mode: Off", "and test mode ending")
end)

test("launcher: while disabled the tooltip still draws, with the same two click hints",
function()
    -- The owner's ruling: the button always answers a hover, including while the addon is off,
    -- which is when the player most needs to ask. Since minor 4 neither click is refused while
    -- disabled -- left opens the panel, right opens the menu with Enabled live -- so the hints do
    -- not change with the state.
    -- red under: the tooltip gated on isEnabled.
    local NS, _, object = launched()
    NS.addon.Settings.Helpers.Set("enabled", false)
    local lines = hover(object)
    assertLines(plain(lines), {
        "Ka0s WhatGroup  v1.4.0",
        "Enabled: No",
        "Locked: No",
        "Test mode: Off",
        "Left-click: Open settings",
        "Right-click: Options menu",
    }, "disabled")
    assertTrue(lines[2]:find("|cFFFF0000", 1, true) ~= nil, "No is red")
end)

test("launcher: the tooltip's version is the TOC's, not the in-code constant", function()
    -- slash-commands-§3's rule, reached through NS.Version: a packaged addon whose TOC can be read
    -- never reports the constant somebody forgot to edit.
    -- red under: `version = WhatGroup.VERSION`, or a version captured at file load.
    local _, mock = T.enableAddon{ mock = function(m) m.metadata.Version = "9.8.7" end }
    assertEqual(plain(hover(mock.ldbObjects[NAME]))[1], "Ka0s WhatGroup  v9.8.7")
end)

test("launcher: there is no host tooltip hook, and the retired label's locale row is gone", function()
    -- The descriptor passes no onTooltipShow, because every line this addon has to say is one the
    -- library draws (a hook drawing a title or a click hint is anti-pattern #89). The left-click
    -- label it used to localize went with rung (a), and a locale row nothing reads is a string a
    -- translator would be asked to translate for nothing.
    -- red under: an onTooltipShow in the descriptor, or the dead locale row left behind.
    local src = readFile("core/LauncherSetup.lua")
    assertNil(src:find("\n%s*onTooltipShow%s*="), "no host tooltip hook")
    assertNil(readFile("locales/enUS.lua"):find('L%["Toggle group popup"%]', 1, false),
        "the retired left-click label is not in the locale")
end)

-- ---------------------------------------------------------------------------
-- The visibility row (launcher-§3)
-- ---------------------------------------------------------------------------

test("launcher: the Minimap button row is stored, global, and LibDBIcon's OWN hide key", function()
    -- One boolean, in the GLOBAL store, and it is the key LibDBIcon itself writes from its own
    -- right-click menu. A parallel `minimap.show` would be a second copy of one state.
    -- red under: sessionOnly on the row, a profile-scoped path, or a second key beside `hide`.
    local NS = T.enableAddon()
    local row = NS.addon.Settings.Helpers.FindSchema("global.minimap.shown")
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
    assertTrue(H.Get("global.minimap.shown"), "shown by default")
    assertTrue(mock.minimapButtons[NAME].shown)

    H.Set("global.minimap.shown", false)
    assertEqual(NS.addon.db.global.minimap.hide, true, "the STORED key says hidden")
    assertFalse(H.Get("global.minimap.shown"), "and the row reads not-shown")
    assertFalse(mock.minimapButtons[NAME].shown, "the button went away now, not at the next reload")

    H.Set("global.minimap.shown", true)
    assertEqual(NS.addon.db.global.minimap.hide, false)
    assertTrue(mock.minimapButtons[NAME].shown, "and came back")
end)

-- ---------------------------------------------------------------------------
-- The row's path reads in the row's own sense (launcher-§3, standard v2.65.0)
-- ---------------------------------------------------------------------------
--
-- The path is also the row's CLI name, so a path spelled after the STORED key made
-- `/wg get global.minimap.hide` answer true while the button was on the minimap. The row is
-- declared at `global.minimap.shown`; storage does not move -- it is still LibDBIcon's own
-- `minimap.hide`, and nothing is ever written at `shown` (anti-pattern #81).

local function linesSince(mock, mark)
    local out = {}
    for i = mark + 1, #mock.prints do out[#out + 1] = mock.prints[i] end
    return out
end

local function anyLine(lines, fragment)
    for _, l in ipairs(lines) do
        if l:find(fragment, 1, true) then return true end
    end
    return false
end

test("launcher: the row's CLI path reads in its own sense", function()
    -- red under: the row declared at the stored key's name, `global.minimap.hide`.
    local NS, mock = T.enableAddon()
    local H = NS.addon.Settings.Helpers
    assertTrue(mock.minimapButtons[NAME].shown, "the button is on the minimap")
    assertTrue(H.Get("global.minimap.shown") == true, "and the row's path answers true")
    -- Spelled in two halves so the item's "no quoted old path left" sweep stays meaningful.
    local OLD = "global.minimap." .. "hide"
    assertNil(H.FindSchema(OLD), "the stored key's name is no row")
    local mark = #mock.prints
    NS.addon:OnSlashCommand("get " .. OLD)
    assertTrue(anyLine(linesSince(mock, mark), "Setting not found: " .. OLD),
               "the old path answers the unknown-setting refusal, not an alias")
end)

test("launcher: a legacy store with hide = true reads not-shown, and nothing moves", function()
    -- The carry-over: no SavedVariables migration, because the stored key is where it was. An
    -- existing player's `hide = true` reads as `shown = false` with no code, the dragged angle is
    -- untouched, and a set never materializes a `shown` key in the raw SavedVariables.
    -- red under: a stored `shown` key, or a migration that rewrites the minimap table.
    local NS, _, mock = T.newAddon()
    _G.WhatGroupDB = { global = { minimap = { hide = true, minimapPos = 200 } } }
    NS.addon:OnInitialize()
    NS.addon:OnEnable()
    local H = NS.addon.Settings.Helpers
    local mark = #mock.prints
    NS.addon:OnSlashCommand("get global.minimap.shown")
    local lines = linesSince(mock, mark)
    assertTrue(anyLine(lines, "global.minimap.shown") and anyLine(lines, "false"),
               "/wg get global.minimap.shown answers false")
    assertFalse(mock.minimapButtons[NAME].shown, "the button stays hidden")
    local sv = _G.WhatGroupDB.global.minimap
    assertEqual(sv.minimapPos, 200, "the dragged angle is untouched")

    H.Set("global.minimap.shown", true)
    H.Set("global.minimap.shown", false)
    assertEqual(sv.hide, true, "the store is still LibDBIcon's hide key")
    assertNil(rawget(sv, "shown"), "no shown key is ever written to the raw SavedVariables")
    assertEqual(sv.minimapPos, 200)
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
    H.Set("global.minimap.shown", false)
    H.Set(DELAY, 6)
    assertEqual(NS.addon.db.global.minimap.hide, true, "the player hid it")
end

local function assertSurvived(NS, mock, H)
    assertEqual(H.Get(DELAY), 0, "the profile row really was reset")
    assertEqual(NS.addon.db.global.minimap.hide, true, "the STORED key still says hidden")
    assertFalse(H.Get("global.minimap.shown"), "the row still reads not-shown")
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
    NS.addon.Settings.Helpers.Set("global.minimap.shown", false)
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
    H.Set("global.minimap.shown", false)
    assertEqual(NS.addon.db.global.minimap.hide, true)
    assertFalse(H.Get("global.minimap.shown"))
end)

test("launcher: with LibKa0s absent the seam answers honestly and the store still moves", function()
    -- The degradation stub every core/ setup file carries. The one thing that still works is the
    -- stored flag, because the write seam calls SetShown on every tick of the checkbox. That the
    -- stub carries EVERY member is tests/test_surface_parity.lua's Launcher case; this one pins what
    -- the members that matter answer.
    -- red under: Register claiming a button, or SetShown no longer writing the store.
    local NS = T.enableAddon{ skip = { "libs/LibKa0s/Launcher.lua" } }
    assertFalse(NS.Launcher:Register())
    assertTrue(NS.Launcher:IsShown(), "shown, from the store rather than from a button")
    NS.Launcher:SetShown(false)
    assertEqual(NS.addon.db.global.minimap.hide, true, "and the store still moves")
end)
