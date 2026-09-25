# 04 — Technical design (2026-09-23)

The remediation design for every deviation in `02_DEVIATIONS.md`: the Medium, the Lows and the Infos.
It is keyed by ID. **Upstream work comes first:** fixes in the `LibKa0s` testkit and clarifications in
`WowAddonStandards` must land before this addon changes. After that, the whole `LibKa0s` folder is
re-vendored, and only then does work in WhatGroup begin. `05_EXECUTION_PLAN.md` orders the steps.

This audit is read-only. Nothing described here has been done.

---

## §0 — Upstream (LibKa0s and WowAddonStandards)

### WG-74 — the kit's citations lose their `§` (libka0s-upstream)

- **Where:** 74 lines in `LibKa0s/testkit/`: `test_prose.lua` (35), `test_eol.lua` (25),
  `test_layout_cap.lua` (9) and `framework.lua` (5). The count comes from this repo's byte-identical
  copy (03 §F). They are case names and comments that write `localization-5`, `line-endings-5`,
  `layout-1` and `testing-12`.
- **Shape:**
  - Spell each one `localization-§5`, `line-endings-§5`, `layout-§1` and `testing-§12`.
  - If the kit deliberately keeps its sources ASCII-only, build the string at runtime from
    `"\194\167"`, the UTF-8 encoding of `§`, or record the ASCII exception in the kit's README and
    in `documentation-§6`. Choosing either option is an upstream decision.
- **Ripple:** every consumer's `docs/test-cases.md` changes on its next regeneration. Case-name changes
  also move `docs/test-cases.md` diffs in all eleven addons, so land them in one kit revision.
- **Test:** the library's own versioning and kit-sync suites. The kit revision bumps.

### WG-66, optional collection-wide half — a kit-level `EventRegistry` survey

- `testing-§1`'s fidelity rules say anything a test needs to observe is recorded. Today the
  `EventRegistry` fake lives in each consumer's `wow_mock.lua`, so every addon's stand-down suite is
  blind to `EventRegistry:RegisterCallback` survivors unless it surveys them itself.
- **Shape:** add an `EventRegistry` fake to `testkit/mock_base.lua`, with a `__registrations()`-style
  entry (`kind = "callback"`) in `mock_record.lua`. WhatGroup's own fake can then shrink to the extras
  it models (`LinkUtil`, `LinkTypes`), or be deleted in favor of the kit's.
- This is **not required** to close WG-66: the local fix in §1 closes it. It is the upstream route
  that keeps the next addon from repeating WG-64.

### WG-82, WG-56, WG-57 — standards text (standards-upstream)

- **WG-82(1):** `AUDIT.md` step 4's re-vendor check says a missing bundle is *"a High finding"*, which
  contradicts step 5. Change the line to *"is a finding (grade by impact, step 5)"*.
- **WG-82(2):** `toc-file-§3`'s "currently `120007`". Update it to `120100`, or drop the literal and
  point at `ADDONS.md`.
- **WG-82(3):** `layout-§4` says the editable `.png` "ships". Decide whether that is descriptive or
  normative. If normative, WhatGroup's `.pkgmeta:30-31` needs a row or a change.
- **WG-56:** `documentation-§3`'s Tier 1 `settings-panel.md` row names *"the `Tab | Covers` table (one
  row per settings subcategory)"*. Word it as either `Page | Covers` or per-tab rows.
- **WG-57:** clarify `architecture-§4`'s applicability. Does *"any module that registers game events"*
  include an AceAddon shell (`core/<Addon>.lua`) whose events serve a single feature module? The
  recommendation is to name "the addon object's own event handlers" explicitly.
  - If the answer is "counts": WhatGroup adopts a minimal bus (§6, option A) or records a row.
  - If the answer is "does not count": close WG-57 against the amended text.

---

## §R — Re-vendor LibKa0s whole (after §0 ships a tag)

- Copy `../LibKa0s/LibKa0s/` over `libs/LibKa0s/` and `../LibKa0s/testkit/` over `tests/_kit/`,
  **whole folder, both**. Bump `CLAUDE.md:79`'s provenance line **in the same commit**. Run
  `git update-index --chmod=+x tests/_kit/run-automated-tests.sh`.
- Write `docs/revendor/<date>-v<tag>/` (`01_DELTA.md` and `05_SUMMARY.md` at minimum).
- **WG-71** is closed in the **same bundle**, by making it consolidated. Its `01_DELTA.md` opens with
  the new tag and has a *Backlog* section naming the unrecorded span, v1.18.0 → v1.24.0 and
  v1.35.0 → v1.53.0: the 25 tags listed in 02, carried by sweeps and folded commits, with the three
  folded commit SHAs. `audit-review-history` names that as the compliant answer. **Do not back-fill a
  folder per tag.**
