# Testing — Ka0s WhatGroup

How WhatGroup is verified. Design overview + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).
Root stub: [../CLAUDE.md](../CLAUDE.md).

WhatGroup is validated on four levels — a headless harness, lint, a **vendor
gate** over the two folders it copies from `../LibKa0s`, and an in-game
smoke-test suite. The first three are the **commit gate**; the fourth is manual.

## The green gate

Both of these MUST be green before every commit (testing-§4):

```sh
lua tests/run.lua      # headless suites: PASS/FAIL per case, non-zero exit on any failure
luacheck .             # must report 0 warnings / 0 errors (config in .luacheckrc)
```

### The harness is the shared kit

The registry, the assertions, the runner, the `--list` renderer, the sandboxed
source loader and the universal half of the WoW mock are **not this addon's
code**. They are `../LibKa0s`'s `testkit/`, vendored whole to `tests/_kit/`
(testing-§1), and **`tests/_kit/` MUST NOT be edited here** — a kit problem is a
finding to fix upstream and re-vendor, and a local patch is a fork the next
re-vendor silently reverts.

What stays this addon's is what is genuinely per-addon:

| File | Holds |
|------|-------|
| `tests/run.lua` | the three lifecycle factories (`newAddon` / `bootAddon` / `enableAddon`), the `Kit.expose` table, and the ordered suite list |
| `tests/loader.lua` | the **isolated-instance** factory: one fresh mock environment and one fresh `NS` per call, over the kit's `Loader.makeEnv` and `Loader.tocFiles` |
| `tests/wow_mock.lua` | a thin **extender** over `mock_base`, never a replacement |
| `tests/test_*.lua` | the suites |

`tests/run.lua` derives the addon's own load list **from the TOC**
(`Loader.tocFiles`, testing-§9) rather than restating it, and spells out the
eight files of `libs/LibKa0s/LibKa0s.xml` explicitly, because a vendored
library comes in through its own XML which `tocFiles` cannot see. Both failure
modes that rule exists for are silent: a suite named in the list but missing
from disk is *skipped*, and a library file omitted from the list makes its
module refuse to register — so every seam falls back to its stub and the suite
happily measures the stub, green. `tests/test_harness.lua` pins the derivation
against a fresh read of the TOC and the XML.

The suites, in run order: `test_harness`, `test_libka0s`, `test_util`,
`test_compat`, `test_database`, `test_settings`, `test_slash`, `test_labels`,
`test_capture`, `test_notify`, `test_frame`, `test_panel`, `test_lifecycle`,
`test_debuglog`.

`test_libka0s` is the integration suite for the four adopted LibKa0s majors:
that each really registers, that each descriptor is well-formed, that the
degraded install answers rather than errors, and the two halves of the `L`-trap
guard. The library's own behavior is tested where it lives — this addon keeps
no duplicate of those cases (testing-§8).

Coverage extends past pure logic into the UI and event layers — the popup's
field rendering and secure-teleport-button states (`test_frame`), the settings
panel's deferred build and widget write-back (`test_panel`), the delayed
join-notify pipeline (`test_notify`), and the event/hook wiring
(`test_lifecycle`). What genuinely **cannot** be reproduced headlessly stays in
the manual [smoke-test checklist](./smoke-tests.md): real frame layout and
skinning, and above all taint — the **GameMenu → Logout taint check** is the
critical in-game one. The headless suites assert the *structural* half of the
taint contract (nothing protected is created at load; the popup, its
`UISpecialFrames` entry, the `StaticPopupDialogs` write and every AceGUI widget
are all built lazily) but only the client can prove the taint itself is gone.

### Mock fidelity

`tests/wow_mock.lua` is an **extender** over the kit's `mock_base`, not a swap
(testing-§1). The base owns everything universal — above all a `LibStub` with a
real `NewLibrary`, without which every LibKa0s seam would silently take its
degraded path while the suite stayed green — plus AceDB's merge-in-place
`copyDefaults`, AceConsole's `:Print` clobber, the AceGUI widget recorder and
the Settings registrars.

