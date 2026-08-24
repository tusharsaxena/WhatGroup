-- defaults/TeleportSpells.lua
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
-- Each row's trailing comment gives the dungeon and, in parentheses, the
-- spell's own name — read back from C_Spell.GetSpellInfo in-game rather
-- than from a wiki. Two names separated by " / " means the candidates
-- genuinely differ; one name on a list row means Blizzard re-issued the
-- same spell under a second ID.
--
-- That parenthetical is a cross-check, not decoration. A spell name never
-- contains its dungeon's name ("Path of the Fractured Core" is
-- Nexus-Point Xenas), so searching a wiki by dungeon returns something
-- adjacent rather than nothing, and neighbouring IDs in a patch block are
-- unrelated spells. Take IDs off a spellbook that owns them — the sweep
-- is in docs/common-tasks.md — and treat a name that does not fit its
-- dungeon as a wrong ID.
--
-- Getting one wrong does not error. The row still renders, just
-- desaturated and tagged "(not learned)" for a player who owns the
-- teleport, with a /cast naming a spell nobody has.
--
-- Refresh recipe (new season / patch): see
-- docs/common-tasks.md → "Add a dungeon teleport spell mapping".

-- Writes straight to the shared private namespace (NS) so load order
-- relative to WhatGroup.lua doesn't matter — `self.TeleportSpells`
-- (self == NS.addon == NS) reads this same slot at lookup time.
local addonName, NS = ...

