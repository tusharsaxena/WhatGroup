# Ka0s WhatGroup

![WoW](https://img.shields.io/badge/WoW-Midnight_12.1.0-purple)
![CurseForge Version](https://img.shields.io/curseforge/v/1489907)
![License](https://img.shields.io/badge/License-MIT-orange)
![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
![Tests](https://img.shields.io/badge/Tests-824%2F824_passing-green)

WhatGroup remembers the group you signed up for through the Group Finder tool. You get accepted, you shut the LFG window, and the details are still in front of you: the group's name, the instance, the type (Mythic+, Raid, Dungeon, PvP and the rest), who's leading, and the playstyle.

It tells you twice, on purpose. A moment after you join, a chat line appears with a cyan `[WG]` tag in front and a "view details" link at the end. A popup window shows the same fields, plus a teleport button for the dungeon. You can trim the chat line down to the fields you care about. The popup always shows everything.

## Screenshots

**_Popup dialog_**

![Popup dialog](https://media.forgecdn.net/attachments/1936/728/whatgroup-screenshot-01-png.png)

**_Chat message with clickable link_**

![Chat message with clickable link](https://media.forgecdn.net/attachments/1936/729/whatgroup-screenshot-02-png.png)

## Usage

WhatGroup starts working as soon as it loads. You don't have to switch anything on. Apply to a group through the Premade Group Finder and join it, and the summary prints while the popup opens. That happens instantly, unless you've asked for a pause of up to ten seconds under **Chat**. If you join in the middle of a fight, the popup waits, tells you it's waiting, and opens the second you drop out of combat.

The popup has six rows: group, instance, type, leader, playstyle and the teleport. That last one is the row people install this for. It's a real spell button, so clicking it casts. It stays grayed out until you've learned that dungeon's teleport, and goes gray again while the spell recharges, with the time left spelled out beside the icon and a cooldown swipe over it. If a dungeon has no teleport at all, the row is skipped. The chat line marks the same states with `(not learned)` and `(on cooldown)`.

Drag the window by its title bar and it remembers where you left it. `ESC` or the Close button puts it away, and `/wg show` or the "view details" link brings it back, as long as you're still in the group.

You can watch the whole thing without joining anything. `/wg test notify` runs it once on sample data, and so does the **Test** button on the **Chat** tab. To put the popup where you want it, type `/wg test` or tick **Test mode** on the **Master controls** tab. The popup comes up with a sample group and stays up while you drag it around. It goes away when you run `/wg test` again, untick the box, close the popup, or get into a fight.

Three tabs hold the options. On the **Chat** tab, six toggles decide what the join summary contains: instance, type, leader, playstyle, the link and the teleport spell. **Print to Chat** turns the message off entirely. Its mirror is **Open Automatically** under **Popup**, which skips the window and leaves you the chat line. **Width** and **Height** sit next to it.

The **Master controls** tab is the same in every Ka0s addon, so if you want to turn an addon off, make it smaller or put it back where it was, you always look in the same place. It has **Enable WhatGroup**, **General visibility** (always, only in combat, only out of combat, or never), **Master scale**, **Master alpha**, **Lock frame** for when you keep nudging the window by accident, **Debug console**, **Minimap button** and **Test mode**, then **Reset position** and **Reset all settings** at the end. [docs/settings-panel.md](docs/settings-panel.md#the-tab-strip) lists every row on every tab and where each one is stored.

There's a minimap button too, with the addon's own logo on it. Left-click opens Settings. Right-click opens a small menu of checkboxes: **Enabled**, **Locked** (the popup's Lock frame), **Test mode** and **Show window** (the group popup). Each one does exactly what its slash command does. While the addon is switched off, Enabled is the only one you can click, and the rest are grayed out with a note telling you to enable the addon first. Hover over the button and the tooltip shows where things stand with **Enabled**, **Locked** and **Test mode**. It still answers while the addon is switched off.

The same entry shows up in Titan Panel, ElvUI data texts or any other broker display you run. It's the same button as the one on the minimap, shown in a second place. To hide it, untick **Minimap button** on the **Master controls** tab. WhatGroup remembers that choice per installation, so switching profiles won't move your buttons around, and **Reset all settings** won't bring a hidden one back.

You can do all of this from chat as well. `/wg config` opens the panel. `/wg enable` and `/wg disable` turn the addon on and off without opening anything. `/wg test` flips test mode, and `on` or `off` sets it. `/wg list` prints every setting with its value, and `/wg get` and `/wg set` read and write a single setting by path (switches take `on`, `off` or `toggle`). `/wg reset path` restores one setting, `/wg resetall` restores the lot after asking you to confirm, and `/wg version` prints the build you're running.

When something misbehaves, `/wg debug on` starts logging and `/wg debug` opens the window that holds the log. `/wg diagnostics` adds a report on the addon's state to the same window. [Reporting a bug](#reporting-a-bug) has the three steps for a bug report.

Everything else is configuration. It lives on the **Ka0s WhatGroup** page in the game's Settings → AddOns list, and `/wg` (or `/whatgroup`) opens that page for you. `/wg help` prints the full command list.

## How it works

When you click **Apply** in the Premade Group Finder, WhatGroup writes down what the tile said. Applications queue, so having four in flight at once doesn't confuse it. When an invite lands, the details waiting for you belong to the group you actually joined. Then the chat message prints and the popup opens. By default that's instant. If you'd rather let the zone-in settle first, set a pause under **Chat → Notification Delay**.

The group info doesn't outlive the session. WhatGroup drops it the moment you leave the group, which is why `/wg show` stops answering then. Your settings persist, and so does the spot you dragged the popup to. If you want to see how it's built, read [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## FAQ

| Question | Answer |
|---|---|
| Does this work for cross-realm or cross-faction groups? | Yes. WhatGroup reads whatever the group finder shows it, so realm, faction and category don't matter. |
| Is anything saved between sessions? | Your settings, plus the place you dragged the popup to. The debug console's position isn't saved. The group info itself is session-only. It clears the moment you leave the group, so `/wg show` only works while you're still in it. |
| How do I preview the popup without joining a real group? | `/wg test notify`, or the **Test** button in Settings. Both run the full message and popup on sample data, once. To keep the popup up while you move it, type `/wg test` or tick **Test mode** on the **Master controls** tab. |
| Can I delay the message and popup instead of getting them instantly? | Yes. They appear instantly by default; set a pause under **Chat → Notification Delay** (0-10 seconds). |
| What is the **Debug console**, and how do I turn on debug logging? | `/wg debug` opens the on-screen window; `/wg debug on` starts logging into it, `off` stops it. Logging is session-only and starts off after every login. The **Debug console** checkbox only shows or hides the window; it doesn't turn logging on. |
| Why is the teleport button or teleport line grayed out or missing? | Three reasons, and the popup says which: you haven't learned the spell (`Teleport spell not learned` beside the button), you have it but it's still recharging (`On cooldown — 7h 58m 12s`, counting down, with a cooldown swipe over the icon), or that dungeon has no teleport at all, in which case the row is skipped. |
| Can I keep the chat message but hide the popup, or the reverse? | Yes. Turn **Popup → Open Automatically** off to skip the popup, or **Chat → Print to Chat** off to skip the message. They work independently. |
| Can I make the popup bigger or smaller? | Yes. **Popup → Width** and **Popup → Height** move it between 320-700 and 200-520 pixels; it ships at 420 x 260. Dragging still remembers where you left it. |
| Are there per-character settings? | No. Your settings are shared across all your characters. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| The popup never appears when I join a group | Check that **Enable WhatGroup** (the **Master controls** tab) and **Open Automatically** (the **Popup** tab) are both on. If you joined while fighting, the popup is held ("Popup deferred until combat ends.") and opens when you drop out. |
| The chat message is missing some lines | The per-line toggles on the **Chat** tab control what the chat message includes. The popup always shows every line. |
| `/wg show` says "No group info available" | The group info clears when you leave the group, so `/wg show` only works while you're still in it. Use `/wg test` to preview the popup instead. |
| The teleport button is grayed out | You haven't learned that dungeon's teleport spell on this character, or the dungeon has no teleport. |
| I opened Settings but can't find the toggles | `/wg config` lands on the landing page. Click **General** in the sidebar. |
| `/wg config` says "cannot open settings during combat" and nothing opens | The Blizzard settings panel can't be opened in combat. Leave combat and run it again. |
| **Test mode** turned itself off | It ends when a fight starts, when you close the popup, and when you ask for the real one (`/wg show`, `/wg test notify`, or the chat link). It also won't start during combat. Joining a group while it's on doesn't end it; click the chat link to see that group. |
| I ticked **Debug console** but no debug output shows up | That checkbox only shows or hides the window. Turn logging on with `/wg debug on`, or the **Debug: OFF** button inside the window itself. Logging always starts off after a login or `/reload`. |
| Something looks wrong and I want to report it | Follow [Reporting a bug](#reporting-a-bug) below. |

## Reporting a bug

1. Type `/wg debug on` and reproduce the bug.
2. Type `/wg diagnostics`.
3. If the debug window isn't open, open it with `/wg debug`. Press **Copy**, copy the entire output, and include it with your bug report.

The report is added after the debug trace in the same window, so one copy carries both.

## Issues and feature requests

Bugs, feature requests and outstanding work are all tracked at [https://github.com/tusharsaxena/WhatGroup/issues](https://github.com/tusharsaxena/WhatGroup/issues). Please file new reports there rather than as comments. The issue tracker is the one place the project's backlog is kept.

## Version History

| Version | Date | Highlights |
|---|---|---|
| 1.4.0 | 2026-09-10 | - **Show** and **Close** are now combat-safe: the popup is no longer asked to hide while protected<br>- A popup you closed stays closed instead of returning on the next update<br>- The visibility gate is re-asked when combat starts and ends<br>- Each capture is paired to its own application rather than to whichever answered first<br>- Updated for game patch 12.1.0 |
| 1.3.0 | 2026-07-12 | - The Settings page now appears in the AddOns list as soon as you log in.<br>- The chat message and popup appear instantly on join (add a delay under Chat if you prefer).<br>- New on-screen debug window, toggled with `/wg debug`; debug output no longer goes to chat.<br>- Color-coded `/wg list`, `/wg get`, and `/wg set` output.<br>- The Defaults button now performs a full, clean reset.<br>- Updated for game patch 12.0.7. |
| 1.2.0 | 2026-05-03 | - Added the Settings panel and the `/wg` slash commands.<br>- Added a teleport button to the popup, grayed out until you learn the spell.<br>- Fixed a logout error, stale notification timers, and the wrong teleport spell and playstyle showing on real group joins. |
| 1.1.0 | 2026-04-24 | - Updated for a new game patch. |
| 1.0.0 | 2026-03-19 | - Initial release: a chat message and popup whenever you join a group through the Premade Group Finder. |
