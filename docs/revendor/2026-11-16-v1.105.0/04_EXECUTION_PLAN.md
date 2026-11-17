# 04 Execution plan

Nothing adopted, so no characterization tests and no adoption commits. The run is the copy, the provenance roll, the prune, and the fixes the new payload forced in this repo's own seams and tests, all in the one RV-WG commit:

- `tests/loader.lua`: ten loader lines in XML order.
- `core/DebugLogSetup.lua`: stub `Report` (returns 0) and `Serialize` (returns `{}, false`).
- `settings/OptionsSetup.lua`: stub `SideTabs` (inert no-op, like `NavRail`).
- `core/Compat.lua`: `RegionalNames`, `UnitCharacterName`, `CharacterKey`, `RealmKey` on `NS.Compat`, the library's members or the documented absent answers.
