# Ka0s WhatGroup — Remediation Design (2026-08-04)

Keyed to the deviation IDs in `02_DEVIATIONS.md`. This is a **design**, not a change: the audit is
read-only and no addon file was touched.

---

## The shape of the work

Fourteen deviations fall into three genuinely independent groups, and only one of them needs a
decision before any code is written.

| Group | IDs | Blocked on |
|---|---|---|
| **A — the Perf decision** | WG-30, WG-31, WG-32, WG-33, WG-34, WG-35 | a user decision (wire it, or amend the standard) |
| **B — free-standing fixes** | WG-36, WG-37, WG-40, WG-41, WG-42, WG-43 | nothing |
| **C — documentation shape** | WG-38, WG-39 | nothing |

Group B and C can land immediately and in any order. Group A is one decision followed by either a
substantial addon change or a small upstream one.

---

## Group A — the `LibKa0s-Perf-1.0` decision (WG-30 … WG-35)

### The situation

Six MUSTs are open because of one recorded decision. `docs/pending/LEDGER.md:63` (`LIBKA0S-15`)
declines the harness on two structural grounds and states the user was asked and took it on
2026-08-02. The reasoning is not hand-waving:

1. **No hot path.** Zero `OnUpdate`, zero tickers, zero repeating timers. The only work reachable
   inside a combat-gated capture window is the roster handler — an `IsInGroup()` and three
   comparisons — which on most pulls fires zero times. Every declared bucket would read `0.000`, and
   performance-§3 itself says a bucket no bracket meaningfully reaches is *"a lie in every report"*.
2. **`suspend` would destroy user data.** WhatGroup is a **capture** addon. `OnApplyToGroup` records
   the group applied to and the LFG status event carries it to the invite. Making the addon inert for
   a measurement window means an apply or an invite-accept inside that window is never recorded — so
   the popup and chat summary the player joined for silently do not appear. performance-§6's
   contract does not have a shape for *"inert except for the one thing that must not stop"*.

Four of the eight adopters (BankLedger `LIBKA0S-17`, PanelMaster `LIBKA0S-31`, prettychat
`LIBKA0S-12`, and this) have declined on the same reasoning independently. That is a pattern, not
four oversights.

### Route A1 — wire it anyway

Full conformance. Six files change:

- **`core/PerfSetup.lua`** (new) — `LibStub("LibKa0s-Perf-1.0", true)` silently, guarded `:New`,
  and a stub carrying `on`, `Note`, the slash entry point and whatever the show-decision ladder
  touches. TOC slot: in `# Core`, before `modules/Frame.lua`.
- **Buckets** — realistically two: `rosterUpdate` (the `GROUP_ROSTER_UPDATE` handler) and
  `captureApply` (the `ApplyToGroup` post-hook), each bracketed with the exact gated idiom
  performance-§2 pins. Both will read near zero, which is honest — they are the addon's only
  repeated work — but performance-§3's "bucket a bracket actually reaches" test is satisfiable, and
  the suite must pin it (testing-§8).
- **Suspend** — the hard part, and the reason this route is not obviously right. The only defensible
  implementation unregisters `GROUP_ROSTER_UPDATE` and cancels the notify timer while **keeping**
  the two `hooksecurefunc` post-hooks live, so captures still land and only the *announcement* is
  suppressed. That is a deliberate reading of performance-§6's *"stop producing output"* over its
  *"unregister its event frames"*, and it needs a written justification in-code and a case pinning
  that a capture taken during suspend survives to resume.
- **`WhatGroupPerfDB`** (WG-31) — TOC line, and the name handed to the descriptor. `.luacheckrc`
  `globals` (WG-35).
- **`perf` verb** (WG-32) — one `COMMANDS` row, dispatching to the library's entry point and printing
  the returned lines through `NS.Print`. The library registers nothing.
- **Docs and the offline runner** (WG-33, WG-34) — `docs/performance.md`, `docs/perf-runs/README.md`,
  `tests/perf.lua` with the zero-overhead scenario, kept out of `tests/run.lua`'s suite list.

**Risk:** the suspend reading above is a genuine reinterpretation of a MUST. Shipping it without
raising it upstream would be exactly the silent conformance `CLAUDE.md`'s deviation rule forbids.

### Route A2 — take it upstream (recommended)

