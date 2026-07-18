# 02 — Deviations

**Addon:** Ka0s WhatGroup · **Prefix:** `WG-` · **Standard:** v2.7.0 (2026-07-17) · **Date:** 2026-07-18

Stable per-addon IDs. A recurring deviation keeps its original ID; new deviations continue from
`WG-22` (`WG-20`/`WG-21` are sanctioned in-code exceptions — the vendored debug font and the logo —
which the standard says an audit **MUST NOT** flag, so they are not deviations). Severity:
**MUST** = standard violation (bug); **SHOULD** = strongly preferred, deviation needs a code
comment. Evidence with `file:line` is in `03_EVIDENCE.md`; remediation in `04`/`05`, keyed by ID.

## Summary

| Severity | Count | IDs |
|---|---|---|
| MUST | 9 | WG-09 · WG-14 · WG-19 · WG-22 · WG-23 · WG-24 · WG-25 · WG-26 · WG-29 |
| SHOULD | 3 | WG-17 · WG-27 · WG-28 |

**Verdict: moderate deviations.** All nine MUST failures are contained, mechanical edits; the
addon's core architecture (private namespace, schema-single-source, eager settings registration,
Compat, tests/lint, debug console, canonical docs) is compliant. Most WG-01…WG-19 findings from
the 2026-07-12 audit are closed (see `01_CURRENT_STATE.md`); the recurring ones are noted below.

**Closed since 2026-07-12:** WG-01, WG-02, WG-03, WG-04, WG-05, WG-06, WG-07, WG-08, WG-10,
WG-11, WG-12, WG-13, WG-15, WG-16, WG-18. (WG-19 partially recurs; WG-09/WG-14/WG-17 recur.)

---

## MUST

### WG-09 — TOC missing `X-Wago-ID` (toc-file-§1) · *recurring, conditional*
`WhatGroup.toc` carries `X-Curse-Project-ID: 1489907` but no `X-Wago-ID`. toc-file-§1: "MUST have
`X-Curse-Project-ID` **and** `X-Wago-ID` once an addon is published anywhere." **Fix:** add
`## X-Wago-ID: <id>` as the last metadata line if a Wago listing exists; if the addon is
deliberately not on Wago, record that as an accepted deviation rather than inventing an ID.

### WG-14 — TOC file-listing section order departs from the mandated order (toc-file-§5, anti-pattern #28) · *recurring, redefined*
The `#`-sections run `Libraries → Core → Defaults → Locales → Settings → Modules`. toc-file-§5
MUSTs the order **`Libraries → Locales → Core → Defaults → Modules → Settings`** (settings load
**last**; locales right after libraries). **Fix:** reorder the section blocks (and their file
lines) so `# Locales` sits directly after `# Libraries`, and `# Settings` is the final block
after `# Modules`. Load order is runtime-safe either way (cross-refs resolve at runtime), so this
is a pure text reorder.

### WG-19 — Generated help header ends with a trailing colon (slash-commands-§4) · *recurring, partial*
`printHelp` emits `… is an alias for /wg):` — the line ends in `:`. slash-commands-§4: "**No**
chat line the addon prints … MUST end in a trailing `:`." (The `NS.PREFIX` constant and the
`list`/`get`/`set` colour scheme are already compliant — this is the residual colon.) **Fix:**
drop the trailing colon from the header string.

### WG-22 — Chat printer and debug sink are not secret-safe (events-frames-taint-§8, slash-commands-§4, debug-logging-§4, anti-pattern #35) · *new*
There is no secret-safe stringifier in the addon (no `NS.SafeToString` / `NS.IsConcatSafe`). The
chat printer `p(...)` calls the global `print(CHAT_PREFIX, ...)` with raw args, and the debug sink
`NS.Debug` runs `fmt:format(...)` directly. A combat-protected "secret" value routed through
either raises in `string.format`/`table.concat` (and, on the repaint/notify path, can freeze the
feature until `/reload`). The rule is non-compliance "even if never handed a secret today."
**Fix:** add the shared `NS.IsConcatSafe` / `NS.SafeToString` seam (the reference `probeConcat`
form) in a `core/Util.lua` (or `core/WhatGroup.lua`), and build every chat line and every
`NS.Debug` line through it.

### WG-23 — Chat call sites bypass the single shared printer (slash-commands-§4, events-frames-taint-§8, anti-pattern #35) · *new*
`WhatGroup:ShowNotification` builds each line as `print(CHAT_PREFIX .. " " .. … .. tostring(…))` —
hand-writing the `[WG]` tag and pre-concatenating args through `..`/`tostring` before printing,
and calling the global `print` rather than the shared `NS.Print`. slash-commands-§4 /
events-frames-taint-§8: call sites **MUST NOT** call global `print()`, hand-write the tag, or
pre-concatenate through `..`/`tostring`/`table.concat`; every line funnels through one shared
secret-safe printer. **Fix:** route every notification/hint line through `NS.Print` (which, per
WG-22, secret-stringifies and prepends the tag); pass the tag/label and value as separate args
instead of a pre-built string. (Depends on WG-22.)