- Regenerate `docs/test-cases.md`. It picks up WG-74's renamed case names. Update the README `[tests]`
  badge in the same change if the count moves.
- Gate: both `diff -r`s empty against the new tag, `tests/test_vendor_sync.lua` green, the full suite
  green, and `luacheck .` 0/0.

---

## §1 — The stand-down (WG-64 root; WG-65, WG-66 dependents)

**Files:** `core/WhatGroup.lua`, `tests/test_disabled.lua`, `docs/ARCHITECTURE.md`.

1. **One registration function for the chat link.** Extract `registerLinkCallback()` from
   `core/WhatGroup.lua:108-114`:

   ```lua
   local function registerLinkCallback()
       if not ADDON_LINK_TYPE then return end          -- degraded client: the hooksecurefunc route stays
       EventRegistry:RegisterCallback("SetItemRef", function(_, linkArg)
           onDetailsLinkClick(linkArg)
       end, WhatGroup)
   end
   registerLinkCallback()                             -- file load, as today (taint reasons unchanged)
   ```

2. **Tear it down and rebuild it through the latch.**
   - In `NS.StandDown`, next to the four `UnregisterEvent` calls: `if ADDON_LINK_TYPE then
     EventRegistry:UnregisterCallback("SetItemRef", WhatGroup) end`.
   - In `NS.StandUp`, next to `registerFeatureEvents(self)`: `registerLinkCallback()`.
   - The registry keeps one callback per (event, owner), so a double stand-up replaces the callback
     rather than stacking a second one. The mock models that already.
   - The `IsStoodDown()` check in `onDetailsLinkClick` (`:100`) **stays**, because the degraded
     `hooksecurefunc` route still needs it. Reword its comment: the `EventRegistry` route no longer
     shares the carve-out. It is unregistered.