Four of this addon's overrides model real client behavior instead of
no-op'ing it, and each is the sole reason a class of bug is catchable at all —
the header comment in that file explains why. In short: frame **visibility** and
**geometry** are real state (otherwise "the window closed" and "the position was
saved" are unassertable), and `Hide` fires `OnHide` so the console's visibility
callback is reachable; **`CreateFontString` / `CreateTexture` return distinct
objects** (the base's answer from the frame stub's metatable and hand back the
frame itself — its own README records that this addon is right to differ);
screen-space getters answer real **numbers**, because the popup derives the
secure teleport button's offsets by subtracting them; and the **AceTimer queue**
is fireable, cancelable and **separate from the `C_Timer` queue**, so the
notify delay and the panel's secure-defer hop can be fired independently.

`_G` points back at the mock table itself, because `settings/Panel.lua` and the
library both read several APIs through an explicit `_G.` — without it
`Settings.Register` silently early-returns and the whole panel merely *looks*
untestable.

## Current status & the case inventory (testing-§5)

The **authoritative pass count** is not written in prose here — it lives in the
generated inventory, [docs/test-cases.md](./test-cases.md), so it can never
drift from the suite. That file is produced by a non-executing `--list` mode of
the runner and MUST NOT be hand-edited:

```sh
lua tests/run.lua --list > docs/test-cases.md
```

**No `sed` any more.** The kit's `--list` renderer writes CRLF itself, precisely
because these repos pin `*.md text eol=crlf`, a plain redirect writes LF, and a
regeneration command with a pipeline in it is one somebody eventually runs
without the pipeline.

`--list` loads every suite, stamps each registered case with its origin
`test_*.lua` file, prints the Markdown inventory (per-suite sections in
**declared suite order** + a Totals table with the grand total), and exits
**without running any test**. It is a pure filter over the registry: the kit
**collects** every case and runs nothing until `Kit.run`, so the inventory
cannot disagree with the run. Default `lua tests/run.lua` behavior is
unchanged.

The README's `tests` badge is a **static, hand-maintained** shields.io X/Y
(`img.shields.io/badge/Tests-<X>%2F<Y>_passing-green`) — no CI, no
dynamic/endpoint badge, no GitHub Action (testing-§5). Its number is the grand
total from `docs/test-cases.md`.

## Keeping the inventory & badge in sync

**Rule (hard rule):**
whenever the suite changes — a case added, removed, or renamed, or the pass
count moves (i.e. **whenever a failing test is resolved**) — regenerate
`docs/test-cases.md` **and** update the README `tests` badge X/Y **in the same
change**, never as a deferred follow-up (testing-§5).

Regenerate, then verify it is in lockstep:

```sh
lua tests/run.lua --list > docs/test-cases.md
diff <(lua tests/run.lua --list) docs/test-cases.md   # silent = in sync
```

> **CRLF note.** This repo's `.gitattributes` stores every text file — `.md`
> included — as **CRLF on disk** (WoW client expectation), and the kit's
> `--list` renderer emits CRLF to match, so both sides of that `diff` are CRLF
> and a clean suite is silent. The old `sed`/`tr` pair is gone with the
> hand-rolled runner.
>
> **Do not** use `git diff --exit-code -- docs/test-cases.md` as the lockstep
> check. It compares the file against **HEAD**, not against regenerated output
> — so the moment the suite legitimately changes, a correctly-regenerated
> inventory reports as drift. It only ever means "in sync" when the inventory
> is already committed, which is not when you need the check.

## The vendor gate

`libs/LibKa0s/` and `tests/_kit/` are **whole-folder copies** of `../LibKa0s`'s
two ship folders. Neither the green gate above nor `luacheck` can see a stale
one: the library's suite passes against the library, and this addon's passes
against a stale copy that still works, so **both repos stay green while the
copies diverge** (anti-patterns #45). An after-the-fact `diff` is the only thing
that catches it.

Run all four, from this repo's root, and read the pairs against each other:

```sh
diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s    # content — MUST be empty
diff -r ../LibKa0s/LibKa0s libs/LibKa0s                        # bytes  — SHOULD be empty
diff -r --strip-trailing-cr ../LibKa0s/testkit tests/_kit      # content — MUST be empty
diff -r ../LibKa0s/testkit tests/_kit                          # bytes  — SHOULD be empty
```

| Result | Means | Fix |
|---|---|---|
| both empty | in sync | — |
| **content** non-empty | a copy has genuinely **forked** — the forbidden state | re-vendor the whole folder from `../LibKa0s` |
| content empty, **bytes** non-empty | **nothing has forked.** The two checkouts merely disagree about line endings | renormalize whichever side drifted (`git add --renormalize .`; if the working tree does not flip, delete the affected paths and `git checkout -- .` to pull them back through the filter) |

Never fix either by editing `libs/` or `tests/_kit/`. Re-vendoring will not
converge a line-ending divergence either — it just moves the wrong endings
downstream, and the step people reach for after a re-vendor that did not work is
exactly the one this discipline forbids.

Which version is vendored is answerable without grepping eight minor constants
out of the source: the README carries a provenance line naming the LibKa0s
release, and it moves in the same commit as the bytes.

## Lint scope

`luacheck`'s 0/0 is **scoped by `.luacheckrc`'s `exclude_files`**, not
repo-wide: `libs/`, `tests/` and the frozen audit/review bundles are excluded.
Before reading a clean run as a clean change, confirm the files you touched are
inside the checked set:

```sh
luacheck . --formatter plain | tail -1     # check the file count it reports
```

A warning inside one of the four LibKa0s seam files (`core/CoreSetup.lua`,
`core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua`) is
a defect in this addon's wiring. A warning under `libs/` is not this addon's to
fix — it is a finding for `../LibKa0s`.

## In-game smoke tests

The pieces that can't be exercised headlessly — AceGUI panel rendering, the
secure teleport button, and the **GameMenu → Logout taint check** — are covered
by the manual [smoke-test checklist](./smoke-tests.md). Run the relevant section
after any non-trivial change, after an `## Interface:` bump, after refreshing
`libs/`, and before tagging a release; the Quick-reference checklist at the
bottom of that file is the minimum pre-release pass.
