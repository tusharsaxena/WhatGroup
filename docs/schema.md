# Schema

What WhatGroup persists, where each default is declared, and the migration seam. The controls that
write these values are [settings-panel.md](settings-panel.md); the capture pipeline that reads them is
[data-flow.md](data-flow.md).

## The saved variable

One SavedVariable, `WhatGroupDB` (`WhatGroup.toc:7`), an AceDB-3.0 store created in `OnInitialize`.
User settings live in the **profile** scope; the schema stamp lives in `db.global`.

```lua
db.profile = {
  -- Master controls (options-ui-§15), at the profile ROOT because they govern the addon
  -- as a whole. Composed rows, but ordinary stored values.
  enabled    = true,              -- master switch
  visibility = "always",          -- always | inCombat | outOfCombat | never
  scale      = 1,                 -- popup scale   (clamped 0.5..2)
  alpha      = 1,                 -- popup opacity (clamped 0..1)
  locked     = false,             -- popup drag disabled
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
  schemaVersion = 0,              -- DECLARED 0 (pre-versioning); RunMigrations stamps 1. See below
  windows = {                     -- persisted standalone-window geometry (WG-26), seeded empty
    -- [name] = { point, relPoint, x, y }   written on drag-stop, restored on show
  },
  minimap = {                     -- LibDBIcon-1.0's OWN table (launcher-§3), handed to it whole
    hide = false,                 -- stores the ONE schema row outside db.profile: `global.minimap.shown`
    -- minimapPos = 0             -- LibDBIcon writes this when the player drags the button
  },
}
```

**Why the declared `schemaVersion` is 0.** AceDB's `removeDefaults` strips every stored value that
equals its declared default when the player logs out. A default equal to the current version
(`NS.SCHEMA_VERSION`) would therefore never reach the SavedVariables file, and on the first real bump
the new default would read back as the stored version, so the step for it would be skipped for every
existing user. The default is the pre-versioning 0 instead: a fresh install walks the steps from 0 like
any old one, and the stamp `RunMigrations` writes (1 today) always differs from the default, so it
persists (`savedvariables-§1`).

