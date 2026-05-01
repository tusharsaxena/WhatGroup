# Ka0s WhatGroup

![version](https://img.shields.io/badge/version-1.1.0-blue)
![wow](https://img.shields.io/badge/WoW-Midnight%2012.0.5-orange)
![license](https://img.shields.io/badge/license-MIT-green)

![alt text](https://media.forgecdn.net/attachments/1588/403/whatgroup-logo-png.png)

A World of Warcraft addon that notifies you of group details after joining via the Premade Group Finder.

## Features

*   Displays a popup dialog with group info when you join a group through the LFG tool
*   Shows group name, instance, type (Mythic+, Raid, Dungeon, PvP), leader, and playstyle (Casual/Moderate/Serious)
*   Teleport spell button for known dungeon teleport spells (grayed out if not learned)
*   Clickable chat link to re-open the info dialog after dismissing it
*   Draggable frame, closeable with ESC
*   No settings or SavedVariables — just install and go

## Screenshots

**_Popup Dialog_**

![Popup Dialog](https://media.forgecdn.net/attachments/1588/404/dialog-png.png)

**_Chat Message_**

![Chat Message](https://media.forgecdn.net/attachments/1588/405/chat-png.png)

## Slash Commands

| Command          |Description                            |
| ---------------- |-------------------------------------- |
| <code>/wg</code> or <code>/wg show</code> |Re-open the last group info dialog     |
| <code>/wg test</code> |Preview the dialog with fake test data |
| <code>/wg debug</code> |Toggle debug logging to chat           |
| <code>/wg help</code> |Show command help                      |
| <code>/whatgroup &lt;cmd&gt;</code> |Alias — same commands as <code>/wg</code> |

## How It Works

1.  When you click **Apply** on a group in the Premade Group Finder, WhatGroup captures the group's details.
2.  When the group leader accepts your application, the capture is associated with that application ID.
3.  When you accept the invite and join the group, a chat notification is printed and the info dialog pops up automatically.

## Bug Reports

Please report any issues in the [Issues](https://github.com/tusharsaxena/WhatGroup/issues) tab, not as a comment!

## Version History

**1.1.0**

*   TOC version bump

**1.0.0**

*   Initial Release … yay!