# Ka0s WhatGroup — Proposed Changes (HLD + LLD), 2026-08-03

**Standard resolved:** Ka0s WoW Addon Standard **v2.17.1 (2026-08-03)**, fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md`
and verified byte-identical to the local `master` checkout used to read the linked section files.
The standards cross-check below was **performed**, not skipped.

**Scope rule observed:** no change in this document targets a path under `libs/` or `tests/_kit/`.
The vendored LibKa0s copy and the vendored test kit are byte-identical to their source repo, and
no upstream defect was identified in this review — so there is **no upstream change-set section**
below. If one is ever added, it belongs in its own section and its own milestone, never folded into
a task that edits this addon's files.

---

## HLD — themes

### T-1. Make "the capture you are shown is the capture you joined" an invariant, not a coincidence

**Covers:** F-001, F-006, F-009.

The capture pipeline's session state (`captureQueue`, `pendingApplications`, `pendingInfo`,
`notifiedFor`) is well factored and well commented, but its lifetime is enforced by four separate
call sites agreeing with each other. The combat-deferred popup breaks that agreement by writing
`pendingInfo` back after a wipe, and the LFG status handler never reclaims applications that die
without a join. The theme adds one cheap piece of shared truth — a **wipe generation counter** —
and lets the deferral consult it, instead of adding a fifth site that has to remember the rules.

*Alternatives considered.* (a) Simply not restoring `pendingInfo` after the deferral — rejected:
it regresses the deliberate, tested behavior at `tests/test_frame.lua:317`, which exists so a popup
requested mid-combat still shows the group the user asked about. (b) Comparing table identity of
the captured `pending` against a "last wiped" reference — rejected: identity says *which* table, not
*whether the state was invalidated*, and it gets subtle the moment `pendingInfo` is replaced rather
than wiped. A generation integer answers exactly the question asked.

*Trade-offs.* One more field on the addon table and one more line in `WipeCapture`. In exchange the
rule ("a wipe invalidates anything in flight, including deferred UI work") becomes stateable in one
sentence and testable in one assertion.

### T-2. Put the last stray version-variant API call back behind Compat

**Covers:** F-003.

compat-§1 is unambiguous: `core/Compat.lua` is the **only** file that calls deprecated APIs.
`GetAddOnMetadata` is the one that got away, and it got away twice, with two different fallbacks.
The change is additive — one shim, two call sites — and it also removes a hardcoded `"WhatGroup"`
folder-name literal where `addonName` was already in scope.

*Alternatives considered.* Leaving it, on the grounds that `C_AddOns.GetAddOnMetadata` is stable —
rejected: the rule is about *routing*, not about how likely this particular API is to move, and the
two call sites already disagree about the fallback, which is the drift the rule prevents.

### T-3. Make the migration seam fail loudly rather than silently succeed

**Covers:** F-004.

The seam is right; the unconditional stamp at the end of it is the one line that can destroy the
evidence a migration is owed. Removing it costs nothing today and converts a future silent
data-shape bug into a visible one.

*Alternatives considered.* Keeping the stamp and adding an assertion that the loop covered every
version — rejected as more machinery for the same guarantee the loop already gives when it is the
only writer.

### T-4. Stop the small duplications that the LibKa0s adoption otherwise eliminated

**Covers:** F-002, F-008, F-010, F-011, F-012.

The addon just finished replacing seven-way-drifting per-addon code with one library. These are the
leftovers of the same shape at addon scale: a label formatter written twice, locale keys for
strings nobody reads, a lint surface that no longer matches the code, an alias nobody consumes, and
two chat lines that do not sound like the other forty. Each is small; together they are the
difference between a codebase that documents itself accurately and one that nearly does.

*Alternatives considered.* Routing the panel's `"General"` / `"Slash Commands"` literals through
`L` instead of deleting the keys — deliberately left as an either/or in the LLD, because
`locales/enUS.lua:19-25` already declares a narrower scope on purpose; what must not survive is the
*disagreement* between the declared scope and the table's contents.

### T-5. Harden the two lazily-built UI paths against their own failure modes

**Covers:** F-005, F-013.

Both are "works today, fails invisibly if a precondition shifts": geometry arithmetic on
possibly-unresolved rects, and a one-shot latch that outlives the attempt it was guarding.

### T-6. Close the release-readiness gap before the next tag

**Covers:** F-007.

Not a code change — a release-hygiene change that versioning-git and documentation-§1 already
require, and that the breaking `/wg reset` re-specification makes urgent rather than routine.

---

## LLD — change-set

### C-01 — Wipe generation gates the deferred popup's `pendingInfo` restore

**Findings:** F-001. **Files:** `core/WhatGroup.lua`, `modules/Frame.lua`, `tests/test_frame.lua`.

`core/WhatGroup.lua` — `WipeCapture` (around line 526) gains a generation bump, and the counter is
seeded next to the other session state (around line 74):

```lua
-- before (WipeCapture, core/WhatGroup.lua:526)
function WhatGroup:WipeCapture(reason)
    local hadInFlight = ...
    self.pendingInfo = nil
    notifiedFor      = nil

