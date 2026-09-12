# 02 — Candidates: LibKa0s v1.29.0 → v1.30.0

Sources, in order: `git -C ../LibKa0s log --oneline v1.29.0..v1.30.0` (four commits, `7aaf1fe`,
`aaef20a`, `e5f6906`, `e369e0f`), the `## v1.30.0` block of the tag's `CHANGELOG.md`, and
`docs/api/testkit/version-16-docs.md`. No `LibKa0s/` file moved its minor, so no major's
`docs/api/<Major>/` document changed, and no **class C** (whole-module) candidate is possible. The
whole release is kit revision 16: four changes to the headless fakes and to `vendor_sync.lua`.

## Class A — delivered by the copy alone

- **#28, `vendor_sync.lua`: the runner's recorded mode.** `VendorSync.register` now adds the case
  `the automated-test runner is recorded executable (100755)`. `tests/test_vendor_sync.lua` calls
  `register(_G.WHATGROUP_TEST, {})` with default options, so the case arrived with no host change. It
  passes: the index records `tests/_kit/run-automated-tests.sh` as `100755`. The suite total moves
  568 → **569**. This closes the open audit finding **WG-51** (`docs/audits/2026-09-08/02_DEVIATIONS.md`,
  *"the vendored-payload gate still does not assert the runner's recorded mode"*).
- **#30, `NewAddon` stamps `Printf`.** `tests/wow_mock.lua` replaces the kit's AceAddon but calls
  `baseNewAddon(self, obj)` first, so the kit's `Printf` lands on the addon object. No addon code
  calls `Printf` (`grep -rn Printf core modules settings` is empty), and no local shim duplicates it.
  Delivered, and inert.

## Declined — the kit fix cannot reach this harness (not offered for adoption)

The owner's rule for this rollout: a shim is adopted only where the kit now provides the same
contract and the suite stays green; anything needing a harness migration is declined.

- **#29, AceEvent's event half on an embed.** The addon never reaches `AceEvent:Embed`. It takes
  `"AceEvent-3.0"` only as a `NewAddon` mixin (`core/WhatGroup.lua:31-33`), and the mock's `NewAddon`
  ignores the mixin list. There is no `NS.NewBusTarget()` anywhere in the addon. On the `NewAddon`
  target, `tests/wow_mock.lua:412-417` overwrites the kit's `RegisterEvent`/`UnregisterEvent` after
  `baseNewAddon`, and records into `mock.addonEvents[event] = handler or event`, the handler **name**,
  not the kit's `obj.__events[event] = handler or true`. That shape is load-bearing (fidelity note 6,
  `tests/wow_mock.lua:56-63`). Two events share `OnCombatStateChanged`, and `mock.fireAddonEvent`
  (`:451-458`) dispatches by that name. Suites read it directly: `tests/test_lifecycle.lua:82-88`,
  `tests/test_frame.lua:962-963`, and 21 `addonEvents`/`fireAddonEvent` sites in `tests/test_frame.lua`.
  Adopting the kit's recorder would be a harness migration, not a shim deletion. **Declined.**
  - A side effect worth recording: `baseNewAddon` now also stamps the kit's `UnregisterAllEvents`
    on the addon object, and the local override does not replace it. That function clears the kit's
    per-build registry, not `mock.addonEvents`. Nothing calls `WhatGroup:UnregisterAllEvents()` today.
    `modules/Frame.lua:831` is a frame's own `UnregisterAllEvents`, served by the frame stub at
    `tests/wow_mock.lua:270`. So this is latent, not live.
- **#27, `AceGUI:Release`.** `tests/wow_mock.lua:503-541` wraps the kit's `aceGUI.Create` rather
  than replacing it, so widgets now carry the kit's `userdata = {}` and a `widget:Release()` method,
  and `aceGUI:Release` exists. No addon code and no `libs/LibKa0s/*.lua` path this addon renders
  calls `:Release(` (grep empty). The only local release-shaped code is the ScrollFrame's
  `w.OnRelease = function(s) s.released = true end` (`:541`). That models the stock `OnRelease`
  the always-shown-scrollbar patch restores (`tests/test_panel.lua:614-616` asserts `scroll.released`).
  It is a different mechanism with a different field (`released`, not `__released`), not a copy of
  the kit's release. There is nothing to delete. **Inert, and recorded as declined.**

## Class B / class C candidates

**None.** No new descriptor field, public surface or row type shipped, and no module moved.
