-- core/Constants.lua
-- The addon's one frame-layering table (frame-layering-§5). Every SetFrameStrata in the addon reads
-- it, so no strata call in core, modules or settings types a quoted literal. The addon sets no
-- frame level of its own, so there is no LEVEL table yet: a level band added later goes here as
-- LEVEL.<NAME>, relative to its parent (frame-layering-§3), never as an absolute number.
--
-- THE WHOLE STACK, the library- and Blizzard-owned tiers the popup is placed around included
-- (frame-layering-§1 tier keys, §6 library rows):
--
--   T0 exempt          ESC proxy `WhatGroupFrameEscape`, binding button `WhatGroupTogglePopup`
--                      (modules/Frame.lua): no visuals, no mouse, inherit UIParent's MEDIUM.
--   MEDIUM (library)   LibDBIcon's minimap button, fixed level 8 (the library's choice).
--   HIGH (Blizzard)    the Settings panel, toplevel. The General, Profiles and landing canvases
--                      inherit it; LibKa0s's combat cover sits over them at a measured level.
--   DIALOG  MODAL      the group info popup `WhatGroupFrame` -- the event-raised notice previewed
--                      from Settings (frame-layering-§1's documented exception): NOT toplevel,
--                      Raise()d on an explicit show out of combat, children at parent + 1. Its
--                      tier-mates are toplevel, so a click on them wins: the LibKa0s debug console
--                      and the reset confirmation StaticPopup.
--   FULLSCREEN         the LibKa0s copy window, over the console that opens it.
--   FULLSCREEN_DIALOG  AceGUI pullouts (General visibility, the Profiles selects), Blizzard's Menu
--                      (the launcher's context menu).
--   TOOLTIP            GameTooltip (the teleport spell, the launcher).
--   library levels     the LibKa0s resize grip (+10, the console's) and the combat cover
--                      (max(panel + 100, deepest + 1), capped 10000).
--
-- modules/Frame.lua reads LAYERS at file scope (its STRATA_POPUP), and the # Core -> # Modules group
-- order already guarantees that read, so the slot within # Core is conventional (toc-file-§5).

local _, NS = ...

NS.Constants = NS.Constants or {}

NS.Constants.LAYERS = {
    STRATA = {
        MODAL = "DIALOG",
    },
}
