# 04 — Technical Design (remediation)

**Addon:** Ka0s WhatGroup · **Standard:** v2.7.0 (2026-07-17) · **Date:** 2026-07-18

How to close each gap in `02_DEVIATIONS.md`. This is design only — the audit changes no code.
Every change lands under the addon's TDD gate: a covering headless test (where logic exists) plus
`lua tests/run.lua` green and `luacheck .` clean before commit. Keyed by deviation ID.

---

## Theme A — the secret-safe single-printer seam (WG-22, WG-23)

The anchor change. Today `p()` and `NS.Debug` feed raw args to `print`/`string.format`, and
`ShowNotification` hand-builds tagged lines. The standard wants **one** secret-safe seam that
every chat and debug line flows through.

- **New `core/Util.lua`** (loaded first among addon files, before `WhatGroup.lua`), exposing:
  - `NS.IsConcatSafe(v)` — `pcall(function() return table.concat({v}) end)` (probe `table.concat`,
    **not** `..`).
  - `NS.SafeToString(v)` — `nil`→`"nil"`, booleans→`tostring`, concat-safe→`tostring`, else
    `"<secret>"` (the reference form from events-frames-taint-§8).
- **Rework the chat printer.** Move the single `NS.Print` into `Util` (or keep it in
  `WhatGroup.lua` but have it call `NS.SafeToString` on each arg). Signature: `NS.Print(...)`
  prepends `NS.PREFIX` and joins `NS.SafeToString(arg)` for each argument with a space. Reclaim it
  after `NewAddon` per architecture-§2 (AceConsole embeds `:Print` onto `NS`) — the naming-
  cheatsheet convention is `NS.Util.print`; either name it that and call it everywhere, or set
  `NS.Print = NS.Util.print` immediately after `AceAddon:NewAddon(...)`. (WhatGroup does **not**
  currently mix in AceConsole's `:Print` collision because it never calls a bare `NS.Print` before
  the reclaim — but making the seam explicit removes the latent trap.)
- **Route the debug sink through the seam.** `NS.Debug` builds `msg` via `NS.SafeToString` on each
  `...` value before `string.format` (or formats then guards) — so a secret logged in combat
  yields `<secret>` instead of raising. Keep the zero-alloc gate as the first line.
- **Migrate call sites (WG-23).** Rewrite `ShowNotification` so each line is
  `NS.Print(label, value)` (or `NS.Print(prefixText, colorize(...))`) with the pieces passed as
  **separate args** — no `print(CHAT_PREFIX .. …)`, no `tostring`/`..` pre-concatenation. The
  colour codes for labels are fine as literal strings; the *values* (group title, leader, etc.)
  must arrive as args the seam stringifies. Sweep every `print(` in `core/ settings/ modules/`
  (16 sites) to confirm they go through `NS.Print`/`ack`/`pout`, not the global.
- **Risk:** low. Values are LFG-sourced (not secrets today), so behaviour is unchanged out of
  combat; the seam only adds a guard. Watch that colour codes and the em-dash spacing render
  identically after the arg split (a smoke check on `/wg test`).
- **Tests:** `test_util.lua` — `IsConcatSafe`/`SafeToString` on nil/bool/string/table; a fake
  "secret" (a table/userdata that raises in `table.concat`) resolves to `<secret>`. Extend
  `test_debuglog.lua` to assert the sink doesn't raise on an unsafe arg.

---

## Theme B — slash surface (WG-19, WG-29)