### WG-24 — Profile defaults hardcoded in `settings/Schema.lua`, no `defaults/Profile.lua` (savedvariables-§2, layout-§1) · *new*
Every default is a `default =` field on a schema row, threaded into AceDB by
`Settings.BuildDefaults()`; `defaults/` contains only `TeleportSpells.lua` (data), no
`Profile.lua`. savedvariables-§2 MUSTs defaults declared in `defaults/Profile.lua` as the **only**
place a default is hardcoded, with schema `default =` referencing those constants if reused. This
is in tension with schema-as-single-source (architecture-§5), which the addon implements well.
**Fix (pick one, user decides):** (a) move the default *values* into `defaults/Profile.lua` as a
`C` table and have each schema row's `default =` reference `NS.C.<path>`; or (b) record this as an
**accepted deviation** (schema is the single source) with an in-code justification comment.

### WG-25 — Combat panel-open refusal is non-canonical and uncoloured (options-ui-§2) · *new*
`runConfig` refuses correctly under `InCombatLockdown()` (good — it does not defer-and-replay),
but prints `"Cannot open the settings panel during combat. Try again after combat ends."` in the
default colour. options-ui-§2 MUSTs a single `NS.PREFIX`-tagged **grey** notice with the canonical
text **"cannot open settings during combat — Blizzard's category-switch is protected"**. **Fix:**
replace the locale string/print with the canonical grey (`|cff888888…|r`) notice.

### WG-26 — Standalone windows don't persist position/size (standalone-windows) · *new*
The popup (`modules/Frame.lua`) is movable but re-centres on every build and never saves its
point; the debug console (`core/DebugLog.lua`) likewise opens at a fixed `CENTER` offset with no
persistence. standalone-windows MUSTs persisting window position (and size, where resizable) in
SavedVariables (e.g. `db.global.window`), restored on open. **Fix:** on `OnDragStop`, capture the
frame point into a `db.global` sub-table and restore it in the show path (guard behind AceDB
being ready). *(The popup is a transient info window; if the team decides geometry persistence
isn't wanted for it, record that as an accepted deviation and still persist the debug console.)*

### WG-29 — No standalone `version` slash verb (slash-commands-§3) · *new*
The `COMMANDS` table has `help/show/test/config/list/get/set/reset/debug` but no `version`.
slash-commands-§3 MUSTs a standalone `version` verb printing `<tag> v<version>` on its own line,
reading the version from TOC metadata (`GetAddOnMetadata`) with the in-code constant as fallback.
**Fix:** add a `{"version", "Print addon version", …}` row that prints via `NS.Print` using the
TOC `Version` field (fallback `WhatGroup.VERSION`).

---

## SHOULD

### WG-17 — Mandatory `AceTimer-3.0` neither vendored nor mixed in (library-stack-§1) · *recurring, accepted*
The mandatory-lib table lists `AceTimer-3.0`; the addon uses raw `C_Timer.After` and omits
AceTimer from `libs/` and the `NewAddon` mixin list. An in-code SHOULD-justification comment
already documents the deliberate choice (the generation-counter cancel gives the one thing
AceTimer would add). **Status:** accepted, documented deviation — no action required unless the
team wants to conform. Kept on the register so it stays visible.

### WG-27 — Standards-reference section not under the canonical heading (documentation-§2/§6, anti-pattern #34) · *new*
`CLAUDE.md`'s standards section is titled **"## Standards adherence — read before any change"**;
documentation-§2/§6 (and anti-pattern #34) name the required section **`## Standards compliance
(read first)`**. The *substance* is fully present (stop-and-flag; accepted-deviation vs
change-the-standard; "when in doubt…"), and `docs/agent-context.md`'s first hard rule carries the
conform-to-the-standard rule — but it points back to the `docs/audits/` snapshot rather than to a
`CLAUDE.md` "Standards compliance" section by that name. **Fix:** rename the `CLAUDE.md` heading to
`## Standards compliance (read first)` and have the `agent-context.md` first hard rule reference it
by that name, so the four-place reference is greppable by the canonical anchor. *(The section also
cites the retired `§0` notation — update to a current cross-reference while editing.)*

### WG-28 — No shared `SKIN` + `ApplySkin` re-skin seam for the windows (standalone-windows) · *new*
The popup (`modules/Frame.lua`) and the debug console (`core/DebugLog.lua`) each hand-roll their
own backdrop/colours inline. standalone-windows SHOULDs centralising the window look in a single
`SKIN` table + one `ApplySkin(frame)` seam that the debug console reuses, so a future
settings-driven re-skin has one touch point. **Fix:** extract a shared `NS.SKIN` + `NS.ApplySkin`
(the debug console already has a local `applySkin` to promote) and apply it from both windows.