`performance`'s adoption-strength paragraph already splits **wiring (MUST)** from **coverage
(SHOULD)** on the grounds that *"some addons have almost no hot path"*. The evidence now says the
split is one notch off: four of eight addons have no hot path **and** a suspend contract that would
cost the user a feature. The amendment is small and self-contained:

- a carve-out in `performance-§1`/`§6` for an addon whose suspended arm would **lose user-visible
  work** rather than pause a display, requiring the decline to be **recorded** (which `LIBKA0S-15`
  already is) and a `docs/performance.md` stating it;
- `toc-file-§2` and `lint` relax `<Addon>PerfDB` from unconditional to *"when the harness is wired"*;
- `slash-commands-§2` keeps `perf` **reserved** either way — a reserved verb that is unimplemented is
  fine; a reserved verb meaning something else is not.

Under A2, `WG-30`/`WG-31`/`WG-32`/`WG-34`/`WG-35` close as compliant, and `WG-33` shrinks to the one
doc worth having regardless: a `docs/performance.md` that says *this addon has no bracketed hot path,
here is why, here is where the decision lives*. That page is genuinely useful — it is the thing that
stops the next reader hunting for a harness that was never meant to exist.

**This is the user's call, not the auditor's.** Both routes are recorded so the choice is a choice.

---

## Group B — free-standing fixes

### WG-37 — delete the two `print()` fallbacks

`settings/Panel.lua:22-25` and `settings/Schema.lua:48-51`. The fallback arm is unreachable (the TOC
loads `# Core` before `# Settings`, and `core/WhatGroup.lua:83` sets `_print` there), so removing it
changes no behavior.

```lua
-- both files, replacing the local pout
local function pout(...)
    if NS.Print then return NS.Print(...) end
end
```

Two things to keep straight while editing: the *guard* is worth keeping (it costs nothing and the
files are loaded by the test harness in permutations the client never produces), but the *second
printer* is not — a no-op is the correct degraded behavior here, because `core/CoreSetup.lua` already
guarantees a working `NS.Print` on both the library-present and library-absent paths, so the only way
to reach this arm at all is a load-order bug that the harness's own derivation cases would catch
first.

**Risk:** none. **Tests:** `tests/test_panel.lua` and `tests/test_settings.lua` already capture chat
through the mock's global `print`; if any case relies on the raw-print arm, it was testing the wrong
path and should move to asserting through `NS.Print`.

### WG-40 — drop the combat guard from `Settings.Register()`

`settings/Panel.lua:245-251`. Delete the `InCombatLockdown()` early return and its `pout` line.

The guard was added as defense-in-depth against a taint that options-ui-§9 says does not come from
category registration — and the addon's *own* documentation (`docs/ARCHITECTURE.md:66`,
`settings/Panel.lua:232-236`) already identifies its real boot-taint sources as the secure teleport
button and the `UISpecialFrames` insert, both of which stay deferred in `modules/Frame.lua` and are
untouched by this change. The panel-**open** gate is unaffected: it lives inside the library's
`OpenOptionsPanel` (options-ui-§2), which every caller reaches.

If the guard is kept instead, it **must** grow a recovery arm — register a one-shot
`PLAYER_REGEN_ENABLED` handler that retries — because the current behavior leaves the category
missing until the user runs `/wg config`, which is the defect options-ui-§9 exists to prevent.

**Risk:** low, and the failure mode is loud rather than silent — if registration during combat did
taint something, it would surface as `ADDON_ACTION_FORBIDDEN` on a GameMenu button, which
`docs/smoke-tests.md` already has a check for. **Tests:** add a case driving `OnEnable` with the mock
reporting `InCombatLockdown() == true` and asserting the category still registers.
**Smoke test:** log in / `/reload` while in combat, confirm **Ka0s WhatGroup** is in Settings →
AddOns without running `/wg config`, then click Logout from the GameMenu.

### WG-36 — `.pkgmeta` ignore list

Add `- _dev` and `- "*.bak"` under `ignore:`. One line each, no behavior change, and it closes a
literal MUST. Do it in the same commit as WG-43's `.pkgmeta` comment fix.

### WG-41 — `docs/complexity.md`

`lizard core/ defaults/ locales/ modules/ settings/` (excluding `libs/` and `tests/`), redirected to
`docs/complexity.md` with a two-line header saying it is generated and how. performance-§10 is
explicit that it **must not** gate commits — this is a report read when deciding where to refactor,
and absent tooling means the report is stale rather than the addon non-compliant.

