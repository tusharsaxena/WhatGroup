# Decisions (WhatGroup)

Decided by the orchestrated run under the owner's delegation (no interview); reasoning recorded here.

| # | Surface | Decision | Reasoning | Issue |
|---|---|---|---|---|
| C1 | WidgetsDragHandle 4 `tooltipPlace` | **declined: not applicable** | The hook places the tooltip of a `LibKa0s-Widgets-1.0` drag strip. WhatGroup creates no drag strip: it looks up no Widgets major (01_DELTA 3e) and `grep -rn 'DragHandle\|tooltipPlace' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds only `tests/loader.lua:44`, the payload load list. There is no tooltip for the hook to place, so this is not a gap. | none filed: not a real gap (plan rule: a decline is filed only when its reason is a real gap) |

Should WhatGroup ever draw a drag strip, the hook is available from v1.68.0 and is the way to put
its tooltip beside the strip.
