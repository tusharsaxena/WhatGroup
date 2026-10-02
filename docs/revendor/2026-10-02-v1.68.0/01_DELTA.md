Delta: LibKa0s v1.67.0 -> v1.68.0

# 01 — Delta (WhatGroup)

Plan item TP-WG-01 of the 2026-10-02 LibKa0s tooltip-place re-vendor
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/`). Payload taken from the
**local annotated tag** v1.68.0 (`cc9f5eb`; `../LibKa0s` HEAD equals the tag's commit and
`git -C ../LibKa0s diff --quiet v1.68.0 -- LibKa0s testkit` is clean):

```sh
git -C ../LibKa0s archive v1.68.0 LibKa0s testkit | tar -x -C <scratch>/new
```

## 3a. Base

```sh
grep -n '[Bb]undles' CLAUDE.md          # :79  Bundles [LibKa0s](...) v1.67.0 (MIT)
c=$(git log -1 --format=%H -- libs/LibKa0s tests/_kit)
git show "$c:CLAUDE.md" | grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9.]+'   # v1.67.0
git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>/old
diff -rq <scratch>/old/LibKa0s libs/LibKa0s && diff -rq <scratch>/old/testkit tests/_kit   # payload-matches
```

Base **v1.67.0**; the claim, the last payload commit's line and the payload agree. `git -C
../LibKa0s log --oneline v1.67.0..v1.68.0`: 12 commits (4 of them the v1.67.0 census follow-ups
and merge, 8 the DA-LK-* release); `git -C ../LibKa0s diff --shortstat v1.67.0 v1.68.0 -- LibKa0s
testkit`: 1 file changed, 69 insertions, 15 deletions (`LibKa0s/WidgetsDragHandle.lua`).

Step 0: the newest single-tag bundle `2026-10-02-v1.67.0` states base v1.66.0, and the provenance
line before its re-vendor commit `9d377b5` named v1.66.0: ok, no correction.

## 3b / 3c. Minors (only the file that moved; every other file unchanged)

| File | Old | New |
|---|---|---|
| `WidgetsDragHandle.lua` | DRAG_MINOR 3 | DRAG_MINOR 4 |

`LibKa0s-Widgets-1.0` key 12.1.3 -> 12.1.4. No `NEEDS_*` floor rises, no major and no payload file
is added or removed (CHANGELOG.md:15-21). No consumer file was behind its claim: no cross-major skew.

## 3d. Diffs

Before the copy, `diff -rq <scratch>/new/LibKa0s libs/LibKa0s` and its `--strip-trailing-cr` twin
report `WidgetsDragHandle.lua` only; `diff -rq <scratch>/new/testkit tests/_kit` is empty. No
`Only in libs/LibKa0s` or `Only in tests/_kit`: nothing to delete.

## 3e. Consumption

```sh
grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'
```

The addon's ten lookup sites are unchanged (Compat, Core, Env, Media, DebugLog, Launcher,
Lifecycle in `core/`; Options, Schema, Slash in `settings/`). **Widgets is not looked up by the
addon**; it arrives only through the library's own `DebugLog.lua:33` (the console's copy window),
and no library file calls the drag handle (`grep -rn DragHandle libs/LibKa0s/*.lua` outside the
file itself finds comments only). `tests/loader.lua:44` loads the file as part of the whole payload.

## 3f. Kit

`Kit.VERSION` 35 -> **35** (`tests/_kit/framework.lua:20`): the kit is byte-identical between the
two tags. Both payloads still move together (the kit-revision pairing rule, satisfied by
construction).

## 3g. Contract delta

The one moved major is Widgets, through `WidgetsDragHandle.lua` minor 4
(`../LibKa0s/docs/api/Widgets/version-12.1.4-docs.md:18-48`): the spec gains the optional
`tooltipPlace(tip, frame)` and the tooltip descriptor `place`, both Since 4. "Without a hook
nothing changes ... minor 3's calls in minor 3's order" (`:44-45`) and "What a host must change:
nothing" (`:47`). WhatGroup consumes no Widgets surface and attaches nothing
(`grep -rn '__Attach[A-Za-z]*\|DragHandle\|tooltipPlace' . --include='*.lua' --exclude-dir=libs
--exclude-dir=_kit` finds only the loader line), so no host-supplied member can be reached.

**Blockers:** none.

## 3h. Unrecorded vendored tags

The playbook's listing (`vendored.txt` minus `recorded.txt`, horizon `2026-08-25`) prints nothing:
every tag WhatGroup vendored has a bundle. No span bundle.
