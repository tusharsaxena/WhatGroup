# Test Cases

The full inventory of every headless test case in this repo, grouped by the suite file it
lives in. The `## Totals` table below is the **authoritative pass count** — the README test
badge and any count quoted in the docs must agree with it.

**Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.

### test_harness.lua (17)

- harness: the runner is on the shared kit and reports its revision
- harness: the addon's load list is DERIVED from the TOC, in TOC order (testing-§9)
- harness: every derived addon path exists on disk
- harness: no libs/ path leaked into the derived addon list
- harness: the explicit LibKa0s list matches LibKa0s.xml, in XML order (anti-patterns #48)
- harness: every LibKa0s file the runner loads exists on disk
- harness: the libraries load BEFORE the addon's own files
- harness: the addon is a named AceAddon the kit can look up
- harness: the addon's event registrations reach the kit's dispatcher
- harness: UnregisterAllEvents silences what the dispatcher reaches
- harness: a registration naming a method the addon lacks is refused
- harness: the addon's AceTimer handles are the kit's, on the kit's queue
- events: one retired event name does not abort OnEnable
- events: one retired event name does not abort OnEnable on a client without C_EventUtils
- events: the [Init] summary carries no rejected clause when every name registered
- degraded: the Core stub's SafeRegisterEvent survives a bad name
- events: a stand-up after a rejection records the name once

### test_libka0s.lua (54)

- libka0s: every vendored major registers under LibStub
- libka0s: MODULES names every file of every major, at a positive integer minor
- core: the published seams ARE the library's, not a lookalike
- core: the close button is the library's, told which addon folder is asking
- core: ApplySkin stays a bare bind, so its optional override survives
- core: the printer emits <prefix><space><body> as one line
- core: the prefix is read at CALL time, not captured at load
- core: the sink is the Lua global print, so the harness can see chat output
- debuglog: the console is the library's instance, and the sink is bound bare
- debuglog: the library is told the FOLDER name, not just the frame name
- debuglog: the descriptor keeps the frame globals the old console used
- debuglog: the composed window title is unchanged
- debuglog: the flag stays the addon's — the library never keeps a copy
- debuglog: the [Init] summary is the addon's, reached through the descriptor
- debuglog: the console's user-visible strings resolve to prose, not to their own keys
- debuglog: the gated sink survives a format its arguments cannot satisfy (WG-22)
- options: Settings.Helpers IS the library instance, decorated in place
- options: the host's data seams survived the move onto the instance
- options: the host's RestoreAllDefaults deliberately overrides the library's
- options: a panel write takes the addon's single write seam
- options: no layout constant is restated in this addon's own source
- options: the panel body still builds on the NEXT frame, not inside OnShow
- slash: the help header is the library's, with this addon's alias sentence
- slash: a help row is the one command-row formatter, indented two spaces
- slash: the landing page renders the SAME rows, un-indented (convergence #2)
- slash: the landing page draws those rows and nothing of its own
- slash: `list` renders through the shared key/value formatter
- slash: a number row still renders through its schema `fmt`
- slash: `toggle` survived the adoption, through the descriptor's parse adapter
- slash: the descriptor's L overrides exactly one string and nothing else
- slash: every user-visible CLI string resolves to prose, not to its own key
- degraded: the addon loads with LibKa0s absent
- degraded: the cause clause is published on BOTH paths
- degraded: the printer announces the absence exactly ONCE, then prints normally
- degraded: the fallback printer still degrades a secret in place
- degraded: every DebugLog member the addon calls still answers
- degraded: the console stub copies NO library formatter
- degraded: every HAND-WRITTEN schema row survives the options library's absence (options-ui-§1)
- degraded: the STORED profile is the same shape with the library absent
- degraded: `/wg disable` and `/wg enable` print the library-absent line and write nothing (options-ui-§1, WhatGroup#22)
- degraded: `/wg test on|off` print the library-absent line and move nothing
- degraded: Reset all settings still resets the profile (options-ui-§1)
- degraded: the settings stub carries no widget maker and no layout constant
- degraded: the settings panel explains itself once at load and once per config
- degraded: a bare /wg runs `config`, as the library's dispatcher does
- degraded: `/wg debug on` still moves the flag and explains the missing window ONCE
- libka0s: no seam re-spells the refusal line (slash-commands-§7)
- degraded: the Slash stub's DisabledLine uses the library's DISABLED_LINE_FORMAT bytes
- libka0s: the Master controls hook is keyed off the library's constant, not a copy of it
- libka0s: the L-trap matcher flags the table and the `or` spelling, not the `and` one
- libka0s: no seam file hands a descriptor this addon's locale table (the L trap)
- libka0s: Core has no STRINGS and reads no descriptor L (tripwire)
- libka0s: Options reads no descriptor L (tripwire)
- locale: every key enUS.lua defines has a reader

### test_surface_parity.lua (9)

- parity: the Core seam's whole namespace surface survives the library's absence
- parity: the DebugLog stub carries the whole live surface
- parity: the Slash stub carries the whole live surface
- parity: the Options helpers stub carries the whole live surface
- parity: the Schema host stub's instance carries the whole live instance surface
- parity: the Schema host stub carries the library's own members
- parity: the Launcher stub carries the whole live surface
- parity: the Lifecycle stub carries the whole live surface
- parity: the Compat reader arm carries every library member the addon wires

### test_mediasetup.lua (11)

- mediasetup: NS.Icon answers the vendored path, EXTENSIONLESS
- mediasetup: an icon the library does not ship answers nil
- mediasetup: NS.MediaFont answers the vendored face, and only for a face it ships
- mediasetup: the face this addon names is the face the library registers
- mediasetup: the LSM registration is the library's, made at file load
- mediasetup: every icon this addon draws is one the library ships
- mediasetup: every icon this addon draws has a file in the vendored copy
- mediasetup: the whole catalog has a file in the vendored copy
- mediasetup: this addon ships no private copy of the shared art (anti-patterns #63)
- mediasetup: with no library there is no art and no face, and that is not an error
- mediasetup: a degraded install still gets a REAL font, never nil and never a dead path

### test_envsetup.lua (8)

- envsetup: NS.Meta reads this addon's TOC
- envsetup: NS.Meta asks about this addon's FOLDER, not its title or its frame prefix
- envsetup: NS.Meta degrades to nil when the client exposes no manifest reader
- envsetup: NS.Version prefers the TOC over this addon's own constant
- envsetup: NS.Version falls back to this addon's own constant
- envsetup degraded: an install with no LibKa0s still reads its own TOC
- envsetup: no file inlines its own C_AddOns ladder any more
- envsetup: the ladder did not land in Compat either

### test_util.lua (31)

- util: SafeToString handles nil / booleans / strings / numbers
- util: SafeToString yields <secret> for a value that raises in concat
- util: IsConcatSafe true for scalars, false for a raising value
- util: NS.Print prepends the [WG] prefix and stringifies each arg
- util: NS.Print degrades a secret-like arg in place, never raising
- util: Windows.Save/Restore round-trips a frame point through db.global (WG-26)
- util: Windows.Restore is a no-op when nothing is saved (WG-26)
- util: SafeToString renders a negative and a fractional number
- util: SafeToString degrades a function and a coroutine
- util: IsConcatSafe reports a boolean as unsafe
- util: IsConcatSafe reports nil as safe (concat of an empty table)
- util: NS.Print with no arguments still prints the prefix
- util: NS.Print joins several arguments with single spaces
- util: NS.Print stringifies nil and boolean arguments in place
- util: PointOf reads a frame's primary anchor
- util: PointOf defaults relPoint to the point and offsets to zero
- util: PointOf returns nil for a frame with no anchor yet
- util: PointOf returns nil for nil or a non-frame
- util: Save is a no-op before the db is ready
- util: Save skips a frame that has no anchor
- util: Save overwrites a previously stored point
- util: windows are stored under independent names
- util: Restore returns false for a frame that cannot be anchored
- util: Restore is a no-op before the db is ready
- util: Restore clears existing anchors before applying the saved one
- util: a Save/Restore round trip survives through the real frame stub
- util: FormatDuration renders hours, minutes and seconds
- util: FormatDuration drops units above the largest non-zero one
- util: FormatDuration keeps trailing zero units once a larger one is present
- util: FormatDuration rounds fractional seconds up
- util: FormatDuration renders a non-positive duration as 0s

### test_compat.lua (42)

- compat: GetSpellName returns the C_Spell name
- compat: GetSpellTexture is non-nil (caller supplies default)
- compat: GetSpellLink returns a hyperlink for the spell
- compat: IsSpellKnown true when learned
- compat: the harness answers a learned spell through C_SpellBook, not the global
- compat: IsSpellKnown false when not learned
- compat: GetSpellCooldownRemaining is 0 for a spell that is ready
- compat: GetSpellCooldownRemaining counts down from start + duration
- compat: GetSpellCooldownRemaining is 0 once the cooldown has elapsed
- compat: GetSpellCooldownRemaining ignores a global-cooldown-length window
- compat: GetSpellCooldownRemaining reports 0 when the cooldown is disabled
- compat: GetSpellCooldownRemaining returns 0 when the API is missing
- compat: GetActivityInfoTable passes the table through
- compat: GetSpellName falls back to the legacy GetSpellInfo global
- compat: GetSpellName falls through when the modern API returns nil
- compat: GetSpellName returns nil when no API exists at all
- compat: GetSpellTexture falls back to the legacy global
- compat: GetSpellTexture returns nil with no API (the caller supplies a default)
- compat: GetSpellLink returns nil with no API (the caller renders plain text)
- compat: IsSpellKnown normalizes to a plain boolean
- compat: IsSpellKnown returns false when the API is missing
- compat: IsSpellKnown asks C_SpellBook first when both APIs exist
- compat: IsSpellKnown takes a false from C_SpellBook as the answer
- compat: IsSpellKnown uses the global when C_SpellBook or its member is absent
- compat: IsSpellKnown returns false when neither API exists
- compat: GetActivityInfoTable returns nil for an unknown activity
- compat: GetActivityInfoTable returns nil when C_LFGList is absent
- compat: AddOnLinkType answers Blizzard's addon link type
- compat: AddOnLinkType is nil without LinkTypes.AddOn
- compat: AddOnLinkType is nil without EventRegistry:RegisterCallback
- compat: Compat is the sole namespace the addon reads variant APIs through
- compat: GetSpellCooldownTimes hands SetCooldown exactly two values on every rung
- compat: GetSpellCooldownRemaining reads a legacy isEnabled of 0 as disabled, 1 and nil as enabled
- compat: GetSpellCooldownRemaining reads a modern table with no isEnabled as enabled
- compat: GetSpellCooldownRemaining is 0 for a cooldown table with no start or duration
- compat: GetSpellName and GetSpellTexture answer the popup's numeric teleport ids
- compat: GetSpellName and GetSpellTexture ARE LibKa0s-Compat-1.0's members
- compat: GetSpellName falls through a plain empty string from the modern rung
- compat: GetSpellName reads C_Spell.GetSpellInfo's name when GetSpellName has none
- compat: an id outside the spell domain answers the no-answer value without asking the client
- compat: GetSpellTexture hands back one value when the client answers two
- compat degraded: with LibKa0s absent the spell readers answer the library's absent values

### test_database.lua (11)

- database: fresh DB lands at schemaVersion 1
- database: RunMigrations is idempotent
- database: RunMigrations re-seeds a missing schemaVersion
- database: defaults declare global.schemaVersion 0 (savedvariables-§1)
- database: the stamp survives AceDB's logout strip, so the first real migration runs
- database: a raising step leaves the stamp at the last completed version
- database: RunMigrations before the db exists is a no-op
- database: an older saved DB is stepped up to the current version
- database: a version move is logged, a no-op migration is silent (debug-logging-§8)
- database: migrations run before any profile read (OnInitialize order)
- database: the profile is untouched by a migration pass

### test_settings.lua (56)

- settings: BuildDefaults threads profile + global defaults
- settings: defaults source from NS.C (defaults/Profile.lua, WG-24)
- settings: BuildDefaults seeds an empty global.windows table (WG-26)
- settings: debug is not a persisted schema row (WG-12)
- settings: ValidateSchema reports zero errors
- settings: Get/Set round-trips through db.profile
- settings: RestoreAllDefaults resets a changed value
- settings: RestoreAllDefaults prunes orphaned profile keys (F1)
- settings: RestoreAllDefaults deep-copies table defaults (F2)
- settings: RestoreAllDefaults skips per-row onChange (F3)
- settings: enabled=false onChange wipes capture
- settings: every schema row declares the fields the panel and CLI need
- settings: schema paths are unique
- settings: every schema row carries a tooltip
- settings: every number row declares min, max and step
- settings: ValidateSchema counts each defect on a broken row
- settings: ValidateSchema reports a non-table row
- settings: a broken row does not stop the panel registering
- settings: BuildDefaults nests dotted paths into real subtables
- settings: BuildDefaults covers every schema row
- settings: BuildDefaults deep-copies table defaults
- settings: BuildDefaults is a fresh table each call
- settings: Get returns nil before the db exists
- settings: Set before the db exists is a harmless no-op
- settings: a write creates the intermediate tables it walks through
- settings: Get on an unknown deep path returns nil and creates no table
- settings: Resolve replaces a non-table intermediate
- settings: there is no RawSet; a write to `enabled` always runs its onChange
- settings: Set takes no skipOnChange option
- settings: a throwing onChange propagates, after the value landed
- settings: Set on a path with no schema row is refused and stores nothing
- settings: FindSchema matches on the exact path
- settings: RestoreAllDefaults restores every schema row
- settings: RestoreAllDefaults leaves db.global untouched
- settings: RefreshAll runs every refresher on the open page, in registration order
- settings: a throwing refresher does not abort the sweep
- settings: a hidden page is not refreshed — it is flagged dirty (options-ui-§11)
- settings: every Set re-syncs the widgets once; there is no skipRefresh
- settings: RestoreAllDefaults refreshes once, plus once per session-only row
- settings: EnsureResetPopup is idempotent
- settings: the reset dialog is a blocking, escapable confirmation
- settings: accepting the reset dialog acknowledges in chat
- settings: the page's tabs are the designed ones, in order, at the designed size
- settings: no tab holds fewer than two controls
- settings: every row's group is one of the designed tabs
- settings: the popup size defaults are the literals they replaced
- settings: the size sliders cannot travel outside the frame's own clamp
- settings: the Master controls block is the FIRST group, in canonical order
- settings: the Master controls rows are the COMPOSER's, not hand-written
- settings: Enable names the addon, and visibility is a four-value dropdown
- settings: Enable names the FOLDER this addon loaded from, not a hand-typed copy of it
- settings: the master rows keep this addon's own shipped defaults
- settings: the debug console is a SESSION-ONLY row that never reaches db.profile (WG-12)
- settings: a global reset closes the console a profile reset cannot reach (options-ui-§12)
- settings: every row on every page carries a `group`
- settings: every color row is followed by its class-color companion, and none is disabled

### test_slash.lua (59)

- slash: COMMANDS has a standalone version verb (WG-29)
- slash: /wg version prints [WG] v<version> on its own line (WG-29)
- slash: help header has no trailing colon (WG-19)
- slash: a bare /wg opens the settings landing page through `config`
- slash: whitespace-only input is treated as bare /wg
- slash: nil input is tolerated
- slash: help lists one row per COMMANDS entry, plus the header
- slash: every COMMANDS row carries a verb, a description and a handler
- slash: an unknown verb says so and then prints the help index
- slash: the verb is case-insensitive
- slash: only the verb is lower-cased — the argument keeps its case
- slash: /wg version reads the version from TOC metadata
- slash: /wg version falls back to the in-code constant
- slash: /wg list prints every schema row
- slash: /wg list groups rows under their section header
- slash: /wg list shows current values, not defaults
- slash: /wg get prints key = value
- slash: /wg get with no path prints usage
- slash: /wg get reports an unknown path rather than printing nil
- slash: /wg get formats a number through the schema fmt
- slash: /wg set with no path prints usage
- slash: /wg set reports an unknown path
- slash: /wg set accepts 'true' as true
- slash: /wg set accepts '1' as true
- slash: /wg set accepts 'on' as true
- slash: /wg set accepts 'yes' as true
- slash: /wg set accepts 'false' as false
- slash: /wg set accepts '0' as false
- slash: /wg set accepts 'off' as false
- slash: /wg set accepts 'no' as false
- slash: /wg set bool words are case-insensitive
- slash: /wg set toggle flips the current value
- slash: /wg set rejects a non-boolean word and lists the accepted ones
- slash: /wg set writes a number
- slash: /wg set rejects a non-numeric value for a number row
- slash: /wg set clamps a number below the schema min
- slash: /wg set clamps a number above the schema max
- slash: /wg set echoes the STORED value back, not the typed one
- slash: /wg set with a missing value is rejected, not silently applied
- slash: /wg set enabled false runs the master-switch onChange
- slash: /wg debug with a bad subcommand prints both usage lines
- slash: /wg debug (bare) toggles the console window's visibility
- slash: /wg debug on does not open the window
- slash: /wg set writes an enum value from the row's own value set
- slash: /wg set rejects a value the enum does not offer
- slash: /wg list carries the Master controls rows under their section
- slash: /wg enable and /wg disable write the checkbox's own stored path
- slash: the verbs and the checkbox are the same row, so they cannot disagree
- slash: `disable` runs the row's onChange, exactly as the checkbox does
- slash: each verb acknowledges on one `key = value` line
- slash: the dispatcher answers while the addon is disabled
- slash: the reserved pair is in COMMANDS, so help and the landing page carry it
- slash: `/wg show` refuses while disabled, and does not show the popup
- slash: `/wg test on` refuses while disabled, and does not enter test mode
- slash: every verb is either on the live list or refuses — there is no third kind
- slash: the gate lifts the moment the addon is enabled again
- slash: the refusal REPLACES the handler — not even its own empty-state hint prints
- slash: the refusal does not touch the help index or the landing page
- slash: `perf` is reserved here but not registered (LIBKA0S-15)

### test_labels.lua (34)

- labels: GetGroupTypeLabel Mythic+
- labels: GetGroupTypeLabel Dungeon by categoryID
- labels: GetGroupTypeLabel Raid by player count
- labels: GetGroupTypeLabel fallback Group
- labels: GetPlaystyleLabel prefers playstyleString
- labels: GetPlaystyleLabel enum lookup when string empty
- teleport: GetTeleportSpell picks the known spell from a list
- teleport: GetTeleportSpell returns first + false when none known
- teleport: GetTeleportSpell nil when no mapping
- labels: GetGroupTypeLabel Raid (Current)
- labels: GetGroupTypeLabel Heroic Raid
- labels: GetGroupTypeLabel PvP by categoryID 2
- labels: GetGroupTypeLabel Dungeon by a small player count
- labels: GetGroupTypeLabel treats exactly 10 players as a Raid
- labels: GetGroupTypeLabel treats 9 players as a Dungeon
- labels: GetGroupTypeLabel falls back to Group at zero players
- labels: Mythic+ outranks every other signal
- labels: the raid flags outrank categoryID
- labels: categoryID outranks the player count
- labels: every playstyle enum maps to its Blizzard-localized wording
- labels: playstyle None (0) has no label
- labels: an unmapped playstyle enum yields an empty label, not nil
- labels: playstyleString wins even when the enum is also set
- labels: a nil playstyleString falls through to the enum
- teleport: a scalar mapping returns (spellID, known) directly
- teleport: a scalar mapping the player has not learned reports known=false
- teleport: mapID takes precedence over activityID
- teleport: activityID is the fallback when the mapID is unmapped
- teleport: a nil mapID and nil activityID resolve to nothing
- teleport: the FIRST known spell in a candidate list wins
- teleport: the shipped mapping table is keyed by numbers only
- teleport: the Midnight Keystone Hero rows match the spellbook-verified IDs
- teleport: the Midnight season 2 rows match the spellbook-verified IDs
- teleport: Siege of Boralus offers the spellbook-verified spell first

### test_capture.lua (35)

- capture: inviteaccepted prefers FRESH when both have mapID
- capture: inviteaccepted falls back to QUEUED when fresh lacks mapID
- capture: enabled queues so pendingInfo survives a nil fresh fetch
- capture: master switch off means nothing is queued
- capture: master switch off blocks the inviteaccepted fresh fetch too
- capture: CaptureGroupInfo maps the search-result fields
- capture: CaptureGroupInfo maps the activity fields
- capture: CaptureGroupInfo returns nil when the search result is gone
- capture: missing search-result fields fall back to safe defaults
- capture: an unknown activity leaves the activity fields at their defaults
- capture: no activityIDs at all leaves activityID nil
- capture: fullName falls back to the activity name
- capture: the legacy `playstyle` field is used when generalPlaystyle is absent
- capture: the raid flags are carried through
- capture: applications are matched to captures in FIFO order
- capture: an 'invited' status changes nothing — it waits for the accept
- capture: an unrecognized status is ignored
- capture: accepting clears the queue so a stale apply can't resurface
- capture: 'applied' with nothing queued is a harmless no-op
- capture: accepting with no data anywhere leaves pendingInfo nil
- capture: re-enabling the master switch resumes capturing
- capture: inviteaccepted resolves the searchResultID via GetApplicationInfo
- capture: GetApplicationInfo may return a table; the id is read off it
- capture: an unmapped application falls back to treating appID as the id
- capture: a missing GetApplicationInfo degrades to the appID path
- capture: a raising GetApplicationInfo is caught and falls back
- capture: two outstanding applications pair to their own search results
- capture: a declined application drops its queued capture
- capture: a canceled application drops its unanswered capture
- capture: a timedout application drops its capture
- capture: an invitedeclined application drops its capture
- capture: a failed application drops its capture
- capture: a search field holding false takes the default, not the false
- capture: an activity field holding false takes the default, not the false
- capture: a stored zero survives the defaults, because 0 is truthy in Lua

### test_notify.lua (48)

- notify: no pendingInfo schedules no timer
- notify: out of a group schedules no timer even with pendingInfo
- notify: in a group with pendingInfo schedules exactly one timer
- notify: the scheduled delay comes from notify.delay
- notify: firing the timer prints the summary and clears the handle
- notify: a second call for the SAME pendingInfo schedules nothing more
- notify: both event paths together fire the summary exactly once
- notify: a NEW pendingInfo is eligible to fire again
- notify: a re-fire cancels the in-flight timer so two can't race
- notify: a callback whose pendingInfo was replaced mid-flight prints nothing
- notify: WipeCapture cancels an in-flight notify so it never fires
- notify: WipeCapture clears pendingInfo
- notify: WipeCapture re-arms a later capture (notifiedFor is cleared)
- notify: the master-switch off-flip wipes an in-flight capture (Schema onChange)
- notify: autoShow on opens the popup when the timer fires
- notify: autoShow off prints the summary but never builds the popup
- notify: autoShow is read when the timer FIRES, not when it is scheduled
- notify: notify.enabled off prints nothing at all
- notify: no pendingInfo prints nothing
- notify: the default summary carries every row
- notify: the Group row always prints, even with every toggle off
- notify: notify.showInstance off drops the Instance: row
- notify: notify.showInstance on keeps the Instance: row
- notify: notify.showType off drops the Type: row
- notify: notify.showType on keeps the Type: row
- notify: notify.showLeader off drops the Leader: row
- notify: notify.showLeader on keeps the Leader: row
- notify: notify.showPlaystyle off drops the Playstyle: row
- notify: notify.showPlaystyle on keeps the Playstyle: row
- notify: notify.showTeleport off drops the Teleport: row
- notify: notify.showTeleport on keeps the Teleport: row
- notify: notify.showClickLink off drops the [Click here to view details] row
- notify: notify.showClickLink on keeps the [Click here to view details] row
- notify: the Instance row falls back to Unknown when fullName is empty
- notify: the Type row prefers shortName over the derived label
- notify: the Type row derives the label when shortName is empty
- notify: the Playstyle row is skipped when the label resolves empty
- notify: the Teleport row is skipped when the map has no teleport spell
- notify: an unlearned teleport is tagged '(not learned)'
- notify: a learned teleport carries no '(not learned)' tag
- notify: a teleport on cooldown is tagged '(on cooldown)'
- notify: the cooldown tag carries no countdown to go stale
- notify: an unlearned teleport outranks a cooldown in chat too
- notify: a ready teleport carries neither tag
- notify: every summary line carries the shared [WG] prefix
- notify: a secret-like title degrades in place instead of raising
- notify: the Leader row still prints when leaderName is nil
- notify: Playstyle and Teleport drop their rows while Leader keeps its own

### test_frame.lua (90)

- frame: nothing is created at addon load
- frame: the first ShowFrame builds and shows the popup
- frame: buildFrame is one-shot — a second show reuses the same frame
- frame: ESC-to-close registers the proxy lazily, once, and never the popup itself
- frame: nothing reaches UISpecialFrames at load, not even after OnEnable (Logout taint)
- frame: the Close button hides the popup
- frame: fields render the pending capture
- frame: with no pendingInfo every field reads 'No data'
- frame: the no-data playstyle renders the dim em-dash placeholder
- frame: an empty fullName falls back to Unknown
- frame: the Type field prefers shortName
- frame: the Type field derives a label when shortName is empty
- frame: the Playstyle field prefers the server-rendered string
- frame: the Playstyle field falls back to the enum label
- frame: playstyle None (0) renders the dim em-dash, not an empty row
- frame: re-showing with a new capture re-renders the fields
- frame: the teleport button registers both click edges, because the up edge is the caster
- frame: a known teleport wires the secure /cast macro
- frame: a known teleport renders at full alpha, undesaturated
- frame: an unlearned teleport shows desaturated at half alpha and casts nothing
- frame: a teleport on cooldown arms no macro, so the click casts nothing
- frame: a teleport on cooldown renders desaturated and dimmed
- frame: a teleport on cooldown says how long is left
- frame: a teleport on cooldown arms the swipe with the real start and duration
- frame: a ready teleport clears the note and the swipe
- frame: an open popup ticks the cooldown note down each second
- frame: closing the popup cancels the ticker
- frame: re-opening the popup arms exactly one ticker, not a second
- frame: a ready teleport arms no ticker at all
- frame: a popup the gate keeps off screen arms no ticker
- frame: a popup that reaches the screen later still gets its ticker
- frame: the ticker rearms the cast the moment the cooldown expires
- frame: an unlearned teleport says so beside the button
- frame: an unlearned teleport is never labeled as on cooldown
- frame: a map with no teleport hides the button entirely
- frame: the button clears a stale macro when re-shown for a teleport-less map
- frame: the teleport icon uses the spell's texture
- frame: no pendingInfo hides the teleport button
- frame: a first show in combat defers the build and says so
- frame: leaving combat builds the deferred popup
- frame: the deferred show restores a pendingInfo cleared during the wait
- frame: repeated in-combat shows queue exactly one deferred show
- frame: a show requested in combat is deferred, not forced
- frame: a popup held at alpha 0 comes back in combat without a Show
- frame: reconfiguring the teleport button in combat stashes and replays it
- frame: a fresh profile leaves the popup at its default center anchor
- frame: dragging the title bar persists the popup position
- frame: a saved position is restored on the next build
- frame: the popup is built at the profile's width and height
- frame: a stored size is honored on build
- frame: a size change re-sizes a popup that is already open
- frame: a size hand-edited past the clamp is drawn at the nearest legal value
- frame: a non-numeric stored size falls back to the shipped default
- frame: a size change taken in combat is refused, and lands on the next open
- frame: the popup opens at the profile's master scale
- frame: a scale change re-scales a popup that is already open
- frame: a scale hand-edited past the clamp is drawn at the nearest legal value
- frame: a scale change taken in combat is refused, and lands on the next open
- frame: the popup opens at the profile's master alpha
- frame: an alpha change lands DURING combat, unlike a size or scale change
- frame: locking the popup stops the title bar starting a drag
- frame: Reset position re-anchors the popup and forgets the saved point
- frame: Reset position in combat is refused, but still forgets the saved point
- frame: visibility 'never' refuses every path to the screen
- frame: visibility 'inCombat' BUILDS out of combat but only SHOWS in it
- frame: visibility 'outOfCombat' is the mirror of it
- frame: an unrecognized visibility value fails OPEN, not closed
- frame: switching visibility to 'never' hides a popup that is already open
- frame: both combat-transition events are registered, and to one handler
- frame: entering combat does NOT attempt a hide the client would refuse
- frame: 'never' set during combat is honored the moment the lockdown lifts
- frame: Close pressed in combat is remembered, not fired into a refusal
- frame: a deferred Close outranks a gate that would still permit the popup
- frame: a combat edge brings back a popup the gate had hidden
- frame: Close in combat takes the popup off screen at once
- frame: the real Hide lands when the lockdown lifts, and the alpha comes back with it
- frame: the alpha restored is the player's own, not a hardcoded 1
- frame: 'out of combat' takes the popup off screen the moment combat starts
- frame: and it opens again by itself when combat ends
- frame: a popup the PLAYER closed does not come back when combat starts
- frame: a popup closed with ESC does not come back either
- frame: Escape in combat never calls the popup's protected Hide, and soft-hides it
- frame: Escape out of combat really hides the popup, and the next Escape opens the menu
- frame: Escape in combat is a player dismissal -- regen lands the real Hide, and nothing reopens it
- frame: Escape in combat clears a gate flag left over from a re-show
- frame: the proxy is shown exactly while the popup is on screen
- frame: leaving combat does not reopen a popup the player closed mid-fight either
- frame: a combat transition never opens a popup with nothing to show
- frame: PLAYER_REGEN_DISABLED is answered from the event, not from a lockdown flag that has not flipped
- frame: a combat transition with no popup built is a no-op, not an error

### test_frame_secure.lua (7)

- frame: reopening a soft-hidden popup in combat with no capture never Hides the secure button
- frame: a deferred no-capture configure is replayed, not dropped
- frame: a gate-declined reopen in combat leaves a soft-hidden popup at alpha 0, and the launcher still closes it
- frame: an alpha write while soft-hidden does not reveal the popup
- frame: a real show after the soft hide restores the master alpha
- frame: a stand-down in combat drops a queued first show and a queued teleport configure
- frame: reconfiguring the teleport button reuses the same three script handlers

### test_panel.lua (54)

- panel: OnEnable registers the parent category and the General subcategory
- panel: the parent category is added to the AddOns list
- panel: Register is idempotent — a second call registers nothing more
- panel: a registration taken in combat is parked and lands at PLAYER_REGEN_ENABLED, with no second host call
- panel: a login taken in combat is parked and lands at combat end, with no second registration
- panel: registration validates the schema
- panel: both panels start hidden
- panel: registration creates no AceGUI widgets
- panel: OnShow itself builds nothing; the deferred hop does
- panel: the build is one-shot across repeated shows
- panel: two OnShows before the hop runs still build only once
- panel: the Defaults button is built lazily, on the General page only
- panel: clicking Defaults raises the confirmation popup rather than resetting
- panel: confirming the popup restores defaults
- panel: the reset dialog is not registered before it is needed (taint)
- panel: every schema row renders a widget, on its own tab
- panel: the strip draws one tab per schema group, in declaration order
- panel: bool rows render checkboxes, number rows sliders, enum rows dropdowns
- panel: widgets open showing the current profile value
- panel: the slider inherits its bounds and step from the schema row
- panel: a tabbed page draws its group names as TABS, never as headings
- panel: a mixed tab draws its SUBGROUPS as headings (options-ui-§7)
- panel: no subgroup heading repeats its own tab's name
- panel: paired rows get half width, solo rows go full width
- panel: the Chat group renders its Test action button
- panel: the Master controls tab closes with the reset button PAIR
- panel: Reset all settings raises the confirmation, it does not reset on the click
- panel: Reset position drops the stored point and re-anchors
- panel: the Test button runs the same path as /wg test notify
- panel: a throwing button onClick is caught, not propagated
- panel: the Debug console renders as an ordinary Master controls checkbox
- panel: ticking Debug console shows the window without touching db.profile
- panel: unticking Debug console hides the window
- panel: opening the console while General is OPEN moves the checkbox
- panel: re-opening General re-syncs the Debug console checkbox
- panel: ticking a checkbox writes through to db.profile
- panel: a checkbox coerces its value to a real boolean
- panel: releasing the slider writes through to db.profile
- panel: the slider snaps its committed value to the schema step
- panel: unticking Enable fires the master-switch onChange
- panel: rendering registers one refresher per rendered widget
- panel: a re-render REPLACES the refresher list rather than growing it
- panel: a /wg set re-syncs the open widget
- panel: RestoreAllDefaults re-syncs every open widget once
- panel: a throwing refresher does not abort the remaining ones
- panel: the scroll container is patched to always show its scrollbar
- panel: the patch is one-shot per widget
- panel: releasing the widget restores AceGUI's stock behavior
- panel: the landing page lists one row per slash command
- panel: the landing page shows the TOC Notes line
- panel: the landing page renders the Slash Commands heading and the logo
- panel: the landing logo path is built from the folder this copy loaded from
- panel: the landing page adds logo, notes, heading and command rows in that order
- panel: a dirty landing page re-renders in place instead of stacking a second copy

### test_testmode.lua (23)

- testmode: bare /wg test toggles test mode, and the checkbox follows
- testmode: /wg test on|off sets it, and repeating either changes nothing
- testmode: /wg test in combat is refused with one line and leaves it off
- testmode: /wg test with an unknown word prints usage and changes nothing
- testmode: the COMMANDS row describes the mode and the notify sub-word
- testmode: the Test mode row is composed right after the Debug console, on its own line
- testmode: the row's tooltip is this addon's, not the composer's generic one
- testmode: it is session-only and never reaches db.profile
- testmode: ticking the box shows the popup with placeholder content, pendingInfo untouched
- testmode: with no capture at all, it still shows the placeholder and leaves pendingInfo nil
- testmode: it shows the popup whatever General visibility and Open Automatically say
- testmode: unticking hides the popup and puts the real capture back
- testmode: the popup's Close button ends test mode and unticks the box
- testmode: ESC ends test mode and unticks the box
- testmode: the lock is honored while it is up
- testmode: a start in combat from the checkbox is refused by the library's lock, box unticked
- testmode: combat starting ends it, says so once, and unticks the box
- testmode: combat with test mode off prints nothing about it
- testmode: Reset all settings ends it
- testmode: /wg test notify is the one-shot notify + popup flow, and ends test mode
- testmode: /wg show ends it and shows the real capture
- testmode: the join popup does NOT end it; the capture waits for the chat link
- testmode: the sample capture is a fresh table each time

### test_launcher.lua (29)

- launcher: it registers at login, and the broker object IS the minimap button's
- launcher: the object is a launcher, named for the FOLDER, wearing this addon's logo
- launcher: the label is the BRAND NAME in plain text (launcher-§1)
- launcher: the label is NOT wired to the TOC Title
- launcher: the name is the FOLDER this copy loaded from, not a hand-typed literal
- launcher: Register is idempotent -- a second call builds no second button
- launcher: the icon file exists and is an uncompressed 32-bit TGA
- launcher: the TOC's IconTexture is the same file the object wears
- launcher: LEFT-click toggles the group popup, through the addon's own seam
- launcher: a LEFT-click dismissal ends test mode, as the Close button does
- launcher: a disabled left-click prints the dispatcher's line and does not toggle
- launcher: RIGHT-click opens the settings panel
- launcher: the tooltip reads title, status, lock, test mode, then the two click hints
- launcher: Locked and Test mode are read on every hover, from the rows' own stores
- launcher: while disabled the tooltip still draws, and the left hint points at /wg enable
- launcher: the tooltip's version is the TOC's, not the in-code constant
- launcher: the left-click label is localized, and there is no host tooltip hook
- launcher: the Minimap button row is stored, global, and LibDBIcon's OWN hide key
- launcher: the row's get/set invert, and the button follows immediately
- launcher: the row's CLI path reads in its own sense
- launcher: a legacy store with hide = true reads not-shown, and nothing moves
- launcher: a button the player hid survives Reset all settings (options-ui-§12)
- launcher: a button the player hid survives the General page's Defaults button
- launcher: a button the player hid survives the Master controls reset button
- launcher: LibDBIcon's own writes into the table are not disturbed
- launcher: an install with neither broker library loads, and says so once
- launcher: with no LibDBIcon the broker plugin still registers
- launcher: the row still stores with no broker library at all
- launcher: with LibKa0s absent the seam answers honestly and the store still moves

### test_lifecycle.lua (46)

- lifecycle: the addon exposes no public global (WG-01)
- lifecycle: NS IS the addon object (AceAddon mixes into the namespace)
- lifecycle: earlier files' fields survive NewAddon
- lifecycle: the shared chat prefix is the cyan [WG] tag
- lifecycle: NS.Print, WhatGroup._print and NS.Util.print are one seam
- lifecycle: debug state is session-only and starts off
- lifecycle: OnInitialize builds the db from the schema defaults
- lifecycle: OnInitialize registers both slash verbs
- lifecycle: OnEnable registers the two capture events
- lifecycle: no events are registered before OnEnable
- lifecycle: OnEnable seeds wasInGroup from the current roster state
- lifecycle: the ApplyToGroup hook installs at file load
- lifecycle: the ApplyToGroup hook routes into the capture pipeline
- chat link: the details link is Blizzard's addon link type, addon:WhatGroup:show
- chat link: a click through SetItemRef opens the popup and never reaches the ItemRef fallthrough
- chat link: a shift-click opens the popup and never reaches HandleModifiedItemClick
- chat link: a stale link prints the hint, opens nothing and never reaches the fallthrough
- chat link: another addon's addon: link is not ours
- chat link: an item link goes to the ItemRef tooltip, not to us
- chat link: the SetItemRef callback registers at file load, exactly once
- lifecycle: disable drops the SetItemRef callback and enable restores exactly one
- chat link: degraded (no EventRegistry) falls back to the WhatGroup: link and the post-hook
- chat link: degraded (no LinkTypes.AddOn) falls back to the WhatGroup: link and the post-hook
- chat link: the degraded post-hook ignores links that aren't ours
- chat link: the degraded post-hook ignores a non-string link argument
- lifecycle: joining a group with a capture waiting fires the notify
- lifecycle: a roster tick while already grouped is not a transition
- lifecycle: leaving the group wipes the capture
- lifecycle: leaving the group cancels an in-flight notify
- lifecycle: rejoining after a leave fires a fresh notify
- lifecycle: the retail ordering (ROSTER before inviteaccepted) still notifies
- lifecycle: InitSummary reflects live runtime state
- lifecycle: InitSummary is safe before the db exists
- lifecycle: /wg config opens the parent settings category
- lifecycle: /wg config is refused during combat (options-ui-§2)
- lifecycle: a login taken in combat registers the panel at combat end
- lifecycle: /wg test notify injects a synthetic capture and runs the full flow
- lifecycle: /wg test notify refuses while the master switch is off
- lifecycle: the panel Test button previews while the addon is disabled
- lifecycle: /wg test notify fires immediately, without the notify delay
- lifecycle: /wg show opens the popup when a capture exists
- lifecycle: /wg show with no capture prints a hint and opens nothing
- lifecycle: /wg reset <path> resets one setting, with no confirmation
- lifecycle: a bare /wg reset explains the change rather than resetting or erroring
- lifecycle: /wg resetall asks for confirmation rather than resetting outright
- lifecycle: /wg resetall and the Defaults button share one OnAccept body

### test_debuglog.lua (49)

- debuglog: FONT_MONO points at the library payload's JetBrains Mono TTF
- debuglog: the console renders in the vendored TTF when the client can fetch it
- debuglog: a TTF the client cannot fetch falls back to a Blizzard font (debug-logging-§2)
- debuglog: FormatPlain wraps the tag in brackets, single-space separators
- debuglog: FormatPlain tolerates a nil tag
- debuglog: FormatColored colors timestamp + tag; pipe and content default
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
- debuglog: debug-logging-§11 scrollbar + line-counter sync is a safe no-op under the mock
- debuglog: settings change logs one [Set] line at the write seam (debug-logging-§10)
- debuglog: RestoreAllDefaults logs one [Set] reset profile line counting the rows it changed (debug-logging-§10)
- debuglog: RestoreAllDefaults on a pristine profile counts 0 rows (debug-logging-§10)
- debuglog: a profile reset from outside the helper is logged once, without a count (debug-logging-§10)
- debuglog: the library's page reset is one [Set] line counting the rows it changed (debug-logging-§10)
- debuglog: an all-default page reset logs 0 rows, not a line per row (debug-logging-§10)
- debuglog: the bulk bracket adds no line when the act reset the profile (debug-logging-§10)
- debuglog: a nested bracket logs once, at the outermost close, with the summed tally (debug-logging-§10)
- debuglog: a nested bracket that reset the profile silences the outer line (debug-logging-§10)
- debuglog: a bracket that closes on an error still logs its tally and unmutes (debug-logging-§10)
- debuglog: a write that raises inside a bracket is not counted (debug-logging-§10)
- debuglog: a profile reset that raises logs one marked line and re-raises (debug-logging-§10)
- debuglog: a profile reset that raises leaves no count for a later reset (debug-logging-§10)
- debuglog: a profile reset inside an open bracket silences the bracket (debug-logging-§10)
- debuglog: a profile copy logs one [Set] copied line naming the source (debug-logging-§10)
- debuglog: InitSummary leads with the debug-logging-§5 identity fields, then runtime state
- debuglog: enable ack is color-coded green/red matching the header (debug-logging-§5)
- debuglog: pin — a vanished search result logs the [Capture] nil line
- debuglog: pin — an apply logs the [Apply] captured line
- debuglog: pin — every application status logs the [LFG] appID/status line
- debuglog: pin — an accepted invite with a capture logs the [Invite] line naming it
- debuglog: pin — an accepted invite with no capture logs the [Invite] no-capture line
- debuglog: pin — a roster transition logs the [Roster] line
- debuglog: pin — the details link logs the [ChatLink] click line
- debuglog: pin — an accepted invite with nothing pending logs the [Notify] skip line
- debuglog: pin — a scheduled join notify logs the [Notify] scheduling line
- debuglog: pin — a wipe with a reason and something in flight logs the [Capture] wiped line
- debuglog: pin — /wg test notify logs the [Test] injection line
- debuglog: pin — showing a capture logs the [Frame] popup-shown and teleport lines
- debuglog: pin — showing with no capture logs the [Frame] fallback and nil teleport lines
- debuglog: pin — a show the visibility gate withholds logs the [Frame] not-shown line
- debuglog: pin — unticking test mode logs the [Test] off line with its reason

### test_docmap.lua (1)

- docmap: every Tier 2 row agrees with what docs/ holds

### test_lintconfig.lua (6)

- lintconfig: .luacheckrc sets no top-level ignore
- lintconfig: .luacheckrc switches no warning class off wholesale
- lintconfig: every files[...] ignore is narrowed to a file or a name
- lint: exclude_files carries the template's frozen stores
- lint: read_globals grants no removed or unread global
- lintconfig: no source file carries a bare inline luacheck ignore

### test_doc_structure.lua (8)

- docs/ARCHITECTURE.md carries the ten sections documentation-§3 names
- every mandated hub section that has a topic doc has spilled into it
- every anchor pointing into docs/ARCHITECTURE.md resolves to a heading
- the player-facing history has the ONE home documentation-§1 allows, and no second
- README.md's top-level sections are the ones documentation-§1 names, in its order
- the README's settings table is page-granular, not per-tab
- every settings tab the README sends a player to exists in the schema
- docs/smoke-tests.md carries a non-English-client section

### test_register.lua (1)

- every evidence id the register cites is assigned by its bundle in docs/audits/ or docs/reviews/

### test_disabled.lua (18)

- disabled 1: enabled, the addon holds a NON-EMPTY registration set
- disabled 3: the registration set is EMPTY, by count and by name
- disabled 3: the write seam is the route — the checkbox and the verb reach the same latch
- disabled: no raw frame registration exists at any point, in combat or out
- disabled 4: no timer, ticker or OnUpdate survives, and none is armed afterwards
- disabled 5: every frame shown while enabled is hidden, and the show ladder answers no
- disabled 6: firing every event it used to watch writes nothing, says nothing, shows nothing
- disabled 7: every reserved verb answers normally, and the bare /wg opens the panel
- disabled 7: each FEATURE verb answers exactly one refusal line and reaches no write seam
- disabled 8: left-click is refused with no write and no frame; right-click opens the panel
- disabled 9: re-enabling restores the registration set exactly
- disabled 9: a setting changed WHILE DISABLED is what the rebuild reflects
- disabled 10: releasing the perf hold does NOT resurrect an addon `disabled` still holds down
- disabled 10: the other order — disabled first, perf released last
- disabled 10: the latch persists nothing
- disabled: the chat command, the panel, the db callbacks and the launcher all survive
- disabled: a profile switch that flips `enabled` is re-evaluated, both ways
- disabled: a stand-down in combat holds the protected Hide pending, and one event with it

### test_vendor_sync.lua (3)

- libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
- tests/_kit is the test kit that shipped with that release
- the automated-test runner is recorded executable (100755)

### test_eol.lua (2)

- eol: every tracked file carries the terminator .gitattributes declares for it
- eol: .gitattributes is line-endings-§5's canonical body for this repo kind

### test_prose.lua (15)

- prose: no authored file carries a British spelling from localization-§5's published list
- prose: the gate carries localization-§5's two lists whole, and nothing of its own
- prose self-test: the carve-out suppresses the named generated folder, and only it
- prose self-test: a path the carve-out does not name is not covered by one that looks like it
- prose self-test: a carve-out that is not a set of path strings is a failure, not a silence
- prose self-test: a TOC's file lines are read as paths, and its directives and comments are not
- prose self-test: a .pkgmeta's ignore block is read, and the keys around it are not
- prose self-test: an ignore entry covers a path exactly, by folder, and by wildcard
- prose self-test: the carve-out admits a generated dump and refuses a file the TOC loads
- prose self-test: a waiver-file exclusion meets the same two refusals as the carve-out
- prose self-test: each list is refused on the matching rule its own scan uses
- prose self-test: the scan and the refusals read the added exclusions through one reader
- prose self-test: a narrowing is refused by what it suppresses, not by how it is written
- prose self-test: the disclosure names what each entry suppressed, and says when it is bounded
- prose self-test: a malformed waived is a failure, not a silence

### test_layout_cap.lua (13)

- layoutcap: every authored file over the 1500-line cap is named in the census
- layoutcap: no census row outlives the breach it records
- layoutcap: every over-cap census row carries one of layout-§1's three terminal states
- layoutcap: the census and the exempt set agree about which paths were exempted
- layoutcap: an empty census is written as a result rather than left standing empty
- layoutcap self-test: the parser reads the census nested under the register, and stops there
- layoutcap self-test: a census outside its register, or at the wrong level, is not read
- layoutcap self-test: an over-cap file missing from the census is reported, and an exempt one is not
- layoutcap self-test: a census row that outlives its breach is reported
- layoutcap self-test: an over-cap row that names no terminal state is reported
- layoutcap self-test: the census and the exempt set are held to naming the same paths
- layoutcap self-test: a census that states nothing is told apart from one that states none
- layoutcap self-test: the exempt set takes folders as well as paths

## Totals

| Suite | Cases |
|-------|------:|
| test_harness.lua | 17 |
| test_libka0s.lua | 54 |
| test_surface_parity.lua | 9 |
| test_mediasetup.lua | 11 |
| test_envsetup.lua | 8 |
| test_util.lua | 31 |
| test_compat.lua | 42 |
| test_database.lua | 11 |
| test_settings.lua | 56 |
| test_slash.lua | 59 |
| test_labels.lua | 34 |
| test_capture.lua | 35 |
| test_notify.lua | 48 |
| test_frame.lua | 90 |
| test_frame_secure.lua | 7 |
| test_panel.lua | 54 |
| test_testmode.lua | 23 |
| test_launcher.lua | 29 |
| test_lifecycle.lua | 46 |
| test_debuglog.lua | 49 |
| test_docmap.lua | 1 |
| test_lintconfig.lua | 6 |
| test_doc_structure.lua | 8 |
| test_register.lua | 1 |
| test_disabled.lua | 18 |
| test_vendor_sync.lua | 3 |
| test_eol.lua | 2 |
| test_prose.lua | 15 |
| test_layout_cap.lua | 13 |
| **Total** | **780** |