- **WG-29 `version` verb.** Add a `COMMANDS` row `{"version", "Print addon version", function(self)
  runVersion(self) end}` placed after `config` (mirrors the standard's example ordering).
  `runVersion` reads `C_AddOns.GetAddOnMetadata("WhatGroup", "Version")` (fallback
  `WhatGroup.VERSION`) and prints `NS.Print("v" .. ver)` → `[WG] v1.3.0`. It surfaces
  automatically on the landing page and README slash table (both generate from `COMMANDS`).
- **WG-19 header colon.** Delete the trailing `:` from the `printHelp` header string
  (`core/WhatGroup.lua:637`).
- **Risk:** trivial. **Tests:** extend a slash suite to assert `version` prints `v<version>` and
  that the help header does not end in `:`.

---

## Theme C — TOC & metadata (WG-09, WG-14)

- **WG-14 order.** Reorder the file-listing blocks in `WhatGroup.toc` to
  `# Libraries → # Locales → # Core → # Defaults → # Modules → # Settings`. Move the `# Locales`
  block (currently after Defaults) up to directly after Libraries, and move `# Settings` to the
  end after `# Modules`. Verify in-game load still works (it will — Schema/Panel reference
  `NS.addon`/`NS.L`, both available before Settings under the new order; Frame references resolve
  at runtime). Anti-pattern #28 also wants the field order preserved — it already is.
- **WG-09 `X-Wago-ID`.** If a Wago listing exists, append `## X-Wago-ID: <id>` as the final
  metadata line (after `X-Curse-Project-ID`). If the addon is intentionally Curse-only, instead
  record an accepted deviation (a short note in the audit + a TOC comment) rather than a fake ID.
- **Risk:** low. **Tests:** none (metadata); confirmed by an in-game load + `/wg` smoke.

---

## Theme D — settings & window polish (WG-24, WG-25, WG-26, WG-28)

- **WG-24 defaults home.** Preferred: create `defaults/Profile.lua` exporting `NS.C` (a nested
  table of the default *values*), loaded after `Constants`/before Schema; each schema row's
  `default =` becomes `NS.C.notify.delay` etc.; `BuildDefaults` still threads them into AceDB. This
  keeps schema-as-single-source (the schema still drives widgets/slash/reset) while satisfying
  savedvariables-§2 (values live in `defaults/Profile.lua`). Alternative: keep as-is and log an
  accepted deviation. **User decides** — the two-source split adds a small indirection.
- **WG-25 combat notice.** Replace the runConfig combat branch with a grey canonical notice:
  `NS.Print("|cff888888cannot open settings during combat — Blizzard's category-switch is
  protected|r")` (or add a locale key with that exact text and grey colour). Keep the refuse-and-
  return behaviour (no defer-replay).
- **WG-26 window geometry.** Add a `db.global.windows` sub-table. On `OnDragStop` for the popup and
  the debug console, capture `point, relTo, relPoint, x, y` (and size for a resizable window — the
  popup is fixed-size, so point only) into that table; on show, restore it if present (fall back to
  the current default point). Guard on `WhatGroup.db` existing (the debug console can be shown
  before login in theory — it isn't, but guard anyway). *(If the team prefers the popup stay a
  transient centred info window, persist only the debug console and record the popup as accepted.)*
- **WG-28 shared skin.** Promote `core/DebugLog.lua`'s local `BACKDROP`/`applySkin` to
  `NS.SKIN` + `NS.ApplySkin(frame)` (in `Util` or a small `core/Skin.lua`), and call it from both
  the popup (`modules/Frame.lua`) and the console. One re-skin touch point thereafter.
- **Risk:** WG-26/WG-24 are the higher-touch items (new SavedVariables sub-tree; new defaults
  file + schema refactor). Both are well-contained. **Tests:** `test_settings.lua` — with
  `defaults/Profile.lua`, assert `BuildDefaults` still produces the same profile shape; a window
  geometry round-trip test (store point → restore) against the mock frame.

---

## Theme E — standards-reference heading (WG-27)

- Rename the `CLAUDE.md` section heading from `## Standards adherence — read before any change` to
  the canonical **`## Standards compliance (read first)`**, keeping the existing (compliant)
  substance. Update the `docs/agent-context.md` first hard rule to reference *"the root CLAUDE.md
  'Standards compliance' section"* by name. Replace the stale `§0` reference with a current
  cross-ref. Pure docs; no code, no tests. This makes all four reference sites (TOC `X-Standard`,
  README badge, `CLAUDE.md`, `agent-context.md`) greppable by the canonical anchor (anti-#34).

---

## Cross-cutting notes

- **Ordering constraint:** Theme A (the seam) lands **before** WG-23's call-site migration and
  before WG-29's `version` verb (which should print through `NS.Print`). Everything else is
  independent.
- **No version bump / no auto-commit** — per the repo's hard rules, remediation commits are the
  user's call; each lands only on green tests + clean lint.
