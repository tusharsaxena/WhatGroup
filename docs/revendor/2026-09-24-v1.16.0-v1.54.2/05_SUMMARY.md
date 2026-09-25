# 05 — Summary: LibKa0s span v1.16.0 -> v1.54.2 (base v1.15.0)

Plan item WG-29, 2026-09-24, branch `feat/2026-09-23-review-audit-remediation`. Records the 28 tags
this addon vendored after its store's first bundle and never recorded (finding WHATGROUP-A-10). No
code changes, nothing is re-vendored, nothing is pushed, and the addon version is not bumped. The
commit list, the base and how the span was derived are in `01_DELTA.md`.

## Backlog

This span was **not recorded at the time**. Each re-vendor landed with its copy, its provenance
roll and a green gate, but no `docs/revendor/` bundle and no `## Documented deviations` row, which
is the `audit-review-history` MUST the 2026-09-23 audit found unmet. The convention lapsed
collection-wide at once, during the bulk sweeps, so the per-tag deliberation a bundle would hold
mostly never happened.

**No per-tag folder is back-filled.** `audit-review-history` permits one consolidated bundle naming
the span it covers, and that is what this folder is: writing twenty-eight folders after the fact
would record deliberation that did not take place. The frozen earlier bundles are not edited.

## One line per tag

"Carried, nothing adopted" means the bytes arrived and this addon's own code took no new surface
from that tag. Anything the library fixed still reached the player through the carry.

- **v1.16.0** — carried, nothing adopted (`ce69ccc`: Pool 2, Widgets 7, DebugLog 12, kit 13).
- **v1.18.0** — carried inside `f98ef41`, which adopts options-ui-§12: the global reset becomes
  `db:ResetProfile()` and `core/WhatGroup.lua` registers the three profile callbacks.
- **v1.18.1** — carried, nothing adopted (the landing logo texture fix arrives with the bytes).
- **v1.19.0** — carried, nothing adopted (`Widgets.ReorderList` is unused here).
- **v1.23.0** — `8122e40`: the General page becomes a tab strip through `O.RenderTabbedSchema`
  (options-ui-§13), the commit after the copy.
- **v1.24.0** — `127baa1`: the composed Master controls tab and the settings-revamp-v2 page shape,
  in the same commit as the copy.
- **v1.26.0** — carried, nothing adopted (`caf1cbd`; the pooled tab strip arrives with the bytes).
- **v1.27.0** — `a8ef42c`: the kit's `test_eol.lua` gate wired into `tests/run.lua`, and `O.__print`
  added to the parity case's ignore list, in the re-vendor commit itself.
- **v1.28.0** — carried, nothing adopted (Perf only: the usage block's doubled pipes).
- **v1.29.0** — carried, nothing adopted (Perf only: `dump` folds into `report`).
- **v1.35.0** — carried; the Options degradation stub gained six inert members for surface parity
  only (`cab07ec`). No widget adopted.
- **v1.36.0** — carried; the stub gained `SelectTab` for parity (`1294cd1`). Nothing calls it.
- **v1.36.1** — carried, nothing adopted (the pooled CheckBox color fix arrives with the bytes).
- **v1.36.2** — carried, nothing adopted.
- **v1.37.0** — `8af7636`: the Master controls Test mode checkbox through `testModePath`. The
  re-vendor commit `f6ae5fd` had said nothing would use it; the next commits did.
- **v1.38.0** — `130676c`: a bare `/wg` opens the settings panel (Slash 11), with the library-absent
  stub, tests and docs, in the re-vendor commit itself.
- **v1.39.0** — `bf5aad2`: the launcher. One `LibKa0s-Launcher-1.0` object with this addon's logo,
  the popup on the left button, and the Master controls `Minimap button` row through `minimapPath`
  (compose minor 7), in the same commit.
- **v1.42.0** — `f74893a`: the Lifecycle latch. Disabling the addon stands it down and a perf run
  takes the same latch. The copy rode in this commit.
- **v1.43.0** — carried, nothing adopted (kit revision 23 only; the library bytes did not move).
- **v1.44.0** — carried, nothing adopted (`removeStyle = "icon"` on `O.IdList`; this addon draws no
  id list).
- **v1.45.0** — carried, nothing adopted (`shownWhen` is unused here).
- **v1.46.1** — carried. The settings panel's combat lock arrives with the bytes and needs no host
  code; `f2dfddc` moved the Test mode checkbox test to the library's `COMBAT_LOCKED_NOTICE`.
- **v1.47.0** — carried; `columns` on `O.IdList` declined in `8f2af6f` because this addon has no
  `O.IdList` call site.
- **v1.50.0** — carried, nothing adopted (fixes behind an unchanged member manifest).
- **v1.51.0** — carried, nothing adopted (the optional `O.IdList` help fields are unused here).
- **v1.52.0** — carried, nothing adopted.
- **v1.53.0** — carried, nothing adopted (the Add button height fix arrives with the bytes).
- **v1.54.2** — `7f38ddd`: the kit's US-English prose gate replaces this repo's own copy. The copy
  rode in this commit.

## Declined

The only explicit decline in the span is v1.47.0's `columns` (`8f2af6f`): there is no id list here
for it to pack, so it is not a gap and no issue is filed. No other candidate was formulated at the
time, so nothing else counts as declined.

## Open

- The frozen bundles are not edited. `docs/revendor/2026-09-03/` and `docs/revendor/2026-09-12/`
  keep their heading-style line 1. The audit reads only the last tag from each, which is why v1.24.0
  and v1.29.0 are in this span.
- From here, every re-vendor writes its own `docs/revendor/<YYYY-MM-DD>-v<tag>/` bundle, as
  `2026-09-23-v1.55.0/` and `2026-09-23-v1.56.0/` already do.