3. **Taint check, which is the one real risk.** The file-load placement exists because registering in
   `OnEnable` tainted GameMenu's Logout closures (`docs/midnight-quirks.md`). That history was about
   AceHook closures and secure frames, and a plain `EventRegistry` registration made from a checkbox
   click is expected to be clean. Still, add a smoke test to `docs/smoke-tests.md`:
   - disable, then re-enable (panel or verb);
   - `/reload`-free Logout via GameMenu;
   - click a details link.

   If the in-client check shows a taint cost, stop. Revert step 2 and file a `slash-commands-§7`
   `## Documented deviations` row naming the taint evidence, with a re-check trigger ("Blizzard
   exposes the link click without a callback registration" or "the taint is shown not to occur").
   WG-66 then **graduates**.

4. **WG-66: make the suite see it.** In `tests/test_disabled.lua`, extend `regNames` (`:76-82`):

   ```lua
   for owner in pairs(mock.EventRegistry.__callbacks("SetItemRef")) do
       out[#out + 1] = "callback:SetItemRef@" .. tostring(owner == nil and "?" or (owner.__seq or "addon"))
   end
   ```

   Add a `-- red under: drop the EventRegistry:UnregisterCallback in NS.StandDown` line at step 3.
   Step 9's `R_on` equality then covers the re-registration. Before relying on it, verify the case
   goes red by deleting the unregister line from a `cp` backup, as `testing-§12` requires.

5. **WG-65:** rewrite `docs/ARCHITECTURE.md:158-161` and `:238-241` so that only the two
   `hooksecurefunc` rows survive, which is then true. Move the `EventRegistry` row at `:170` into the
   "gone while disabled" set.

**Risk:** low. The link only matters while a capture exists. Test mode and `/wg show` are unaffected.

---

## §2 — Event registration robustness (WG-67, WG-68)

**Files:** `core/WhatGroup.lua`, `modules/Frame.lua`, `core/DebugLogSetup.lua` (surfacing),
`tests/test_lifecycle.lua` or a new `tests/test_events.lua`.

### WG-67 — one isolated registration helper

```lua
-- core/WhatGroup.lua (file scope)
NS.RejectedEvents = {}      -- name -> the error string; session-only, read by /wg debug
local function safeRegister(target, event, handler)
    local valid = C_EventUtils and C_EventUtils.IsEventValid
    if valid and not valid(event) then
        NS.RejectedEvents[event] = "not valid on this client"
        return false
    end
    local ok, err = pcall(target.RegisterEvent, target, event, handler)
    if not ok then NS.RejectedEvents[event] = tostring(err) end
    return ok
end
```

- `registerFeatureEvents` calls `safeRegister(self, …)` for each of the four events. A bad name now
  costs one edge and never aborts `OnEnable`.
- **Reachable by the player.** The record has to be one the player can reach. The simplest compliant
  surface is the `[Init]` summary, emitted on `/wg debug on`, which appends
  `rejectedEvents=<names>` when non-empty. Log each rejection once through `NS.Debug("Events", …)`.
  The line must be pre-formatted-free (see WG-69).
- **Test:** the kit mock raises for any name in `M.__badEvents`. Add a case that seeds `__badEvents`
  with `GROUP_ROSTER_UPDATE`, runs `OnEnable`, and asserts four things:
  - the other three events are registered;
  - `Settings.Register` ran;
  - `NS.Launcher:Register` ran;
  - `NS.RejectedEvents.GROUP_ROSTER_UPDATE` is set.

  Carry a `-- red under:` comment naming the bare `RegisterEvent`.
- Record the trade in `docs/midnight-quirks.md`: "probing loses the edge an event covers on a client
  that lacks it" (`events-frames-taint-§1`).

### WG-68 — drain both deferrals from AceEvent

The addon object already owns `PLAYER_REGEN_ENABLED` (→ `OnCombatStateChanged`), and AceEvent keys
one handler per (event, target). **Recommended:** a pending-work queue drained by the existing handler.

```lua
-- modules/Frame.lua
local pendingOnRegen = {}   -- ordered: { fn, ... }; file scope so NS.FrameStandDown can clear it
function NS.FrameQueueForCombatEnd(fn) pendingOnRegen[#pendingOnRegen + 1] = fn end
function NS.FrameDrainCombatEnd()
    local q = pendingOnRegen; pendingOnRegen = {}
    for i = 1, #q do q[i]() end
end
```

- `WhatGroup:OnCombatStateChanged("PLAYER_REGEN_ENABLED")` calls `NS.FrameDrainCombatEnd()` first.
- `deferTeleportUntilCombatEnds` queues `function() ConfigureTeleportButton(…, pending) end` in place
  of `f:RegisterEvent`. The "only the latest info" semantics are kept by storing `f._pendingTeleportInfo`
  and queuing once.
- `ShowFrame`'s first-show defer queues `function() … WhatGroup:ShowFrame() end`, and
  `buildWaitFrame` is deleted.
- `NS.FrameStandDown` clears the queue. That replaces its two raw unregisters at `:1115-1123`.
- **Stand-down interplay:** while the addon is disabled, `PLAYER_REGEN_ENABLED` is unregistered except
  for the pending-Hide edge (`OnDisabledCombatEnded`). The queue is emptied on the way down, so nothing
  queued can run on a disabled addon. `OnDisabledCombatEnded` does not drain the queue.
- **Alternative**, if the queue feels wrong: one private AceEvent target
  (`local regen = {}; LibStub("AceEvent-3.0"):Embed(regen)`). It is registered only while work is
  pending and unregistered in `FrameStandDown`. It keeps the current shape, but it is a second target
  to tear down.
- **Tests:** retarget the existing `tests/test_frame.lua` combat-defer cases (`frame: the deferred show
  restores a pendingInfo …`) to fire `PLAYER_REGEN_ENABLED` through the AceEvent mock. Then
  `tests/test_disabled.lua`'s `rawRegs` survey has no raw frames left to report, so keep it, since it
  is the guard that none come back.

---

## §3 — Debug sink discipline (WG-69)

- Mechanically rewrite the 16 sites in 03 §E to the deferred-format form. For example:
  - `NS.Debug("LFG", "appID=" .. tostring(appID) .. " status=" .. tostring(newStatus))` becomes
    `NS.Debug("LFG", "appID=%s status=%s", appID, newStatus)`. The library's sink runs `safeToString`
    on each vararg, so the explicit `tostring` goes too.
  - Conditional messages (`modules/Frame.lua:890`) become two calls, or a format with a
    `"%s"` of a pre-picked **constant** string: `info and "…" or "…"` is fine when both arms are
    literals.
- The `events-frames-taint-§8` register row lists these same sites as pre-formatting SHOULDs. Once the
  sites are rewritten, **amend that row**: the pre-formatting half no longer describes the tree, and
  only the two unreachable `pout` fallbacks remain. That is a doc change under the register's second
  MUST, not a re-decision.
- **Test:** the kit's sink is zero-allocation when off. Add one case per busiest path, e.g.
  `LFG_LIST_APPLICATION_STATUS_UPDATED` with debug off. It asserts `collectgarbage("count")` does not
  grow across 1000 fires beyond a small bound, or it spies `string.format` and `..` indirectly by
  counting `NS.Debug` argument types. The simplest honest form asserts that each rewritten call site
  passes more than two arguments to `NS.Debug`.

---

## §4 — TOC annotation (WG-70)

Above `WhatGroup.toc:42`:

```
# Before core\WhatGroup.lua: that file calls NS.Compat.AddOnLinkType() at file load
# (core/WhatGroup.lua:87) to pick the chat link's type. Load-bearing.
core\Compat.lua
```

Above `:41`, add `# core\Util.lua: conventional -- NS.Windows and NS.FormatDuration are read at call time.`.
`tests/test_harness.lua` already pins the TOC-derived load list. No code changes.

---

## §5 — Tests: stub-surface parity (WG-72)

In `tests/test_surface_parity.lua`, add two by-name cases on the Options pattern. Each takes its
degraded arm from `T.newAddon{ skip = NO_LIBKA0S }`. Register the live instances with
`Kit.setSurfaceSource` in `tests/run.lua`, as the three existing by-name seams do.

```lua
test("parity: the Launcher stub carries the whole live surface", function()
    -- members from: grep -rnoE "NS\.Launcher[:.][A-Za-z]+" core modules settings
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(degraded.Launcher, "LibKa0s-Launcher-1.0")
end)
test("parity: the Lifecycle stub carries the whole live surface", function()
    -- members from: grep -rnoE "NS\.Lifecycle[:.][A-Za-z]+" core modules settings
    local degraded = T.newAddon{ skip = NO_LIBKA0S }
    T.assertSurfaceParity(degraded.Lifecycle, "LibKa0s-Lifecycle-1.0", { name = true })  -- `name` is data, not a member
end)
```

- Rewrite the header (`:1-43`) to name all seven stubs, plus Env and Media, which are covered by the
  namespace case.
- The Lifecycle live instance is `lib:New(...)`, the `LC` table. Confirm `name` is present on both
  arms, or ignore it with the rule stated.

---

## §6 — The bus question (WG-57)

The upstream answer (§0) decides the branch.

- **Option A, adopt.** Declare `NS.MSG = { JOIN_READY = "Ka0s_WhatGroup_JoinReady" }` in
  `core/WhatGroup.lua`, or wrap it with `LibKa0s-Bus-1.0`'s `Catalog` for strictness. The join-notify
  timer then publishes `JOIN_READY`, and `modules/Frame.lua` subscribes on its own target
  (`NS.NewBusTarget()` or `Bus:NewTarget()`) in place of the direct `self:ShowFrame()`.
  - The stand-down must unregister that subscription. `LibKa0s-Bus-1.0`'s `StandDown`/`StandUp`, or
    the host's own target plus `UnregisterAllMessages`, does this.
  - `docs/ARCHITECTURE.md` `## Message Bus` then documents the name, the sender, the payload and the
    consumer.
  - The bus mock must key receivers by target (`architecture-§4`); the kit's does.
- **Option B, record.** Add a `## Documented deviations` row with Rule `architecture-§4`. What
  differs: no bus, even though core registers game events. Why: one feature module, direct calls, the
  clobber hazard cannot arise. Re-check trigger: *"a second feature module, or a second consumer of
  the join data"*.
- **Option C, upstream closes it.** If §0 amends the clause so it excludes the addon object's own
  handlers, WG-57 closes against the amended text. Keep `## Message Bus`'s sentence.

**Recommendation:** C, with B as the fallback if upstream declines. A has real cost and buys nothing
in a single-feature addon.

---

## §7 — Docs and register (WG-61, WG-63, WG-75, WG-76, WG-77, WG-78, WG-79, WG-73, WG-80, WG-83, WG-81)

- **WG-61, with WG-63:**
  - `docs/ARCHITECTURE.md:503`: `WG-R-06` → `F-006` (`docs/reviews/2026-08-05/`).
  - `:504`: `WG-A-08` → `WG-37` (`docs/audits/2026-08-05/`).
  - Extend the key at `:494-498` to name the `F-NNN` review shape and the dated bundle it resolves in.
  - Tighten `tests/test_register.lua`:
    - resolve `WG-R-NN`/`F-NNN` ids against `docs/reviews/` rather than skipping them (`:94`);
    - drop a bundle's *Recorded deviations* echo table from `isAssigned`'s corpus (`:59-77`);
    - add `-- red under: restore WG-A-08 in :504`.
- **WG-78:** change `:503`'s Rule cell to `` `localization-§1` ``.
- **WG-75:**
  - Cut `docs/compat-layer.md` to the six addon shims. Replace the rung-by-rung prose for
    `GetSpellName`/`GetSpellTexture` with one sentence pointing at LibKa0s's
    `docs/api/Compat/version-1-docs.md`. Correct `docs/ARCHITECTURE.md:464` to "six".
  - For `debug.md`, the recommended route is to trim it to the per-addon content (the descriptor
    fields, the tag vocabulary, "adding a debug line", the `/wg debug` semantics) and point at the
    library for the window, format, font and copy/clear. Then set `:462`'s row honestly: *Present —
    trigger not fired; kept for the addon's tag vocabulary*. Alternatively mark it Not applicable and
    move the tag vocabulary to a Tier 3 doc.
- **WG-76:** spill `## The stand-down` (`:193-282`) to a new Tier 3 `docs/stand-down.md`, which gets a
  `### Addon-specific` row, and spill `## Load order`'s per-file list (`:367-410`) to `module-map.md`.
  Leave a 5–10 line summary and one link for each. The target is ≤ ~400 lines. Re-run
  `tests/test_docmap.lua` and `tests/test_doc_structure.lua` and fix whatever they pin.
- **WG-77:** apply the eight corrections in 02's table.
  - README lines `:41`/`:48`: *"the place you dragged the popup to"*. Only the popup's position is
    saved. Run the de-AI pass on the README change.
  - `docs/ARCHITECTURE.md:19` and `docs/module-map.md:68`: `FIFO` → "keyed by search-result id".
  - `:55` "eight" → "nine".
  - `:319`: list every degrading seam, and change "the other three" to count what it lists.
  - `:383`: stop spelling out `LibKa0s.xml` and say "the 21 files `LibKa0s.xml` lists", or list all 21.
    Prefer the first, so the count cannot drift again.
  - `:502`: drop "the row above" and "the exemption row above".
  - `core/MediaSetup.lua:33-34`: the footer mark was removed, and `NS.Icon` has no caller today.
- **WG-79:**
  - `DEPENDENCIES.md` §3 (Release/assets): add **Python 3 + Pillow**, citing `layout-§4`'s recipe for
    `media/logos/whatgroup.logo.128.tga`. Install it with
    `sudo apt install -y python3-pil`, or `pipx`/a venv, and verify with
    `python3 -c "import PIL; print(PIL.__version__)"`. State that it is not needed to build, run or
    test.
  - §2.3: relabel lizard *"optional per commit, required at release (the release gate treats a
    complexity skip as not passed — automated-tests-§3)"*.
