# WhatGroup — proposed changes (2026-10-07)

This design follows `01_FINDINGS.md`, finding for finding. It was checked against Ka0s WoW Addon
Standard **v2.76.1 (2026-10-07)**: 19 sections were fetched from GitHub, and 8 were read from the
sibling checkout `../WowAddonStandards` at `f472389` (same version header). `01_FINDINGS.md` lists which
sections came from where. **No change below targets `libs/` or `tests/_kit/`.**

## HLD — themes

### T1. Ask whether a cooldown value is secret before comparing it (F-001, F-002)

`NS.Compat` gains the library's **guard arm**, `Compat.IsSecret`:
- When LibKa0s-Compat is present, `Compat.IsSecret` is the library's own `IsSecret`.
- When the library is absent, it falls back to the three-line `issecretvalue` body. `anti-patterns`
  #47 sanctions this stub as a deliberate duplication, as long as it is commented at the host and
  cites the major's API document. `LibKa0s/Compat.lua` (its *"GUARDS … the stub MUST re-implement the
  three-line body"* note) requires it.

`GetSpellCooldownRemaining` asks `IsSecret` before it compares anything.

When either value is secret, the reader returns `0, false`. The second return is a new `readable`
flag, so the existing "never negative, never nil" contract still holds.

- The ticker skips a tick it cannot read. Its timer stays armed, and the note keeps its last text
  until combat ends and the next tick can read the value again.
- The chat Teleport row prints no cooldown tag when the value is unreadable. The line is printed once
  and never refreshed, so leaving the tag off is the honest answer.

The suite gains a secret value in `tests/wow_mock.lua`, so the combat path is measured (F-002).

**Alternatives rejected:**
- **`pcall` around the compare.** This hides every other client defect too. The library's rule 6
  ("No pcall. A client defect raises where it happens") applies to the same reader.
- **Reading `isActive` and dropping the remaining time in combat.** `isActive` includes the GCD, so a
  learned teleport would read "on cooldown" for 1.5 s after any cast. That re-creates the flicker the
  GCD floor exists to stop (`core/Compat.lua:93-97`).
- **Passing the secret pair to `FormatDuration`.** That function does arithmetic, which is exactly
  what the standard forbids.

**Trade-off:** in combat, the countdown note stops updating and the chat row loses its tag. Both are
honest, and neither raises an error.

### T2. One-shot test output gets a slot of its own (F-003, F-004)

`RunTest` stops writing the real `pendingInfo`. It renders the sample through the same record test mode
uses (`previewInfo`, read through `shownInfo()`), and it hands `ShowNotification` the sample as an
argument. The player's real capture is never touched.

While the addon is stood down, the panel's **Test** button prints the chat preview and does **not**
build the popup or record a withheld show. The popup cannot be shown while stood down
(`visibilityAllows` answers no at the source), so a deferred show would only come back later,
uninvited.

**Alternatives rejected:**
- **Restoring the real capture after the test.** The popup stays open showing the sample with no end
  point, so there is no moment to restore it.
- **Refusing the Test button while disabled.** `docs/slash-dispatch.md:89` and
  `tests/test_lifecycle.lua:485` make it *"the surviving preview route"*. Its chat half still works,
  and `slash-commands-§7` makes refusing a feature only a SHOULD.

### T3. Correct three statements that no longer describe the code (F-005, F-006, F-007)

These are a tooltip, a perf write-up and a comment. No behavior changes.

## Upstream change-set

| ID | Owning repo · file | Change | Version | Then in WhatGroup |
|---|---|---|---|---|
| U-1 (F-008) | WowAddonStandards · `standards/standards/events-frames-taint.md` §8, *named APIs* list | Add `C_Spell.GetSpellCooldown`'s `startTime` / `duration` / `modRate`, and `C_Spell.GetSpellCooldownDuration`'s remaining time, to the trigger set. Cite `LibKa0s-Compat-1.0`'s contract | Standard patch bump (v2.76.x → next) | Nothing beyond C-001. Re-run the standards audit after the bump to confirm C-001 satisfies the MUST |
| U-2 (F-009) | LibKa0s · `testkit/` (new additive helper, for example `testkit/mock_secrets.lua`, wired from `mock_base.lua`) | Additive secret simulator: `secret(v)` raises on compare, arithmetic, concat and boolean test; `issecretvalue` answers for it. Fold in MultiMeters' `tests/mock_secrets.lua` as the reference | Bump `Kit.VERSION` (37 → 38) and the LibKa0s minor tag | Re-vendor `tests/_kit/` whole as its own commit, then retire C-002's local helper in favor of the kit's |

## LLD — per change

### C-001 — Secret-safe cooldown reader (F-001)

