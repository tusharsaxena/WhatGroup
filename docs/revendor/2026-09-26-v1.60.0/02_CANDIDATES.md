# Candidates: LibKa0s v1.58.0 -> v1.60.0

The sources are `git -C ../LibKa0s log --oneline v1.58.0..v1.60.0`, the v1.59.0 and v1.60.0 blocks of
the library's `CHANGELOG.md` (read at the tag), `Widgets/version-10.3-docs.md`,
`DebugLog/version-14.1-docs.md` and `Slash/version-16-docs.md`.

The 2026-09-25 diagnostics rollout plan settled this run's candidates before the run began
(`Ka0sAddonsCommonTasks/docs/2026-09-25-DIAGNOSTICS_COMMAND/03_EXECUTION_PLAN.md`, "M3: per addon").
The owner's rulings are in `OWNER_RULINGS.md` there. The interview in `03_DECISIONS.md` is answered
from that plan.

## Class A: delivered on the copy alone

| What | Evidence | Reaches WhatGroup |
|---|---|---|
| The console holds 3000 lines, up from 1500, and the compaction slack is 128, up from 64 | CHANGELOG v1.60.0, *DebugLog minor 14*; `DebugLog/version-14.1-docs.md`, Compatibility | Yes. The `N / 3000 lines` counter and the deeper history arrive with no host change. This is not an adoption (plan, M3). The docs that still say 1500 are DR-WG-05's. |
| `lib.TIME_COPY`, the copy-window timing switch, off by default | CHANGELOG v1.60.0, *DebugLog minor 14* | Available as a hand-set `/run` aid. It never saves and changes nothing while off. |
| `diagnostics` is on Slash's default live-verb list | CHANGELOG v1.60.0, *Slash minor 16* | Yes. WhatGroup passes no `liveVerbs`, so the verb is live while disabled as soon as a row exists. |

## Class B: host change required

| Candidate | Evidence | Would touch | Blast radius | Plan's answer |
|---|---|---|---|---|
| The diagnostics report: `D:RunDiagnostics`, `D:DebugVerb`, the `brandName` and `diagnostics` descriptor fields, and `Kit.diagnostics` for the kit's contract suite | CHANGELOG v1.60.0, *DebugLogDiagnostics minor 1* and *Test kit revision 27*; `DebugLog/version-14.1-docs.md:524-526` | `core/DebugLogSetup.lua`, a new `modules/Diagnostics.lua`, `settings/Slash.lua`, `tests/run.lua` | Additive | **Adopt in DR-WG-03** (after the DR-WG-02 snapshot accessors). The standard's debug-logging-§14 makes it a MUST. |
| Slash 16's `diagnostics` as a COMMANDS row with a `debug diagnostics` branch | CHANGELOG v1.60.0, *Slash minor 16* | `settings/Slash.lua`, `tests/test_slash.lua` | Additive | **Adopt in DR-WG-03**, together with the report. |
| WidgetsDragHandle minor 3's `spec.onClose` close mark | CHANGELOG v1.59.0, *WidgetsDragHandle minor 3*; `Widgets/version-10.3-docs.md` | none | none | **Not a candidate.** WhatGroup has no DragHandle host. The plan adopts the close mark only in ConsumableMaster and AbsorbTracker. |

## Class C: whole-module adoption

No new major arrived (DebugLogDiagnostics is a second file of the DebugLog major). The existing
unadopted majors keep their recorded status: Perf is declined on structural grounds
([`LIBKA0S-15`](https://github.com/tusharsaxena/WhatGroup/issues/7), settled), and no minor moved in
Bus, Pool, Item or Perf in this range. Nothing here changes a recorded premise.
