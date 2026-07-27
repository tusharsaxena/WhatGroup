# Testing — Ka0s WhatGroup

How WhatGroup is verified. Design overview + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).
Working notes: [agent-context.md](./agent-context.md). Root stub: [../CLAUDE.md](../CLAUDE.md).

WhatGroup is validated on three levels — a headless harness, lint, and an
in-game smoke-test suite. The first two are the **commit gate**; the third is
manual.

## The green gate

Both of these MUST be green before every commit (testing-§4):

```sh
lua tests/run.lua      # headless suites: PASS/FAIL per case, non-zero exit on any failure
luacheck .             # must report 0 warnings / 0 errors (config in .luacheckrc)
```

`tests/run.lua` loads every source in TOC order under a WoW mock
(`tests/wow_mock.lua` + `tests/loader.lua`) and runs every suite: `test_util`,
`test_compat`, `test_database`, `test_settings`, `test_slash`, `test_labels`,
`test_capture`, `test_notify`, `test_frame`, `test_panel`, `test_lifecycle`,
`test_debuglog`.

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

Four pieces of `tests/wow_mock.lua` deliberately model real client behaviour
instead of no-op'ing it, and each is the sole reason a class of bug is
catchable at all — the header comment in that file explains why. In short:
frame **visibility** and **geometry** are real state (otherwise "the window
closed" and "the position was saved" are unassertable); the **AceTimer queue**
is fireable and honours cancellation (otherwise the notify delay, its supersede
check, and `WipeCapture`'s `CancelTimer` are all invisible); and
**`CreateFontString` returns a distinct object** per call (otherwise every
popup row shares one `SetText` sink). `env._G` also points back at the mock env,
because `settings/Panel.lua` reads `_G.Settings` explicitly — without it
`Settings.Register` silently early-returns and the whole panel merely *looks*
untestable.

## Current status & the case inventory (testing-§5)

The **authoritative pass count** is not written in prose here — it lives in the
generated inventory, [docs/test-cases.md](./test-cases.md), so it can never
drift from the suite. That file is produced by a non-executing `--list` mode of
the runner and MUST NOT be hand-edited:

```sh
lua tests/run.lua --list | sed 's/$/\r/' > docs/test-cases.md
```

`--list` loads every suite, stamps each registered case with its origin
`test_*.lua` file, prints the Markdown inventory (per-suite sections + a Totals
table with the grand total), and exits **without running any test**. Default
`lua tests/run.lua` behaviour is unchanged.

The README's `tests` badge is a **static, hand-maintained** shields.io X/Y
(`img.shields.io/badge/Tests-<X>%2F<Y>_passing-green`) — no CI, no
dynamic/endpoint badge, no GitHub Action (testing-§5). Its number is the grand
total from `docs/test-cases.md`.

## Keeping the inventory & badge in sync

**Rule (Hard rule — see [agent-context.md](./agent-context.md#hard-rules)):**
whenever the suite changes — a case added, removed, or renamed, or the pass
count moves (i.e. **whenever a failing test is resolved**) — regenerate
`docs/test-cases.md` **and** update the README `tests` badge X/Y **in the same
change**, never as a deferred follow-up (testing-§5).

Regenerate, then verify it is in lockstep:

```sh
lua tests/run.lua --list | sed 's/$/\r/' > docs/test-cases.md
diff <(lua tests/run.lua --list) <(tr -d '\r' < docs/test-cases.md)   # silent = in sync
```

> **CRLF note.** This repo's `.gitattributes` stores every text file — `.md`
> included — as **CRLF on disk** (WoW client expectation), while `--list`
> emits LF. The `sed` on the way out writes CRLF; the `tr -d '\r'` on the way
> back in strips it, so the comparison is LF-vs-LF and a clean suite is silent.
>
> **Do not** use `git diff --exit-code -- docs/test-cases.md` as the lockstep
> check. It compares the file against **HEAD**, not against regenerated output
> — so the moment the suite legitimately changes, a correctly-regenerated
> inventory reports as drift. It only ever means "in sync" when the inventory
> is already committed, which is not when you need the check.

## In-game smoke tests

The pieces that can't be exercised headlessly — AceGUI panel rendering, the
secure teleport button, and the **GameMenu → Logout taint check** — are covered
by the manual [smoke-test checklist](./smoke-tests.md). Run the relevant section
after any non-trivial change, after an `## Interface:` bump, after refreshing
`libs/`, and before tagging a release; the Quick-reference checklist at the
bottom of that file is the minimum pre-release pass.
