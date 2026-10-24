# Decisions (WhatGroup, LibKa0s v1.76.0 to v1.77.0)

This run had no interview and filed no GitHub issue. The item spec for WG-RV rules that the
adoptions this run needs are the WG-KB and WG-ZS items, and that every other candidate is recorded
as deferred (run 2026-10-24), with nothing filed.

| Candidate | Decision | Source |
|---|---|---|
| Keybindings tab (`KeybindingsTab`, `KeybindRows`, `KEYBINDS_UNCHANGED`) | Adopted by WG-KB | item WG-KB; OWNER_SCOPE 015 |
| Kit 42 `mock_bindings.lua`, `assertBindingsXml`, `keybindThroughTab` | Adopted by WG-KB | item WG-KB |
| Kit 42 `mock_layers.lua` | Adopted by WG-ZS (held for the owner) | item WG-ZS; OWNER_SCOPE 030 |
| `O.StrataTooltip` | deferred (run 2026-10-24); WG-ZS adopts it only if its accepted changes add a strata row | item WG-RV spec |
| `Core.RaiseStaticPopups()` from `modules/Frame.lua` | deferred (run 2026-10-24); WG-ZS decides from `accepted.json` | item WG-RV spec |
| DragHandle `level` / `ApplyLevel` / `ignoreParentAlpha` | deferred (run 2026-10-24); no DragHandle here | item WG-RV spec |
| Widgets, Perf, Sim (whole module) | Settled, unchanged (#12, Perf declined, #24) | this addon's records |

No decline issue was filed. Unreached: none.
