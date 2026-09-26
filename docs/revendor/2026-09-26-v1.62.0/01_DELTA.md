# LibKa0s v1.61.0 -> v1.62.0: the delta (WhatGroup)

Copied from the tag `v1.62.0` (`5dc9f5d`), never from a working tree.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/LibKa0s.xml and libs/LibKa0s/LibKa0s.xml differ
Files <tag>/LibKa0s/Options.lua and libs/LibKa0s/Options.lua differ
Only in <tag>/LibKa0s: OptionsCombat.lua
Only in <tag>/LibKa0s: OptionsIdList.lua
Only in <tag>/LibKa0s: OptionsIds.lua
Only in <tag>/LibKa0s: OptionsRegistry.lua
Files <tag>/LibKa0s/OptionsTabs.lua and libs/LibKa0s/OptionsTabs.lua differ
Files <tag>/LibKa0s/OptionsWidgets.lua and libs/LibKa0s/OptionsWidgets.lua differ
```

- `Options.lua`: minor 25 -> 26. The page registry moves out to `OptionsRegistry.lua` (new, minor 1), attached by `lib.__AttachRegistry`.
- `OptionsWidgets.lua`: minor 31 -> 32. The id surface moves out to `OptionsIds.lua` and `OptionsIdList.lua` (new, minor 1 each), attached by `lib.__AttachIds` / `lib.__AttachIdList`.
- `OptionsTabs.lua`: minor 5 -> 6. The combat lock's page chrome moves out to `OptionsCombat.lua` (new, minor 1), attached by `lib.__AttachCombat`.
- `LibKa0s.xml`: loads each new file right after the file it left.
- The Options major key moves to `26.1.32.1.1.6.1.7.4.1`. No member, descriptor field or row field changes, and no `NEEDS_*` floor rises.

## tests/_kit

Kit revision 27 -> 31. `framework.lua` peels the suite inventory to the new `inventory.lua`; `test_prose.lua` peels to the new `prose_coverage.lua` and `prose_selftests.lua`; `test_layout_cap.lua` shares its exempt matcher; `run-automated-tests.sh` prints `None.` under an empty watch-list table (ATS-20) and leaves `Kit.layoutCap.exempt`'s generated files out of the band table (ATS-21); `README.md` follows. No public member, kit case or mock changes.
