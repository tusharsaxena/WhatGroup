# Ka0s WhatGroup

![wow](https://img.shields.io/badge/WoW-Midnight_12.0.5-orange)
![CurseForge Version](https://img.shields.io/curseforge/v/1489907)
![license](https://img.shields.io/badge/license-MIT-green)

![alt text](https://media.forgecdn.net/attachments/1588/403/whatgroup-logo-png.png)

WhatGroup is a lightweight, single-folder WoW addon that surfaces the details of any group you join through the Premade Group Finder, so you don't have to keep the LFG window open just to remember what you signed up for. It pairs two pieces of UI:

*   A **chat notification** printed a moment after you join: group name, instance, type (Mythic+ / Raid / Dungeon / PvP / …), leader, playstyle (Learning / Fun (Relaxed) / Fun (Serious) / Expert — using the LFG UI's own labels), the dungeon's teleport spell (with a "not learned" tag if you don't have it), and a clickable `[Click here to view details]` link to re-open the popup.
*   A **popup dialog** with the same fields plus a teleport button for known dungeon teleport spells (grayed out if not learned). Draggable, closeable with `ESC`, and re-openable any time the group is still active via `/wg show` or the chat link.

Every chat line is prefixed with a cyan `[WG]` banner. Every option is configurable through the standard Blizzard Settings panel and through the `/wg` slash command (every panel control has a CLI peer via `/wg get` / `/wg set`).

## Screenshots

**_Popup Dialog_**

![Popup Dialog](https://media.forgecdn.net/attachments/1588/404/dialog-png.png)

**_Chat Message_**

![Chat Message](https://media.forgecdn.net/attachments/1588/405/chat-png.png)

## Usage

### Slash commands

| Command | Description |
|---|---|
| `/wg` or `/wg help` | Print the help index |
| `/wg show` | Re-open the last group info popup (only while you're still in that group) |
| `/wg test` | Preview the chat notification + popup with synthetic data — also available as a **Test** button in the Settings panel |
| `/wg config` | Open the Settings panel on the addon's landing page, with the subcategory tree unfolded |
| `/wg list` | Print every setting and its current value |
| `/wg get <path>` | Print one setting's current value |
| `/wg set <path> <value>` | Update a setting. Bools accept `true / false / on / off / 1 / 0 / yes / no / toggle`; numbers clamp to the option's min/max |
| `/wg reset` | Reset every setting to its default |
| `/wg debug` | Toggle debug logging (persisted across sessions) |
| `/whatgroup` | Long-form alias for `/wg` — accepts the same subcommands |

### Settings panel

`/wg config` opens the Blizzard Settings panel on **Ka0s WhatGroup**'s landing page (logo, addon notes, slash-command list) with the subcategory tree unfolded so **General** is one click away in the sidebar.

The **General** subcategory holds every setting in a two-column layout with a **Notify** sub-section further down. The page header carries a **Defaults** button on the right that resets every setting after a confirm prompt — same code path as `/wg reset`.

*   **General** — master enable, popup auto-show on group join, chat notification on/off, debug log, and a **Test** button that runs the full notify + popup flow against synthetic data.
*   **Notify** — notification delay (0–10s) plus per-line gates for the chat notification: Instance, Type, Leader, Playstyle, the "Click here" link, and the dungeon teleport spell line. Each toggle controls **chat output only** — the popup always shows every field.

## How It Works

When you click **Apply** in the Premade Group Finder, WhatGroup quietly snapshots the group's details from the search-result tile. It tracks the application across the LFG state machine so the right group info ends up paired with the right invite, even when several applications are in flight at once. Once you actually join the group, the chat notification prints and the popup opens — both fired after `notify.delay` seconds so the zone-in has time to settle.

Capture state is session-only and clears when you leave the group; only your settings persist between sessions. For the full event flow, hooks, and capture-pipeline diagram see [ARCHITECTURE.md](ARCHITECTURE.md).

## FAQ

| Question | Answer |
|---|---|
| Does this work for cross-realm or cross-faction groups? | Yes — WhatGroup just reads whatever the LFG API hands it. Realm, faction, and category don't matter. |
| Is anything saved between sessions? | Only your settings (in `WhatGroupDB`). The captured group info is session-only and clears the moment you leave the group, so `/wg show` only works while you're still grouped. |
| How do I preview the popup without joining a real group? | `/wg test`, or the **Test** button in Settings. Both run the full notification + popup flow against synthetic data. |
| Why is the teleport button or chat teleport line grayed / missing? | Either you don't know the spell (popup grays the button, chat tags `(not learned)`), or the activity has no teleport mapping (popup hides the row, chat skips the line). |
| Can I disable the popup but keep the chat message (or vice versa)? | Yes — toggle **Auto Show** off to skip the popup, or **Print to Chat** off to skip the chat summary. The two are independent. |
| Are there profiles? Per-character configs? | Settings live in a single shared profile. There's no Profiles panel exposed in the UI. |

## Troubleshooting

| Symptom | Resolution |
|---|---|
| Popup never appears when I join a group | Check `/wg get enabled` (master switch) and `/wg get frame.autoShow` — both must be `true`. If they are, run `/wg debug` and re-apply to a group; the log will tell you which capture stage didn't fire. |
| Chat notification is missing fields | The per-line `notify.show*` toggles are independent. The popup always shows every field; the toggles only affect chat output. |
| `/wg show` says "No group info available" | The captured info clears when you leave the group, so `/wg show` only works while you're still in that group. Use `/wg test` if you just want to preview the popup. |
| Teleport button is grayed out for a dungeon I'm in | Either the spell isn't learned on the current character, or the activity has no teleport mapping. The popup always renders the row; the button is disabled when the spell isn't castable. |
| Settings panel opens but I can't find the toggles | `/wg config` lands on the addon's landing page (logo + slash list) with the subcategory tree unfolded — click **General** in the sidebar to reach the toggles. |

## For contributors

WhatGroup has no automated test suite — validation is manual, in-game. Before opening a PR or tagging a release, run the relevant section of the [manual smoke-test checklist](docs/smoke-tests.md) (boot health, slash commands, settings panel, `/wg test`, real LFG flow, regression checks). The Quick reference checklist at the bottom of that file is the minimum 80%-coverage pass.

## Issues and feature requests

All bugs, feature requests, and outstanding work are tracked at [https://github.com/tusharsaxena/WhatGroup/issues](https://github.com/tusharsaxena/WhatGroup/issues). Please file new reports there rather than as comments — the issue tracker is the single source of truth for the project's backlog.

## Version History

| Version | Notes |
|---|---|
| 1.2.0 | Added schema-driven Settings panel with `/wg config` (scrollable General page, Defaults button, AceDB profile)<br>Added `/wg list`, `/wg get`, `/wg set`, `/wg reset`, `/wg debug`, `/wg test` slash commands<br>Added popup teleport button keyed to mapID, grayed when not learned<br>Added atlas-chevron breadcrumb separator (`Ka0s WhatGroup ▸ <Page>`) — font/locale-agnostic inline texture<br>Fixed Logout taint by deferring secure-button config, frame build, and Settings registration past combat / boot<br>Fixed stale notify timers via `notifyGen` generation-counter and `WipeCapture` consolidator<br>Fixed popup teleport and playstyle for real-world LFG joins<br>Internals: Ace3 adoption, schema-first settings, orchestrated `Helpers.Set`, deterministic refresh order, English-only `WhatGroup.Labels` namespace |
| 1.1.0 | TOC version bump |
| 1.0.0 | Initial Release … yay! |
