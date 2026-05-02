# Scope

What's in scope, what's out, and the resolved decisions that shaped the contract. The contract itself (what the user sees, slash UX, settings panel) is documented in [README.md](../README.md) — this doc records the *boundary* decisions so a fresh contributor can tell whether a feature request is in or out of scope without re-litigating it.

## In scope

- **Group-info capture from the Premade Group Finder.** Hook `C_LFGList.ApplyToGroup`, capture the search-result tile's fields (title, leader, activity, playstyle, voice-chat note, etc.), and resurface them once the player joins the group.
- **Chat notification on join.** A summary line for each captured field, with per-line gates (`notify.show*` schema rows). Always wears the cyan `[WG]` chat prefix.
- **Popup dialog on join.** A 420×260 `WhatGroupFrame` showing every field plus a teleport spell button for known dungeon teleports. Auto-opens on join when `frame.autoShow` is true.
- **Re-open via clickable chat link.** The notification ends with a `WhatGroup:show` hyperlink; clicking re-opens the popup. `RawHook` on `SetItemRef` short-circuits on that prefix.
- **Schema-driven settings.** A flat `Settings.Schema` array drives the panel widgets, the `/wg list/get/set/reset` slash surface, AceDB defaults, and `/wg reset`. One row = one option, six surfaces.
- **Account-wide preferences.** Single AceDB profile (`AceDB:New("WhatGroupDB", defaults, true)` — `true` = shared `Default` profile across every character on the account).
- **Master enable switch.** `db.profile.enabled` gates the capture path entirely. `/wg test` and `/wg show` deliberately bypass the gate.
- **Test affordance.** Both `/wg test` and the panel's Test button route through `WhatGroup:RunTest()`, which injects synthetic `pendingInfo` and runs the full notify + popup flow without joining a real group.

## Out of scope

These have been considered and explicitly declined. A change of heart needs an issue + design discussion, not a stealth PR.

- **LFG state mutation.** The addon never auto-applies, never declines invites, never modifies the LFG search results, and never blocks the join flow. Every hook is observation-only (`SecureHook` on `ApplyToGroup`) or short-circuits only on its own custom hyperlink (`RawHook` on `SetItemRef` for `WhatGroup:` links).
- **Localization.** English-only. The schema labels, tooltips, chat prefixes, and `GetGroupTypeLabel` strings are all literal English. Localization plumbing is a deliberate non-goal at this size.
- **Classic / Wrath / Cataclysm.** Retail only. Interface line in `WhatGroup.toc` is `120000,120001,120005`. The Premade Group Finder API surface and the `Settings.RegisterCanvasLayoutCategory` shape are retail-specific.
- **Per-character profiles.** Single account-wide profile by design. No profile switcher, no per-character overrides.
- **Profile import / export.** No serialization layer.
- **LDB / minimap icon.** Not provided.
- **History / log of past groups.** `pendingInfo` holds a single capture and is cleared on group leave. The notification is the only persistent record (in chat scrollback).
- **Group quality scoring / filtering.** WhatGroup observes; it doesn't recommend, rank, or block groups.
- **Voice-chat URL extraction or auto-join.** The voice-chat string is captured and shown verbatim — no parsing, no auto-join.
- **Custom hyperlinks beyond `WhatGroup:show`.** Only the one prefix is intercepted. The `RawHook` falls through to the original handler on every other link prefix.

## Resolved decisions

Decisions that were made during requirements review and the v1.0 / v1.1 launches — these are settled, not open.

- **Capture queue is FIFO, not single-slot.** A player can have multiple applications in flight before any of them resolve. The `applied` LFG event is the first place the API tells us which `appID` corresponds to which apply, so captures wait FIFO until they're paired up.
- **Group-leave wipes capture state.** `GROUP_ROSTER_UPDATE` with `inGroup == false` clears `pendingInfo`, `captureQueue`, and `pendingApplications`. No "remember last group" mode.
- **`wasInGroup` is the join-trigger gate.** The notify + popup fire on the not-in-group → in-group transition only. Re-entering combat, leveling, or any other roster update inside an existing group does nothing.
- **`SecureHook` on `ApplyToGroup`, `RawHook` on `SetItemRef`.** `SecureHook` because we only observe the apply (no need to intercept). `RawHook` because we genuinely need to short-circuit `SetItemRef` on our own prefix. See [wow-quirks.md](./wow-quirks.md#hook-discipline).
- **The popup always shows every field.** The `notify.show*` schema rows gate the **chat** notification only — the popup is "what got captured", uneditable. If a field is missing from the capture (e.g. activity not resolved), the populator falls back to placeholder text rather than hiding the row.
- **Parent settings category is intentionally a thin landing page.** WoW 12.0 hides parent-category widgets when the parent has subcategories, so widgets there would never display. Every actual setting lives in the General subcategory; the parent panel hosts a logo + TOC notes one-liner + the slash-command list (read live from `WhatGroup.COMMANDS`). See [wow-quirks.md](./wow-quirks.md#settings-api-parent-vs-subcategory).
- **`/wg config` opens the parent and unfolds the tree.** `Settings.OpenToCategory(self._parentSettingsCategory:GetID())` followed by a `pcall`-wrapped `SettingsPanel:GetCategoryList():GetCategoryEntry(parent):SetExpanded(true)` — the user lands on the addon-landing page (logo + slash list) with every subcategory visible one click away in the sidebar. Refuses to open during `InCombatLockdown()` because the Settings UI uses secure templates that can taint mid-combat.
- **Settings panel body is built lazily.** AceGUI widgets must render against a non-zero panel width. The General subcategory's `OnShow` has a `built` one-shot guard that builds the body the first time the user opens the panel. See [wow-quirks.md](./wow-quirks.md#lazy-acegui-panel-build).
- **Cyan `[WG]` chat prefix.** Every line the addon prints is routed through `CHAT_PREFIX = "\|cff00FFFF[WG]\|r"` so users can identify WhatGroup output at a glance. Debug lines additionally tag `[DBG]` in orange.
- **Embedded libs over external dependencies.** Ace3 + LibStub + CallbackHandler are vendored under `libs/` and loaded via `WhatGroup.toc`. Copied verbatim from Ka0s KickCD to keep versions aligned across the user's addons.

## Where the contract lives

- User-facing behaviour: [README.md](../README.md) — slash commands, FAQ, troubleshooting.
- Engineer working notes: [../CLAUDE.md](../CLAUDE.md) — hard rules, response style, working environment.
- Module map + invariants: [../ARCHITECTURE.md](../ARCHITECTURE.md).
