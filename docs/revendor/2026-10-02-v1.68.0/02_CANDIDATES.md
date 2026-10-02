# Candidates (WhatGroup)

Listed, **not interviewed**: the run is non-interactive (the owner delegated every decision for the
2026-10-02 tooltip-place plan), and the plan already routes this addon: "The other seven: re-vendor
only (no strip)" (`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/00_PLAN.md`).

| # | Class | Surface | Evidence | Would touch | Blast radius |
|---|---|---|---|---|---|
| C1 | B | WidgetsDragHandle 4: `spec.tooltipPlace(tip, frame)` and the descriptor's `place` | CHANGELOG.md:28-44 (v1.68.0); `docs/api/Widgets/version-12.1.4-docs.md:18-48`, `:692` | none: WhatGroup draws no drag strip | none |

Class A, delivered on the copy: nothing visible. The minor-4 split of the tooltip drawing into
evaluate and draw keeps minor 3's call order for a host without a hook (`version-12.1.4-docs.md:44-45`),
and this addon has no drag handle at all.
