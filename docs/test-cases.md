# Test Cases

_Generated — do not hand-edit, regenerate with `lua tests/run.lua --list > docs/test-cases.md`._

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

### test_settings.lua (6)
- settings: BuildDefaults threads profile + global defaults
- settings: debug is not a persisted schema row (WG-12)
- settings: ValidateSchema reports zero errors
- settings: Get/Set round-trips through db.profile
- settings: RestoreDefaults resets a changed value
- settings: enabled=false onChange wipes capture

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

### test_debuglog.lua (17)
- debuglog: FONT_MONO points at the vendored JetBrains Mono TTF
- debuglog: FormatPlain wraps the tag in brackets, single-space separators
- debuglog: FormatPlain tolerates a nil tag
- debuglog: FormatColored colours timestamp + tag; pipe and content default
- debuglog: /wg debug on enables session state
- debuglog: /wg debug off disables session state
- debuglog: /wg debug (no arg) toggles the window, not the state
- debuglog: header toggle click flips debug state
- debuglog: enabling writes a '[Debug] logging enabled' console line
- debuglog: enabling debug appends the [Init] session summary after the bracket (§5)
- debuglog: [Init] fires only on enable, not on disable (§5)
- debuglog: disabling still appends a '[Debug] logging disabled' line
- debuglog: NS.Debug is a no-op (no console write) when debug is off
- debuglog: settings change logs one [Set] line at the write seam (§10)
- debuglog: RestoreDefaults coalesces to one [Reset], zero [Set] (§9)
- debuglog: InitSummary leads with the §5 identity fields, then runtime state
- debuglog: enable ack is colour-coded green/red matching the header (§5)

## Totals

| Suite | Count |
| --- | --- |
| test_compat.lua | 6 |
| test_database.lua | 3 |
| test_settings.lua | 6 |
| test_labels.lua | 9 |
| test_capture.lua | 4 |
| test_debuglog.lua | 17 |
| **Total** | **45** |
