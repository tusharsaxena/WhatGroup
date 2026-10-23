Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

# 01 — Delta (consolidated span)

Written 2026-10-23 by item WG-RV of the 2026-10-23 run "sim auto-run, QC preview selector, mode
strips, MM/KCD simulators" (`Ka0sAddonsCommonTasks/docs/2026-10-23-SIM_PREVIEW_MODE_STRIPS/`),
beside that run's own bundle `docs/revendor/2026-10-23-v1.76.0/`. Two tags this addon vendored were
never given a bundle of their own; this span records them (the revendor command's step 3h).

## The listing

The standards audit's re-vendor walk, run from the repo root before this run's copy:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)      # 2026-08-25
tag_at() { git show "$1:CLAUDE.md" 2>/dev/null |
  grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
  grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
{ git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit
  git log --since="$horizon 00:00" --format=%H -- CLAUDE.md | while read -r c; do
    [ "$(tag_at "$c")" != "$(tag_at "$c^")" ] && echo "$c"; done
} | while read -r c; do tag_at "$c"; done | sed '/^$/d' | sort -uV > vendored.txt
# recorded.txt: every bundle folder's tag(s), span bundles by their line 1
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.75.1
v1.75.2
```

The commits that carried them (`git log --oneline e6b5d13..102a618 -- libs/LibKa0s tests/_kit CLAUDE.md`):

- `91d30b1` Re-vendor LibKa0s v1.75.1 (SimPanel minor 3)
- `8cbd735` Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)

Both replaced `libs/LibKa0s/SimPanel.lua` alone and rolled the provenance line. `tests/_kit/` stayed
at kit revision 41. The newest single-tag bundle before this span, `docs/revendor/2026-10-22-v1.75.0/`,
names base v1.71.0 and new v1.75.0, which matches the provenance line before its re-vendor
(`08dd668`). No base correction is owed.
