# LibKa0s v1.62.0 -> v1.63.0: the delta (WhatGroup)

Copied from the tag `v1.63.0` (`dd7a774`), never from a working tree: `git archive v1.63.0 LibKa0s testkit`, extracted to a scratch folder, and both payloads replaced whole.

## libs/LibKa0s (`diff -rq --strip-trailing-cr`, before the copy)

```
Files <tag>/LibKa0s/Slash.lua and libs/LibKa0s/Slash.lua differ
```

- `Slash.lua`: minor 16 -> 17 (`LibKa0s-Slash-1.0`). The `profile` verb's behavior ships once in the library:
  - descriptor field `profiles`, a function answering the host's profile store (duck-typed on AceDB-3.0's `GetProfiles` / `GetCurrentProfile` / `SetProfile`), asked at call time;
  - instance members `Sl:CliProfile(rest)` (bare lists, a name switches; one pair of surrounding quotes stripped, case kept) and `Sl:ProfileSwitch(name)` (already-current, combat refusal, switch, or unknown-name refusal with a did-you-mean; never creates a profile);
  - lib-level `lib.ProfileNames(store)`;
  - nine `lib.STRINGS` keys, `PROFILE_UNAVAILABLE` to `PROFILE_DID_YOU_MEAN`.
- `profile` is not added to `lib.LIVE_VERBS` and is not reserved. No `NEEDS_*` floor rises; every other file is byte-identical to v1.62.0.
- Line shifts in `Slash.lua`: `lib.DISABLED_LINE_FORMAT` moves 84 -> 94 and the dispatcher's verb split to 949-951. The two live citations of them (`settings/Slash.lua`, `docs/slash-dispatch.md`) are re-pointed.

## tests/_kit

No change: kit revision 31 at both tags (`diff -rq` empty, with and without `--strip-trailing-cr`).

## What the copy turned red

`parity: the Slash stub carries the whole live surface` (tests/test_surface_parity.lua): the by-name `Kit.assertSurfaceParity` reads the live dispatcher instance, which now carries `CliProfile` and `ProfileSwitch`, and the degraded stub in `settings/Slash.lua` had neither.
