# Seed validation — WhatGroup

The seed-validation contract `/dev-copilot:validate-seeds WhatGroup <flavor>` runs. The command
supplies the loop (clean tree, one date, status, derive, rule, apply, gate, hand-back) and its
standing rules. This file supplies WhatGroup's procedure: the tool, the files it writes, the
precedent a ruling follows and the nuances of the one client. The headings below are the interface
the command reads, so keep their names.

WhatGroup has one seed list, `defaults/TeleportSpells.lua`: a dungeon's (or raid's) instance map id
to its "Path of ..." teleport spell id. It is keyed by map id because Group Finder activity ids
rotate every season (the file's own header). The tool is `tools/seeds/teleports.py`, whose
docstring documents every flag and how a destination is resolved. Each run ends in a frozen bundle
under `docs/seed-research/`; the first is `docs/seed-research/2026-11-15-retail/`.

## Flavors

| Flavor | Source | Seed files | Tools |
| --- | --- | --- | --- |
| `retail` | wago.tools product `wow` (Retail live) | `defaults/TeleportSpells.lua` (hand-curated, tool-checked) | `tools/seeds/teleports.py` |

The roster (WowAddonStandards `standards/ADDONS.md`) lists WhatGroup as Retail only, so there is no
`forever` flavor. `teleports.py` refuses any other flavor.

## Rules

- **The seed file stays hand-curated.** A new row is still added by the recipe in
  `docs/common-tasks.md` → *Add a dungeon teleport spell mapping* (spell ids off a spellbook that
  owns them). `teleports.py apply` writes only what a ruling says: a row moved to another key, a row
  or spell removed, an accepted candidate added. A comment the build shows to be stale is fixed by
  hand, in the same change as its `keep` ruling.
- **Rulings are data.** They live in `tools/seeds/retail_rulings.json`, written only by
  `teleports.py rule`. A ruling is keyed `shipped:<kind>:<map>` or `shipped:<kind>:<map>:<spell>`
  for a flag (`keep`, `remove` or `rekey`), and `candidate:<spell>` for a candidate (`accept` or
  `reject`), never by build. It holds until the thing it ruled on stops being proposed, and then it
  stays in the file as provenance.
- **Precedent, in this order, never re-litigated:**
  1. a ruling already in `tools/seeds/retail_rulings.json`;
  2. the notes in `defaults/TeleportSpells.lua`: the header (a spell name never contains its
     dungeon's name, so a name match proves nothing; ids come off a spellbook), the list rows (two
     ids for one dungeon, the first being the one a spellbook confirmed, as on Siege of Boralus),
     and the reserved slots (Nerub-ar Palace and the Midnight raids have no teleport);
  3. `docs/common-tasks.md` → *Add a dungeon teleport spell mapping*: `1254553` "Hero's Path", one
     digit off a real id, shipped twice from name lookups before a spellbook caught it.
- **What the DB2 can and cannot say.** A Path-of spell teleports to a server-side point (effect 252
  or 15 on target 17, DEST_DB), so no client table holds its destination. The tool reads it from
  the spell's own text, "Teleport to the entrance to <name>.", matched exactly against
  `Map.MapName_lang` over the party and raid maps and narrowed by `GroupFinderActivity`. That is a
  mechanical reading, but of text, so:
  - **Accept a candidate** only when its destination resolves to one map, nothing in its own data
    contradicts that (the tool marks a subtext naming somewhere else as a `conflict`, and `apply`
    refuses it), and the map is a dungeon or raid the Group Finder lists. Even then, say in the
    reason that no spellbook has confirmed the id yet; a new row's first smoke check is that.
  - **Reject with "needs owner review: <why>"** anything less: an unresolved destination, a
    conflict, a destination already served by a confirmed spell.
  - **Rekey a shipped row** only when the build says its key is wrong in more than one table (Map,
    `GroupFinderActivity`, the spell's text) and the spell and the comment agree with each other.
  - **Keep** a flag the text explains: a description that abbreviates the dungeon, a comment that
    shortens it, an old raid name on a newer dungeon's entrance.
- **Evidence.** Read each flag's and candidate's rows in the bundle's `raw/*.csv.gz` before ruling,
  and cite the table and id in the reason. When the evidence is thin, say so.
- **Privacy.** No player name, realm or GUID goes into a bundle, a ruling or a commit.

## Flavor: retail

### Status

```sh
python3 tools/seeds/teleports.py status --flavor retail
```

Prints `CURRENT <build> (<bundle>)`, or `NEW <build> (last ruled <build>, <bundle>)`, comparing the
live `wow` build with the newest `docs/seed-research/*-retail` bundle.

### Freeze and derive

```sh
python3 tools/seeds/teleports.py derive --flavor retail --bundle docs/seed-research/<date>-retail --date <date> --build <build>
```

Downloads five tables (about 93 MB uncompressed on 12.1.5, cached in `tools/seeds/.cache/`), freezes
them gzipped into the bundle's `raw/` (about 17 MB), and writes `SOURCES.md` and `candidates.json`.
`--replay` re-derives from the bundle's `raw/` alone. Report the row and spell counts, the flag
counts by kind, the candidate count and the unruled count it prints.

### Rule

```sh
python3 tools/seeds/teleports.py check --bundle docs/seed-research/<date>-retail
python3 tools/seeds/teleports.py rule --tsv <scratchpad>/rulings.tsv --bundle docs/seed-research/<date>-retail
```

`check` lists every unruled key and exits 1 while there is one; it must print `OK` after `rule`.
The TSV is `key<TAB>ruling<TAB>reason`, one line each.

- **Flags** (`keep`, `remove`, `rekey`):
  - `map-missing`, `no-activity`: the key never arrives from `C_LFGList.GetActivityInfoTable`.
    Rekey when the spell's destination resolves; otherwise needs the owner.
  - `pairing`: the spell's destination is not the row's map. Rekey, or keep with the reason the
    text misleads.
  - `map-renamed`, `spell-renamed`: keep and fix the comment by hand if the instance or spell is
    the same; otherwise the id was reused, and it is a `remove`.
  - `spell-missing`, `not-teleport`: remove, unless the file's comment records why it stays.
  - `not-instance`, `wrong-section`: the row is in the wrong place or is not a dungeon or raid.
  `rekey` moves a row to the one map all its spells resolve to; `apply` refuses it otherwise.
- **Candidates** (`accept`, `reject`): an unshipped SpellName row named "Path of ..." with a
  teleport effect at DifficultyID 0. Under the rules above.

### Apply

```sh
python3 tools/seeds/teleports.py report --bundle docs/seed-research/<date>-retail --date <date>
python3 tools/seeds/teleports.py apply  --bundle docs/seed-research/<date>-retail --date <date>
```

`report` comes before `apply`: it writes `RULINGS.md` with the changes `apply` is about to make,
which a later run no longer shows once they are made. `apply` refuses while anything is unruled,
keeps the file's CRLF and column layout, sorts a moved row into its run, and a second `apply`
changes nothing.

### After

- Roll the `RE-VALIDATED AGAINST BUILD` note in `defaults/TeleportSpells.lua`'s header.
- Fix by hand any comment a `keep` ruling said was stale.
- Write the bundle's `ANALYSIS.md` by hand, in the 2026-11-15 bundle's shape: what changed, what was
  accepted or rejected and why, what a later run should re-check.
- Add a smoke check per changed or added row to `docs/smoke-tests.md` → *The teleport button*, plus
  its *Pending sign-off* note, following TELE-7 and TELE-8. A run that changes no row adds none.

### Stage

`defaults/TeleportSpells.lua`, `tools/seeds/retail_rulings.json`, `docs/seed-research/<date>-retail`,
`docs/smoke-tests.md`, plus any citation edits. Commit message:
`TeleportSpells: Retail re-validation against <build> (<date>)`.

## Gate

```sh
~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
python3 -m unittest discover -s tools/seeds -p 'test_*.py'
```

luacheck must report 0 warnings and 0 errors, and every suite 0 failed. WhatGroup is Retail only, so
the suite runs under the default kit profile alone.

## Notes

- **Bundle size.** A bundle's `raw/` is about 17 MB, nearly all of it `Spell`, `SpellEffect` and
  `SpellName`, which are read whole. One bundle per patch is acceptable.
- **Map.ExpansionID is no witness.** The build files the Mists of Pandaria Scarlet and Scholomance
  remakes and Manaforge Omega under expansion 0, so the tool checks only the Dungeons / Raids
  subsection, and `apply` refuses to insert a candidate whose expansion section the file lacks.
- **The shared helper.** The build pin, cache, bundle and rulings code is copied from Aura Master's
  `tools/spell-research/retail.py`, not imported. Whether it becomes a shared helper is LibKa0s#91.