### WG-42 — mono-font fallback

`core/WhatGroup.lua:96`. Either resolve the constant through a guard falling back to
`Fonts\ARIALN.TTF`, or write the omission down as deliberate. The honest version of the first:

```lua
local MONO = "Interface\\AddOns\\WhatGroup\\media\\fonts\\JetBrainsMono-Regular.ttf"
NS.FONT_MONO = MONO   -- Fonts\ARIALN.TTF is the fetch-failure fallback (debug-logging-§2)
```

with the fallback applied where the descriptor reads it, since the library validates `font` at `:New`
time and a nil there raises. Note this is only reachable if a **vendored** file fails to load, which
is close to hypothetical — so the written-down-decision route is also defensible and cheaper.

### WG-43 — retired section citations

`.luacheckrc:1`: `(§14)` → `(lint)`. `.pkgmeta:4`: `(§3.3, §13)` → `(library-stack-§3, packaging)`.
Comment-only.

---

## Group C — documentation shape

### WG-38 — relocate `## Bundled libraries`

Move `README.md:81-83` into `docs/ARCHITECTURE.md`'s `## External dependencies` section, which
already carries the same list in more detail. If the MIT attribution needs to stay user-visible,
fold one sentence into the `## How it works` closing paragraph rather than keeping a section for it.
The canonical twelve sections and their order are already correct, so this is a deletion plus a
paste — no renumbering, no other section moves.

### WG-39 — four headings in `docs/ARCHITECTURE.md`

Add, in documentation-§3's order, interleaved with what is already there:

- **`## Settings Schema`** — a `Path | Type | Default | Widget | Section` table generated from
  `settings/Schema.lua`, with a pointer to `docs/settings-system.md` for the mechanics. The pointer
  stays; the table is what is missing.
- **`## Message Bus`** — one paragraph: *this addon has none*. One feature module, no cross-module
  messages, so architecture-§4's receiver-clobber rules are not reachable. Saying so is the point —
  an absent section reads as an oversight, a section saying "none, and here is why" reads as a
  decision, and the next person to add a second module needs to find that sentence.
- **`## Slash Commands`** — the `Command | What it does` table straight from `NS.COMMANDS`, matching
  the README's. Both are generated from one table, so they cannot drift.
- **`## Known Limitations`** — content already exists and is currently scattered: the English-only
  locale scope (`docs/scope.md`), the declined Perf wiring (`LIBKA0S-15`), the console's lost
  position persistence (`LIBKA0S-05`), and the `LIBKA0S-12` parse-string gap.

**Risk:** none; documentation only. **Sync:** `wow-addon:sync-docs` keeps the slash table in lockstep
afterwards.

---

## Ordering constraints

1. **WG-43's `.pkgmeta` edit and WG-36 touch the same file** — one commit.
2. **WG-30 gates WG-31, WG-32, WG-33, WG-34 and WG-35.** None of them should be closed
   independently: a `WhatGroupPerfDB` declared in the TOC that nothing ever writes, or a `perf` verb
   that answers nothing, is worse than the honest absence — it advertises a capability the addon does
   not have.
3. **WG-39's Known Limitations entry depends on the WG-30 outcome** — write it last, so it records
   what was actually decided rather than what was pending.
4. Everything else is independent.

## What must not be "fixed"

Recording these so a later pass does not undo a correct decision:

- The **vendored JetBrains Mono font** (`WG-20`) and the **landing-page logo** (`WG-21`) are
  sanctioned shipped media (debug-logging-§2, options-ui-§5). Not deviations.
- The **Options stub's load-completing shape** (`settings/OptionsSetup.lua:19-84`) is the one
  documented exception in options-ui-§1, measured and pinned. Making it member-answering like the
  other three would be a regression.
- The **host `RestoreAllDefaults` override** (`LIBKA0S-08`) and the **next-frame panel-build hop**
  (`LIBKA0S-07`) are deliberate, justified in-code, and sanctioned by options-ui-§9.
- **`libs/LibKa0s/` and `tests/_kit/`** are byte-identical whole-folder copies. Never edit either;
  a library defect is an upstream fix plus a re-vendor commit (library-stack-§7).
- The **two `Perf` files under `libs/LibKa0s/`** stay vendored whatever route Group A takes. The ship
  payload is the whole folder regardless of what the addon wires (anti-pattern #48).