**`core/Compat.lua`**:
- Add the `IsSecret` guard arm after `local CompatLib = …`.
- Rewrite `GetSpellCooldownRemaining`.
- Update the header comment's list of what this file publishes.

```lua
-- THE GUARD ARM (LibKa0s docs/api/Compat/version-1-docs.md, "Degradation"; anti-patterns #47):
-- deliberate, documented duplication of the library's one-rung body. "The library is absent" is not
-- "the client has no secrets system", so the stub must still answer true for a secret.
Compat.IsSecret = CompatLib and CompatLib.IsSecret or function(v)
    if not issecretvalue then return false end
    return issecretvalue(v) and true or false
end

--- Seconds left, and whether the client let us read them. `0, true` ready; `n, true` cooling;
--- `0, false` unreadable (secret in combat) -- the caller keeps what it last showed.
function Compat.GetSpellCooldownRemaining(spellID)
    local start, duration, enabled = spellCooldown(spellID)
    if not enabled then return 0, true end
    if Compat.IsSecret(start) or Compat.IsSecret(duration) then return 0, false end
    if start <= 0 or duration <= GCD_SECONDS then return 0, true end
    local remaining = (start + duration) - GetTime()
    return remaining > 0 and remaining or 0, true
end
```

The `issecretvalue` global is read bare and at call time, which is rule 1 of the library's file.

**`modules/Frame.lua:587-596` (ticker body):**

```lua
local left, readable = NS.Compat.GetSpellCooldownRemaining(spellID)
if not readable then return end          -- secret in combat: keep the last text, stay armed
if left > 0 then return renderNote(left) end
```

`resolveTeleportState` (`:639`) runs only out of combat, because `ConfigureTeleportButton` defers in
combat first. It still takes the first return only. A defensive comment there notes why.

**`core/WhatGroup.lua:826-830` (`teleportValue`):**

Before: `elseif NS.Compat.GetSpellCooldownRemaining(spellID) > 0 then`. After:

```lua
local tag
if not known then
    tag = NS.L["(not learned)"]
else
    local left, readable = NS.Compat.GetSpellCooldownRemaining(spellID)
    if readable and left > 0 then tag = NS.L["(on cooldown)"] end   -- unreadable: no tag
end
```

The `(on cooldown)` tag is left off when the value is unreadable.

**Docs:** in `docs/compat-layer.md` (the Cooldown row and the §"GetSpellCooldownRemaining"
paragraphs), add the second return and the `IsSecret` guard arm. `docs/module-map.md`'s
`core/Compat.lua` row lists `IsSecret`.

- **Standards:** `events-frames-taint-§8` (no compare on a protected value). The guard stub's shape
  follows `anti-patterns` #47 and the library's own stub rule. The rejected `pcall` would break the
  library's rule 6.
- **Risk:** low. Out of combat, behavior is byte-identical, because `IsSecret` answers false for plain
  numbers.
- **Perf:** `cooldownTick` gains two `IsSecret` calls per tick. Today's `tests/perf.lua` records
  `cooldownTick` at **2.0 api/iter, 240.4 bytes/iter**. The scenario's `apiPerIter == 2` assert at
  `tests/perf.lua:215` counts frame API calls, not Lua functions, so it should hold. Confirm with the
  next offline run, and update `docs/performance.md` in the same change if any figure moves.

### C-002 — Make the combat path measurable (F-002)

**`tests/wow_mock.lua`**:
- Add `mock.secret(v)`, a table with `__lt`, `__le`, `__add`, `__sub` and `__concat` metamethods that
  each raise `"attempt to … a secret value"`.
- Add `mock.issecretvalue(v)`, exposed as the bare global through the loader's environment, which
  answers true for those tables.

This is a local helper until U-2 ships. A comment at the helper names U-2 as its retirement trigger.

**New cases:**
- `tests/test_compat.lua`: *"compat: a secret cooldown reads as unreadable, never compared"*.
  It asserts `0, false` and no raise. `-- red under: removing the IsSecret line in GetSpellCooldownRemaining`.
- `tests/test_frame.lua`: *"frame: a ticker in combat over a secret cooldown keeps its text and stays
  armed"*. It asserts no raise, an unchanged note text, `mock.__fireTimers() == 1` on the next tick,
  and a correct countdown again once the value is plain.
- `tests/test_notify.lua`: *"notify: a secret cooldown prints the Teleport row without a tag and the
  link row still prints"*.

**Test movement:** +3 cases, 914 → **917 passed**. Regenerate `docs/test-cases.md` with `--list` and
update the README `Tests-…_passing` badge **in the same commit** (`testing-§7`).

### C-003 — `RunTest` previews through its own record (F-003, F-004)

