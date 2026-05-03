# CLAUDE.md — working notes for future sessions

Guidance for Claude Code (and other LLM-assisted editors) working on **Ka0s WhatGroup**. Read this first before touching code.

## What this addon is

A retail WoW addon that hooks into the Premade Group Finder flow. It captures the group details visible at apply time and resurfaces them when the player joins, as a chat notification + popup dialog. The popup carries a teleport button for known dungeon teleport spells. Observation-only — never mutates LFG state.

User-facing reference: [README.md](./README.md). Design overview + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).

## Hard rules

- **Observation-only, direct `hooksecurefunc` only.** WhatGroup never mutates LFG state, never auto-applies, never blocks the join flow. Both hooks are direct Blizzard `hooksecurefunc` calls (one on `C_LFGList.ApplyToGroup`, one on `SetItemRef` filtered to `WhatGroup:` link clicks). **No AceHook usage** — AceHook's `SecureHook` / `RawHook` wrappers leave a per-invocation closure around the callback, and that closure taints Blizzard's secure-execute chain. The taint surfaces later as `ADDON_ACTION_FORBIDDEN ... 'callback()'` at `Blizzard_GameMenu/Shared/GameMenuFrame.lua:69` when the player clicks Logout. AceHook-3.0 has been removed from the addon's NewAddon mixin list and from `libs/` for this reason.
- **Schema-first.** Adding a setting = one row in `Settings.Schema` (`WhatGroup_Settings.lua`). The panel widget, `/wg list/get/set`, AceDB defaults, and `/wg reset` all follow automatically. Don't reach into `db.profile` directly from new code; go through `Settings.Helpers.Get` / `Settings.Helpers.Set` so the panel refreshers stay in sync.
- **Slash-first.** Adding a command = one row in the `COMMANDS` table (`WhatGroup.lua`). Help output iterates the table.
- **Cyan `[WG]` chat prefix on all addon output.** Every `print(...)` in `WhatGroup.lua` goes through `CHAT_PREFIX = "\|cff00FFFF[WG]\|r"`. Debug lines additionally tag `[DBG]` in orange. No raw `print(...)` without the prefix.
- **English-only.** Schema labels, tooltips, chat prefix, and `WhatGroup.Labels.{GetGroupTypeLabel, PLAYSTYLE}` strings are all literal English. Localization plumbing is a deliberate non-goal — see [docs/scope.md](./docs/scope.md).
- **Retail-only.** Interface line in `WhatGroup.toc` is `120000,120001,120005`. The Premade Group Finder API surface and `Settings.RegisterCanvasLayoutCategory` shape are retail-specific.
- **Capture state is session-only.** `captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`, `notifiedFor` never touch SavedVariables. Group-leave wipes all five. Don't add a "remember last group across reloads" mode without explicit ask.
- **Single AceDB profile.** `AceDB:New("WhatGroupDB", defaults, true)` — third arg `true` shares one `Default` profile across every character on the account. Don't add per-character settings without explicit ask.
- **Don't overwrite `category.ID` with a string.** `Settings.OpenToCategory(category:GetID())` requires the auto-assigned integer ID. Stamping a string over it silently breaks the lookup.
- **Don't auto-stage, auto-commit, or auto-push.** The user chooses when to `git add` / `git stage`, `git commit`, and `git push`. Even after completing work, do not run any of those commands unless the user explicitly asks in the current turn. A prior approval does not carry forward. After making edits, leave the working tree in whatever modified-but-unstaged state your edits produced — describe what changed, do not stage it.
    - **Carve-out — `/wow-addon:commit`:** When the user invokes the `/wow-addon:commit` slash command (from their personal `wow-addon` plugin), that invocation IS the explicit per-turn instruction this rule asks for. Follow the command's flow (propose message → `y` confirmation → `git add <named files>` → `git commit`) and treat the user's `y` reply as authorization to stage and commit the proposed file set. This carve-out is narrow: it only applies when the user has explicitly invoked `/wow-addon:commit` (or equivalently typed "commit these"/"commit it" in plain language) in the current turn. It does NOT extend to other slash commands and does NOT mean a `y` to something else earlier in the session counts. Outside of an explicit commit instruction in the current turn, the no-auto-commit rule above still applies in full.
- **Don't bump the version without explicit instruction.** Never edit `## Version:` in `WhatGroup.toc`, `WhatGroup.VERSION` in `WhatGroup.lua`, the README version badge, or the README "Version History" table unless the user says so in the current turn. Refactors, feature additions, dep upgrades, and doc changes do not justify a bump — release versioning is the user's call. If a change feels release-worthy, mention it in the end-of-turn summary but leave the edit to the user.

## Working environment

- **Dual-path WSL.** `/home/tushar/GIT/WhatGroup/` and `/mnt/d/Profile/Users/Tushar/Documents/GIT/WhatGroup/` are the same repo via symlink. Either path works for git and file tools.
- **No automated tests.** Validation is manual, in-game. `/wg test` exercises the full notify + popup flow without joining a real group; the panel's Test button hits the same `WhatGroup:RunTest()` code path. The full manual smoke-test checklist lives in [docs/smoke-tests.md](./docs/smoke-tests.md) — run the relevant section after any non-trivial change, after a patch, after a lib refresh, or before tagging a release.
- **Vendored libs.** `libs/` is copied verbatim from Ka0s KickCD (`/mnt/d/Profile/Users/Tushar/Documents/GIT/KickCD/libs/`). Refresh by re-copying that directory. See [docs/common-tasks.md](./docs/common-tasks.md#refresh-embedded-libs).
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
| Per-file responsibility map | [docs/file-index.md](./docs/file-index.md) | "Which file owns X?" |
| Scope boundaries (in / out / resolved decisions) | [docs/scope.md](./docs/scope.md) | Evaluating a feature request; deciding whether a behaviour is in scope. |
| LFG capture pipeline + queue mechanics + `hooksecurefunc` on `SetItemRef` | [docs/capture-pipeline.md](./docs/capture-pipeline.md) | Touching event handling, capture flow, the `wasInGroup` join trigger, or chat-link hyperlinks. |
| Settings schema, panel renderer, helpers, db.profile shape | [docs/settings-system.md](./docs/settings-system.md) | Adding a setting, changing the panel layout, building schema-driven CLIs. |
| `/wg` slash UX + `COMMANDS` table | [docs/slash-dispatch.md](./docs/slash-dispatch.md) | Adding or modifying a slash command. |
| Popup dialog (`WhatGroupFrame`) | [docs/frame.md](./docs/frame.md) | Touching the popup layout, value colours, or teleport button. |
| WoW API gotchas (hook discipline, Settings API, lazy panel build) | [docs/wow-quirks.md](./docs/wow-quirks.md) | Patch-day breakage, hook decisions, Settings API integration. |
| Recipes (add a setting, add a command, add a teleport, refresh libs, bump Interface) | [docs/common-tasks.md](./docs/common-tasks.md) | Routine modifications. |
| Manual smoke tests (boot, slash, settings panel, /wg test, real LFG, regression checks) | [docs/smoke-tests.md](./docs/smoke-tests.md) | After any non-trivial change, after `/wow-addon:commit`, after a patch / lib refresh, before tagging a release. |
