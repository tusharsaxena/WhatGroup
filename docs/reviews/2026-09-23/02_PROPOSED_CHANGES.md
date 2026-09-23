# WhatGroup — proposed changes (HLD + LLD), 2026-09-23

**Standard resolved:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**, fetched verbatim from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`
and every section it links. The cross-check was **not** skipped. Every change below was vetted
against it as a constraint on the remediation. This is not an audit.

Finding IDs refer to `01_FINDINGS.md`. Change IDs are `C-NNN`.

## HLD — themes

### T1. One combat-safe path onto and off the screen (F-001, F-002, F-006)

`modules/Frame.lua` already has the right primitives: `hidePopup` / `showPopup`, the
`softHidden` / `pendingHide` pair, and the per-button combat defer. The two High bugs are both
places where a *side path* (`preparePopup`'s alpha restore, `PopulateFields`' no-capture branch)
does protected or visibility work without going through them. The theme is to route both through
the existing seams, with no new mechanism.

- *Alternative considered:* add an `InCombatLockdown()` early return to `ShowFrame` for every
  soft-hidden reopen. **Rejected.** It would break the one legal in-combat reopen that
  `tests/test_frame.lua:684` pins (an alpha-0 popup brought back without a `Show`).
- *Alternative considered:* skip `preparePopup` entirely when soft-hidden. **Rejected.** A
  capture that changed while the popup was soft-hidden must still repaint the fields, and only the
  alpha and the secure button are the problem.

### T2. SavedVariables stamp that actually persists (F-003)

Declare the stamp's default at the pre-versioning value so a real stamp never equals the default
and survives AceDB's `removeDefaults`. The standard's MUST ("declare `schemaVersion` in the global
namespace", `savedvariables-§1`) is kept. Its template's literal `1` is routed upstream.

- *Alternative considered:* drop `schemaVersion` from the defaults and seed it only in
  `RunMigrations`. **Rejected.** It violates `savedvariables-§1`'s "MUST declare `schemaVersion` in
  the global namespace". It is also indistinguishable from the proposed fix at runtime.
- *Alternative considered:* `rawset`/`rawget` tricks. **Rejected.** `removeDefaults` compares
  values, not how they were written, so the stamp is still stripped.

### T3. The degradation stub adds members and never replaces host ones (F-004)

The Options stub must fill the gaps the library leaves, never overwrite a member the host already
published. The fix is a presence guard on the one colliding member. `options-ui-§1`'s SHOULD
("keep the global-reset entry point real in the stub") is the rule that shapes it.

### T4. Debug sink discipline (F-005, F-016)

Convert the 16 pre-built `NS.Debug` messages to the sink's format-args form
(`debug-logging-§4` MUST NOT build before the call). Separately, hoist the teleport button's three
script closures to file scope so a configure allocates none.

### T5. Hygiene: comments, locale, lint config, dead state (F-007 to F-013)

These are mechanical and behavior-neutral. They are grouped so one reviewer can read them as one
diff.

### Deferred (routed, not changed here)

- **F-014** is a disposition for the next release run's `RESULTS.md` regeneration
  (`/wow-addon:bump-version`). It is never regenerated or hand-edited here.
- **F-003 (standard half) and F-015** are WowAddonStandards changes. See the upstream change-set.

## Upstream change-set (lands outside this repo)

| Finding | Owning repo | Where | Change | Version impact | Consumer follow-up |
|---|---|---|---|---|---|
| F-003 | **WowAddonStandards** | `standards/savedvariables.md` §1 template | Change the template's `global = { schemaVersion = 1 … }` to declare the **pre-versioning** default (0), and add one sentence: AceDB strips a value equal to its default at logout, so a stamp equal to its default never persists and the first migration is skipped for every existing user | Standard minor bump | Every Ka0s addon re-checks its `BuildDefaults`/defaults table. WhatGroup's own C-003 already conforms |
| F-015 | **WowAddonStandards** (and, if adopted, **LibKa0s** OptionsCompose/Slash) | `launcher-§3`, `options-ui-§15` | Decide whether the CLI may expose the Minimap button row under a **shown**-polarity alias while storage stays `minimap.hide`. Today the row's CLI path reads inverted in every addon | Standard minor. A library minor bump only if a composer/CLI alias field is added | If adopted: fix upstream, bump the file's LibStub minor, **re-vendor the whole `libs/LibKa0s/` folder** in its own commit. **Not a local edit** |

No entry in this document targets a path under `libs/` or `tests/_kit/`.

## LLD — change-set

### C-001 — The no-capture branch defers the secure button in combat (F-001)

- **Files:** `modules/Frame.lua`, in `PopulateFields` (`:843-878`), `deferTeleportUntilCombatEnds`
  (`:526-541`) and `ConfigureTeleportButton` (`:803-840`).
- **Change:** in the `not info` branch, stop calling `fields.teleportBtn:Hide()` directly and route
  it through `ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon, nil)`. That function
  already defers under lockdown, and `resolveTeleportState(nil)` resolves to the "no teleport"
  arm that clears and hides the button out of combat. The replay needs a sentinel, because it
  currently skips a stashed `nil`:
  ```lua
  local NO_CAPTURE = {}            -- file scope: "configure against no capture"
  -- deferTeleportUntilCombatEnds(info):
  f._pendingTeleportInfo = info == nil and NO_CAPTURE or info
  -- replay:
  if pending ~= nil then
      ConfigureTeleportButton(fields.teleportBtn, fields.teleportIcon,
                              pending ~= NO_CAPTURE and pending or nil)
  end
  ```
  `fields.teleportNote:Hide()` stays direct. It is a FontString on `content` and unprotected.
- **Risk:** low. The out-of-combat behavior is identical (the same clear arm). `NS.FrameStandDown`
  already clears `_pendingTeleportInfo`.
- **Standards:** events-frames-taint-§2 (combat lockdown). There is no new registration: the
  deferral reuses the existing self-unregistering `PLAYER_REGEN_ENABLED` on `f`, which
  slash-commands-§7's stand-down already tears down.

### C-002 — The alpha seam honors the soft hide (F-002)

- **Files:** `modules/Frame.lua`, `WhatGroup:ApplyFrameAlpha` (`:148-151`).
- **Change:**
  ```lua
  function WhatGroup:ApplyFrameAlpha()
      if not f then return end
      -- A soft-hidden popup is a refused Hide standing in at alpha 0. Only showPopup (which
      -- clears softHidden first) or the settled real Hide may bring the alpha back.
      f:SetAlpha(softHidden and 0 or masterAlpha())
  end
  ```
  `softHidden` is declared at `:227`, **after** `ApplyFrameAlpha`. Hoist the two flag declarations
  (`softHidden`, `pendingHide`) above `:148` so the function closes over them as upvalues. As it
  stands the name would resolve as a global and read `nil`.
- **Why this is sufficient:** `showPopup` (`:264-280`) sets `softHidden = false` before it calls
  `ApplyFrameAlpha`, and so does `hidePopup`'s real path (`:249-251`). Every legitimate restore
  still restores. `preparePopup` and the alpha row's `onChange` no longer reveal a soft-hidden
  popup, so `onScreen()` stays truthful and the launcher and ESC keep working.
- **Risk:** low. It needs the new F-006 cases plus the existing
  "an alpha change lands DURING combat" case (`tests/test_frame.lua:877`). That case runs against
  an on-screen popup, so it is unaffected, and the regression run must confirm it stays green.
- **Standards:** it keeps `standalone-windows`' one close/hide seam. No new deviation.

### C-003 — Persistable schema stamp (F-003)

- **Files:** `settings/Schema.lua` `Settings.BuildDefaults` (`:608-610`) and
  `core/Database.lua` `NS:RunMigrations` (`:23-45`).
- **Change:** declare `global.schemaVersion = 0` as the default (the pre-versioning value), and
  keep `NS.SCHEMA_VERSION = 1`. `RunMigrations` then reads 0 on every DB that has no stored stamp
  (fresh installs and every existing user alike), steps `0 → 1` (a no-op step, recorded as such) and
  stores 1. That value now differs from the default and **persists**. Delete the dead
  `or NS.SCHEMA_VERSION` on `:27`. Document in `Database.lua` that every migration step must be
  idempotent against a fresh default profile, because a fresh DB walks the whole chain once.
- **Side effect to accept:** the `[Migrate] v0 -> v1` debug line fires once per existing install
  on first login after the change. It is gated off by default (debug is session-only), and it is
  correct: the stamp was never stored.
- **Tests to move (same change):** `tests/test_database.lua` "fresh DB lands at schemaVersion 1"
  still holds after `RunMigrations`. "BuildDefaults seeds global.schemaVersion from
  NS.SCHEMA_VERSION" (`:27-30`) **changes meaning** and is rewritten to pin the default at 0. Add a
  red-under case that models the real hazard: boot, run AceDB's logout strip
  (`removeDefaults` / the mock's equivalent), re-boot with `SCHEMA_VERSION = 2` and a registered
  `1 → 2` step, and assert the step ran (`-- red under: default schemaVersion == SCHEMA_VERSION`).
  The pass count moves, so `docs/test-cases.md` and the README `Tests` badge move **in the same
  commit** (`testing-§5`).
- **Standards:** `savedvariables-§1` MUST ("declare `schemaVersion` in the global namespace") is
  kept. The template's literal differs, and that difference is routed upstream rather than recorded
  as a local deviation.

### C-004 — The Options stub stops clobbering the host reset (F-004)

- **Files:** `settings/OptionsSetup.lua` degraded branch (`:52-157`).
- **Change:** do not assign `H.RestoreAllDefaults`, because the host has already published the real
  one (`settings/Schema.lua:691`). Guard it the way the stub's intent reads:
  ```lua
  -- The host's RestoreAllDefaults (settings/Schema.lua) is a db:ResetProfile() and needs no
  -- library; options-ui-§1 keeps the global reset real in the stub. Only fill the gap if absent.
  H.RestoreAllDefaults = H.RestoreAllDefaults or function() end
  ```
  Audit the other stub assignments for the same collision class. By inspection, `RefreshAll`,
  `Get`, `Set`, `FindSchema`, `ValidateSchema`, `ApplyDefault`, `InlineButton` and
  `BuildMainContent` are **not** assigned by the stub, so `RestoreAllDefaults` is the only one.
- **Tests (same change):** add the degraded case to `tests/test_libka0s.lua` beside `:637-661`:
  load with `NO_LIBKA0S`, change a row, call `Settings.Helpers.RestoreAllDefaults()`, and assert the
  row is back at its default (`-- red under: the stub's no-op assignment`). The pass count moves, so
  the inventory and badge move with it. `tests/test_surface_parity.lua` compares the stub's member
  set **by name**, and the name set is unchanged.
