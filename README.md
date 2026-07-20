# Ka0s WhatGroup

![WoW](https://img.shields.io/badge/WoW-Midnight_12.0.7-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1489907)
![License](https://img.shields.io/badge/License-MIT-orange)
[![Standard](https://img.shields.io/badge/Ka0s-WoW%20Addon%20Standard-yellow)](https://github.com/tusharsaxena/WowAddonStandards)
![Tests](https://img.shields.io/badge/Tests-61%2F61_passing-green)

![Logo](https://media.forgecdn.net/attachments/1794/926/whatgroup-logo-png.png)

WhatGroup remembers the details of any group you join through the Premade Group Finder, so you can close the LFG window and still know what you signed up for. It shows those details two ways:

*   A **chat message** a moment after you join. It lists the group name, the instance, the type (Mythic+, Raid, Dungeon, PvP, and so on), the leader, and the group's playstyle. If the dungeon has a teleport spell, that's shown too (tagged if you haven't learned it), plus a "view details" link that re-opens the popup.
*   A **popup window** with the same details and a teleport button for the dungeon (grayed out until you learn the spell). Drag it anywhere, close it with `ESC`, or re-open it with `/wg show` while you're still in the group.

Every chat line starts with a cyan `[WG]` tag. Set things up in the Blizzard Settings panel, or with the `/wg` commands below.

## What's new in 1.3.0

*   The **Ka0s WhatGroup** page now shows up in the game's AddOns settings list the moment you log in — you no longer have to run `/wg config` first to make it appear.
*   The chat message and popup now appear **instantly** when you join a group. Prefer a short pause? Set a delay under **Notify**.
*   A new **on-screen debug window** — open or close it with `/wg debug` (or the **Debug console** box in **General**). Debug output goes there instead of cluttering your chat.
*   Output from `/wg list`, `/wg get`, and `/wg set` is now **colour-coded** and easier to read at a glance.
*   The **Defaults** button now does a full, clean reset — no leftover settings survive it.
*   Updated for game patch **12.0.7**.

## Screenshots

**_Popup Dialog_**

![Popup Dialog](https://media.forgecdn.net/attachments/1806/616/whatgroup-screenshot-01-png.png)

**_Chat Message with Clickable Link_**

![Chat Message with Clickable Link](https://media.forgecdn.net/attachments/1806/617/whatgroup-screenshot-02-png.png)

**_Settings Panel_**

![Settings Panel](https://media.forgecdn.net/attachments/1806/618/whatgroup-screenshot-03-png.png)

## Usage

### Slash commands

`/wg` is the short form and `/whatgroup` is the long form; both take the same commands, and every reply is tagged with `[WG]`.

| Command | What it does |
|---|---|
| `/wg` or `/wg help` | Show the list of commands |
| `/wg show` | Re-open the last group popup (while you're still in that group) |
| `/wg test` | Preview the chat message and popup with sample data — also a **Test** button in the Settings panel |
| `/wg config` | Open the Settings panel |
| `/wg version` | Print the addon version |
| `/wg list` | Show every setting and its current value |
| `/wg get <name>` | Show one setting's current value |
| `/wg set <name> <value>` | Change a setting. On/off settings accept `on`, `off`, or `toggle`; number settings stay within their allowed range |
| `/wg reset` | Reset every setting to its default |
| `/wg debug` | Open or close the on-screen debug window |
| `/wg debug on` / `/wg debug off` | Turn debug logging on or off (resets to off each login) |
| `/whatgroup` | Long-form alias for `/wg` |

### Settings panel

`/wg config` opens the Blizzard Settings panel. It starts on the **Ka0s WhatGroup** landing page (logo, notes, and the command list); click **General** in the sidebar to reach the options.

| Tab | Covers |
|---|---|
| General | Every setting, with a **Notify** section below it, plus a **Test** button and a **Defaults** reset |

**General** — turn the addon on or off, show the popup automatically when you join, and print the chat message or not. The **Test** button previews the whole thing with sample data, and the **Defaults** button in the top-right resets every setting after a confirmation. There's also a **Debug console** checkbox, but it only shows or hides the debug window — it isn't a saved setting and doesn't turn logging on (use `/wg debug` for that).

**Notify** (a section within General) — set how long to wait before the message appears (0–10 seconds), and toggle each line the chat message can include: instance, type, leader, playstyle, the "view details" link, and the teleport spell. These toggles only change the chat message; the popup always shows everything.

## How it works

When you click **Apply** in the Premade Group Finder, WhatGroup quietly notes the group's details. It keeps track of your application so the right group info is waiting for you when you join — even if you've applied to several groups at once. When you join, the chat message prints and the popup opens — instantly by default, or after the delay you set under **Notify** if you'd rather let the zone-in settle first.

The group info is only remembered for your current play session and clears when you leave the group. Only your settings are saved between sessions (plus where you've dragged the popup and debug windows). For the technical details, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## FAQ

| Question | Answer |
|---|---|
| Does this work for cross-realm or cross-faction groups? | Yes. WhatGroup just reads whatever the group finder shows it, so realm, faction, and category don't matter. |
| Is anything saved between sessions? | Your settings, plus where you've dragged the popup and debug windows. The group info itself is session-only — it clears the moment you leave the group, so `/wg show` only works while you're still in it. |
| How do I preview the popup without joining a real group? | Use `/wg test`, or the **Test** button in Settings. Both run the full message and popup with sample data. |
| Can I delay the message and popup instead of getting them instantly? | Yes. They appear instantly by default; set a pause under **Notify → Notification Delay** (0–10 seconds). |
| What is the **Debug console**, and how do I turn on debug logging? | `/wg debug` opens the on-screen debug window; `/wg debug on` starts logging into it, `off` stops it. Logging is session-only and starts off after every login. The **Debug console** checkbox in **General** only shows or hides the window — it doesn't turn logging on. |
| Why is the teleport button or teleport line grayed out or missing? | Either you haven't learned the spell (the button grays out and the chat line is tagged), or that dungeon has no teleport (the line is skipped). |
| Can I keep the chat message but hide the popup, or the reverse? | Yes. Turn **Auto Show** off to skip the popup, or **Print to Chat** off to skip the message. They work independently. |
| Are there per-character settings? | No. Your settings are shared across all your characters. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The popup never appears when I join a group | Make sure both **Enable** and **Auto Show** are turned on in the **General** settings. If you joined while in combat, the popup is held until combat ends ("Popup deferred until combat ends.") and opens the moment you drop out. |
| The chat message is missing some lines | The per-line toggles under **Notify** control what the chat message includes. The popup always shows every line. |
| `/wg show` says "No group info available" | The group info clears when you leave the group, so `/wg show` only works while you're still in it. Use `/wg test` to preview the popup instead. |
| The teleport button is grayed out | You haven't learned that dungeon's teleport spell on this character, or the dungeon has no teleport. |
| I opened Settings but can't find the toggles | `/wg config` lands on the landing page; click **General** in the sidebar to reach the options. |
| `/wg config` says "cannot open settings during combat" and nothing opens | The Blizzard settings panel can't be opened in combat. Leave combat and run `/wg config` again. |
| I ticked **Debug console** but no debug output shows up | That checkbox only shows or hides the debug window. Turn logging on with `/wg debug on` (or the **Debug: OFF** button inside the window). Logging always starts off after a login or `/reload`. |

## Issues and feature requests

All bugs, feature requests, and outstanding work are tracked at [https://github.com/tusharsaxena/WhatGroup/issues](https://github.com/tusharsaxena/WhatGroup/issues). Please file new reports there rather than as comments — the issue tracker is the single source of truth for the project's backlog.

## Version History

| Version | Date | Highlights |
|---|---|---|
| 1.3.0 | 2026-07-12 | The Settings page now appears in the AddOns list as soon as you log in.<br>The chat message and popup appear instantly on join (add a delay under Notify if you prefer).<br>New on-screen debug window, toggled with `/wg debug`; debug output no longer goes to chat.<br>Colour-coded `/wg list`, `/wg get`, and `/wg set` output.<br>The Defaults button now performs a full, clean reset.<br>Updated for game patch 12.0.7. |
| 1.2.0 | 2026-05-03 | Added the Settings panel and the `/wg` slash commands.<br>Added a teleport button to the popup, grayed out until you learn the spell.<br>Fixed a logout error, stale notification timers, and the wrong teleport spell and playstyle showing on real group joins. |
| 1.1.0 | 2026-04-24 | Updated for a new game patch. |
| 1.0.0 | 2026-03-19 | Initial release: a chat message and popup whenever you join a group through the Premade Group Finder. |
