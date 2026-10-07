# Candidates (WhatGroup, LibKa0s v1.70.0 -> v1.71.0)

Sources: `git -C ../LibKa0s log --oneline v1.70.0..v1.71.0` (20 commits; payload in `LK-01` to
`LK-06`), the tag's `CHANGELOG.md` v1.71.0 block and its "What a consumer owes" list, and the
`docs/api/` documents it links. Base v1.70.0 from this repo's CLAUDE.md provenance line.

## A. Delivered on the re-vendor alone

- **Kit revision 38, `--list` Totals** (`LK-01`): the Totals table counts only the cases that run,
  with a `Skipped` row. `docs/test-cases.md` is regenerated in this commit: the diagnostics
  contract's declared skip leaves its suite row (9 -> 8) for `| Skipped | 1 |`, and Total is 914,
  which the README badge already carried. Carried by re-vendor, no code change.
- **Env minor 2** (`LK-06`): consumed major; carried by re-vendor, no code change.
- **Slash key 20.2** (`LK-05`; SlashParse minor 2, Slash minor 20): consumed major; carried by
  re-vendor, no code change. A `/wg set` on a number row now refuses `nan` and the infinities.
- **OptionsIdList minor 4** (`LK-06`): consumed major (Options); carried by re-vendor, no code
  change. The panel builds no id list.

## B. Host change required (candidates)

- **`Kit.secret` / `Kit.isSecret` / `Kit.reveal` / `Kit.installSecretValue`** (kit revision 38,
  `testkit/secrets.lua`, `LK-02`): the shared secret-value simulator, raised from this addon's own
  2026-10-07 review (`WG-R-09`). Opt-in; nothing installs `issecretvalue` by default. **Adopted in
  this run by WG-01**, the plan item that replaces the local simulator; not adopted in this commit.

## C. Not consumed by this addon

- **WidgetsLineChart minor 3 / `ChartMath.ClipSegment`** (`LK-03`): not adopted in this run. The
  Widgets major is declined ([#12](https://github.com/tusharsaxena/WhatGroup/issues/12)) and the
  addon draws no chart.
- **WidgetsAutocomplete minor 2** (`LK-04`): not adopted in this run. Widgets declined (#12); no
  free-text field to complete.
