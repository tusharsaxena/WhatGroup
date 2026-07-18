# Agent context — Ka0s WhatGroup

Full working notes for Claude Code (and other LLM-assisted editors) working on
**Ka0s WhatGroup**. The root [`CLAUDE.md`](../CLAUDE.md) is a stub that points
here; this is the complete brief. Read it before touching code.

This addon adheres to the Ka0s WoW Addon Standard —
<https://github.com/tusharsaxena/WowAddonStandards>.

## What this addon is

A retail WoW addon that hooks into the Premade Group Finder flow. It captures the group details visible at apply time and resurfaces them when the player joins, as a chat notification + popup dialog. The popup carries a teleport button for known dungeon teleport spells. Observation-only — never mutates LFG state.

User-facing reference: [README.md](../README.md). Design overview + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).

## Hard rules

- **Build against the Ka0s WoW Addon Standard, and flag every deviation.** The standard (<https://github.com/tusharsaxena/WowAddonStandards>, `standards/STANDARDS.md`) is the source of truth for structure, conventions, metadata, testing, and layout. This is spelled out in the root [`CLAUDE.md`](../CLAUDE.md) **"Standards compliance (read first)"** section — that section and this rule are the same policy. Check every change against it. If a change would deviate — or you find existing code/docs that already deviate — **stop and flag it to the user**; never silently conform or silently deviate. The user decides whether it's (1) an **accepted deviation** here (record it with an in-code SHOULD-justification comment, as the existing accepted deviations do) or (2) a **change to the standard definition** (a PR to the WowAddonStandards repo). The frozen compliance snapshot is in `docs/audits/2026-07-18/`.
- **Observation-only, direct `hooksecurefunc` only.** WhatGroup never mutates LFG state, never auto-applies, never blocks the join flow. Both hooks are direct Blizzard `hooksecurefunc` calls (one on `C_LFGList.ApplyToGroup`, one on `SetItemRef` filtered to `WhatGroup:` link clicks). **No AceHook usage** — AceHook's `SecureHook` / `RawHook` wrappers leave a per-invocation closure around the callback, and that closure taints Blizzard's secure-execute chain. The taint surfaces later as `ADDON_ACTION_FORBIDDEN ... 'callback()'` at `Blizzard_GameMenu/Shared/GameMenuFrame.lua:69` when the player clicks Logout. AceHook-3.0 has been removed from the addon's NewAddon mixin list and from `libs/` for this reason.
- **Private `NS` namespace, no global.** Every source file starts with `local addonName, NS = ...`. The AceAddon object is `NS.addon` (mixed into `NS`; downstream files alias `local WhatGroup = NS.addon`). There is **no `_G.WhatGroup`** (WG-01) — the addon exposes no public global. New standalone data/logic hangs on `NS.*` (e.g. `NS.Compat`, `NS.L`, `NS.State`, `NS.TeleportSpells`, `NS.PREFIX`). If a public surface is ever needed, expose only a versioned `NS.API.v1` via `_G[addonName]`, never the whole table.
- **Schema-first.** Adding a setting = one row in `Settings.Schema` (`settings/Schema.lua`). The panel widget, `/wg list/get/set`, AceDB defaults, and `/wg reset` all follow automatically. Don't reach into `db.profile` directly from new code; go through `Settings.Helpers.Get` / `Settings.Helpers.Set` so the panel refreshers stay in sync.
- **Slash-first.** Adding a command = one row in the `COMMANDS` table (`WhatGroup.lua`). Help output iterates the table.
- **Cyan `[WG]` chat prefix on all user-facing output.** The prefix is the single shared constant `NS.PREFIX = "\|cff00FFFF[WG]\|r"`. Every chat line funnels through one **secret-safe** printer — `NS.Util.print` (`core/Util.lua`), exposed as `NS.Print` / `WhatGroup._print` (aliased to a file-local `p` in `WhatGroup.lua`) — which prepends the prefix and runs every argument through `NS.SafeToString` so a combat-protected value can never raise in the chat path (events-frames-taint-§8 / WG-22). Pass label and value as **separate args**; never pre-concatenate through `..`/`tostring` at the call site (WG-23). No raw `print(...)` without the prefix. **Debug output does NOT go to chat** — route it through `NS.Debug(tag, …)`, which renders in the on-screen console (`DebugLog.lua`), styled like the main window, as the standard requires for any addon with a main window (debug-logging-§7). See [debug-console.md](./debug-console.md).
- **Debug is session-only, console-based.** Debug state lives in `NS.State.debug` (debug-logging-§5 / WG-12), default **off** on every login. `/wg debug` toggles the console **window**; `/wg debug on\|off` toggles logging — both through the single `NS.DebugLog:SetEnabled` seam. It is **not** a schema row and **never** persisted to SavedVariables. Don't reintroduce a `db.profile.debug`, and don't add a chat `[DBG]` sink — the console is the sink.
- **English-only, but the locale module is mandatory.** Every string the addon authors is routed through `NS.L[...]` (`locales/enUS.lua`), whose fall-back metatable returns the key so English needs no translation table. Localization *content* is a deliberate non-goal — see [scope.md](./scope.md) — but the locale *shell* (localization-§3 / WG-07) stays. Playstyle enum *values* still read Blizzard's `GROUP_FINDER_GENERAL_PLAYSTYLE1..4` globals; those are Blizzard's strings, not ours.
- **Retail-only.** Interface line in `WhatGroup.toc` is `120007`. The Premade Group Finder API surface and `Settings.RegisterCanvasLayoutCategory` shape are retail-specific.
- **Capture state is session-only.** `captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`, `notifiedFor`, and the `self.notifyTimer` handle never touch SavedVariables. Group-leave (and the master-switch off-flip) routes through `WhatGroup:WipeCapture()`, which clears all of them and `self:CancelTimer(self.notifyTimer)`s any in-flight notify callback (AceTimer-3.0, WG-17). Don't add a "remember last group across reloads" mode without explicit ask.
- **Single AceDB profile.** `AceDB:New("WhatGroupDB", defaults, true)` — third arg `true` shares one `Default` profile across every character on the account. Don't add per-character settings without explicit ask.
- **Don't overwrite `category.ID` with a string.** `Settings.OpenToCategory(category:GetID())` requires the auto-assigned integer ID. Stamping a string over it silently breaks the lookup.
- **Don't auto-stage, auto-commit, or auto-push.** The user chooses when to `git add` / `git stage`, `git commit`, and `git push`. Even after completing work, do not run any of those commands unless the user explicitly asks in the current turn. A prior approval does not carry forward. After making edits, leave the working tree in whatever modified-but-unstaged state your edits produced — describe what changed, do not stage it.
    - **Carve-out — `/wow-addon:commit`:** When the user invokes the `/wow-addon:commit` slash command (from their personal `wow-addon` plugin), that invocation IS the explicit per-turn instruction this rule asks for. Follow the command's flow (propose message → `y` confirmation → `git add <named files>` → `git commit`) and treat the user's `y` reply as authorization to stage and commit the proposed file set. This carve-out is narrow: it only applies when the user has explicitly invoked `/wow-addon:commit` (or equivalently typed "commit these"/"commit it" in plain language) in the current turn. It does NOT extend to other slash commands and does NOT mean a `y` to something else earlier in the session counts. Outside of an explicit commit instruction in the current turn, the no-auto-commit rule above still applies in full.
- **Don't bump the version without explicit instruction.** Never edit `## Version:` in `WhatGroup.toc`, `WhatGroup.VERSION` in `WhatGroup.lua`, the README version badge, or the README "Version History" table unless the user says so in the current turn. Refactors, feature additions, dep upgrades, and doc changes do not justify a bump — release versioning is the user's call. If a change feels release-worthy, mention it in the end-of-turn summary but leave the edit to the user.
- **Keep the test-case inventory & badge in lockstep with the suite (testing-§5).** When the suite changes — a case added/removed/renamed or the pass count moves (i.e. whenever a failing test is resolved) — regenerate `docs/test-cases.md` via `lua tests/run.lua --list` **and** update the README `tests` badge count **in the same change**, not as a follow-up. `docs/test-cases.md` is generated (never hand-edit) and is the authoritative pass count. Verify sync with `git diff --exit-code -- docs/test-cases.md` (git-native — CRLF-safe; the raw `diff <(…)` reports a spurious diff because `.gitattributes` stores `.md` as CRLF). See [testing.md](./testing.md).
- **Keep the `[wow]` badge in lockstep with the TOC `## Interface:` (documentation-§1 / toc-file-§3).** The static README `[wow]` badge (`WoW-<Expansion>_<X.Y.Z>-purple`) and `## Interface:` in `WhatGroup.toc` MUST show the same patch number and move together — on every Interface bump (via `/wow-addon:bump-interface`) update the badge in the **same change**, not as a follow-up. `[wow]` and `[tests]` are both static badges that go stale silently, so each rides the change that moves its source of truth (`[wow]` ↔ TOC `## Interface:`; `[tests]` ↔ regenerated `docs/test-cases.md`).

## Working environment

- **Dual-path WSL.** `/home/tushar/GIT/WhatGroup/` and `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup/` are the same repo via symlink. Either path works for git and file tools.
- **Headless tests + lint (commit gate).** `lua tests/run.lua` loads every source in TOC order under a WoW mock (`tests/wow_mock.lua` + `tests/loader.lua`, `setfenv` + `chunk(addonName, NS)`) and runs the suites (`test_util`, `test_compat`, `test_database`, `test_settings`, `test_slash`, `test_labels`, `test_capture`, `test_debuglog`). `luacheck .` must be clean (config in `.luacheckrc`). Both must be green before every commit (testing-§4). Pure logic is covered here; frame/panel rendering and taint are **not** — those stay manual.
- **Manual smoke tests.** `/wg test` exercises the full notify + popup flow without joining a real group; the panel's Test button hits the same `WhatGroup:RunTest()` code path. The checklist lives in [smoke-tests.md](./smoke-tests.md) — run the relevant section after any non-trivial change, after a patch, after a lib refresh, or before tagging a release. The **GameMenu → Logout taint check is the critical one** and can only be verified in-game.
- **Vendored libs.** `libs/` is copied verbatim from Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD/libs/`). Refresh by re-copying that directory. See [common-tasks.md](./common-tasks.md#refresh-embedded-libs).
- **`.gitattributes`** enforces CRLF line endings on disk for `.lua` / `.toc` / `.xml` (WoW client expectation).

## Response style for this repo

- **Terse.** State the change, not the deliberation.
- **Use `file_path:line_number` references** when pointing at code.
- **Don't write summaries** the user can read from the diff.
- **No comments explaining *what* well-named code does.** Only add a comment when the *why* is non-obvious (subtle invariant, workaround for a Blizzard quirk, hidden constraint).
- **Don't create docs or planning files unless asked.**
- **Match the existing patterns.** WhatGroup mirrors KickCD's slash-dispatch and schema-driven settings shape — when extending, look at the equivalent system in KickCD before inventing a new one.

## Doc index

Topic-specific detail lives in `docs/`. Read on demand — these are not auto-loaded.

| Topic | File | When to read |
|-------|------|--------------|
| Design overview, subsystem map, load order, invariants | [ARCHITECTURE.md](./ARCHITECTURE.md) | Orienting on the whole addon. |
| Per-file responsibility map | [file-index.md](./file-index.md) | "Which file owns X?" |
| Scope boundaries (in / out / resolved decisions) | [scope.md](./scope.md) | Evaluating a feature request; deciding whether a behaviour is in scope. |
| LFG capture pipeline + queue mechanics + `hooksecurefunc` on `SetItemRef` | [capture-pipeline.md](./capture-pipeline.md) | Touching event handling, capture flow, the `wasInGroup` join trigger, or chat-link hyperlinks. |
| Settings schema, panel renderer, helpers, db.profile shape | [settings-system.md](./settings-system.md) | Adding a setting, changing the panel layout, building schema-driven CLIs. |
| `/wg` slash UX + `COMMANDS` table | [slash-dispatch.md](./slash-dispatch.md) | Adding or modifying a slash command. |
| On-screen debug console + `NS.Debug` sink + `/wg debug` semantics | [debug-console.md](./debug-console.md) | Adding debug logging, changing the console, or the debug toggle. |
| Popup dialog (`WhatGroupFrame`) | [frame.md](./frame.md) | Touching the popup layout, value colours, or teleport button. |
| WoW API gotchas (hook discipline, Settings API, lazy panel build) | [wow-quirks.md](./wow-quirks.md) | Patch-day breakage, hook decisions, Settings API integration. |
| Recipes (add a setting, add a command, add a teleport, refresh libs, bump Interface) | [common-tasks.md](./common-tasks.md) | Routine modifications. |
| Verification model (green gate, `--list` inventory, badge sync-discipline) | [testing.md](./testing.md) | Changing tests, the runner, `docs/test-cases.md`, or the README `tests` badge. |
| Manual smoke tests (boot, slash, settings panel, /wg test, real LFG, regression checks) | [smoke-tests.md](./smoke-tests.md) | After any non-trivial change, after `/wow-addon:commit`, after a patch / lib refresh, before tagging a release. |

**Standard-shaped files**: `core/Compat.lua` (`NS.Compat.*` spell/LFG shims — the sole caller of version-variant APIs), `locales/enUS.lua` (`NS.L` shell), `core/Database.lua` (`NS:RunMigrations` + `global.schemaVersion`), `defaults/TeleportSpells.lua` (`NS.TeleportSpells`), `tests/` (headless harness), `.luacheckrc`, `.pkgmeta`. Every doc — this file, `ARCHITECTURE.md`, and the topic docs under `docs/` — describes the current private-`NS` namespace; there is no `_G.WhatGroup`.
