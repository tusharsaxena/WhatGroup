# Analysis — TeleportSpells re-validation, 2026-11-15 (Retail build 12.1.5.70783)

The first run of `tools/seeds/teleports.py`, under the contract `docs/validate-seeds.md`
(Ka0sAddonsCommonTasks#1). It re-checks every row of `defaults/TeleportSpells.lua` against the
live Retail build on wago.tools (product `wow`, 12.1.5.70783) and proposes the Path-of teleports
the file lacks. There was no previous bundle: until now the file was checked only by hand, against
spellbook dumps and the wiki. Every flag and candidate is ruled in `tools/seeds/retail_rulings.json`,
and `RULINGS.md` beside this file lists each one with its reason and the changes `apply` made.

## What was checked

82 rows, 85 spell ids (three rows carry two ids). For each row: the map exists, is a party or raid
instance, sits in the matching Dungeons / Raids subsection, carries the comment's dungeon name, and
is the MapID of at least one `GroupFinderActivity` row (the table `C_LFGList.GetActivityInfoTable`
reads, and so the source of the key at runtime). For each spell: it exists, its name is the
comment's, it has a teleport effect (252 or 15) at DifficultyID 0, and its own text names the row's
map as its destination.

All 85 spells exist, all 85 carry the comment's name, and all 85 are teleports (effect 252 on target
17, DEST_DB, every one). No row sits in the wrong subsection. Map.ExpansionID was tried as a
section check and dropped: the build files Scarlet Halls, Scarlet Monastery, Scholomance and
Manaforge Omega under expansion 0, so it is no witness (the contract's *Notes*).

## What was wrong: three keys, now moved

| Row | Was | Now | Evidence |
| --- | --- | --- | --- |
| Scarlet Monastery, `131229` Path of the Scarlet Mitre | `[1001]` | `[1004]` | Map 1004 is Scarlet Monastery and 1001 is Scarlet Halls; the Scarlet Monastery activities (78, 169, 1337, 1338) carry 1004; the spell's text, "Teleport to the entrance to Scarlet Monastery.", names 1004 |
| Scarlet Halls, `131231` Path of the Scarlet Blade | `[1004]` | `[1001]` | the mirror of the row above: activities 77, 170, 1335 and 1336 carry 1001 |
| Brackenhide Hollow, `393267` Path of the Rotting Woods | `[2080]` | `[2520]` | the build has no map 2080 and no activity on it; Map 2520 is Brackenhide Hollow, and LFGDungeons (2362 and others) and activities 1161 to 1164 carry 2520 |

In each case the spell and both names in the comment were right and only the key was wrong, so the
fix is a rekey: `apply` rewrote the key, kept the row's text, and sorted the row into its run. The
Scarlet pair had been swapped since the rows were written, so a player in a Scarlet Halls group was
offered the Scarlet Monastery teleport and the other way round. Brackenhide Hollow's 2080 is no map
on this build, so the row has never matched a Group Finder listing and a Brackenhide Hollow group
got no teleport line at all. Neither failure errors, which is the failure the file's header warns
about.

## What was flagged and kept

- `1011` Siege of Niuzao Temple: the spell's text abbreviates the dungeon ("Siege of Niuzao"), so
  the exact match finds no map. The spell name matches the comment, and Map 1011 is the comment's
  dungeon.
- `1651` Return to Karazhan: the text of `373262` Path of the Fallen Guardian names Karazhan, which
  resolves to the raid, map 532. Return to Karazhan is entered at the same Deadwind Pass door, the
  name matches the comment read in-game, and moving the row would lose it for every Return to
  Karazhan group.
- `2441` Tazavesh: the comment shortens Map 2441's "Tazavesh, the Veiled Market". The spell's own
  text gives the full name and the row resolves.

## Candidates: two, both rejected

The build has 186 SpellName rows named "Path of ...". 87 have a teleport effect at DifficultyID 0;
85 ship, and the other two were proposed:

| Spell | Ruling | Why |
| --- | --- | --- |
| `412555` Path of the Naaru | reject | "Returns you to $z" on target 9: a hearthstone, not a dungeon entrance |
| `467546` Path of the Waterworks | reject: **needs owner review** | the description says Cinderbrew Meadery (2661), already served by `445440` Path of the Flaming Brewery, while the name and the subtext say Waterworks, a delve (map 2683). The data contradicts itself, so the destination is not mechanical, and no spellbook has confirmed a player owns it |

Nothing was accepted, so nothing was added. The three spells named "Teleport" whose text reads
"Teleport to the entrance ..." (215275, 215277, 226890) are outside the candidate rule, which is
the file's Path-of family, and were not proposed.

## The tables

Five, all read whole and frozen in `raw/` (16.7 MB gzipped): `Map`, `GroupFinderActivity`,
`SpellName`, `Spell` and `SpellEffect`. The adoption inventory (Ka0sAddonsCommonTasks#1) listed
`LFGDungeons`; the tool reads `GroupFinderActivity` instead, because that is the table the
addon's key comes from at runtime. `LFGDungeons` was read once by hand, for the Brackenhide Hollow
and Scarlet rows above, and agrees with it.

## What a later run should re-check

- **467546 Path of the Waterworks.** If a spellbook dump shows a player owns it, or a later build
  settles its text, rule it again under its own key.
- **The two kept pairings** (1011, 1651). A later build that rewrites either spell's text turns the
  flag green or changes what it says; read it before keeping it again.
- **New Path-of spells each season.** A new season's teleports arrive as candidates. Accept one only
  on a single resolved map and no conflict, then confirm it on a spellbook (the smoke check), as the
  file's header asks.
- **The smoke checks** TELE-7 and TELE-8 (`docs/smoke-tests.md`) confirm the three moved keys in
  game.
