# 03 — Decisions

Non-interactive run (bulk-logging rollout, 2026-09-12). The owner ruled `debug-logging-§10` in
advance, and the orchestrator scoped WhatGroup's acts. Filing and pushing were skipped by
instruction: this run opened no GitHub issue and pushed nothing.

| Item | Decision | Why |
|---|---|---|
| Options 16 / Slash 8 bracket, unsupplied | **delivered, inert** | Nothing moves on re-vendor; 589 / 0 / 589 unchanged. |
| Slash 8 bracket on `CliResetAll` | **not wired** | Unreached: `/wg resetall` is host-owned. Outside the orchestrator's WhatGroup scope. |
| B-1 the global reset's one `[Set] reset profile …` line, with the changed-row count | **adopted** | Owner ruling, §10. |
| B-2 the Options bracket, wired defensively | **adopted** | Orchestrator: optional. Cheap, and pinned by tests that drive `O.RestoreDefaults` directly. |
| `resetProfile` descriptor field | **declined** | It would put the library's walk on the path and break `test_settings.lua`'s refresh-once case. |

**The count, after the v1.32.0 review correction.** The first draft counted the schema's profile
rows, following the library's worked example. The coordinator's correction (binding) says N is the
rows whose stored value actually changed, and `bulkEnd`'s `count` (rows walked) is not N. Both counts
were moved to that rule before the adoption was committed:

- the profile reset counts the profile rows that differ from their default just before
  `db:ResetProfile()`;
- the bracket tallies, in the write seam, only the writes that change a stored value, summed across
  nested brackets and logged once at the outermost close.

An all-default act therefore logs `(0 rows)` / `: 0 rows`, never a line per row. A reset driven
straight at the db (not through `RestoreAllDefaults`) has no pre-reset count and logs the line
without one, which §10 permits.

**Noted, not changed:** `OnProfileCopied` and `OnProfileChanged` log nothing. §10 words a copy line
(`[Set] copied profile 'A' → 'B'`) and keeps an addon's existing switch line, but WhatGroup ships no
profile UI and had no switch line, and the orchestrator's scope for this addon is the reset alone.
Coverage under §8–§10 is a SHOULD.