- **Standards:** `options-ui-§1` SHOULD (keep the global reset real) and anti-pattern #47. Nothing
  is copied from the library, and the kept function is the host's own.

### C-005 — `NS.Debug` format-args at the 16 sites (F-005)

- **Files:** `core/Database.lua:43`; `core/WhatGroup.lua:506, 786, 818, 832, 885, 916-918, 973,
  1026, 1096`; `modules/Frame.lua:425-427, 504-507, 890-892, 1050-1051`;
  `settings/Schema.lua:398, 465`.
- **Change pattern:** move each concatenation into the sink's format-args form, with values
  passed raw so the sink's `safeToString` renders them:
  ```lua
  -- before
  NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))
  -- after
  NS.Debug("LFG", "appID=%s status=%s", appID, newStatus)
  ```
  `modules/Frame.lua:890-892` picks between two messages with a ternary. Split it into an
  `if info then … else … end` pair of calls so neither branch builds a string. Keep the logged
  **wording** byte-identical. The `[Set]` line at `settings/Schema.lua:465` is pinned by
  debug-logging cases.
- **Risk:** low. Any `%` in a logged value is a vararg, not part of the format string, so it cannot
  inject. Lines already asserted by `tests/test_debuglog.lua` must stay byte-identical, and the
  existing suite is the characterization for that (`testing-§13`).
