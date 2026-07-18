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
(`tests/wow_mock.lua` + `tests/loader.lua`) and runs the pure-logic suites
(`test_util`, `test_compat`, `test_database`, `test_settings`, `test_slash`,
`test_labels`, `test_capture`, `test_debuglog`). Frame/panel rendering and taint are **not**
covered here — those stay in the manual [smoke-test checklist](./smoke-tests.md).
The **GameMenu → Logout taint check** is the critical in-game one.

## Current status & the case inventory (testing-§5)

The **authoritative pass count** is not written in prose here — it lives in the
generated inventory, [docs/test-cases.md](./test-cases.md), so it can never
drift from the suite. That file is produced by a non-executing `--list` mode of
the runner and MUST NOT be hand-edited:

```sh
lua tests/run.lua --list > docs/test-cases.md
```

`--list` loads every suite, stamps each registered case with its origin
`test_*.lua` file, prints the Markdown inventory (per-suite sections + a Totals
table with the grand total), and exits **without running any test**. Default
`lua tests/run.lua` behaviour is unchanged.

The README's `tests` badge is a **static, hand-maintained** shields.io X/Y
(`img.shields.io/badge/tests-<X>%2F<Y>_passing-brightgreen`) — no CI, no
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
lua tests/run.lua --list > docs/test-cases.md
git diff --exit-code -- docs/test-cases.md    # clean (exit 0) = in sync
```

> **CRLF note.** This repo's `.gitattributes` stores every text file — `.md`
> included — as **CRLF on disk** (WoW client expectation), while `--list`
> emits LF. Use the git-native `git diff --exit-code` check above (git
> normalizes to LF in the index, so it compares correctly). The raw
> `diff <(lua tests/run.lua --list) docs/test-cases.md` reports a spurious
> whole-file diff here because it compares LF process output against the
> CRLF working copy; if you want a process-only check, strip CR first:
> `diff <(lua tests/run.lua --list) <(tr -d '\r' < docs/test-cases.md)`.

## In-game smoke tests

The pieces that can't be exercised headlessly — AceGUI panel rendering, the
secure teleport button, and the **GameMenu → Logout taint check** — are covered
by the manual [smoke-test checklist](./smoke-tests.md). Run the relevant section
after any non-trivial change, after an `## Interface:` bump, after refreshing
`libs/`, and before tagging a release; the Quick-reference checklist at the
bottom of that file is the minimum pre-release pass.
