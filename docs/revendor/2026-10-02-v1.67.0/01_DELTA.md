Delta: LibKa0s v1.66.0 -> v1.67.0

# 01 — Delta (WhatGroup)

Plan item CA-WG-RV of the 2026-10-02 LibKa0s census adoption
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`). Payload taken from the
**local tag** v1.67.0 (`0bccf4c`; `../LibKa0s` HEAD equals the tag's commit and its tree is clean):

```sh
git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>/new
```

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md          # :79  Bundles [LibKa0s](...) v1.66.0 (MIT)
git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit   # payload-matches
```

Base **v1.66.0**; claim and payload agree (both `diff -rq` empty, bytes). `git -C ../LibKa0s log
--oneline v1.66.0..v1.67.0`: 6 commits; `git -C ../LibKa0s diff --shortstat v1.66.0 v1.67.0 --
LibKa0s testkit`: 3 files changed, 125 insertions, 36 deletions. Step 0: the newest single-tag
bundle `2026-10-01-v1.66.0` states base v1.65.0 and is followed by no unrecorded tag: ok.

## 3b / 3c. Minors (only the files that moved; every other file unchanged)

| File | Old | New |
|---|---|---|
| `Core.lua` | MINOR 9 | MINOR 10 |
| `Options.lua` | MINOR 27 | MINOR 28 |
| `OptionsIdList.lua` | IDLIST_MINOR 2 | IDLIST_MINOR 3 |

`LibKa0s-Options-1.0` key 27.2.34.2.2.8.1.7.4.2 -> 28.2.34.2.3.8.1.7.4.2. No `NEEDS_*` floor rises,
no major and no payload file is added or removed (CHANGELOG v1.67.0). No consumer file was behind
its claim: no cross-major skew.

## 3d. Diffs

Before the copy (`diff -rq <scratch>/new/LibKa0s libs/LibKa0s`, and for the kit): `Core.lua`,
`Options.lua` and `OptionsIdList.lua` differ; the kit does not differ at all. No `Only in
libs/LibKa0s` or `Only in tests/_kit`: nothing to delete. After the copy, `diff -r` (bytes, CRLF
working tree as the tag's archive writes it) against the archive and `diff -r --strip-trailing-cr
../LibKa0s/LibKa0s libs/LibKa0s` are empty; `tests/_kit/run-automated-tests.sh` stays LF and
`100755`.

## 3e. Consumption

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

The moved majors this addon consumes: Core (through `core/CoreSetup.lua`) and Options (through
`settings/OptionsSetup.lua`). WhatGroup calls neither `MakeResizable` nor `O.IdList` itself
(`grep -rn 'MakeResizable\|IdList\|StartSizing\|SetResizable'` over the addon's own Lua finds
nothing); the library's own console, copy window and perf panel call `MakeResizable` with none of
the new fields.

## 3f. Kit

`Kit.VERSION` 35 -> **35** (`tests/_kit/framework.lua:20`): the kit is byte-identical between the
two tags. Both payloads still move together.

## 3g. Contract delta

- **Core 10** (`docs/api/Core/version-10-docs.md:32-34`, `:52`): `MakeResizable` opts gain
  `canResize`, `onResizeStop` and `gripParent`. All optional; a caller passing none behaves exactly
  as on v1.66.0. No member added.
- **OptionsIdList 3 / Options 28** (`docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md:48-65`):
  an id-list help mark's default art uses the descriptor's `addonName` only when the client reports
  that addon loaded, else the client glyph, with one gated `Cfg` line per instance. Options 28 is a
  docblock correction naming `addonName` as recommended for every host. WhatGroup draws no id list,
  so nothing it renders changes.

**Blockers:** none. No consumer test broke: 913 passed / 1 skipped / 914 before and after.
