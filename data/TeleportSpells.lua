-- data/TeleportSpells.lua
-- mapID → Path-of teleport spell ID lookup.
--
-- Keyed by the dungeon's instance map ID (stable across seasons).
-- pendingInfo.mapID is captured into this from
-- C_LFGList.GetActivityInfoTable's mapID field; activityIDs rotate per
-- season and aren't reliable lookup keys.
--
-- Values are either a single spellID (number) or a list of candidates
-- (table). When multiple Path-of spells have been issued for the same
-- dungeon over the years (an original spell + a later refresh), list
-- both — GetTeleportSpell picks whichever the player actually knows
-- via IsSpellKnown.
--
-- Refresh recipe (new season / patch): see
-- docs/common-tasks.md → "Add a dungeon teleport spell mapping".

local _, _ = ...
local WhatGroup = _G.WhatGroup

WhatGroup.TeleportSpells = {

    -- ===== Wrath of the Lich King =====
    [658]  = 1254555,             -- Pit of Saron

    -- ===== Cataclysm =====
    [643]  = 424142,              -- Throne of the Tides
    [657]  = 410080,              -- The Vortex Pinnacle
    [670]  = 445424,              -- Grim Batol

    -- ===== Mists of Pandaria =====
    [959]  = 131206,              -- Shado-Pan Monastery
    [960]  = 131204,              -- Temple of the Jade Serpent
    [961]  = 131205,              -- Stormstout Brewery
    [962]  = 131225,              -- Gate of the Setting Sun
    [994]  = 131222,              -- Mogu'shan Palace
    [1001] = 131229,              -- Scarlet Monastery
    [1004] = 131231,              -- Scarlet Halls
    [1007] = 131232,              -- Scholomance
    [1011] = 131228,              -- Siege of Niuzao Temple

    -- ===== Warlords of Draenor =====
    [1175] = 159895,              -- Bloodmaul Slag Mines
    [1176] = 159899,              -- Shadowmoon Burial Grounds
    [1182] = 159897,              -- Auchindoun
    [1195] = 159896,              -- Iron Docks
    [1208] = 159900,              -- Grimrail Depot
    [1209] = { 159898, 1254557 }, -- Skyreach
    [1279] = 159901,              -- The Everbloom
    [1358] = 159902,              -- Upper Blackrock Spire

    -- ===== Legion =====
    [1458] = 410078,              -- Neltharion's Lair
    [1466] = 424163,              -- Darkheart Thicket
    [1477] = 393764,              -- Halls of Valor
    [1501] = 424153,              -- Black Rook Hold
    [1571] = 393766,              -- Court of Stars
    [1651] = 373262,              -- Return to Karazhan
    [1753] = 1254551,             -- Seat of the Triumvirate

    -- ===== Battle for Azeroth =====
    [1594] = { 467555, 467553 },  -- The MOTHERLODE!!
    [1754] = 410071,              -- Freehold
    [1763] = 424187,              -- Atal'Dazar
    [1822] = 464256,              -- Siege of Boralus
    [1841] = 410074,              -- The Underrot
    [1862] = 424167,              -- Waycrest Manor
    [2097] = 373274,              -- Operation: Mechagon

    -- ===== Shadowlands =====
    [2284] = 354469,              -- Sanguine Depths
    [2285] = 354466,              -- Spires of Ascension
    [2286] = 354462,              -- The Necrotic Wake
    [2287] = 354465,              -- Halls of Atonement
    [2289] = 354463,              -- Plaguefall
    [2290] = 354464,              -- Mists of Tirna Scithe
    [2291] = 354468,              -- De Other Side
    [2293] = 354467,              -- Theater of Pain
    [2296] = 373190,              -- Castle Nathria (raid)
    [2441] = 367416,              -- Tazavesh: Streets / So'leah's
    [2450] = 373191,              -- Sanctum of Domination (raid)
    [2481] = 373192,              -- Sepulcher of the First Ones (raid)

    -- ===== Dragonflight =====
    [2080] = 393267,              -- Brackenhide Hollow
    [2451] = 393283,              -- Halls of Infusion
    [2515] = 393279,              -- The Azure Vault
    [2516] = 393262,              -- The Nokhud Offensive
    [2519] = 393276,              -- Neltharus
    [2521] = 393256,              -- Ruby Life Pools
    [2522] = 432254,              -- Vault of the Incarnates (raid)
    [2526] = 393273,              -- Algeth'ar Academy
    [2549] = 432258,              -- Amirdrassil, the Dream's Hope (raid)
    [2569] = 432257,              -- Aberrus, the Shadowed Crucible (raid)
    [2579] = 424197,              -- Dawn of the Infinite (validate mapID)
    -- [xxxx] = 393222,              -- Uldaman: Legacy of Tyr (validate mapID)

    -- ===== The War Within =====
    [2648] = 445443,              -- The Rookery
    [2649] = 445444,              -- Priory of the Sacred Flame
    [2651] = 445441,              -- Darkflame Cleft
    [2652] = 445269,              -- The Stonevault
    [2660] = 445417,              -- Ara-Kara, City of Echoes
    [2661] = 445440,              -- Cinderbrew Meadery
    [2662] = 445414,              -- The Dawnbreaker
    [2669] = 445416,              -- City of Threads
    [2773] = 1216786,             -- Operation: Floodgate
    [2830] = 1237215,             -- Eco-Dome Al'dani
    [2769] = 1226482,             -- Liberation of Undermine (raid)
    [2810] = 1239155,             -- Manaforge Omega (raid)
    -- [xxxx] = yyyyyyy,             -- Nerub-ar Palace (raid) (spell does not exist, adding as placeholder for now)

    -- ===== Midnight =====
    [2805] = 1254400,             -- Windrunner Spire
    [2811] = 1254572,             -- Magisters' Terrace
    [2874] = 1254559,             -- Maisara Caverns
    -- [xxxx] = yyyyyyy,             -- The Dreamrift (raid) (spell does not exist, adding as placeholder for now)
    -- [xxxx] = yyyyyyy,             -- The Voidspire (raid) (spell does not exist, adding as placeholder for now)
    -- [xxxx] = yyyyyyy,             -- March on Quel'Danas (raid) (spell does not exist, adding as placeholder for now)
}
