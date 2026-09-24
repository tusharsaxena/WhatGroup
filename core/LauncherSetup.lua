-- core/LauncherSetup.lua — wires the addon into LibKa0s-Launcher-1.0 (launcher-§1).
--
-- ONE LibDataBroker object, registered twice: LibDBIcon draws the minimap button from it and any
-- broker display that is installed draws its row from the very same object. One OnClick, one icon,
-- one identity. Two objects with two click handlers is the same feature written twice and is
-- anti-pattern #81 — which is the whole reason this is a five-field descriptor here and a module
-- in the library rather than sixty lines in every addon.
--
-- ── WHAT IS OURS ─────────────────────────────────────────────────────────────────────────────
--
-- The folder name, the logo, what the LEFT button does, and how the settings panel opens. The
-- library owns the rest: the object, both registrations, the click dispatch, the right-click rule
-- and the two LibStub lookups.
--
-- ── THE RUNG ─────────────────────────────────────────────────────────────────────────────────
--
-- WhatGroup is on rung (a) of launcher-§2 (the standard's ADDONS.md records it): it has a PRIMARY
-- WINDOW — the group popup — so LEFT-click toggles that window, through the same
-- `WhatGroup:ToggleFrame` seam the Close button and ESC already close it with. The launcher holds
-- no state of its own about whether the popup is up; it asks the module that owns it.
--
-- RIGHT-click opens the settings panel, on every addon in the collection, and that is the
-- library's own rule rather than a line here.
--
-- ── WHY REGISTER IS NOT CALLED HERE ──────────────────────────────────────────────────────────
--
-- `db.global.minimap` does not exist at file load: AceDB is built in OnInitialize. So `minimap`
-- below is a FUNCTION the library resolves at Register time, and Register itself is called from
-- OnEnable (core/WhatGroup.lua), by which point the db is there. A table captured at load would be
-- a table AceDB later replaced, and the button's position would then be written into a table
-- nothing saves.
--
-- ── TOC SLOT ─────────────────────────────────────────────────────────────────────────────────
--
-- After core/DebugLogSetup.lua, which publishes NS.Debug. Conventional rather than load-bearing:
-- every seam below is read inside a closure at CLICK or REGISTER time — the settings panel and the
-- popup both live in files that load later — and the only thing resolved at load is the LibStub
-- lookup and the icon path.

local addonName, NS = ...

local lib = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

-- THE ADDON'S OWN LOGO, and the same file `## IconTexture` names (launcher-§4, layout-§4): the
-- AddOns list, the minimap button and a broker display then show one identity rather than three.
-- Never a Blizzard icon path and never a numeric file id (anti-pattern #82) — this TOC carried the
-- file id 134149 until the launcher landed, which is to say the addon looked like a Blizzard bag in
-- the one list where the player decides what to turn off.
--
-- BUILT FROM `addonName`, the first vararg every TOC-loaded file gets, for the reason
-- core/MediaSetup.lua spells out at length: the library is vendored and a texture path is absolute
-- from Interface\AddOns\, so the folder this copy was installed into is the only string that can be
-- right. The file half is the folder LOWERCASED, which is what layout-§4 names it.
local ICON = ("Interface\\AddOns\\%s\\media\\logos\\%s.logo.128.tga")
    :format(addonName, addonName:lower())

--- LibDBIcon's own table, resolved at Register time. Nil until OnInitialize has run.
---
--- launcher-§3 puts it in the GLOBAL store and that is the decision rather than an accident: a
--- profile switch must not move a player's buttons, so the ring of buttons around the minimap is
--- furniture the INSTALLATION owns and not something a profile copies.
---
--- SURVIVING A RESET IS A SEPARATE RULE and no longer derived from that one (launcher-§3, standard
--- v2.54.0): a player's minimap-button choice is a per-installation display preference, like the
--- ANGLE LibDBIcon keeps in this same table, so it survives both options-ui-§12's *Reset all
--- settings* and a page-scoped Defaults button — whatever store it happens to sit in. Nothing here
--- has to exempt it, because nothing in this addon reaches it; tests/test_launcher.lua runs all
--- three reset surfaces and says so. settings/Schema.lua declares the default and routes the
--- Master-controls row's get/set to it.
local function minimapStore()
    local db = NS.addon and NS.addon.db
    return db and db.global and db.global.minimap
end

if not lib then
    -- The degradation stub every other setup file in core/ carries. Every member the addon calls is
    -- here and answers honestly: there is no launcher, and the ONE thing that still works without
    -- the library is the stored flag, because settings/Schema.lua's write seam calls SetShown on
    -- every tick of the Minimap button checkbox and a row that silently lost its value would be
    -- worse than a row with no button behind it.
    --
    -- One announce, at the one entry point (core/WhatGroup.lua's OnEnable calls Register once).
    local missing = NS.LIBKA0S_MISSING .. ", so there is no minimap button and no broker plugin."
    local said = false

    NS.Launcher = {
        Register = function()
            if not said then
                said = true
                if NS.Print then NS.Print(missing) end
            end
            return false
        end,
        IsRegistered = function() return false end,
        Object       = function() return nil end,
        IsShown      = function()
            local t = minimapStore()
            return not (t and t.hide)
        end,
        SetShown     = function(_, shown)
            local t = minimapStore()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = lib:New({
    -- THE FOLDER NAME, used for BOTH registrations, and not cosmetic: LibDBIcon keys the button's
    -- SAVED POSITION by it, so a second spelling drops the angle the player dragged the button to
    -- and labels the broker plugin with the other name.
    name  = addonName,
    icon  = ICON,
    -- What a broker display prints beside the icon, and it is the addon's BRAND NAME IN PLAIN TEXT
    -- (launcher-§1, standard v2.54.0). A display prints this row beside the other ten Ka0s addons,
    -- so `label` is the one field that decides whether the collection reads as one collection or as
    -- eleven unrelated addons: across eleven adoptions it came out three ways, and a display sorting
    -- its plugins alphabetically then filed one of them under A while the rest sat under K.
    --
    -- DELIBERATELY NOT THE TOC `## Title`, which is what this line used to read through NS.Meta. The
    -- two agree today, letter for letter, which is exactly why the wiring lasted — but a Title MAY
    -- carry color escapes and one in the collection does (Ka0s Pretty Chat's is
    -- `Ka0s |cffff0000P|cffff9900r|…`), and a display that draws the string raw splatters that row
    -- across a list in which every other row is plain text. So no escape sequence of any kind, and
    -- the two fields are not wired to each other.
    --
    -- Not the folder name either: `addonName` is the registration NAME above, the identifier
    -- LibDBIcon keys the saved position by. Two fields, two jobs.
    label = "Ka0s WhatGroup",

    -- A FUNCTION, not the table: see the header. The library calls it once, at Register.
    minimap = minimapStore,

    -- RIGHT-click always, and LEFT-click on rung (c) — which this addon is not on. The same body
    -- `/wg config` runs, reached through the addon rather than copied: the combat refusal and the
    -- idempotent category registration both live inside it (settings/Slash.lua).
    openSettings = function() NS.addon:OpenSettings() end,

    -- THE LEFT CLICK, AND ITS PRESENCE IS THE RUNG (launcher-§2). The group popup is the primary
    -- window, so it toggles. Resolved at click time because modules/Frame.lua loads after this file.
    --
    onClick = function() NS.addon:ToggleFrame() end,

    -- GATED ON THE STAND-DOWN LATCH (slash-commands-§7, launcher-§2), and the gate is the
    -- LIBRARY'S (LibKa0s-Launcher-1.0 minor 2): it asks `isEnabled` on every left click and, when
    -- that answers false, prints `disabledLine` and never calls onClick. The left button drives
    -- the primary window, which is a FEATURE, so a disabled addon refuses it rather than toggle a
    -- popup the player switched off. The right click is not gated: opening the settings panel is
    -- how the player turns the addon back on. The refusal is the Slash dispatcher's own line,
    -- asked rather than respelled, so the launcher and `/wg show` say one sentence between them.
    -- Both are resolved at click time: NS.IsStoodDown and NS.SlashCommands load after this file.
    isEnabled    = function() return not NS.IsStoodDown() end,
    disabledLine = function() return NS.SlashCommands:DisabledLine() end,

    print = function(line) NS.Print(line) end,
    debug = function(tag, message) NS.Debug(tag, message) end,

    -- Deliberately NOT passed:
    --   onTooltipShow — the button's tooltip is the library's default, which names the addon and
    --                   says what each button does. This addon has no live value to put there: the
    --                   popup's contents are a capture, not a number, and a tooltip that read
    --                   "no group" most of the time would be worse than the two click hints.
    --   L             — nothing here is translated yet, and NS.L answers every key with the key
    --                   itself (anti-patterns #2), so handing it over would render the launcher's
    --                   own reports as NO_BROKER / NO_ICON.
})