Sixteen persisted profile settings, all of them user-facing, all of them schema rows — plus one
**global** row, `global.minimap.shown` (the launcher's visibility, stored at LibDBIcon's own
`db.global.minimap.hide` and inverted at the write seam: the path and the row say *shown*), and two **session-only** rows,
`state.debugConsole` and `state.testMode`, which are schema rows and deliberately not persisted (see
below). The minimap row is global rather than profile-scoped on purpose: a profile switch must not
move the player's buttons. That it also **survives every reset** is a separate rule rather than a
consequence of that one — the row is a per-installation display preference, like the angle LibDBIcon
keeps beside it (launcher-§3, detailed in
[settings-panel.md](./settings-panel.md#the-minimap-button-row)). There are no storage-only carve-outs in the profile: the popup's dragged POSITION is
account-wide geometry and lives in `db.global.windows` (WG-26), not here. That store is
`architecture-§5` named non-setting state, and its owner (`NS.Windows`) and writers are named in
[ARCHITECTURE.md → Settings Schema](./ARCHITECTURE.md#settings-schema).

`scale`, `alpha` and `locked` are **clamped or read at use time** in `modules/Frame.lua` exactly as
the size rows are, and for the same reason. `visibility` fails **open**: `always` and any value the
addon does not recognize both answer yes, so a hand-edited SavedVariable or a profile written by a
future version cannot make the popup look broken.

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
- **The Master controls block declares neither**, and that is the third site. `options-ui-§15` makes
  it `LibKa0s-Options-1.0`'s canonical row set, composed by `Helpers.MasterControls` in
  `settings/Panel.lua`; the composer is handed a `defaults` table built out of `NS.C`, so the values
  are still this addon's and still written down in exactly one place.

`defaults/Profile.lua` loads before `settings/Schema.lua` (the TOC's Defaults section), so the
reference always resolves. Adding a setting is still **one schema row** — with its value declared in
`NS.C`. Two literals for one value is the shape that drifts; a reference cannot.

`Settings.BuildDefaults` **seeds the profile from `NS.C`**, then walks the schema and threads each
row's `default` into the nested AceDB `profile` table, and also declares `global.schemaVersion = 0`
(above) and `global.minimap = { hide = false }`. The seed is what makes the stored shape
independent of whether LibKa0s is installed: the composed rows are absent on the degraded path, and
without the seed the profile would arrive with no `enabled` key — which reads as false. `sessionOnly`
rows are skipped, so nothing about the debug console or test mode reaches the db; **global rows are
skipped too**, because threading `global.minimap.shown` through the profile walk would write a
`profile.global.minimap.shown` branch nothing reads. Its default is the `global` literal above, which
is what materializes the table LibDBIcon is handed (`architecture-§5`).

## One row, six surfaces

A single row in `WhatGroup.Settings.Schema` drives all of these, so there is never a parallel mutator
for a path that already has a row:

| Surface | How the row is used |
|---|---|
| Settings panel | the AceGUI widget rendered into the General sub-page, on the tab its `group` names (`options-ui-§13`) |
| `/wg list` | grouped by `section`, printed as `path = formattedValue` |
| `/wg get <path>` | `Helpers.FindSchema` + `Helpers.Get` |
| `/wg set <path> <value>` | type-aware parse → `Helpers.Set` → the row's `onChange` → `RefreshAll` |
| AceDB defaults | `BuildDefaults` threads `default` into the nested `profile` table |
| the reset surfaces | `/wg reset <path>` → `Helpers.ApplyDefault`, the ordinary `Helpers.Set` path with no confirmation; `/wg resetall` and the **Defaults** button → `Helpers.RestoreAllDefaults`, via the `WHATGROUP_RESET_ALL` popup |

## What is deliberately not persisted

**Debug is session-only.** The debug *flag* (`NS.State.debug`) is never a schema row, never reaches
`BuildDefaults`, and never lands in the saved profile — it resets to off on every reload. The
**Debug console** checkbox on the Master controls tab *is* a schema row now (`options-ui-§15` makes
it one of the canonical nine), on the path `state.debugConsole` and marked `sessionOnly`: it toggles
only the console *window's* visibility (`NS.DebugLog` Show/Hide), never the logging flag and never
`db.profile`. `settings/Schema.lua`'s `SESSION` table intercepts the path in front of `Resolve`, so
no caller can route it to the db; `BuildDefaults` skips it; and `RestoreAllDefaults` restores it row
by row, because `db:ResetProfile()` cannot reach storage that is not the db (`options-ui-§12`). That
is what keeps the WG-12 invariant — debug never persists — true.

**Test mode is session-only too.** The **Test mode** checkbox on the same tab is the row
`state.testMode`, composed from `testModePath` and marked `sessionOnly`; the `SESSION` table routes it
to `WhatGroup:TestModeCheckbox()` in `modules/Frame.lua`, whose flag is `NS.State.testMode`. It is
off at every login, never in `db.profile`, and its declared `default = false` is what lets
`RestoreAllDefaults`' session sweep end it. The sample it shows is a record of its own
(`WhatGroup:SampleInfo()`), so it never writes `pendingInfo` either.

**`defaults/TeleportSpells.lua` is data, not settings.** The `mapID → teleport spellID` lookup is a
shipped table read at runtime; it is never copied into the DB and the user never edits it. Adding a
mapping is a code change — the recipe is in
[common-tasks.md](common-tasks.md) → "Add a dungeon teleport spell mapping".

## The migration seam

`core/Database.lua` owns `NS.SCHEMA_VERSION` (currently **1**) and `NS:RunMigrations()`, called once
from `OnInitialize` immediately after `AceDB:New` and **before any code reads the profile**.

The runner is **step-driven**. `NS.MIGRATIONS[N]` takes the store from N-1 to N and receives the
AceDB handle; the only step today is `[1]`, the no-op 0 -> 1 that exists to write the stamp. The seam
exists from day one (`toc-file-§2` / `savedvariables-§1`) so the first real migration lands in a
structured, ordered, idempotent place instead of being retrofitted under pressure.

It is idempotent and safe to call on every login. It reads `global.schemaVersion` (0 when nothing is
stored), runs each missing step in order, and advances the stamp one version at a time, **only past a
step that returned**. A raising step propagates and leaves the stamp at the last completed version, so
the next login retries it. Lifecycle logging is deliberately conditional (`debug-logging-§8`): the
`Migrate` line, `v<from> -> v<to>`, is emitted **only** when the version actually moved, so an
already-current DB stays silent. A fresh install logs `v0 -> v1` once.

**Adding a migration:** bump `NS.SCHEMA_VERSION` to N and add `NS.MIGRATIONS[N]`. Every step MUST be
idempotent against a fresh default profile, because a fresh install walks every step too. WhatGroup has
no profile-scoped step yet; the first one MUST walk every stored profile through the raw
`db.sv.profiles` (`WhatGroupDB.profiles`), not only the active `db.profile`. A profile nobody has
switched to since would otherwise keep the old shape while the account-wide stamp is already past it.

**The launcher needed none.** `launcher-§3` fixes the minimap table at `db.global.minimap`, and an
addon that already stored it under `profile` owes a migration carrying `hide` and `minimapPos`
across (in the collection that is Multi Meters alone). WhatGroup has never stored a minimap table
anywhere — `grep -rin minimap` over the source before the launcher landed returned one line, in
`docs/scope.md`, saying the addon did not provide one — so adopting it created a new global branch
rather than moving an existing one, and `NS.SCHEMA_VERSION` stays at **1**.
