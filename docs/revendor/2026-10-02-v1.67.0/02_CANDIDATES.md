# Candidates (WhatGroup)

Listed, **not interviewed**: the 2026-10-02 census adoption bundle already assigns each new surface
to an item, so this re-vendor routes rather than asks.

| # | Class | Surface | Evidence | Would touch | Taken by | Blast radius |
|---|---|---|---|---|---|---|
| C1 | B | Options 28: the descriptor's `addonName` (recommended for every host) | CHANGELOG v1.67.0 `### OptionsIdList minor 3 and Options minor 28`; `docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md:48-65` | `settings/OptionsSetup.lua:13` (`local _, NS = ...`) and the descriptor at `:192` | **CA-WG-NM** (LibKa0s#42) | Two tokens; latent here, since WhatGroup draws no id list |
| C2 | — | Core 10 `MakeResizable` `canResize` / `onResizeStop` / `gripParent` | CHANGELOG v1.67.0 `### Core minor 10`; `docs/api/Core/version-10-docs.md:32-34` | none | **none**: WhatGroup has no grip of its own | none |
| C3 | A | OptionsIdList 3 loaded-addon rung and its `Cfg` line | CHANGELOG v1.67.0 | none | Delivered on the copy (no id list here) | none |

This host's adoption item in the census bundle: **CA-WG-NM** only.
