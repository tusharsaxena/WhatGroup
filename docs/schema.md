# Schema

What WhatGroup persists, where each default is declared, and the migration seam. The controls that
write these values are [settings-panel.md](settings-panel.md); the capture pipeline that reads them is
[data-flow.md](data-flow.md).

## The saved variable

One SavedVariable, `WhatGroupDB` (`WhatGroup.toc:7`), an AceDB-3.0 store created in `OnInitialize`.
User settings live in the **profile** scope; the schema stamp lives in `db.global`.

```lua
db.profile = {
  enabled = true,                 -- master switch
  frame = {
    autoShow = true,              -- open the popup automatically on join
    width    = 420,               -- popup width  in pixels (clamped 320..700)
    height   = 260,               -- popup height in pixels (clamped 200..520)
  },
  notify = {
    enabled       = true,         -- print the chat summary on join
    delay         = 0,            -- seconds to wait before notify + popup
    showInstance  = true,
    showType      = true,
    showLeader    = true,
    showPlaystyle = true,
    showClickLink = true,
    showTeleport  = true,
  },
}

db.global = {
  schemaVersion = 1,              -- seeded by Settings.BuildDefaults; see the migration seam below
}
```

Twelve persisted settings, all of them user-facing, all of them schema rows. There are no storage-only
carve-outs in the profile: the popup's dragged POSITION is account-wide geometry and lives in
`db.global.windows` (WG-26), not here.

`frame.width` and `frame.height` were `FRAME_WIDTH` and `FRAME_HEIGHT`, two file-locals in
`modules/Frame.lua`. Their defaults are the numbers they replaced, so an existing install's popup is
drawn exactly as it was. Both are **clamped on read** in `modules/Frame.lua` (320..700 and 200..520,
matching each row's `min`/`max`): the slider cannot produce an illegal value, but a hand-edited
SavedVariable or `/wg set frame.width 4000` can, and a popup wider than the monitor reads as the
setting being broken rather than as the value being refused.

## Two declaration sites, and why

The addon deliberately splits **values** from **structure**, which reconciles two rules that would
otherwise pull against each other:

- **`defaults/Profile.lua` declares every value**, as the `NS.C` tree. That is the single place any
  profile default is hardcoded (`savedvariables-§2`).
- **`settings/Schema.lua` declares every structure** — one row per option carrying `section`, `group`,
  `path`, `type`, label/tooltip and widget hints. Each row's `default` **references** its value as
  `C.<path>` rather than restating the literal (`architecture-§5`).

`defaults/Profile.lua` loads before `settings/Schema.lua` (the TOC's Defaults section), so the
reference always resolves. Adding a setting is still **one schema row** — with its value declared in
`NS.C`. Two literals for one value is the shape that drifts; a reference cannot.

`Settings.BuildDefaults` walks the schema and threads each row's `default` into the nested AceDB
`profile` table, and also seeds `global.schemaVersion` from `NS.SCHEMA_VERSION`.

## One row, five surfaces

A single row in `WhatGroup.Settings.Schema` drives all of these, so there is never a parallel mutator
for a path that already has a row:

| Surface | How the row is used |
|---|---|
| Settings panel | the AceGUI widget rendered into the General sub-page, on the tab its `group` names (`options-ui-§13`) |
| `/wg list` | grouped by `section`, printed as `path = formattedValue` |
| `/wg get <path>` | `Helpers.FindSchema` + `Helpers.Get` |
| `/wg set <path> <value>` | type-aware parse → `Helpers.Set` → the row's `onChange` → `RefreshAll` |
| AceDB defaults | `BuildDefaults` threads `default` into the nested `profile` table |
| `/wg reset` and the **Defaults** button | `Helpers.RestoreDefaults`, via the `WHATGROUP_RESET_ALL` popup |

## What is deliberately not persisted

**Debug is session-only.** The debug flag is never a schema row, never reaches `BuildDefaults` or
`/wg list`, and never lands in the saved profile — it resets to off on every reload. The General panel
does surface a **Debug console** checkbox, but as a session-only non-schema affordance
(`settings/Panel.lua`): it toggles only the console *window's* visibility (`NS.DebugLog` Show/Hide),
never the logging flag and never `db.profile`. That is what keeps the WG-12 invariant — debug never
persists — true.

**`defaults/TeleportSpells.lua` is data, not settings.** The `mapID → teleport spellID` lookup is a
shipped table read at runtime; it is never copied into the DB and the user never edits it. Adding a
mapping is a code change — the recipe is in
[common-tasks.md](common-tasks.md) → "Add a dungeon teleport spell mapping".

## The migration seam

`core/Database.lua` owns `NS.SCHEMA_VERSION` (currently **1**) and `NS:RunMigrations()`, called once
from `OnInitialize` immediately after `AceDB:New` and **before any code reads the profile**.

The runner body is **intentionally empty today**. The seam exists from day one
(`toc-file-§2` / `savedvariables-§1`) so the first real migration lands in a structured, ordered,
idempotent place instead of being retrofitted under pressure — the commented-out step-forward loop in
the function shows the intended shape.

It is idempotent and safe to call on every login: a fresh DB arrives with `schemaVersion` already
defaulted to `NS.SCHEMA_VERSION`, and an old DB is stepped forward one version at a time. Lifecycle
logging is deliberately conditional (`debug-logging-§8`) — the `Migrate` line is emitted **only** when
a migration actually moved the version, so a fresh or already-current DB stays silent.

**Adding a migration:** bump `NS.SCHEMA_VERSION`, add a step inside the loop keyed on the *current*
version, and make it idempotent. Do not stamp the new version until the step has run.