NS.TeleportSpells = {

    -- ===== Wrath of the Lich King =====
    -- Dungeons
    [658]  = 1254555,             -- Pit of Saron                    (Path of Unyielding Blight)

    -- ===== Cataclysm =====
    -- Dungeons
    [643]  = 424142,              -- Throne of the Tides             (Path of the Tidehunter)
    [657]  = 410080,              -- The Vortex Pinnacle             (Path of Wind's Domain)
    [670]  = 445424,              -- Grim Batol                      (Path of the Twilight Fortress)

    -- ===== Mists of Pandaria =====
    -- Dungeons
    [959]  = 131206,              -- Shado-Pan Monastery             (Path of the Shado-Pan)
    [960]  = 131204,              -- Temple of the Jade Serpent      (Path of the Jade Serpent)
    [961]  = 131205,              -- Stormstout Brewery              (Path of the Stout Brew)
    [962]  = 131225,              -- Gate of the Setting Sun         (Path of the Setting Sun)
    [994]  = 131222,              -- Mogu'shan Palace                (Path of the Mogu King)
    [1001] = 131229,              -- Scarlet Monastery               (Path of the Scarlet Mitre)
    [1004] = 131231,              -- Scarlet Halls                   (Path of the Scarlet Blade)
    [1007] = 131232,              -- Scholomance                     (Path of the Necromancer)
    [1011] = 131228,              -- Siege of Niuzao Temple          (Path of the Black Ox)

    -- ===== Warlords of Draenor =====
    -- Dungeons
    [1175] = 159895,              -- Bloodmaul Slag Mines            (Path of the Bloodmaul)
    [1176] = 159899,              -- Shadowmoon Burial Grounds       (Path of the Crescent Moon)
    [1182] = 159897,              -- Auchindoun                      (Path of the Vigilant)
    [1195] = 159896,              -- Iron Docks                      (Path of the Iron Prow)
    [1208] = 159900,              -- Grimrail Depot                  (Path of the Dark Rail)
    [1209] = { 159898, 1254557 }, -- Skyreach                        (Path of the Skies / Path of the Crowning Pinnacle)
    [1279] = 159901,              -- The Everbloom                   (Path of the Verdant)
    [1358] = 159902,              -- Upper Blackrock Spire           (Path of the Burning Mountain)

    -- ===== Legion =====
    -- Dungeons
    [1458] = 410078,              -- Neltharion's Lair               (Path of the Earth-Warder)
    [1466] = 424163,              -- Darkheart Thicket               (Path of the Nightmare Lord)
    [1477] = 393764,              -- Halls of Valor                  (Path of Proven Worth)
    [1501] = 424153,              -- Black Rook Hold                 (Path of Ancient Horrors)
    [1571] = 393766,              -- Court of Stars                  (Path of the Grand Magistrix)
    [1651] = 373262,              -- Return to Karazhan              (Path of the Fallen Guardian)
    [1753] = 1254551,             -- Seat of the Triumvirate         (Path of Dark Dereliction)

    -- ===== Battle for Azeroth =====
    -- Dungeons
    [1594] = { 467555, 467553 },  -- The MOTHERLODE!!                (Path of the Azerite Refinery)
    [1754] = 410071,              -- Freehold                        (Path of the Freebooter)
    [1763] = 424187,              -- Atal'Dazar                      (Path of the Golden Tomb)
    -- Two spells, one name — 445418 (issued with the TWW S1 block) and 464256 both resolve to
    -- "Path of the Besieged Harbor", the same shape as The MOTHERLODE!! above. 445418 leads
    -- because a spellbook confirms players hold it; 464256 has only ever been seen via the API.
    [1822] = { 445418, 464256 },  -- Siege of Boralus                (Path of the Besieged Harbor)
    [1841] = 410074,              -- The Underrot                    (Path of Festering Rot)
    [1862] = 424167,              -- Waycrest Manor                  (Path of Heart's Bane)
    [2097] = 373274,              -- Operation: Mechagon             (Path of the Scrappy Prince)
    -- Midnight S2 rotated these two BfA dungeons back in and issued their first teleports.
    [1762] = 1286831,             -- Kings' Rest                     (Path of the Slumbering Conqueror)
    [1877] = 1286828,             -- Temple of Sethraliss            (Path of the Sacred Temple)

    -- ===== Shadowlands =====
    -- Dungeons
    [2284] = 354469,              -- Sanguine Depths                 (Path of the Stone Warden)
    [2285] = 354466,              -- Spires of Ascension             (Path of the Ascendant)
    [2286] = 354462,              -- The Necrotic Wake               (Path of the Courageous)
    [2287] = 354465,              -- Halls of Atonement              (Path of the Sinful Soul)
    [2289] = 354463,              -- Plaguefall                      (Path of the Plagued)
    [2290] = 354464,              -- Mists of Tirna Scithe           (Path of the Misty Forest)
    [2291] = 354468,              -- De Other Side                   (Path of the Scheming Loa)
    [2293] = 354467,              -- Theater of Pain                 (Path of the Undefeated)
    [2441] = 367416,              -- Tazavesh                        (Path of the Streetwise Merchant)

    -- Raids
    [2296] = 373190,              -- Castle Nathria                  (Path of the Sire)
    [2450] = 373191,              -- Sanctum of Domination           (Path of the Tormented Soul)
    [2481] = 373192,              -- Sepulcher of the First Ones     (Path of the First Ones)

    -- ===== Dragonflight =====
    -- Dungeons
    [2080] = 393267,              -- Brackenhide Hollow              (Path of the Rotting Woods)
    [2451] = 393222,              -- Uldaman: Legacy of Tyr          (Path of the Watcher's Legacy)
    [2515] = 393279,              -- The Azure Vault                 (Path of Arcane Secrets)
    [2516] = 393262,              -- The Nokhud Offensive            (Path of the Windswept Plains)
    [2519] = 393276,              -- Neltharus                       (Path of the Obsidian Hoard)
    [2521] = 393256,              -- Ruby Life Pools                 (Path of the Clutch Defender)
    [2526] = 393273,              -- Algeth'ar Academy               (Path of the Draconic Diploma)
    [2527] = 393283,              -- Halls of Infusion               (Path of the Titanic Reservoir)
    [2579] = 424197,              -- Dawn of the Infinite            (Path of Twisted Time)

    -- Raids
    [2522] = 432254,              -- Vault of the Incarnates         (Path of the Primal Prison)
    [2549] = 432258,              -- Amirdrassil, the Dream's Hope   (Path of the Scorching Dream)
    [2569] = 432257,              -- Aberrus, the Shadowed Crucible  (Path of the Bitter Legacy)

    -- ===== The War Within =====
    -- Dungeons
    [2648] = 445443,              -- The Rookery                     (Path of the Fallen Stormriders)
    [2649] = 445444,              -- Priory of the Sacred Flame      (Path of the Light's Reverence)
    [2651] = 445441,              -- Darkflame Cleft                 (Path of the Warding Candles)
    [2652] = 445269,              -- The Stonevault                  (Path of the Corrupted Foundry)
    [2660] = 445417,              -- Ara-Kara, City of Echoes        (Path of the Ruined City)
    [2661] = 445440,              -- Cinderbrew Meadery              (Path of the Flaming Brewery)
    [2662] = 445414,              -- The Dawnbreaker                 (Path of the Arathi Flagship)
    [2669] = 445416,              -- City of Threads                 (Path of Nerubian Ascension)
    [2773] = 1216786,             -- Operation: Floodgate            (Path of the Circuit Breaker)
    [2830] = 1237215,             -- Eco-Dome Al'dani                (Path of the Eco-Dome)

    -- Raids
    [2769] = 1226482,             -- Liberation of Undermine         (Path of the Full House)
    [2810] = 1239155,             -- Manaforge Omega                 (Path of the All-Devouring)
    -- [xxxx] = yyyyyyy,             -- Nerub-ar Palace — no teleport spell exists; slot reserved

    -- ===== Midnight =====
    -- Dungeons
    [2805] = 1254400,             -- Windrunner Spire                (Path of the Windrunners)
    [2811] = 1254572,             -- Magisters' Terrace              (Path of Devoted Magistry)
    [2874] = 1254559,             -- Maisara Caverns                 (Path of Cavernous Depths)
    [2915] = 1254563,             -- Nexus-Point Xenas               (Path of the Fractured Core)
    -- Season 2.
    [2813] = 1286809,             -- Murder Row                      (Path of the Devious Smuggler)
    [2825] = 1286807,             -- Den of Nalorakk                 (Path of the Worthy Aspirant)
    [2859] = 1286801,             -- The Blinding Vale               (Path of the Blooming Verdure)
    [2923] = 1286804,             -- Voidscar Arena                  (Path of the Brutal Combatant)
    [2993] = 1286812,             -- Altar of Fangs                  (Path of Venomous Evolution)

    -- Raids
    -- [xxxx] = yyyyyyy,             -- The Dreamrift — no teleport spell exists; slot reserved
    -- [xxxx] = yyyyyyy,             -- The Voidspire — no teleport spell exists; slot reserved
    -- [xxxx] = yyyyyyy,             -- March on Quel'Danas — no teleport spell exists; slot reserved
}
