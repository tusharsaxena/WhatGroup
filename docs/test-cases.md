# Test Cases

_Generated — do not hand-edit, regenerate with `lua tests/run.lua --list > docs/test-cases.md`._

### test_util.lua (7)
- util: SafeToString handles nil / booleans / strings / numbers
- util: SafeToString yields <secret> for a value that raises in concat
- util: IsConcatSafe true for scalars, false for a raising value
- util: NS.Print prepends the [WG] prefix and stringifies each arg
- util: NS.Print degrades a secret-like arg in place, never raising
- util: Windows.Save/Restore round-trips a frame point through db.global (WG-26)
- util: Windows.Restore is a no-op when nothing is saved (WG-26)

### test_compat.lua (6)
- compat: GetSpellName returns the C_Spell name
- compat: GetSpellTexture is non-nil (caller supplies default)
- compat: GetSpellLink returns a hyperlink for the spell
- compat: IsSpellKnown true when learned
- compat: IsSpellKnown false when not learned
- compat: GetActivityInfoTable passes the table through

### test_database.lua (3)
- database: fresh DB lands at schemaVersion 1
- database: RunMigrations is idempotent
- database: RunMigrations re-seeds a missing schemaVersion

### test_settings.lua (11)
- settings: BuildDefaults threads profile + global defaults
- settings: defaults source from NS.C (defaults/Profile.lua, WG-24)
- settings: BuildDefaults seeds an empty global.windows table (WG-26)
- settings: debug is not a persisted schema row (WG-12)
- settings: ValidateSchema reports zero errors
- settings: Get/Set round-trips through db.profile
- settings: RestoreDefaults resets a changed value
- settings: RestoreDefaults prunes orphaned profile keys (F1)
- settings: RestoreDefaults deep-copies table defaults (F2)
- settings: RestoreDefaults skips per-row onChange (F3)
- settings: enabled=false onChange wipes capture

### test_slash.lua (3)
- slash: COMMANDS has a standalone version verb (WG-29)
- slash: /wg version prints [WG] v<version> on its own line (WG-29)
- slash: help header has no trailing colon (WG-19)

### test_labels.lua (9)
- labels: GetGroupTypeLabel Mythic+
- labels: GetGroupTypeLabel Dungeon by categoryID
- labels: GetGroupTypeLabel Raid by player count
- labels: GetGroupTypeLabel fallback Group
- labels: GetPlaystyleLabel prefers playstyleString
- labels: GetPlaystyleLabel enum lookup when string empty
- teleport: GetTeleportSpell picks the known spell from a list
- teleport: GetTeleportSpell returns first + false when none known
- teleport: GetTeleportSpell nil when no mapping

### test_capture.lua (4)
- capture: inviteaccepted prefers FRESH when both have mapID
- capture: inviteaccepted falls back to QUEUED when fresh lacks mapID
- capture: enabled queues so pendingInfo survives a nil fresh fetch
- capture: master switch off means nothing is queued

### test_debuglog.lua (18)
- debuglog: FONT_MONO points at the vendored JetBrains Mono TTF
- debuglog: FormatPlain wraps the tag in brackets, single-space separators
- debuglog: FormatPlain tolerates a nil tag
- debuglog: FormatColored colours timestamp + tag; pipe and content default
- debuglog: /wg debug on enables session state
- debuglog: /wg debug off disables session state
- debuglog: /wg debug (no arg) toggles the window, not the state
- debuglog: header toggle click flips debug state
- debuglog: enabling writes a '[Debug] logging enabled' console line
- debuglog: enabling debug appends the [Init] session summary after the bracket (debug-logging-§5)
- debuglog: [Init] fires only on enable, not on disable (debug-logging-§5)
- debuglog: disabling still appends a '[Debug] logging disabled' line
- debuglog: NS.Debug survives an unsafe format arg without raising (WG-22)
- debuglog: NS.Debug is a no-op (no console write) when debug is off
- debuglog: settings change logs one [Set] line at the write seam (debug-logging-§10)
- debuglog: RestoreDefaults coalesces to one [Reset], zero [Set] (debug-logging-§9)
- debuglog: InitSummary leads with the debug-logging-§5 identity fields, then runtime state
- debuglog: enable ack is colour-coded green/red matching the header (debug-logging-§5)

## Totals

| Suite | Count |
| --- | --- |
| test_util.lua | 7 |
| test_compat.lua | 6 |
| test_database.lua | 3 |
| test_settings.lua | 11 |
| test_slash.lua | 3 |
| test_labels.lua | 9 |
| test_capture.lua | 4 |
| test_debuglog.lua | 18 |
| **Total** | **61** |
