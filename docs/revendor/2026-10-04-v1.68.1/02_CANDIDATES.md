# Candidates (WhatGroup, LibKa0s v1.68.0 -> v1.68.1)

Sources: `git -C ../LibKa0s log --oneline v1.68.0..v1.68.1` (7 commits; the only payload change is
`cfefa99`'s three `testkit/` files), `git -C ../LibKa0s show v1.68.1:CHANGELOG.md` (the v1.68.1
block, `:13`-`:53`: "Every library file is unchanged from v1.68.0 ... no member is added or
removed") and `docs/api/testkit/version-36-docs.md` against `version-35-docs.md`. No major moved a
minor, so no `docs/api/<Major>/` document changed in the range (`git -C ../LibKa0s diff --stat
v1.68.0 v1.68.1 -- docs/api` names only `CONSUMERS.md`, `README.md` and the two testkit documents).
Base v1.68.0 from this repo's CLAUDE.md provenance line.

## A. Delivered on the re-vendor alone (not offered)

- **Kit revision 36** (`version-36-docs.md:19`-`:23`, CHANGELOG v1.68.1 `:28`-`:41`):
  `run-automated-tests.sh` prints `/dev-copilot:bump-version` in the `RESULTS.md` lead-in where
  revision 35 printed `/wow-addon:bump-version`; three runner comments and one `test_eol.lua`
  comment follow the rename; `Kit.VERSION` is 36. No member, case, mock or manifest field changes,
  so `docs/test-cases.md` is unchanged (it matches `lua tests/run.lua --list`). The next
  automated-test run rewrites the one lead-in line of `docs/automated-tests/RESULTS.md`.

## B. Host change required (candidates)

**None.** The release adds no surface: no `Since` marker is new in the range and no library file
changed.

## C. Whole-module adoption

None new. No module's premise moved, since the release changes no library file. Perf
([LIBKA0S-15](https://github.com/tusharsaxena/WhatGroup/issues/7)) and Bus
([#21](https://github.com/tusharsaxena/WhatGroup/issues/21)) stay declined as settled
(`docs/ARCHITECTURE.md:296`); Item, Pool and Widgets stay unconsumed by the host.

**Zero adoption candidates.**