-- after
function WhatGroup:WipeCapture(reason)
    local hadInFlight = ...
    self.pendingInfo = nil
    notifiedFor      = nil
    -- Anything holding a capture across a suspension (the combat-deferred popup) compares this
    -- against the value it saw; a wipe invalidates every in-flight reference at once.
    self.captureGen  = (self.captureGen or 0) + 1
```

`modules/Frame.lua` — the deferral closure records the generation and consults it:

```lua
-- before (modules/Frame.lua:316 / :326)
local pending = WhatGroup.pendingInfo
...
WhatGroup.pendingInfo = WhatGroup.pendingInfo or pending

-- after
local pending    = WhatGroup.pendingInfo
local pendingGen = WhatGroup.captureGen or 0
...
-- Restore ONLY if nothing invalidated the capture while we waited. A group-leave during the
-- wait wipes it deliberately, and resurrecting it there would let the NEXT join announce the
-- PREVIOUS group (notifiedFor is cleared by the same wipe).
if not WhatGroup.pendingInfo and (WhatGroup.captureGen or 0) == pendingGen then
    WhatGroup.pendingInfo = pending
end
```

**Risk:** low. The only behavior change is on the wiped path, where the popup now renders its
existing "No data" fallbacks (`modules/Frame.lua:266-274`) instead of stale data.
**Tests:** keep `tests/test_frame.lua:317` green (no wipe → restore still happens); add its mirror
(wipe during the wait → no restore, and a subsequent in-group roster transition fires no notify).

**Standards conformance:** capture state is host-owned session state; no library seam, no
SavedVariables, no new deviation. The "no `_G`" and namespace rules (architecture-§1) are respected
— the counter hangs on the addon object, like `pendingInfo` and `notifyTimer` already do.

### C-02 — Reclaim dead applications on terminal LFG statuses

**Findings:** F-006. **Files:** `core/WhatGroup.lua`, `tests/test_capture.lua`.

In `LFG_LIST_APPLICATION_STATUS_UPDATED` (`core/WhatGroup.lua:563`), add a terminal-status branch
after `invited`:

```lua
elseif newStatus == "declined" or newStatus == "declined_full"
    or newStatus == "declined_delisted" or newStatus == "cancelled"
    or newStatus == "timedout" or newStatus == "failed" then
    -- The application died without a join; drop its capture so a long session of declines
    -- doesn't accumulate one table per attempt.
    pendingApplications[appID] = nil
