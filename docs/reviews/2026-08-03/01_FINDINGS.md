# Ka0s WhatGroup — Review Findings (2026-08-03)

**Verdict: minor issues.** The addon is structurally healthy, cleanly LibKa0s-adopted, green on
`lua tests/run.lua` (415 passed, 0 failed) and clean on `luacheck .` (0 warnings / 0 errors in 14
files). No taint, secret-value, deprecated-API-in-the-wild or data-loss defects were found. One
functional bug (a resurrected capture that can announce the wrong group), a handful of
maintainability/design drifts, and a release-readiness gap are the whole of it.

**Standards cross-check: performed.** `standards/STANDARDS.md` was fetched over the network from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` and resolved to
**v2.17.1 (2026-08-03)**; the fetched index was verified byte-identical (`diff`, exit 0) to the
local `master` checkout of the standards repo, and the section files linked from its Sections list
were read from that verified-identical copy. Every fix direction below was vetted against it.

**Upstream / vendored code:** `diff -r <LibKa0s repo>/LibKa0s libs/LibKa0s` is **empty** and
`diff -r <LibKa0s repo>/testkit tests/_kit` is **empty** — no vendor drift (anti-patterns #45,
library-stack-§7). No `[upstream]` findings were raised: the library's own implementation is out of
scope for this review, and the four descriptor/stub setup files that *are* this addon's half of the
contract (`core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`,
`settings/Slash.lua`) were reviewed member-by-member against their call sites and are complete —
`tests/test_libka0s.lua` additionally pins stub↔instance member parity.

---

## High

### F-001 — A combat-deferred popup resurrects a capture the group-leave already wiped `[logic]`

- **Where:** `modules/Frame.lua:326` (`WhatGroup.pendingInfo = WhatGroup.pendingInfo or pending`),
  interacting with `core/WhatGroup.lua:526-540` (`WipeCapture`) and `core/WhatGroup.lua:477-517`
  (`_TryFireJoinNotify`).
- **Problem:** when the first `ShowFrame()` lands in combat, the deferral closure captures
  `pendingInfo` and, on `PLAYER_REGEN_ENABLED`, writes it back unconditionally if the live value is
  nil — including when the nil was produced by `WipeCapture()` on group-leave, which also cleared
  `notifiedFor`.
- **Impact:** the addon is left holding a capture for a group the player already left, with the
  "already notified" guard reset; the *next* group join (even a direct invite with no LFG apply at
  all) satisfies every gate in `_TryFireJoinNotify` and prints/pops the **previous** group's title,
  leader, instance and teleport spell as if it were the group just joined. The addon's headline
  promise — "these are the details of the group you just joined" — is silently wrong.
- **Note:** the restore itself is deliberate and covered by `tests/test_frame.lua:317`; what is
  missing is the distinction between "pendingInfo was never set" and "pendingInfo was *wiped*
  during the wait". The existing test asserts the restore and would need to be paired with a
  wipe-generation case.
- **Fix direction:** give the capture state a monotonically increasing generation that
  `WipeCapture` bumps, and restore only when the generation is unchanged; otherwise let the popup
  render its existing "No data" path. Host-owned capture state, no library seam involved —
  compliant with architecture-§5 and events-frames-taint.

---

## Medium

### F-002 — Playstyle-label logic is duplicated in the popup, contradicting its own "single source" comment `[design]`

- **Where:** `modules/Frame.lua:292-295` re-implements the body of
  `WhatGroup.Labels.GetPlaystyleLabel` (`core/WhatGroup.lua:360-365`); the comment at
  `core/WhatGroup.lua:325-327` states the Labels namespace is "consumed by both ShowNotification
  (chat) and WhatGroup_Frame.PopulateFields (popup). Single source of truth".
- **Problem:** the popup reads `Labels.PLAYSTYLE` directly and re-derives the
  `playstyleString`-else-enum precedence instead of calling the shared function — which the sibling
  line right above it (`modules/Frame.lua:283`, group type) *does* do correctly.
- **Impact:** a change to playstyle precedence (a new enum member, an empty-string rule, a fallback
  string) lands in chat and not in the popup, or vice versa; the comment actively misleads the next
  maintainer into thinking one edit suffices. This is the same one-formatter-seven-times drift the
  collection extracted LibKa0s to end, in miniature (anti-patterns #47's rationale).
- **Fix direction:** call `Labels.GetPlaystyleLabel(info)` from `PopulateFields` and keep only the
  empty-string→em-dash presentation decision local to the popup.

### F-003 — Addon-metadata API detection is hand-rolled in two settings files instead of routed through Compat `[deprecated-api]` `[design]`

- **Where:** `settings/Panel.lua:117` (`local meta = (C_AddOns and C_AddOns.GetAddOnMetadata) or
  _G.GetAddOnMetadata`) and `settings/Slash.lua:28-31` (`C_AddOns and C_AddOns.GetAddOnMetadata and
  C_AddOns.GetAddOnMetadata(addonName, "Version")`).
- **Problem:** `core/Compat.lua` declares itself (`core/Compat.lua:7-8`) and is documented
  (`docs/file-index.md:13`) as the **sole** caller of version-variant APIs, but the
  `GetAddOnMetadata` → `C_AddOns.GetAddOnMetadata` migration is detected inline in two feature
  files, with **two different** fallback behaviors (Panel falls back to the removed global; Slash
  does not). compat-§1 makes routing every deprecated-API call through `Compat` a MUST, and
  anti-patterns #10 names the direct call.
- **Impact:** the next retail patch that moves or renames this API changes three files instead of
  one, and the two call sites will not degrade the same way. Additionally
  `settings/Panel.lua:118` hardcodes the string `"WhatGroup"` where `addonName` is already in scope
  at `settings/Panel.lua:14` — a folder rename silently blanks the landing page's Notes line.
- **Fix direction:** add `Compat.GetAddOnMetadata(name, field)` and have both call sites use it
  with `addonName`.

### F-004 — The migration runner stamps `schemaVersion` forward unconditionally `[logic]` `[savedvariables]`

- **Where:** `core/Database.lua:38` (`g.schemaVersion = NS.SCHEMA_VERSION`), after the
  intentionally-commented step loop at `core/Database.lua:31-36`.
- **Problem:** the stamp runs whether or not any migration step executed. The moment
  `NS.SCHEMA_VERSION` is bumped (savedvariables / versioning-git-§4 requires a bump when a
  migration is needed) without the loop being uncommented, every existing profile is silently
  marked as migrated. It also silently *downgrades* the recorded version of a database written by a
  newer build of the addon.
- **Impact:** the failure is unrecoverable and undetectable after the fact — the one piece of
  evidence that a database still needs migrating is destroyed by the same line that was supposed to
  record the migration. It costs nothing today (`SCHEMA_VERSION == 1`), which is exactly why it will
  not be noticed until it does.
- **Fix direction:** delete the unconditional stamp and let the (uncommented) `while` loop own the
  version advance, so a version with no step for it cannot be stamped; guard against a
  future-versioned database by leaving `g.schemaVersion` alone (and logging) when it is already
  greater than `NS.SCHEMA_VERSION`.

### F-005 — The teleport button's anchor arithmetic has no nil guard on `GetLeft()` / `GetTop()` `[logic]`

- **Where:** `modules/Frame.lua:139-140` — `local btnX = (lblPort:GetLeft() - f:GetLeft()) +
  LABEL_WIDTH + 6` and `local btnY = lblPort:GetTop() - f:GetTop()`, executed inside `buildFrame()`
  on a frame that was `f:Hide()`-ed at `modules/Frame.lua:44` and has never been shown.
- **Problem:** the region-rect getters return `nil` when a frame's rect is not resolvable, and this
  code does bare arithmetic on four of them with no guard. **I could not verify in-client whether
  this frame's rect is always resolved at this point** — with an anchored, clamped frame under
  `UIParent` it usually is — so treat this as a hardening item rather than a confirmed crash.
- **Impact:** if the rect is ever unresolved (a hidden-parent case, a UI-scale change mid-build, a
  future refactor that builds before anchoring), the first `ShowFrame()` raises "attempt to perform
  arithmetic on a nil value" and the popup never appears — the addon's primary surface, gone, on a
  path that only fires the first time a user opens it.
- **Fix direction:** compute the offsets from the layout constants that already determine them
  (`LABEL_WIDTH`, `yGap`, the row count, the content inset) or fall back to those when any getter
  returns nil, keeping the existing "no magic offsets to retune" intent.

### F-006 — Applications that are declined or cancelled are never reclaimed from the session tables `[perf]` `[logic]`

- **Where:** `core/WhatGroup.lua:563-576` — `LFG_LIST_APPLICATION_STATUS_UPDATED` handles
  `"applied"`, `"invited"` and `"inviteaccepted"` only; `pendingApplications[appID]` is written on
  `"applied"` and cleared only by `wipe()` on `"inviteaccepted"` (`core/WhatGroup.lua:605-606`) or by
  `WipeCapture` (`core/WhatGroup.lua:535-536`).
- **Problem:** the statuses that end an application without a join — `declined`,
  `declined_full`, `declined_delisted`, `cancelled`, `timedout`, `failed` — are not handled, so a
  capture table per dead application accumulates for the whole session.
- **Impact:** small but unbounded within a session for the addon's core use case (a player who
  applies to many groups and is declined by most), and it makes the queue↔status pairing harder to
  reason about than it needs to be. No correctness impact today, because entries are keyed by
  `appID`.
- **Fix direction:** clear `pendingApplications[appID]` on any terminal non-join status; keep the
  `invited` no-op branch (and its `542` luacheck exemption) as the documented waiting state.

### F-007 — Released version, in-code version and README all still say 1.3.0 while a breaking CLI change sits on master `[ux]` `[docs]`

- **Where:** `WhatGroup.toc:5` (`## Version: 1.3.0`), `core/WhatGroup.lua:35`
  (`WhatGroup.VERSION = "1.3.0"`), `README.md:18` (`## What's new in 1.3.0`), `README.md:118`
  (Version History's top row, dated 2026-07-12) — versus the shipped-on-master behavior change
  documented at `settings/Slash.lua:226-250` ("This is a **BREAKING** change to a verb this addon
  has shipped since 1.0").
- **Problem:** since the `1.3.0-release` tag, master has taken the whole LibKa0s adoption **and**
  re-specified `/wg reset` from "wipe everything (confirmed)" to "reset one row by path", adding
  `/wg resetall`. The README's command table (`README.md:57-58`) already documents the new grammar,
  but neither version constant moved and the `## What's new` heading still names 1.3.0 with bullets
  that describe the previous release.
- **Impact:** `/wg version` reports a version whose documented behavior differs from the running
  build; a user reading the top of the README is told what changed two releases ago. anti-patterns
  #40 makes a stale `## What's new` a violation in its own right, and versioning-git-§1/§2 require
  the bump to land in the TOC **and** in code constants and the README Version History together.
- **Fix direction:** before the next release, bump TOC + `WhatGroup.VERSION` together (the
  `/wg reset` re-specification is backwards-incompatible for a user-facing command surface, so
  choose the level deliberately rather than by habit) and roll `## What's new` and the Version
  History row forward in the same change (documentation-§1 item 5, versioning-git-§2).

---

## Low

### F-008 — Five locale keys are defined but referenced nowhere `[locale]`

- **Where:** `locales/enUS.lua:69` (`"Ka0s WhatGroup"`), `:70` (`"General"`), `:71`
  (`"Slash Commands"`), `:72` (`"Defaults"`), `:106-107`
  (`"cannot open settings during combat — Blizzard's category-switch is protected"`). Verified zero
  `L["…"]` references across `core/`, `modules/`, `settings/`, `defaults/`.
- **Problem:** the panel passes the literals directly (`settings/Panel.lua:198`, `:217`,
  `settings/Panel.lua:135`) and the combat-refusal line now comes from the library
  (`libs/LibKa0s/Options.lua:76`, `STRINGS.COMBAT_REFUSED`), so the addon's copies are orphans. The
  file's own header (`locales/enUS.lua:19-25`) claims to carry the player-facing surface, which
  these keys no longer are.
- **Impact:** a translator is handed four strings that change nothing and one that duplicates a
  library string they cannot influence from here — the exact "which copy wins?" confusion the
  metatable-fallback shell exists to avoid.
- **Fix direction:** drop the orphaned keys (they are dead data, not a translation gap), or route
  the panel literals through `L` if the intent is that they *are* in scope — but pick one, and
  update the header comment's stated scope to match. Do **not** hand the library's
  `COMBAT_REFUSED` a host copy (anti-patterns #47, options-ui-§8).

### F-009 — `shortName` is missing from the captured-info initializer; two consumers survive only by an `and/or` accident `[design]`

- **Where:** `core/WhatGroup.lua:202-226` seeds every field of `captured` except `shortName`, which
  is written only inside the `if actInfo then` branch at `core/WhatGroup.lua:241`. Consumers:
  `core/WhatGroup.lua:397` and `modules/Frame.lua:283`, both
  `info.shortName ~= "" and info.shortName or Labels.GetGroupTypeLabel(info)`.
- **Problem:** when activity info is unavailable (no `activityIDs`, unknown activity, API nil),
  `info.shortName` is `nil`, so the guard's first test passes and the expression is rescued only
  because `true and nil` is falsy and falls through to the `or` branch. It is correct by luck of
  operator semantics, not by design, and one refactor to `if info.shortName ~= "" then` breaks it.
- **Impact:** none today; a latent trap, and the initializer's "here is the full captured shape"
  contract is silently incomplete.
- **Fix direction:** seed `shortName = ""` in the initializer alongside its siblings.

### F-010 — `captured.playstyle` is written and never read `[naming]`

- **Where:** `core/WhatGroup.lua:227` (`captured.playstyle = captured.generalPlaystyle`) and
  `core/WhatGroup.lua:655` in the synthetic test capture. Only `tests/test_capture.lua:172` reads
  it; no production code does.
- **Problem:** a legacy alias kept alive by a test that asserts the alias exists rather than any
  behavior that depends on it.
- **Impact:** cosmetic; it reads as a supported field of the capture shape and is not one.
- **Fix direction:** drop the alias and the assertion, or comment it explicitly as a
  back-compat field for external readers if that is the intent (nothing external reads it — the
  addon exposes no `NS.API.v1`, per public-api).

### F-011 — `.luacheckrc` declares globals the addon no longer reads `[naming]`

- **Where:** `.luacheckrc:35` (`CastSpellByID` — appears only in a comment at
  `modules/Frame.lua:229`), `.luacheckrc:38` (`SettingsPanel`), `.luacheckrc:39` (`date`).
- **Problem:** the read-globals list is documentation of the WoW surface the addon touches
  (its own comment says so at `.luacheckrc:26-27`) and has drifted from that surface.
- **Impact:** a future direct call to one of these would pass lint unremarked.
- **Fix direction:** prune the three entries (lint stays green — verified 0/0 today).

### F-012 — Two operator-facing strings drift from the addon's chat voice `[ux]`

- **Where:** `settings/Panel.lua:249` (`pout("Cannot register settings panel during combat.")`) and
  `settings/Slash.lua:217` (`NS.Print("Settings panel is not available.")`).
- **Problem:** every other `[WG]` line in the addon is lowercase-leading and, where a capability is
  missing, names the missing library (`NS.LIBKA0S_MISSING`, per `settings/Slash.lua:76`). These two
  are sentence-cased and generic; the second is additionally near-unreachable, because the
  no-library stub always publishes `OpenOptionsPanel` (`settings/OptionsSetup.lua:77`).
- **Impact:** cosmetic inconsistency plus a dead branch that suggests a failure mode that cannot
  occur.
- **Fix direction:** match the surrounding voice, and either delete the unreachable branch or make
  it say the same thing the stub says.

### F-013 — The deferred Defaults-button guard latches permanently `[logic]`

- **Where:** `settings/OptionsSetup.lua:168-173` — `panel.__wgDefaultsScheduled` is set before the
  `C_Timer.After(0, …)` hop and never cleared.
- **Problem:** if the deferred `baseEnsureDefaultsBtn(panel)` does not produce a button (AceGUI not
  resolvable at that instant, an early raise), the latch prevents every later `OnShow` from
  retrying — while the library's own guard (`panel.defaultsBtn`) is designed to allow exactly that
  retry.
- **Impact:** a settings page permanently missing its Defaults button for the session, with no error.
- **Fix direction:** clear `panel.__wgDefaultsScheduled` inside the timer callback so the
  `panel.defaultsBtn` check remains the real idempotence guard.

---

## Areas explicitly checked and found clean

Recorded so a later reader knows these were examined, not skipped:

- **Taint / combat lockdown** — `hooksecurefunc` used for both hooks including `SetItemRef`
  (`core/WhatGroup.lua:56,62`); the secure teleport button, the `UISpecialFrames` insert and the
  `StaticPopupDialogs` write are all deferred out of the boot sequence
  (`modules/Frame.lua:36,168`, `settings/Schema.lua:444`); secure-attribute writes are gated on
  `InCombatLockdown()` with a `PLAYER_REGEN_ENABLED` replay (`modules/Frame.lua:191-205`);
  `Settings` category registration is combat-guarded (`settings/Panel.lua:248`) and registered
  eagerly at `OnEnable`, not behind `/wg config` (anti-patterns #22).
- **Secret values** — every chat line goes through the single secret-safe printer
  (`core/CoreSetup.lua:126-135`), and no protected-API return is concatenated (anti-patterns #35).
- **Events** — registered in `OnEnable`, not `OnInitialize` (`core/WhatGroup.lua:145-146`); no
  unfiltered `UNIT_*` events; no removed/renamed event names in use.
- **Frames** — no `CreateFrame` in an event or update path except the one-shot combat wait frame;
  no `OnUpdate` handlers anywhere; no `setmetatable` on a widget; anonymous frames are anonymous.
- **Deprecated APIs** — `C_Spell.*` preferred with legacy fallback, all inside `core/Compat.lua`;
  `Settings.RegisterCanvasLayout*` (not `InterfaceOptions_AddCategory`); `BackdropTemplate` used.
  The one exception is F-003.
- **Single write path** — no direct `db.profile.x = y` write outside `Helpers.RawSet`; both the CLI
  and the panel take `Helpers.Set` (`settings/OptionsSetup.lua:112-114`, `settings/Slash.lua:166-170`).
- **COMMANDS ↔ README** — all 11 verbs in `settings/Slash.lua:44-67` are documented at
  `README.md:49-60`, and none is documented that does not exist.
- **Schema rows** — every row carries `section`, `group`, `path`, `type`, `label`, `tooltip`,
  `default` (`settings/Schema.lua:88-200`); `ValidateSchema` runs at registration.
- **Vendoring** — `libs/LibKa0s/` and `tests/_kit/` byte-identical to their source repo; whole ship
  folder vendored and TOC-listed via its packaged `LibKa0s.xml` (anti-patterns #45, #48);
  `.pkgmeta` declares no `externals:`; `.gitattributes` declares CRLF for `.lua`/`.xml`/`.toc`.
</content>
</invoke>