**`modules/Frame.lua`**: add a seam `NS.FramePreviewOnce()`. Out of combat and while not stood down,
it sets `previewInfo = WhatGroup:SampleInfo()` without setting `NS.State.testMode`, then calls
`preparePopup()` and `showPopup()`. Closing the popup (`dismissPopup`) clears that `previewInfo`.

A one-shot preview is not test mode. It ends on Close, ESC or a real show, and it is not left up for
placing. A flag of its own, `oneShot`, tells `endTestMode` and `dismissPopup` to clear it without
printing the "test mode off" line.

**`core/WhatGroup.lua`, `RunTest` and `ShowNotification`:**

```lua
function WhatGroup:ShowNotification(info)          -- nil = the real capture, as today
    info = info or self.pendingInfo
    ...
end

function WhatGroup:RunTest()
    local sample = self:SampleInfo()
    NS.Debug("Test", 'synthetic notify "%s" (pendingInfo untouched)', sample.title)
    self:ShowNotification(sample)
    if NS.IsStoodDown() then return end            -- no popup to show, so build nothing and owe nothing
    if NS.FramePreviewOnce then NS.FramePreviewOnce() end
end
```

`/wg test notify` keeps its current surface. The sample now never lands in `pendingInfo`.

**Tests:**
- Rewrite `tests/test_lifecycle.lua:485-493` as *"the panel Test button prints the chat preview while
  disabled, builds no popup, and re-enabling shows nothing"*. It asserts on the frame registry
  (`mock.frames["WhatGroupFrame"] == nil`), on `pendingInfo == nil`, and that the popup is not shown
  after `Set("enabled", true)`. `-- red under: today's RunTest`.
- Add *"testmode: /wg test notify leaves a real capture in place"* to `tests/test_testmode.lua`.
- Update the existing `pendingInfo.mapID == 2805` assertions in `tests/test_lifecycle.lua:449-457` and
  `tests/test_testmode.lua:384-390` to assert on the popup's shown fields instead. This changes the
  behavior they pin. It is not done to make them pass.

**Test movement:** +1 case (one rewritten, one added), so **918 passed** after C-002. Regenerate
`docs/test-cases.md` and the badge in the same commit.

**Docs:** `docs/slash-dispatch.md:89`, `docs/scope.md:14` and `docs/frame.md:63` currently say *"`/wg
test notify` … set `pendingInfo`"*. `docs/module-map.md` describes `RunTest`.

- **Standards:** `preview-mode` (*"MUST clear the preview and return to live data"*, and *"SHOULD feed
  the preview through the same render path"*, which `shownInfo()` already is). `slash-commands-§7`
  allows a disabled addon to keep panel controls that print. Building nothing while stood down keeps
  `anti-patterns` #85 (no work while disabled) intact.
- **Risk:** medium. The test-mode state machine in `Frame.lua` is the most fragile code in the addon.
  Smoke tests TEST-1 to TEST-4 cover it.

### C-004 — Height tooltip and stale comment (F-005)

- `settings/Schema.lua:282` becomes
  `"Height of the group-info popup, in pixels. The default 280 is the shipped size."`.
- `modules/Frame.lua:58-61`: say the height default is 280, the 260 it replaced plus the Role row.

### C-005 — Re-measure `docs/performance.md` (F-006)

Replace the `combatGateFlipping` and `showFrameRepeat` rows, and the *Re-measured* date, with a fresh
`tests/perf.lua` run taken **after** C-001 and C-003 land, because both touch the measured paths. Bisect
the 18 → 19 API-count move before writing its explanation; do not assume the cause.

### C-006 — Correct the `reloadProfile` comment (F-007)

`core/WhatGroup.lua:246` becomes: *"Idempotent and normally a no-op here: the stamp is account-wide. A
profile-scoped step walks every stored profile itself (core/Database.lua)."* The call stays, because
it is harmless and keeps the seam's single entry point.

## Standards conformance summary

| Change | Rules that shaped it | New deviation? |
|---|---|---|
| C-001 | `events-frames-taint-§8`, `anti-patterns` #47 (guard-arm stub) | No |
| C-002 | `testing-§12` (falsifiable, with a `red under:` comment), `testing-§7` (inventory and badge move with the count) | No. The local mock helper is test-only and retires at U-2 |
| C-003 | `preview-mode`, `slash-commands-§7`, `anti-patterns` #85 | No |
| C-004 to C-006 | `documentation` | No |

**Expected movement at next release (for the release's regeneration to confirm, not to run now):** no
watch-list entry should cross a threshold. `LFG_LIST_APPLICATION_STATUS_UPDATED` (CCN 13) and
`ShowFrame` (CCN 13) are untouched. `RunTest` gains one branch.
