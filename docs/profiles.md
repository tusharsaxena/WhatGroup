# Profiles

AceDB profiles are user-visible in WhatGroup: the **Profiles** sub-page is a profile control in the
options UI, which is the trigger for this page (documentation-§3, Tier 2). The stored shape is in
[schema.md](./schema.md); the pages around this one are in [settings-panel.md](./settings-panel.md).

## What a profile holds

Every stored setting except one. That is the sixteen profile rows of the schema:

- the Master controls stored at the profile root: `enabled`, `visibility`, `scale`, `alpha`, `locked`;
- the **Chat** tab: `notify.delay`, `notify.enabled` and the six `notify.show*` lines;
- the **Popup** tab: `frame.autoShow`, `frame.width`, `frame.height`.

A new profile starts from `defaults/Profile.lua` (`NS.C`), the one place a profile default is written
(savedvariables-§2).

## What stays account-wide

- **`db.global.minimap`**, the minimap button (`global.minimap.shown`, stored inverted as LibDBIcon's
  `hide`). A button belongs to the installation, so a switch never moves it
  ([settings-panel.md](./settings-panel.md#the-minimap-button-row)).
- **`db.global.windows`**, the popup's dragged position (WG-26). Geometry, not a setting.
- **`db.global.schemaVersion`**, the migration stamp.
- **Session state**, which is never saved at all: the debug flag (`NS.State.debug`), the debug console
  window (`state.debugConsole`), test mode (`state.testMode`) and the captured group info.

## AceDB setup

`OnInitialize` in `core/WhatGroup.lua` opens the store with
`AceDB:New("WhatGroupDB", defaults, true)`. The `true` puts every character on the shared `Default`
profile until the player picks a per-character, per-class, per-realm or per-faction one on the
Profiles page. It then runs `RunMigrations` and registers the three profile callbacks:

| AceDB event | Handler | Arguments AceDB passes |
|---|---|---|
| `OnProfileChanged` | `WhatGroup:OnProfileChanged` | `(event, db, newProfileKey)` |
| `OnProfileCopied` | `WhatGroup:OnProfileCopied` | `(event, db, sourceProfileKey)` |
| `OnProfileReset` | a closure that logs the reset | `(event, db)` |

## The Profiles page

`settings/Profiles.lua` registers the `Profiles` subcategory, **last** in the Settings tree (it loads
last in the TOC, so its `RegisterOptionsPage` call queues behind General's). The canvas and header are
`LibKa0s-Options-1.0`'s. Its body is an AceGUI `SimpleGroup` into which `AceConfigDialog` draws
**AceDBOptions'** own options table: choose, create, copy, reset and delete, plus the scope
dropdowns. It is the one AceConfig use in this addon (options-ui-§3), because that table is Ace's and
not the addon's.

- **No Defaults button** (`defaultsButton = false`). Restoring a default here would mean deleting
  profiles.
- **Built on first show**, through `Helpers.SetRenderer`, so the group is created on the next frame
  like every page here and the page carries the library's combat lock.
- **Re-drawn after every profile event.** AceConfigDialog names the active profile only when it is
  fed again, so `Settings.RefreshProfilesPage` re-draws a shown page at once and marks a hidden one
  to re-draw on its next show.
- **Optional.** Without AceDBOptions, AceConfig or AceConfigDialog the builder returns nil and the
  page is absent. Without LibKa0s nothing registers it.

The libraries are vendored under `libs/AceConfig-3.0/` (with its Registry, Cmd and Dialog parts) and
`libs/AceDBOptions-3.0/`, byte-identical to the copies the collection's other Profiles pages load.

## Switching, copying, resetting

All three events end in `reloadProfile` (`core/WhatGroup.lua`):

```
OnProfileChanged / OnProfileCopied / OnProfileReset
  ├─ the event's one debug line         (below)
  └─ reloadProfile
       ├─ RunMigrations()               the incoming profile may predate the schema version
       ├─ Helpers.RefreshAll()          open General widgets re-read their rows
       ├─ Settings.RefreshProfilesPage  the Profiles page re-draws (or is marked to)
       ├─ Lifecycle:Set / :Reevaluate   `enabled` is profile-scoped, so the latch re-syncs:
       │                                a disabled profile stands the addon down, an enabled one
       │                                stands it back up (slash-commands-§7)
       └─ ApplyFrameSize / Scale /      the popup takes the incoming profile's look; size and
          Alpha / Visibility            scale wait for the end of combat, as their rows do
```

Everything else in the profile (`notify.*`, `frame.autoShow`, `locked`) is read when it is used, so
it needs no re-apply.

**One debug line per event** (debug-logging-§10). A switch rewrites no row through the write seam,
so it gets no `[Set]` line; a reset and a copy replace the rows wholesale, so each gets one `[Set]`
line from its handler:

| Event | Line |
|---|---|
| Switch | `[Profile] switched to '<name>'` |
| Copy | `[Set] copied profile '<source>' → '<active>'` |
| Reset | `[Set] reset profile '<name>' to defaults (N rows)`, or without the count when the reset did not come through `Helpers.RestoreAllDefaults` (the Profiles page's own Reset Profile, a `/run`) |

## Reset all settings is Reset Profile

`/wg resetall`, the General page's Defaults button and the Master controls **Reset all settings**
button all confirm through one popup and then call `Helpers.RestoreAllDefaults`, which is
`db:ResetProfile()` on the active profile plus the session-only sweep (options-ui-§12). It never
touches another profile or the profile list, so it is the same act as the Profiles page's Reset
Profile. The Options descriptor passes `resetProfile` and `profilesPage = true`, and the Reset all
settings tooltip says so: *"the same thing Profiles -> Reset Profile does"*.

**The reset veto is named once**, as `Settings.VetoedFromResetAll` in `settings/Schema.lua`: a row on
the Profiles page, and every row that is not session-only, is kept out of any row walk. The
descriptor's `skipRestoreAll` and the session sweep inside `Helpers.RestoreAllDefaults` both read it
(options-ui-§3). The Profiles page has no schema rows today, so nothing on it could be walked
anyway; the veto says so where the standard asks for it.

## From chat

`/wg profile` lists the profiles, the current one marked, and `/wg profile <name>` switches to an
existing one. The verb is `LibKa0s-Slash-1.0`'s `CliProfile` (Slash minor 17); `settings/Slash.lua`
registers the row and hands it this addon's db through the descriptor's `profiles` field.

- **Existing profiles only.** A name the store does not list is refused (`No profile named '<name>'.`,
  a did-you-mean when exactly one name matches ignoring case, then the list). AceDB's `SetProfile`
  would create the profile, so a typo would otherwise leave a stray one full of defaults. New
  profiles are made on the Profiles page.
- **Names are case-sensitive and may hold spaces.** One pair of surrounding quotes is stripped, so
  `/wg profile My Main`, `/wg profile "My Main"` and `/wg profile 'My Main'` are the same switch.
- **Not in combat.** A switch can stand the addon down, and the popup's Hide is protected in combat,
  so the library refuses the switch (`Can't switch profiles in combat.`). Listing still answers.
- **Live while disabled.** `enabled` is profile-scoped, so switching to an enabled profile is a way
  back; the descriptor passes `lib.LIVE_VERBS` plus `profile` as `liveVerbs`.
- A switch fires `OnProfileChanged`, so it takes the same path as a switch on the Profiles page and
  logs the same one `[Profile]` line. The verb logs nothing of its own.
- Without LibKa0s the verb prints `/wg profile is unavailable: the LibKa0s library did not load.`
  and switches nothing.

## Tests

`tests/test_profiles.lua` registers recording AceDBOptions, AceConfig and AceConfigDialog fakes and
covers the page (last in the tree, no Defaults, opts out without any one of the three, built on first
show into a group that was handed out hidden, as a pooled one is, and shown again on every render),
the re-draw after a switch on a shown and a hidden page, the combat lock on a page first shown
in combat (nothing drawn until combat ends), the `[Profile]` line, the popup re-apply
(size, scale and alpha, and `visibility` taking an open popup off screen), the latch following
`enabled`, the Reset all settings tooltip, and the `/wg profile` verb (the list, a switch that runs
the handler, an unknown name refused with nothing created, quotes, the combat refusal). The copy
and reset lines are in `tests/test_debuglog.lua`; the latch across a switch is also in
`tests/test_disabled.lua`, which also pins `/wg profile` as live while the addon is disabled; the
library-absent verb is in `tests/test_libka0s.lua`.
