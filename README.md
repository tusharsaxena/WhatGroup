# WhatGroup

A World of Warcraft addon that notifies you of group details after joining via the Premade Group Finder.

## Features

- Displays a popup dialog with group info when you join a group through the LFG tool
- Shows group name, instance, type (Mythic+, Raid, Dungeon, PvP), and leader
- Teleport spell button (if you know the relevant teleport spell)
- Clickable chat link to re-open the info dialog after dismissing it
- Draggable frame, closeable with ESC

## Installation

1. Download or clone this repository
2. Copy the `WhatGroup` folder into your WoW addons directory:
   ```
   World of Warcraft\_retail_\Interface\AddOns\WhatGroup\
   ```
3. Restart WoW or reload your UI (`/reload`)

## Slash Commands

| Command | Description |
|---|---|
| `/wg` or `/wg show` | Re-open the last group info dialog |
| `/wg test` | Preview the dialog with fake test data |
| `/wg debug` | Toggle debug logging to chat |
| `/wg help` | Show command help |

## How It Works

1. When you click **Apply** on a group in the Premade Group Finder, WhatGroup captures the group's details.
2. When the group leader accepts your application, the capture is associated with that invite.
3. When you accept the invite and join the group, a chat notification is printed and the info dialog is shown automatically.

## Compatibility

- Retail WoW (Interface version 120001+)
- No saved variables — all state is session-only
