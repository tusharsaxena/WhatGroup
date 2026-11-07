# WoW API quirks

The Blizzard-side gotchas WhatGroup specifically depends on, and the conventions that follow from them. If a future patch breaks the addon, this file is the first place to look. It has two parts. The first is the collection's client-quirks catalog, vendored whole from the Ka0s WoW Addon Standard and replaced wholesale on every re-vendor: never edit inside the markers. The second, below the end marker, is WhatGroup's own.

<!-- BEGIN VENDORED: quirks catalog v2.103.1 (source: WowAddonStandards) -->
> Part of the **[Ka0s WoW Addon Standard](https://github.com/tusharsaxena/WowAddonStandards/blob/master/standards/STANDARDS.md)** — the split standard. This section is vendored whole into every addon's `docs/midnight-quirks.md` (§1), so its links are absolute. Cross-references use the `filename-§N` form (see the index's section map).

## Client quirks

The client behaviors the collection paid for more than once. Each entry here was discovered
**independently in two or more Ka0s repositories**, written up in each, and promoted by a harvest so the
next addon reads it instead of rediscovering it. A behavior one repo found stays in that repo's
`docs/midnight-quirks.md` until a second repo meets it.

*Why this section exists.* By 2026-11-06 eleven addons kept a private `docs/midnight-quirks.md`, 2,073
lines and about 133 entries between them, and about 81 of those entries were 21 behaviors written up
independently two to eight times. Nine of the eleven opened with their own restatement of the 12.0 secret
rules. Three write-ups contradicted this standard, and one contradiction was this standard's own error
(events-frames-taint-§2, *The combat-start edge*). A catalog was proposed and deferred twice, on
2026-08-25 and 2026-09-22, because an inventory rots; the build stamp per entry (§1) is the answer to that
objection (WowAddonStandards `harvests/2026-11-06/02_FINDINGS.md`, F3-01; every write-up quoted in
`harvests/2026-11-06/03_EVIDENCE.md`, Part A).

### 1. How an entry is written, and how it expires (MUST)

Every entry **MUST** carry:

- **The behavior**, stated as what the client does, not as advice.
- **Measured:** the client build or date it was observed on, where any write-up recorded one. An entry with
  no measurement says *not measured*; that is a weaker entry, not a missing field.
- **Cost:** what happened to an addon that did not know it.
- **Client:** the client it was measured on, `Retail` or `Forever` (clients-§1). An entry that names none is a Retail entry, which is every entry written before v2.103.0; a Forever behavior is written with `Forever` and its build, and it is not assumed to hold on Retail.
- **Do:** the workaround, as a rule an addon can follow.
- **Source:** the deepest write-up — the repo and document that probed furthest — and the harvest that
  promoted it. Every version is quoted in that harvest's `03_EVIDENCE.md`.

**Expiry.** An entry describes a client, and clients move. When the retail interface number moves past the
newest *Measured* stamp in an entry and an addon observes otherwise, the entry is corrected in a standard
release — not worked around in the addon. An entry nobody can reproduce moves to §6 as an open probe rather
than being deleted, because the behavior may only have moved.

**What an addon does with this section (MUST): carry it as a vendored block.** This section is the one
part of the standard an addon carries a **copy** of, because it is reference data about the game client
that a working addon needs offline, next to the code that works around it — not a rule, which is only ever
pointed at. Every addon's `docs/midnight-quirks.md` (documentation-§3) is two parts: the vendored block,
opened by a `BEGIN VENDORED` HTML comment naming the catalog's version and source and closed by an
`END VENDORED` HTML comment, each spelled exactly as `/dev-copilot:wow-revendor-standards` writes it; then
the addon's own section. The markers are described here rather than shown, because this text travels
inside them: a literal marker in the vendored copy would give the file a second end marker for the next
re-vendor to cut at.

```markdown
[the BEGIN VENDORED comment, stamped quirks catalog v<X.Y.Z>]
… this section, whole …
[the END VENDORED comment]

## <Addon>-specific quirks

… the addon's own quirks: one no second repo has met, its per-event costs, its own probe tables …
```

- The block is **copied whole and replaced wholesale** by `/dev-copilot:wow-revendor-standards`, stamped with
  the standard version it came from, under the same discipline as `libs/LibKa0s/` (anti-pattern #45): never
  a subset, **never edited inside the markers**. A local edit inside them is reverted by the next revendor,
  and the behavior it fixed comes back with no cause in the addon's history; a correction belongs in the
  addon's own section, where the next harvest finds it.
- The addon's own section **MUST NOT** restate a behavior the block carries. When a harvest promotes an
  entry, the revendor prunes the addon's copy: the upstream entry is the deeper write-up, and two live
  copies of one finding is the shape that drifted three times into contradiction.
- An addon with no quirks of its own still carries the block, with an empty own section.

**Contested behaviors are not rules.** Where two repos recorded opposite behavior and nobody has probed
the difference, the entry goes in §6 with both sides and the probe that would settle it.

Behaviors this standard already states elsewhere are not repeated here: the unknown-event raise
(events-frames-taint-§1), `Settings.OpenToCategory`'s numeric ID and collapsed parent (options-ui-§2),
the protected category switch in combat (options-ui-§2, anti-pattern #88), a secret through `tostring` and
`..` (events-frames-taint-§8), lockdown at `PLAYER_REGEN_DISABLED` (events-frames-taint-§2), the spec
readers' move to `C_SpecializationInfo` (compat, `LibKa0s-Compat-1.0`) and `SendChatMessage`'s move to
`C_ChatInfo` (compat).

### 2. Secret values

**A secret boolean cannot be tested at all.** `if`, `not`, `==` and `and`/`or` on a secret boolean raise
("attempt to compare … (a secret boolean value)"); the value is unusable in Lua, not merely unprintable.
`DurationObject`'s `HasExpired`, `HasStarted`, `IsActive` and `IsZero` come back secret in combat, and an
engine button's `IsShown` has answered a secret boolean out of combat. *Measured:* 12.0.7 (probe table);
12.1 (`IsShown`). *Cost:* a raise on every refresh tick of the path that tests it. *Do:* check
`issecretvalue` before any test; route a secret boolean to a C-side consumer
(`C_CurveUtil.EvaluateColorValueFromBoolean`, `SetAlphaFromBoolean`), or treat it as the cautious answer
(a secret lockdown reads as locked, a secret restriction as active, a secret claim as no claim). Two repos
disagree on whether to gate before the C-side call; that disagreement is recorded in `LibKa0s`
`docs/api/Compat` and is not ruled here. *Source:* KickCD `docs/midnight-quirks.md`, "Secret booleans are
unusable"; seven repos (harvest 2026-11-06, Q6).

**A secret cannot be a table key.** Indexing or assigning with a secret key raises "attempted to perform
indexed assignment on a table that cannot be indexed with secret keys". `UnitGUID` on a follower-dungeon
pet (`party3pet`) answers a secret string. *Cost:* a raise on every refresh tick for a roster keyed by
GUID. *Do:* guard a key with `IsSafeKey` (`LibKa0s-Compat-1.0`) or `issecretvalue` before keying; a
secret GUID is never a handle. *Source:* MultiMeters `docs/midnight-quirks.md`, the follower-dungeon pet
GUID; seven repos (Q7).

**A secret never reaches SavedVariables, and one that does is written as `nil`.** A value captured as
secret stays secret after combat ends, and the client writes a secret to SavedVariables as `nil` — or,
where it was a key, loses the entry. *Measured:* a reload probe, 2026-10-25. *Cost:* silent data loss on
the next reload. *Do:* store a plain value or nothing; never store a captured secret to read later.
*Source:* DpsRace `docs/known-limitations.md`, the reload probe; three repos (Q21).

**A frame handed a secret has secret geometry, and so does everything anchored to it.** After
`StatusBar:SetValue(secret)` (or `SetAlphaFromBoolean`, or anchoring to an aura engine container) the
frame `HasSecretValues`: its width, points and frame level read secret, out of combat too, and the
taint runs down the anchor chain to every frame anchored to it; a tooltip showing hidden information has
secret geometry. A secret size's `type` is `"number"`, so a type check lets it through, and
`BackdropTemplate`'s own arithmetic on a secret size raises. *Cost:* a raise inside Blizzard code, or a
layout computed from a secret. *Do:* compute layout from configuration and never read geometry back from a
frame that was handed a value; keep a record of the alpha you set rather than calling `GetAlpha()`; read a
frame level under a restricted anchor through a secret-safe guard (frame-layering). *Source:* AuraMaster
`docs/midnight-quirks.md`, the aura engine container entries (measured and dated); six repos and
`LibKa0s` `docs/api/Widgets` (Q8).

**A restricted spell's cooldown: branch on `isActive`, paint with the duration object.** In a restricted
state `C_Spell.GetSpellCooldown`'s timings are secret while `isEnabled` and `isActive` stay plain
(documented NeverSecret). `GetSpellCooldownDuration` answers a **zeroed** object, not `nil`, when there is
no cooldown, and a fresh object per call. *Cost:* raw `SetCooldown` with a secret start or duration raises;
a nil check passes the zeroed object. *Do:* decide from `isActive`; paint with
`Cooldown:SetCooldownFromDurationObject`, which accepts the object from tainted code. *Source:* KickCD
`docs/midnight-quirks.md`, the cooldown probe table; four repos (Q9).

**`notInterruptible` is secret, and the interruptibility events make it plain.** The cast info's
`notInterruptible` is secret; `UNIT_SPELLCAST_INTERRUPTIBLE` / `_NOT_INTERRUPTIBLE` deliver it plain.
`CastingBarFrameTemplate`'s built-in `OnUpdate` compares `GetTime()` with a secret `maxValue` and raises
when the bar shows another unit. *Do:* split the gate — the color path takes the secret C-side, the logic
path takes the event's plain value; do not inherit `CastingBarFrameTemplate` for a unit other than the
player. *Source:* KickCD `docs/midnight-quirks.md`, "split the gate in two"; two repos (Q13).

**`InChatMessagingLockdown` can answer a secret.** *Do:* read it through a guard and treat a secret as
locked. *Source:* DropWatcher and QuickComms `core/Compat.lua` (byte-identical), DpsRace; three repos (Q27).

### 3. Events

**A valid event can register without complaint and never fire.** `GUILDBANKFRAME_OPENED` registers and
never fires (*Measured:* 12.0.7); `UNIT_SPELLCAST_SUCCEEDED` is suppressed for protected interrupts;
`UNIT_HEALTH` and `UNIT_NAME_UPDATE` never fire for compound tokens such as `party1target`;
`GET_ITEM_INFO_RECEIVED` does not fire for an item already cached. This is the inverse of the
unknown-event raise (events-frames-taint-§1) and it is silent: nothing errors. *Cost:* a feature that
never runs, with nothing in the log. *Do:* confirm a new event fires in game before building on it, and
prefer an edge with a second source (a frame's `OnShow`, a gated timer) where the event is known to be
silent. *Source:* BankLedger `docs/midnight-quirks.md`, `GUILDBANKFRAME_OPENED`; four repos (Q20).

**Client state can lag its own event, or change with no event at all.** `IsMounted()` has flipped by the
time `PLAYER_MOUNT_DISPLAY_CHANGED` arrives while `C_PlayerInfo.GetGlidingInfo`'s `canGlide` sometimes has
not; after `INSPECT_READY` some slots still answer an item id with no link; switching bank tabs fires no
event, and the live warband tab has taken over a second to catch up; chat lockdown clears with no event.
*Cost:* a read at the edge answers the old state, and the display stays wrong until the next unrelated
event. *Do:* answer at the edge **and once more after a short settle** (a fraction of a second, a bounded
retry), never a poll. *Source:* MultiMeters `docs/midnight-quirks.md`, "some client state lags its own
event"; six repos (Q19).

**An empowered cast fires `UNIT_SPELLCAST_EMPOWER_*`, not the channel events.** `UnitChannelInfo`
reports it, but `UNIT_SPELLCAST_CHANNEL_START` / `_STOP` do not fire for it, and its release fires
`UNIT_SPELLCAST_SUCCEEDED` with the same cast GUID. *Do:* register the `EMPOWER_*` events wherever channels
are tracked. *Source:* KickCD `docs/midnight-quirks.md`, empowered casts; three repos (Q12).

**`ADDON_RESTRICTION_STATE_CHANGED` fires *before* enforcement.** The `Activating` state arrives before the
restriction begins, and access is still permitted during that dispatch; a dungeon restriction type has
gone active on entry and not cleared. Read the restriction type by its `Enum.AddOnRestrictionType` member
name — a member can be missing on some builds. *Measured:* 12.1.0, 2026-09-18. *Do:* treat `Activating`
as the last moment to read, not as the start of the restriction. The payload's second argument is
contested (§6). *Source:* AuraMaster `docs/midnight-quirks.md`, the restriction types; six repos (Q10).

### 4. Combat and secure frames

**Blizzard's aura buttons are forbidden to addon code, and `IsForbidden()` can say otherwise.** In
combat every call on a Blizzard aura button's objects raises "Attempt to access forbidden object from code
tainted by an AddOn"; in an instance (seen in Mythic+) the same buttons answer `IsForbidden()` `false` and
still refuse every read, `GetChildren` included. *Do:* never read Blizzard aura buttons; where a frame
must be inspected, `pcall` the read and treat a failure as forbidden. *Source:* PartyFrameEnhanced
`docs/midnight-quirks.md`, forbidden aura buttons; three repos (Q14).

**Escape runs a protected `Hide()` in combat.** A secure or protected frame listed in `UISpecialFrames` is
hidden by `CloseSpecialWindows`, which is a protected action in combat. *Do:* list a non-secure proxy in
`UISpecialFrames` and hide the protected frame from it out of combat, or keep protected frames out of the
list. *Source:* WhatGroup `docs/midnight-quirks.md`, the escape proxy; two repos (Q24).

### 5. Item, tooltip, enum and realm data

**Item data is nil until cached, and the load event has holes.** `GetItemInfo` answers nothing for an
uncached item; `GET_ITEM_INFO_RECEIVED` does not fire on an addon's first scan for an item the client
already holds; an uncached item's tooltip is not empty but a legible `RETRIEVING_ITEM_INFO` line; a failed
load drops its wait and nothing asks again. *Cost:* a blank or wrong row that never repairs. *Do:* load
through `LibKa0s-Item-1.0`'s cache-then-callback path (library-stack-§7), treat `RETRIEVING_ITEM_INFO` as
not-yet-loaded, and re-ask after a failed load. *Source:* ConsumableMaster `docs/midnight-quirks.md`, the
first-scan hole; seven repos (Q15).

**`C_TooltipInfo` returns raw templates.** Tooltip lines can carry the unexpanded plural grammar
`|4singular:plural;` (*Measured:* 12.1.5, "for the next 3 |4hour:hrs; 49 min") and a no-break space that
Lua's `%s` does not match. *Cost:* a parser that knew only the expanded words read no duration and called a
tradeable drop expired. *Do:* expand `|4…;` before matching, and match the no-break space explicitly.
*Source:* DropWatcher `docs/midnight-quirks.md`, the trade window; two repos (Q16).

**Tooltip line text can be secret** under an addon restriction, including through `TooltipDataProcessor`.
*Do:* guard each line before matching. *Source:* DropWatcher `docs/midnight-quirks.md`; two repos (Q17).

**Blizzard renumbers enums; resolve a member by name, never by number.** One build's
`Enum.TooltipDataLineType` and bank-tab values are not the next build's, and a member can be absent on a
build. *Cost:* a numeric guess for a member the build does not expose landed on an unrelated bank
container. *Do:* read `Enum.X.Member`, and handle its absence; localization-§4 already forbids the string
spelling. *Source:* DropWatcher `docs/midnight-quirks.md`, the research's enum values; five repos (Q18).

**`GetNormalizedRealmName` is nil early in login.** *Cost:* a stored `Name-` key with no realm. *Do:* never
build a `Name-Realm` key before the realm is known; defer, or fall back to `GetRealmName` with its spaces
and hyphens removed. *Source:* DropWatcher `docs/midnight-quirks.md`, realm names; four repos (Q25).

**A template-less `FontString` with no font raises on `SetText`.** "Font not set" from a `FontString`
created without a template or `SetFontObject` takes the addon down at load; a mock that does not enforce it
passes every test. *Do:* give every bare `FontString` a font object before its first `SetText`; the kit's
mock enforces it. *Source:* MultiMeters `tests/mock_frame.lua`, the font-not-set guard; three repos and
`LibKa0s` (Q22).

### 6. Open probes — contested behaviors (not rules)

Each needs an in-game probe, recorded with the build, before any section of this standard changes.

- **WoW Forever behaviors (none recorded yet).** The catalog was written on Retail. The Forever client (build 70790) has a missing-API surface, `SetDesaturation` among it, that LibKa0s tracks in LibKa0s#44, and no quirk entry yet meets this section's two-repo bar for it. Record a Forever behavior in the repo that meets it, with the build, and promote it by a harvest like any other.

- **`string.format` on a secret.** events-frames-taint-§8 says it raises, with three repos; two say it
  works, one with a mid-combat observation. The likely difference is the specifier (`%s` against `%d` and
  `%.1f`) or that the result is itself a secret string. Probe each specifier, in combat, on a damage-meter
  value and a `UnitHealth` value. Until then §8's rule stands.
- **`ADDON_RESTRICTION_STATE_CHANGED`'s second argument.** One repo documents an
  `Enum.AddOnRestrictionState` value; three (one measured) record a boolean as well. Handle both shapes.
  The 2026-09-22 harvest called this settled, and it is not.
- **`SetAllPoints(parent)` on a secure button at load.** One repo records "Cannot anchor protected frames
  to regions" and uses the implicit-parent form; another anchors its secure rows with `SetAllPoints(row)`
  at birth and treats it as working, with its in-game smoke check still owed.
<!-- END VENDORED -->

## WhatGroup-specific quirks

## Hook discipline

| Target | Hook type | Why |
|---|---|---|
| `C_LFGList.ApplyToGroup` | direct `hooksecurefunc` (no AceHook) | Observation only. We need the `searchResultID` so we can call `C_LFGList.GetSearchResultInfo` for the same ID. AceHook's `SecureHook` would also work *behaviorally*, but its per-invocation bookkeeping closure leaves a taint trace that the GameMenu's Logout-button secure chain detects later, firing `ADDON_ACTION_FORBIDDEN ... 'callback()'` attributed to the addon. Direct `hooksecurefunc` registers the callback inside Blizzard's secure post-hook list with no addon-side wrapper, so no taint. |
| Chat-link clicks (`SetItemRef`) | **not hooked**: an `EventRegistry` `"SetItemRef"` callback, on Blizzard's `addon` link type | Blizzard's `SetItemRef` (`Blizzard_UIPanels_Game/Mainline/ItemRef.lua:6-27` at 12.1.0) asks `LinkUtil.ProcessLink` first. A link type with no registered handler is `Unhandled` and **falls through**: to `ShowUIPanel(ItemRefTooltip)` plus `ItemRefSetHyperlink(link)`, or to `HandleModifiedItemClick` on a modified click. It does not return silently, so a post-hook on an unregistered prefix runs only after that fallthrough completes. On 2026-09-12 a real join's `WhatGroup:show` link did nothing when clicked. The `addon` type (`LinkTypes.AddOn`) has a handler Blizzard registers (`Shared/ItemRefHandlersShared.lua:278-281`) that raises `EventRegistry`'s `"SetItemRef"` event and counts as Handled, so the fallthrough never runs. The link is `addon:WhatGroup:show` and the callback is registered at file load. A client without that path (`NS.Compat.AddOnLinkType()` nil) falls back to the old link plus a `hooksecurefunc` post-hook. Earlier still we used `RawHook`, which replaces the global function with a non-secure wrapper and leaves a taint trace the GameMenu's Logout-button secure chain detects later (`ADDON_ACTION_FORBIDDEN ... 'callback()'`). Neither current route replaces the global. See [data-flow.md](./data-flow.md). |

The rule:

- **`SecureHook` / `hooksecurefunc` something whose original you want to keep running.** Examples: capturing data from a Blizzard call, reacting to a player action, telemetry.
- **An addon chat link is Blizzard's `addon` link type, heard through `EventRegistry`, not a custom prefix with a `SetItemRef` hook.** Blizzard's `SetItemRef` falls through to the ItemRef tooltip for any link type without a registered handler, and that fallthrough runs before any post-hook.
- **`RawHook` only when the original genuinely has visible side-effects you must suppress.** Replacing a global function with a non-secure wrapper leaves a taint trace that can surface much later in unrelated secure chains (the canonical symptom: `ADDON_ACTION_FORBIDDEN ... 'callback()'` on the GameMenu's Logout button after the player has touched the addon during the session).
- **Never `SecureHook` something you wanted to suppress** — the original already ran by the time your hook fires.

## Settings API parent vs. subcategory

WoW 12.0's Settings API supports nested categories via:

```lua
local parent = Settings.RegisterCanvasLayoutCategory(parentPanel, "Ka0s WhatGroup")
Settings.RegisterAddOnCategory(parent)
local sub = Settings.RegisterCanvasLayoutSubcategory(parent, generalPanel, "General")
```

**Quirk: when a parent has subcategories, its own panel widgets are hidden.** The parent appears as a sidebar entry that expands to reveal subcategories — the parent's own panel content is not displayed.

Practical implication: don't put schema widgets on the parent panel. They won't render. Make the parent a thin landing page (just a title + a hint pointing at the subcategory) and put every actual setting on a subcategory.

WhatGroup follows this — see [settings-panel.md](./settings-panel.md#settingsregister) for the parent / General split.

## `Settings.OpenToCategory` requires the integer ID

```lua
local category = Settings.RegisterCanvasLayoutCategory(panel, "Ka0s WhatGroup")
Settings.OpenToCategory(category:GetID())                  -- correct
Settings.OpenToCategory("Ka0s WhatGroup > General")        -- WRONG (not a valid form)
Settings.OpenToCategory(category)                          -- WRONG (object, not ID)
```

`category:GetID()` returns the auto-assigned integer ID. **Do not overwrite `category.ID` with a string.** Doing so silently breaks the lookup and `OpenToCategory` becomes a no-op.

WhatGroup's `/wg config` goes through `Helpers.OpenOptionsPanel()` — `LibKa0s-Options-1.0`'s member since the adoption, holding the main category's own ID; `settings/Panel.lua` keeps no category handle of its own. It calls `Settings.OpenToCategory` against the **parent** and then reaches into `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` — the path the expand-arrow click handler itself uses — so the subcategory tree comes up unfolded. That whole traversal is wrapped in `pcall` because `CategoryList` / `GetCategoryEntry` / the `CategoryEntry:SetExpanded` shape are private Blizzard internals that can shift between patches; if any link goes missing the panel still opens, just without auto-unfold. The slash command also refuses to open during `InCombatLockdown()` — the Settings UI uses secure templates and opening it mid-combat can taint other addons' secure handlers.

## Lazy AceGUI panel build

Pure AceGUI containers manage their own width via `SetWidth` / `SetRelativeWidth` / `SetFullWidth`. But **AceGUI containers parented to a Blizzard Settings frame don't get a width until Blizzard sizes the panel on first show** — and even then the size doesn't propagate into AceGUI's layout pipeline automatically.

Two consequences:

1. Build the body **lazily** in the panel's `OnShow`, behind a `built` one-shot guard. If you build at registration time, the panel renders against width 0 and every relative-width widget collapses.
2. Hook `OnSizeChanged` on the AceGUI container's frame and forward the dimensions into AceGUI:

```lua
container.frame:SetScript("OnSizeChanged", function(_, w, h)
    if container.OnWidthSet  then container:OnWidthSet(w)  end
    if container.OnHeightSet then container:OnHeightSet(h) end
    if container.DoLayout    then container:DoLayout()     end
end)
```

Without this, widgets inside the AceGUI container stay at width 0 even after Blizzard sets a width on the outer panel.

WhatGroup's General subcategory uses both — see [settings-panel.md](./settings-panel.md#lazy-panel-build) for the full snippet.

## Lowercase only the slash command name

`AceConsole-3.0:RegisterChatCommand` passes the raw input (everything after the slash command name) to the handler. **Don't lowercase the whole input** — schema paths like `notify.showInstance` are camelCase and lowercasing them breaks `Helpers.FindSchema(path)`.

The pattern:

```lua
local cmd, rest = raw:match("^(%S+)%s*(.*)$")
cmd  = (cmd or ""):lower()   -- only lowercase the verb
rest = rest or ""              -- preserve case in everything else
```

See [slash-dispatch.md](./slash-dispatch.md#case-preserving-parse).

## `RawHook` short-circuit pattern (and why we avoid it for `SetItemRef`)

When you `RawHook` something to short-circuit on a prefix, the chain-through call goes through `self.hooks`:

```lua
function WhatGroup:OnSetItemRef(linkArg, text, button, ...)
    if linkArg and linkArg:match("^WhatGroup:") then
        self:ShowFrame()
        return                                       -- short-circuit
    end
    return self.hooks.SetItemRef(linkArg, text, button, ...)   -- pass through
end
```

`self.hooks.<originalName>` is AceHook's stash of the pre-hook function. Forgetting to chain through means every other addon's chat links stop working — a very obvious regression in chat scrollback. Always chain through on the fall-through branch.

**WhatGroup no longer uses this pattern for `SetItemRef`.** `RawHook` replaces the global function with a non-secure wrapper, and that replacement leaves a taint trace that the GameMenu's Logout-button secure-execute chain detects later, firing `ADDON_ACTION_FORBIDDEN ... 'callback()'` attributed to the addon. It went first to a `hooksecurefunc` post-hook, on the belief that Blizzard's `SetItemRef` no-ops on unknown link types. On 12.x it does not: it falls through to the ItemRef tooltip. Since 2026-09-12 the link is Blizzard's `addon` type, heard through `EventRegistry` (see the table above), which needs neither a hook nor a takeover. The pattern above is documented here for reference. Only reach for `RawHook` when the original genuinely has a side-effect you must suppress and Blizzard offers no registered route around it.

## AceDB `true` for shared profile

```lua
self.db = LibStub("AceDB-3.0"):New("WhatGroupDB", defaults, true)
```

The third arg `true` means "start every character on one shared `Default` profile". Every character sees the same settings until the player picks another profile on the **Profiles** page ([profiles.md](./profiles.md)). With `false` (or omitted) AceDB would start each character on a profile of its own instead; `true` keeps the account-wide default a new character has always had.

## `BuildDefaults` runs every login

```lua
local defaults = self.Settings.BuildDefaults()
self.db = LibStub("AceDB-3.0"):New("WhatGroupDB", defaults, true)
```

`BuildDefaults` walks the schema and returns a fresh nested defaults table. AceDB merges saved values over the defaults rather than replacing — so:

- **A new schema row appears with its `default` value** the first time the user logs in after the upgrade.
- **Existing keys are preserved untouched.**
- **Removed schema rows leave orphaned values in SVs.** The keys aren't surfaced in the UI / `/wg list` anymore but they sit in the saved-vars table. AceDB-3.0 has no automatic cleanup. Acceptable today; add a one-shot migration if a removal ever becomes user-visible.

## Secure buttons can't have an explicit non-secure anchor target

A `SecureActionButtonTemplate` Button (or any frame inheriting from `SecureFrameTemplate`) is "protected" the moment it's `CreateFrame`'d. Retail's secure-frame system rejects any `SetPoint` / `SetAllPoints` call on a protected frame that **explicitly names** a non-secure region as the anchor target — including the protected frame's own parent — with:

```
Action[SetPoint] failed because[Cannot anchor protected frames to regions]
```

This isn't combat-gated; it errors during initial layout. Once the load-time `SetPoint` errors, the rest of the source file aborts — anything defined after that line (including `WhatGroup:ShowFrame`) never registers, which surfaces as "attempt to call a nil value" at the next call site.

The protection check gates on the *explicit-region mention*, not on the underlying parent relationship. So the **implicit-parent form** (no `relativeTo` arg) is allowed:

```lua
-- These FAIL ("Cannot anchor protected frames to regions"):
secureBtn:SetAllPoints(parent)
secureBtn:SetPoint("LEFT", someFrame, "LEFT", x, y)

-- These WORK (no explicit relativeTo arg → resolved to parent transitively):
secureBtn:SetPoint("TOPLEFT", 0, 0)
secureBtn:SetPoint("BOTTOMRIGHT", 0, 0)
secureBtn:SetAllPoints()
```

**Workaround for popup-style usage**: parent the secure button **directly to the popup frame** (the same Frame that owns the row labels), and use the implicit-parent `SetPoint("LEFT", xOff, yOff)` form to position it. The protection check passes; visibility rides on the parent-child relationship (the popup's `Show()` / `Hide()` automatically propagate to the button); dragging the popup moves the button with it. No proxy frame, no UIParent parent, no screen-position sync, no combat handler.

## Lazy popup and secure button (GameMenu Logout taint)

**Anything you do at PLAYER_LOGIN that touches Blizzard's secure surface taints Blizzard's GameMenu callbacks.** That taint surfaces as `ADDON_ACTION_FORBIDDEN ... 'callback()'` when the player clicks the GameMenu's Logout button — even on a fresh `/reload` with no addon use. The protected operation that fails is `Logout()`, but the error is attributed to whichever addon left the taint trace. The mechanism: Blizzard's `GameMenuFrame:InitButtons()` builds the Logout / Settings / Macros button-callback closures during boot. If any addon-driven mutation of secure state has happened before that runs, the closures inherit the addon's taint and refuse to invoke `Logout()` (or any other protected button action) when the user clicks them.

In WhatGroup's case, two boot-time operations taint:

1. **Creating a `SecureActionButtonTemplate` Button** (the popup's teleport icon).
2. **`tinsert(UISpecialFrames, "WhatGroupFrame")`** — adding a frame name to UISpecialFrames so ESC closes it. (The entry is now the unprotected `WhatGroupFrameEscape` proxy's, because Escape's bare `Hide()` on the popup itself is protected in combat — [frame.md → ESC-to-close](./frame.md#esc-to-close). Deferred exactly the same way.)

The fix for both: **defer them to actual user demand.** `modules/Frame.lua`'s entire setup (popup creation, secure button creation, `UISpecialFrames` registration) is wrapped in a `buildFrame()` function called only on the first `WhatGroup:ShowFrame()`.

> **Settings registration is NOT one of these.** An earlier revision also listed `Settings.RegisterCanvasLayoutCategory` + `RegisterAddOnCategory` as a boot-taint source and deferred `Settings.Register()` to first `/wg config`. That was a misdiagnosis — a confound with the AceHook `RawHook` / `SecureHook` closures that were the actual hook-taint culprit (since removed; see the hook table above). Every other Ka0s addon (AbsorbTracker, KickCD, LootHistory, ConsumableMaster) registers its canvas Settings category at login with no taint, so WhatGroup now registers in `OnEnable` too — the panel appears in Settings → AddOns at login. The category still registers at login with no user action; in combat (a `/reload` taken mid-pull) the library parks it and lands it at combat end, without a second `/wg config`. The panel's widget bodies still build lazily on first `OnShow` (Panel.lua), so no AceGUI frame is created inside a secure-execute chain.

At PLAYER_LOGIN the addon now adds nothing to Blizzard's secure surface, GameMenu's `InitButtons` runs in a clean context during boot, and Logout works correctly. Any taint the addon does generate later (on first popup show) is contained to a session where the player has actively used the addon — and even then, GameMenu's button closures were already built with the clean context they captured at boot.

The regression tests for this are INSTALL-3 and INSTALL-4 in [smoke-tests.md → Install](./smoke-tests.md#install), the GameMenu Logout check on a clean boot and after each surface. Run it after any change that touches hooks, the popup, the Settings panel, or the StaticPopup table.

See `modules/Frame.lua`'s `buildFrame()`, `settings/Panel.lua`'s `Settings.Register()`, and `core/WhatGroup.lua`'s `runConfig()`.

WhatGroup uses this pattern for the popup's teleport icon — see `modules/Frame.lua` and [frame.md → Teleport button](./frame.md#teleport-button).

> **Earlier iterations got this wrong.** A previous attempt parented the secure button to `UIParent` and synced its screen position from a non-secure proxy frame (`teleportSlot`) via a `syncTeleportButton` function, plus a `PLAYER_REGEN_ENABLED` retry, plus a deferred-Hide on the popup's `OnHide`. That pattern *worked* in the sense that the icon appeared in the right place — but the addon-driven `Show()` / `Hide()` / `SetPoint(... UIParent ...)` calls on a `SecureActionButtonTemplate` parented to `UIParent` accumulated taint that surfaced later as `ADDON_ACTION_FORBIDDEN ... 'callback()'` when the player clicked the GameMenu's Logout button (the Logout closure's `callback()` runs inside Blizzard's secure-execute chain at `Blizzard_GameMenu/Shared/GameMenuFrame.lua:69`, which detects the addon's prior taint of the secure system and refuses to run `Logout()`). Parenting to the popup frame directly eliminates all of those non-secure operations on the protected button — the only non-secure interaction left is `SetAttribute` calls in `ConfigureTeleportButton`, which is the standard pattern Blizzard expects.

Side note: `CastSpellByID` is also protected in retail (it fires `ADDON_ACTION_FORBIDDEN` from a non-secure `OnClick`). The macro-attribute path on a `SecureActionButtonTemplate` is the legal cast route from addon code — set `type="macro"` and `macrotext="/cast <SpellName>"`, and the click runs through Blizzard's secure action handler.

## Spell texture fallback (`134400`)

`C_Spell.GetSpellTexture(spellID)` returns `nil` for spell IDs that aren't currently loaded into the client's spell database (e.g. teleport spells the player has never trained). The texture lookup is routed through `NS.Compat.GetSpellTexture` (the shim returns `nil` when the API has nothing); the popup's `ConfigureTeleportButton` supplies the `134400` (`?` glyph fileID) fallback so the row still shows *something*:

```lua
local texID = NS.Compat.GetSpellTexture(spellID) or 134400
```

`134400` is widely used as a "dynamic / unknown spell" sentinel across Blizzard's UI. Not load-bearing — any other placeholder fileID would work — but it's the convention.

## An unknown event name raises at registration

The client raises `Attempt to register unknown event "<NAME>"` when an addon registers a name it does not know, and a patch that retires an event makes a formerly good name unknown. `registerFeatureEvents` runs first in `OnEnable`, so a bare `self:RegisterEvent` there would lose the settings category, the minimap button and the disable latch to one retired name. The four registrations go through `NS.SafeRegisterEvent` (LibKa0s-Core minor 8, bound in `core/CoreSetup.lua`) instead, and the trade is a probe before each one. `C_EventUtils.IsEventValid` is asked first when the client has it, and that answer decides without the name ever reaching AceEvent. On a client without it the library registers the name on a private frame under `pcall` and unregisters it at once, and the registration on the addon itself is `pcall`ed as well, so a retail raise on an unknown name is caught rather than propagated. A refused name is not retried and not printed: it is appended once to the session-only `NS.RejectedEvents`, and the `[Init]` line `/wg debug on` writes (`, rejected events: <names>`) is the only record of it. With the library missing, the degraded stub keeps only the `pcall` and the append.

## Pattern reference

Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD`) is the source pattern for WhatGroup's slash dispatch and schema-driven settings rendering. The shape here is a scaled-down version of `KickCD/core/KickCD.lua` (slash dispatch) and `KickCD/settings/Panel.lua` (helpers + builder). When in doubt about how to extend a system here, check how the equivalent system is shaped over there.

The differences (smaller surface area in WhatGroup):

- No `valueGate` on schema rows (rows enabling/disabling on another value).
- One schema panel, not many. WhatGroup passes `panelKey = "main"` / `"general"` to `CreatePanel` for ctx tracking, and the descriptor's `rowsForPage` hands back the whole schema regardless of key — every row belongs to the General sub-page. What splits them there is the TAB strip (`RenderTabbedSchema` partitions the page's rows by `group`), not a second page.
- `afterGroup` callbacks render non-setting actions (Test) outside the schema, but the schema rows themselves stay simpler than KickCD's (no module-specific post-render hooks).
- No vertical layout — every WhatGroup widget pairs into the two-column Flow grid.