- **WG-73:** fix the five sites to `slash-commands-§7`, `localization-§5` (×3) and `layout-§1`.
- **WG-80:** `settings/Panel.lua:87` → `("Interface\\AddOns\\%s\\media\\logos\\%s.logo.tga"):format(addonName, addonName:lower())`.
  The file already binds `addonName` at `:14`.
- **WG-83:** add `"docs/revendor/"` to `.luacheckrc:17`. `tests/test_lintconfig.lua` may pin the list,
  so update it in the same change.
- **WG-81:** in `core/LauncherSetup.lua:151-152`, drop `or "Ka0s WhatGroup is disabled."`. `NS.SlashCommands`
  is always published by `settings/Slash.lua`, on both branches. If a guard is still wanted, make it
  return the degraded stub's own `DisabledLine` shape.

---

## §8 — Record (WG-48)

At the next release, run `tests/_kit/run-automated-tests.sh` with the full four suites, from a clean
tree. This is the first run on kit revision 25, so it emits the commit and clean/dirty cells. Give
`core/WhatGroup.lua` a disposition in the band table. Write `ANALYSIS.md`. The release gate then
evaluates all four suites at `pass` plus zero CCN > 15. HEAD's max is 14, so it passes.

---

## Ordering constraints

1. §0 (LibKa0s kit + standards) → a new LibKa0s tag.
2. §R, the whole re-vendor with the consolidated bundle (closes WG-71, and WG-74 lands here), must
   precede §5 and §1-step-4, because the parity and survey cases run against the new kit.
3. §1 before §2. Both touch `NS.StandDown`/`NS.StandUp` and `OnCombatStateChanged`. Land the
   stand-down fix first and keep `tests/test_disabled.lua` green between them.
4. §3 before amending the `events-frames-taint-§8` row (§3's final bullet).
5. §7's doc edits come after §1, §2 and §4, so they describe the final code (WG-65 and WG-77's
   stand-down text).
6. §8 comes last, at release.
