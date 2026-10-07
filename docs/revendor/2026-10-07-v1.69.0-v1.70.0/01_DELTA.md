Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)

# 01 — Delta (consolidated span)

Written 2026-10-07 by plan item RV-WG of the 2026-10-07 review and standards-audit remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/`), beside this run's
own bundle `docs/revendor/2026-10-07-v1.71.0/`. Two tags this addon vendored were never given a
bundle of their own, because both arrived by a bulk `chore: re-vendor` sweep and not through
`/dev-copilot:wow-revendor-libka0s`. This span records them (the revendor command's step 3h; the
2026-10-07 audit's `WG-71`, remediation finding `WG-A-02`).

**Base: v1.68.1**, the tag vendored before the span (`docs/revendor/2026-10-04-v1.68.1/`;
`git show 9677d99^:CLAUDE.md` names v1.68.1, LibKa0s commit `9000cbd`). The base is not itself
covered by this span.

## The listing

The standards audit's re-vendor walk (horizon 2026-08-25), run before this run's copy, printed:

```
v1.69.0
v1.70.0
```

The commits that carried them (`git log --oneline -- libs/LibKa0s tests/_kit CLAUDE.md`):

- `9677d99` chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget) — LibKa0s tag
  `v1.69.0` (`5949f4c`).
- `3fd8a2f` chore: re-vendor LibKa0s v1.70.0 — LibKa0s tag `v1.70.0` (`162a7fd`).

## The delta as it landed

`git -C ../LibKa0s diff --stat v1.68.1 v1.70.0 -- LibKa0s testkit`: seven files, 932 insertions,
2 deletions.

- **v1.69.0 (`9677d99`)**
  - `libs/LibKa0s/WidgetsLineChart.lua`, new (WidgetsLineChart minor 1, under
    `LibKa0s-Widgets-1.0`).
  - `libs/LibKa0s/LibKa0s.xml` +1 line for it.
  - Test kit revision 36 -> **37**: `tests/_kit/mock_lines.lua` new (the line-primitive mock the
    chart's tests draw on), `mock_base.lua` +2 lines to load it, `framework.lua`'s `Kit.VERSION`
    and `README.md`.
  - `tests/loader.lua` lists `WidgetsLineChart.lua` in `LibKa0s.xml` order.
- **v1.70.0 (`3fd8a2f`)**
  - `libs/LibKa0s/WidgetsAutocomplete.lua`, new (WidgetsAutocomplete minor 1).
  - `libs/LibKa0s/WidgetsLineChart.lua` minor 1 -> 2 (a 10-line change).
  - `libs/LibKa0s/LibKa0s.xml` +1 line.
  - Kit stays at revision 37.
  - `tests/loader.lua` lists `WidgetsAutocomplete.lua` in XML order.

No `NEEDS_*` floor rose and no consumed major moved a minor across the span: both new files and the
chart's minor sit under `LibKa0s-Widgets-1.0`, which WhatGroup does not take (declined,
[#12](https://github.com/tusharsaxena/WhatGroup/issues/12)). The ten majors the host consumes
(`docs/ARCHITECTURE.md` `## External dependencies`) kept their v1.68.1 minors. Payload parity was clean at
both commits (the audit's `03_EVIDENCE.md`).
