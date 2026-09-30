-- settings/Profiles.lua — the Profiles sub-page (options-ui-§3).
--
-- AceDBOptions' create / switch / copy / reset / delete UI, drawn by AceConfigDialog into an AceGUI
-- group inside this addon's own canvas. The canvas, header, breadcrumb and registration are still
-- LibKa0s-Options-1.0's, so the page looks like General rather than like a separate Ace window. It
-- is the one AceConfig use in this addon, and the reason is that the options table is not ours:
-- AceDBOptions generates it, and re-expressing it as schema rows would be a copy of AceDB's own
-- profile model.
--
-- NO DEFAULTS BUTTON (options-ui-§3). "Restore defaults" here would mean deleting profiles. The page
-- has no schema rows, so the global reset cannot reach it either: `/wg resetall` and the Defaults
-- button are `db:ResetProfile()` on the active profile (settings/Schema.lua's RestoreAllDefaults),
-- which is the same act as this page's own Reset Profile and never touches the profile list.
--
-- A switch, copy or reset made anywhere else (`/run`, the reset popup) reaches core/WhatGroup.lua's
-- reloadProfile, which calls Settings.RefreshProfilesPage below: AceConfigDialog re-reads the
-- active profile only when it is fed again, so the page is re-drawn if shown and marked dirty if
-- hidden. A change made ON the page needs nothing extra; AceConfigDialog re-opens the group itself.
--
-- Optional dependency: without AceDBOptions, AceConfig or AceConfigDialog the builder returns nil and
-- the page is simply absent. With LibKa0s absent, Helpers.RegisterOptionsPage is the degradation
-- stub's no-op (settings/OptionsSetup.lua), so nothing here runs at all.

local _, NS = ...
local WhatGroup = NS.addon
local Settings  = WhatGroup.Settings
local L         = NS.L

local APPNAME = "WhatGroup-Profiles"

-- The page's ctx once built, for Settings.RefreshProfilesPage. Nil until the builder has run, and
-- nil for the session when the page opted out.
local page

local function build(parentCategory)
    if not (_G.Settings and _G.Settings.RegisterCanvasLayoutSubcategory) then return nil end
    if not LibStub then return nil end
    local AceDBOptions    = LibStub("AceDBOptions-3.0", true)
    local AceConfig       = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceGUI          = LibStub("AceGUI-3.0", true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI) then return nil end
    local db = WhatGroup.db
    if not (db and db.profile) then return nil end
    local H = Settings.Helpers

    -- Registered once. The table AceDBOptions returns reads the db live, so a profile change does
    -- not need a new one.
    AceConfig:RegisterOptionsTable(APPNAME, AceDBOptions:GetOptionsTable(db))

    local ctx = H.CreatePanel("WhatGroupProfilesPanel", L["Profiles"], {
        pageKey        = "profiles",
        defaultsButton = false,
    })

    -- Built on first show, never in the builder (options-ui-§5), and on the next frame like every
    -- page here (settings/OptionsSetup.lua's SetRenderer wrapper keeps AceGUI frame creation out of
    -- Blizzard's secure-execute chains). Through H.SetRenderer rather than a hand-parked OnShow, so
    -- the page carries the library's combat lock: the Blizzard AddOns sidebar reaches a canvas
    -- without going through OpenOptionsPanel, which makes this page reachable mid-fight.
    local container
    H.SetRenderer(ctx, function()
        if not container then
            container = AceGUI:Create("SimpleGroup")
            container:SetLayout("Fill")
            container.frame:SetParent(ctx.body)
            container.frame:ClearAllPoints()
            container.frame:SetPoint("TOPLEFT", ctx.body, "TOPLEFT", 8, -8)
            container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
        end
        -- SHOWN EXPLICITLY, every render. AceGUI:Release hides a frame before pooling it, and
        -- neither AceGUI:Create nor AceConfigDialog:Open shows it again, so a pooled group would be
        -- filled while hidden and the page would read as blank.
        container.frame:Show()
        AceConfigDialog:Open(APPNAME, container)
    end)

    page = ctx
    return _G.Settings.RegisterCanvasLayoutSubcategory(parentCategory, ctx.panel, L["Profiles"])
end

-- Re-draw the page after a profile event: now if it is shown, on its next show if not. The
-- library's RefreshPanel owns that shown/hidden decision (LibKa0s-Options-1.0).
function Settings.RefreshProfilesPage()
    local H = Settings.Helpers
    if page and H and H.RefreshPanel then H.RefreshPanel(page, true) end
end

Settings.Helpers.RegisterOptionsPage("profiles", L["Profiles"], build)