- **Standards:** `debug-logging-§4` MUST NOT build before the call. This removes an existing
  deviation and introduces none.

### C-006 — Hoist the teleport button's script closures (F-016)

- **Files:** `modules/Frame.lua`, `applyTeleportAction` (`:403-456`).
- **Change:** define `onTeleportEnter(self)`, `onTeleportLeave()` and
  `onTeleportPreClick(self, button, down)` once at file scope. Keep the per-button spell id on the
  button (`btn.__wgSpellID`, `btn.__wgSpellName`) and have the handlers read it from `self`. The
  `SetScript` calls then pass the same function objects every time.
- **Expected movement:** `showFrameRepeat` bytes/iter should fall below today's **1872.5**
  (`tests/perf.lua`). Record the new figure in `docs/performance.md` and lower the scenario's
  ceiling in the same change (the page's "measured + 24" rule). **Do not claim a number before the
  scenario is re-run.**
- **Standards:** `performance-§9` (offline scenario is the evidence). No new deviation.

### C-007 — Comment and header corrections (F-007, F-008, F-009)

- `modules/Frame.lua:180-212`: rewrite the `outOfCombat` bullet and delete the `:205-206`
  paragraph. Both contradict `:255-258` and the soft-hide behavior.
- `modules/Frame.lua:748-751`: state that the swipe itself costs no Lua repeat, and point at
  `docs/performance.md` for the ticker's ratified deviation.
- `modules/Frame.lua:385-402`: move each doc block onto the function it describes
  (`deferTeleportUntilCombatEnds`, `resolveTeleportState`, `applyTeleportNote`,
  `applyTeleportAction`).
- `modules/Frame.lua:999-1005`: delete the superseded paragraph.
- `modules/Frame.lua:608`: change to `stopCooldownTicker()`.
- `core/WhatGroup.lua:2`, `:20`, `:44`, `:129`: name `settings/Slash.lua` and
  `core/CoreSetup.lua`.
- `core/Util.lua:1-25`: fix the header to name both seams, and move the Windows comment block to
  sit above `NS.Windows`.
- Counts (F-009): replace every numeric "N addons" / "N rows" with the non-numeric phrasing ("every
  Ka0s addon", "the composed block"), so the comments cannot drift again. Fix
  `core/LauncherSetup.lua:143` to `slash-commands-§7`.
- **Risk:** none (comments only). The `test_doc_structure`/`test_docmap` suites read docs, not
  these comments.

### C-008 — Locale surface honesty (F-010)

- Delete `locales/enUS.lua:119-123`, the dead key and its comment.
- Correct the header (`:19-28`): the refusal line is LibKa0s-Slash's `DISABLED_LINE_FORMAT`, and the
  `"Settings layer not ready yet"` example goes.
- **Standards:** it matches `localization-§3` and the file's own "a key with no reader is a defect".
  The ratified partial-routing deviation in `docs/ARCHITECTURE.md` is unaffected.

### C-009 — Trim `.luacheckrc` `read_globals` (F-011)

- Remove `GetSpellInfo`, `GetSpellTexture`, `GetSpellCooldown`, `CastSpellByID`, `SettingsPanel`
  and `date` from the top-level `read_globals`. Then run `luacheck .`: it must stay 0/0. If any
  remaining authored read surfaces, restore that one name with a comment naming its reader.
- **Standards:** `lint` and `testing-§4`. `tests/test_lintconfig.lua` checks ignores, not
  `read_globals`, so no case moves.

### C-010 — Complete `APPLICATION_ENDED` (F-012)

- **Files:** `core/WhatGroup.lua:936-941`.
- **Change:** add `timedout`, `invitedeclined` and `failed`, **after** confirming the exact status
  spellings against the 12.1.0 client (`/etrace` on `LFG_LIST_APPLICATION_STATUS_UPDATED` while
  letting an application time out and declining an invite). Add one `tests/test_capture.lua` case
  per status, pinning that the capture is dropped. The pass count moves.
- **Risk:** low. It drops only session state for an application that can no longer produce a join.

### C-011 — Remove the dead category handles (F-013)

- Delete `settings/Panel.lua:387-390` (the two assignments and their comment), and drop
  `tests/test_panel.lua:90-91`. Those two asserts pin dead state. Before deleting, confirm that no
  **reader** exists under `libs/LibKa0s/` (`grep -rn _settingsCategory libs/`). If the library
  reads either name, keep it and document the reader instead.
- **Tests:** the pass count is unchanged if the asserts sit inside a larger case (they do,
  "panel: the parent category is added to the AddOns list", `tests/test_panel.lua:87-92`). No library reader exists (`grep -rn _settingsCategory libs/` is empty). Re-run `--list` and move the inventory only if it changes.

## Test and inventory movement (all in the same commits as the code)

C-003, C-004 and C-010 add cases, so the pass count rises from **727**. `docs/test-cases.md` is
regenerated with `lua tests/run.lua --list > docs/test-cases.md`, and the README `Tests` badge
moves in the **same commit** as each count change (`testing-§5`). F-006 is closed by the
C-001/C-002 cases:

- `frame: reopening a soft-hidden popup in combat with no capture never Hides the secure button`
  (`-- red under: PopulateFields' direct teleportBtn:Hide()`)
- `frame: a gate-declined reopen in combat leaves a soft-hidden popup at alpha 0, and the launcher still closes it`
  (`-- red under: ApplyFrameAlpha ignoring softHidden`)
- `frame: an alpha write while soft-hidden does not reveal the popup`

**Expected watch-list direction** (for the next release run to confirm; nothing is regenerated
here): `modules/Frame.lua` grows slightly with C-001, C-002 and C-006 and stays in the 1000–1500
band. `core/WhatGroup.lua` shrinks marginally with C-005 and C-007 and stays in the band.
`WhatGroup:ShowFrame` (CCN 14) is not touched.

## Standards conformance summary

| Change | Rule(s) that shaped it | New deviation? |
|---|---|---|
| C-001 | events-frames-taint-§2, slash-commands-§7 (the stand-down clears the stash) | No |
| C-002 | standalone-windows (one hide seam), events-frames-taint-§2 | No |
| C-003 | savedvariables-§1 (declared in global); template literal routed upstream | No |
| C-004 | options-ui-§1 (stub SHOULD keep reset real; no copies, anti-pattern #47) | No |
| C-005 | debug-logging-§4 | No (removes one) |
| C-006 | performance-§9 | No |
| C-007 | documentation (comments tell the truth) | No |
| C-008 | localization-§3 | No |
| C-009 | lint | No |
| C-010 | none beyond testing-§12 (each new case must be able to go red) | No |
| C-011 | testing-§12 (retire a test that pins dead state) | No |

Rejected on standards grounds: dropping `schemaVersion` from the defaults (C-003 alternative,
`savedvariables-§1`); copying the library's reset into the Options stub (anti-pattern #47); any
local edit that renames `global.minimap.hide` (`launcher-§3` MUST store at `minimap.hide`).