```

Keep the `invited` no-op branch and its `.luacheckrc` `542` exemption.
**Risk:** low — these statuses are currently unhandled, so nothing depends on the entry surviving.
Should Blizzard use a status token not in the list, behavior is exactly as today.
**Standards conformance:** no rule engaged beyond general hygiene; nothing here is a documented
anti-pattern in either direction.

### C-03 — Seed `shortName` in the capture initializer

**Findings:** F-009. **Files:** `core/WhatGroup.lua`.
Add `shortName = "",` to the `captured` table literal at `core/WhatGroup.lua:202-226`, beside
`activityName`/`fullName`. No consumer changes; the two `x ~= "" and x or y` guards keep working and
now do so by construction.
**Risk:** none. **Standards conformance:** n/a.

### C-04 — Popup uses the shared playstyle label function

**Findings:** F-002. **Files:** `modules/Frame.lua`.

```lua
-- before (modules/Frame.lua:292-295)
local playStyle = info.playstyleString
if not playStyle or playStyle == "" then
    playStyle = Labels.PLAYSTYLE[info.generalPlaystyle] or ""
end

-- after
local playStyle = Labels.GetPlaystyleLabel(info)
```

The em-dash placeholder line below it (`modules/Frame.lua:296`) is presentation and stays local.
**Risk:** low — `GetPlaystyleLabel` (`core/WhatGroup.lua:360-365`) is behaviorally identical for
every input the popup passes; `tests/test_labels.lua` and `tests/test_frame.lua:150-190` both cover
the result.
**Standards conformance:** this is the direction anti-patterns #47's rationale points (one
formatter, one place). Explicitly **rejected** alternative: hoisting `GetPlaystyleLabel` into
`libs/LibKa0s/` — it is this addon's LFG-specific label rule, and no local edit under `libs/` is
permissible in any case.

### C-05 — `Compat.GetAddOnMetadata`

**Findings:** F-003. **Files:** `core/Compat.lua`, `settings/Panel.lua`, `settings/Slash.lua`,
`.luacheckrc` (see C-09), `docs/file-index.md`.

`core/Compat.lua` gains, beside the other shims:

```lua
--- Addon metadata field (Version / Notes / …). C_AddOns.* on modern clients, the removed
--- global as the last resort. Returns nil when neither is present, so callers keep their
--- own default.
function Compat.GetAddOnMetadata(name, field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        local v = C_AddOns.GetAddOnMetadata(name, field)
        if v then return v end
    end
    if GetAddOnMetadata then return GetAddOnMetadata(name, field) end
    return nil
end
```

`settings/Panel.lua:117-118` becomes `local notes = NS.Compat.GetAddOnMetadata(addonName, "Notes")
or ""`. `settings/Slash.lua:27-32`'s `version()` becomes
`local ver = NS.Compat.GetAddOnMetadata(addonName, "Version")`, keeping the
`if not ver or ver == "" then ver = WhatGroup.VERSION end` fallback (slash-commands-§3's
TOC-metadata-first order is preserved).
**Risk:** low; both call sites are already nil-tolerant. `core/Compat.lua` loads before both
(`WhatGroup.toc`, `# Core` before `# Settings`).
**Standards conformance:** compat-§1 (Compat is the only caller of deprecated APIs),
anti-patterns #10. Rejected alternative: a local helper in each settings file — that is the current
state and the deviation itself.

### C-06 — Migration runner stops stamping unconditionally

**Findings:** F-004. **Files:** `core/Database.lua`, `tests/test_database.lua`.

```lua
-- before (core/Database.lua:29-43)
local from = g.schemaVersion
-- while g.schemaVersion < NS.SCHEMA_VERSION do ... end
g.schemaVersion = NS.SCHEMA_VERSION

-- after
local from = g.schemaVersion
if from > NS.SCHEMA_VERSION then
    -- Written by a NEWER build. Leave it alone: stamping it down would hide the mismatch
    -- and re-run migrations on the next upgrade.
    if NS.Debug then NS.Debug("Migrate", "db is newer (v" .. tostring(from) .. ") — left as-is") end
    return
end
while g.schemaVersion < NS.SCHEMA_VERSION do
    -- if g.schemaVersion == 1 then  -- migrate 1 -> 2 here
    -- end
    g.schemaVersion = g.schemaVersion + 1
end
```

**Risk:** low today (`SCHEMA_VERSION == 1`, so the loop never runs and the behavior is identical).
The live loop is now the only writer, so bumping `NS.SCHEMA_VERSION` without adding a step advances
the version one step at a time with no data change — the same end state as today, but reached by the
code path a real migration will use, and reviewable.
**Standards conformance:** savedvariables' `schemaVersion` + migration-runner requirement and
versioning-git-§4 (increment `schemaVersion` when a migration is required) are both preserved; the
seam itself is untouched.

### C-07 — Nil-safe teleport-button anchor

**Findings:** F-005. **Files:** `modules/Frame.lua`.

```lua
-- before (modules/Frame.lua:139-140)
local btnX = (lblPort:GetLeft() - f:GetLeft()) + LABEL_WIDTH + 6
local btnY = lblPort:GetTop()  - f:GetTop()

-- after
-- Derived from the rendered label when the rect is resolvable; otherwise from the same layout
-- constants that produced it, so a frame whose rect isn't computed yet can't take the build down.
local ROW_INDEX  = 5                      -- Teleport is the 6th row (0-based) under the header
local FALLBACK_X = 14 + LABEL_WIDTH + 6   -- content inset + label column + gutter
local FALLBACK_Y = -38 - 4 + (ROW_INDEX * yGap)
local lx, fx = lblPort:GetLeft(), f:GetLeft()
local ly, fy = lblPort:GetTop(),  f:GetTop()
local btnX = (lx and fx) and ((lx - fx) + LABEL_WIDTH + 6) or FALLBACK_X
local btnY = (ly and fy) and (ly - fy) or FALLBACK_Y
```

**Risk:** low; the fallback is only reached where the current code would raise. The magic-number
comment at `modules/Frame.lua:135-138` should be updated to say the fallback exists and why (it is
no longer true that there are "no magic offsets" — say so honestly rather than leaving a comment
that now lies, which is its own finding class).
**Standards conformance:** none engaged; this is ordinary defensive coding on a non-secure frame's
geometry. The secure button's `SetPoint` keeps its implicit-parent form, which the secure-frame
system requires.

### C-08 — Defaults-button latch clears in the callback

**Findings:** F-013. **Files:** `settings/OptionsSetup.lua`.

```lua
-- after (settings/OptionsSetup.lua:168-173)
panel.__wgDefaultsScheduled = true
C_Timer.After(0, function()
    panel.__wgDefaultsScheduled = nil   -- the attempt is over; panel.defaultsBtn is the real guard
    baseEnsureDefaultsBtn(panel)
end)
```

**Risk:** none — the library's own `panel.defaultsBtn` check (mirrored on the first line of the
wrapper) still prevents a second button.
**Standards conformance:** this is the **wrapper on the instance** the file already documents
(`settings/OptionsSetup.lua:143-163`), not a re-implementation. Explicitly **rejected**: editing
`libs/LibKa0s/Options.lua` to defer natively — no local edit under `libs/` (anti-patterns #45, #47);
if a second host ever needs the hop, it becomes an **additive descriptor field** pushed upstream,
which the file itself already names as the trigger.

### C-09 — Housekeeping: locale keys, alias, lint globals, chat voice

**Findings:** F-008, F-010, F-011, F-012. **Files:** `locales/enUS.lua`, `core/WhatGroup.lua`,
`tests/test_capture.lua`, `.luacheckrc`, `settings/Panel.lua`, `settings/Slash.lua`.

1. `locales/enUS.lua` — remove the orphaned `"Ka0s WhatGroup"`, `"General"`, `"Slash Commands"`,
   `"Defaults"` and `"cannot open settings during combat …"` rows, and update the scope paragraph at
   `locales/enUS.lua:19-25` to state that settings-panel chrome is library- or literal-sourced. (If
   the team prefers the other direction, route `settings/Panel.lua:198/:217/:135` through `L`
   instead and keep the four keys — but **not** the combat one, which is the library's string.)
2. `core/WhatGroup.lua:227` — drop `captured.playstyle`; drop the matching assertion at
   `tests/test_capture.lua:172`, and the field at `core/WhatGroup.lua:655` in `RunTest`.
3. `.luacheckrc` — remove `CastSpellByID`, `SettingsPanel`, `date` from `read_globals`; add nothing
   (C-05 uses `GetAddOnMetadata`, already declared).
4. `settings/Panel.lua:249` — `pout("cannot register the settings panel during combat")`;
   `settings/Slash.lua:215-218` — either delete the unreachable branch or make it print
   `CLI_MISSING`-shaped text naming the library.

**Risk:** none functionally; item 1 touches a translator-facing surface only, item 2 touches a field
with no production reader (verified by grep).
**Standards conformance:** localization-§1/§2 — removing a key that nothing references is safe
precisely because no call site holds it; the metatable fallback (`locales/enUS.lua:29-31`) covers
any literal that later wants routing. **Not** proposed: adding a host copy of the library's
`COMBAT_REFUSED` string (options-ui-§8, anti-patterns #47).

### C-10 — Release hygiene for the next tag

**Findings:** F-007. **Files:** `WhatGroup.toc`, `core/WhatGroup.lua`, `README.md`.

Not a behavior change. In one commit, at release time: bump `WhatGroup.toc`'s `## Version:` and
`core/WhatGroup.lua:35`'s `WhatGroup.VERSION` together; rewrite `## What's new in <X.Y.Z>` to the
current release's highlights (the LibKa0s adoption is largely invisible to users — the
user-visible items are the `/wg reset` re-specification, the new `/wg resetall`, and the shared
window edge); add the matching `## Version History` row. The `/wg reset` change is
backwards-incompatible on a user-facing command surface — pick the semver level deliberately and
record the reasoning in the commit message.
**Standards conformance:** versioning-git-§1/§2 (semver; bump TOC **and** code constants **and**
README Version History in the same change), documentation-§1 item 5 and anti-patterns #40 (a
`## What's new` that names an old version is a violation). The `Interface:` line is a separate axis
(toc-file-§3) and is **not** part of this change unless a retail patch has landed — I could not
verify the current live retail interface number from here, so leave `120007` alone until
`wow-addon:bump-interface` says otherwise.

---

## Change → finding matrix

| Change | Findings | Files | Parallel-safe with |
|---|---|---|---|
| C-01 | F-001 | `core/WhatGroup.lua`, `modules/Frame.lua`, `tests/test_frame.lua` | C-05, C-06, C-08 |
| C-02 | F-006 | `core/WhatGroup.lua`, `tests/test_capture.lua` | C-05, C-06, C-08 |
| C-03 | F-009 | `core/WhatGroup.lua` | C-05, C-06, C-08 |
| C-04 | F-002 | `modules/Frame.lua` | C-05, C-06, C-08 |
| C-05 | F-003 | `core/Compat.lua`, `settings/Panel.lua`, `settings/Slash.lua`, `docs/file-index.md` | C-01…C-04, C-06 |
| C-06 | F-004 | `core/Database.lua`, `tests/test_database.lua` | everything |
| C-07 | F-005 | `modules/Frame.lua` | C-05, C-06, C-08 |
| C-08 | F-013 | `settings/OptionsSetup.lua` | everything |
| C-09 | F-008, F-010, F-011, F-012 | `locales/enUS.lua`, `core/WhatGroup.lua`, `.luacheckrc`, `settings/Panel.lua`, `settings/Slash.lua`, `tests/test_capture.lua` | C-06, C-08 |
| C-10 | F-007 | `WhatGroup.toc`, `core/WhatGroup.lua`, `README.md` | — (run last) |
</content>
