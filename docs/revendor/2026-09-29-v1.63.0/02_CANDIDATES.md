# Candidates (WhatGroup)

| # | Surface | What it offers | Blocker? |
|---|---|---|---|
| C1 | `Sl:CliProfile` / `Sl:ProfileSwitch` / descriptor `profiles` (Slash minor 17) | A `/wg profile [<name>]` verb: list the profiles, or switch to an existing one, with the combat refusal and the no-create rule the library owns. | Not a blocker, but the stub owes both members at once: the by-name parity case goes red on the copy alone. |
| C2 | `lib.ProfileNames(store)` | Sorted names and the current profile, for a host sub-tree of its own. | No. WhatGroup has no profile sub-tree; `CliProfile` covers the verb. |
