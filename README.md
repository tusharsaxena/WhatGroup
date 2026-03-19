![alt text](https://media.forgecdn.net/attachments/1588/403/whatgroup-logo-png.png)

# Ka0s WhatGroup

A World of Warcraft addon that notifies you of group details after joining via the Premade Group Finder.

## Features

- Displays a popup dialog with group info when you join a group through the LFG tool
- Shows group name, instance, type (Mythic+, Raid, Dungeon, PvP), leader, and playstyle (Casual/Moderate/Serious)
- Teleport spell button for known dungeon teleport spells (grayed out if not learned)
- Clickable chat link to re-open the info dialog after dismissing it
- Draggable frame, closeable with ESC
- No settings or SavedVariables — just install and go

## Screenshots

***Popup Dialog***

![Popup Dialog](https://media.forgecdn.net/attachments/1588/404/dialog-png.png)

***Chat Message***

![Chat Message](https://media.forgecdn.net/attachments/1588/405/chat-png.png)

## Slash Commands

| Command | Description |
|---|---|
| `/wg` or `/wg show` | Re-open the last group info dialog |
| `/wg test` | Preview the dialog with fake test data |
| `/wg debug` | Toggle debug logging to chat |
| `/wg help` | Show command help |
| `/whatgroup <cmd>` | Alias — same commands as `/wg` |

## How It Works

1. When you click **Apply** on a group in the Premade Group Finder, WhatGroup captures the group's details.
2. When the group leader accepts your application, the capture is associated with that application ID.
3. When you accept the invite and join the group, a chat notification is printed and the info dialog pops up automatically.

## Compatibility

- Retail WoW (Interface version 120001+)

## Version History

**v1.0.0**

*   Initial Release … yay!