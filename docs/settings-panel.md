# Settings system

A single flat array `WhatGroup.Settings.Schema` declares every option. One row drives six surfaces simultaneously, so adding a setting is a single-row diff.

The **Master controls** block is the exception, and it is the library's: `Helpers.MasterControls` composes options-ui-§15's canonical eight-control tab from one declaration in `settings/Panel.lua`, which splices the rows it returns at the head of the array. Everything else — the schema rows and the data seams that read and write them — lives in `settings/Schema.lua` and that half is genuinely this addon's. The panel *machinery* is not: the canvas factory, the header and breadcrumb, the lazy Defaults button, the AceGUI ScrollFrame, the widget makers, the two-column flow engine, the tab strip and its chrome band, the page registry and the refresh fan-out are `LibKa0s-Options-1.0`'s, wired up in `settings/OptionsSetup.lua`. `settings/Panel.lua` keeps only the landing page's body, the one action button the library's makers cannot express, and the General page's registration.

## Six surfaces, one row

| Surface | Mechanism |
|---|---|
| Settings panel widget | `Helpers.RenderTabbedSchema(ctx, "general", AFTER_GROUP)` → `Helpers.RenderRows` → `Helpers.RenderField` → the library's CheckBox / Slider makers; each maker appends a refresher closure to **`ctx.refreshers`** (per panel, not a global registry) |
| `/wg list` | `Sl:CliList()` (`LibKa0s-Slash-1.0`) groups the schema by `section` — this addon's `groupKey`, because these rows carry no `page` — and prints `path = formattedValue` per row |
| `/wg get <path>` | `Sl:CliGet` → `Helpers.FindSchema(path)` → `lib.FormatValue`, which honors `def.fmt` for numbers |
| `/wg set <path> <value>` | `Sl:CliSet` → type-aware parse → `Helpers.Set(path, value)` (orchestrated: writes value, logs one `[Set]` line, fires `onChange`, runs `RefreshAll` in one call) |
| AceDB defaults | `Settings.BuildDefaults()` walks the schema, threads each row's `default` into the right slot under `profile.*` |
| `/wg reset <path>`, `/wg resetall` + Defaults button | **One row:** `Sl:CliReset` → `Helpers.ApplyDefault(row)` — the ordinary `Set` path, no confirmation. **Everything:** `/wg resetall` and the Defaults button both `StaticPopup_Show("WHATGROUP_RESET_ALL")` → on confirm → `Helpers.RestoreAllDefaults()` (one `db:ResetProfile()`, which empties the active profile in place, merges the defaults back and fires `OnProfileReset`; then the `sessionOnly` rows are restored by hand, because a profile reset cannot reach storage that is not the db) |

`/wg reset` taking a path is a **breaking change** — it used to be the confirmation-gated global wipe, which is now `/wg resetall`. A bare `/wg reset` prints a deprecation naming both replacements rather than a usage error, because the old form still parses as something. See [slash-dispatch.md](./slash-dispatch.md).

The schema is settings-only — the action buttons (Reset position / Reset all settings, and the "Test" button) render through the `AFTER_GROUP` hook table in `settings/Panel.lua`, not as schema rows. See [Action buttons](#action-buttons-aftergroup).

## Row format

```lua
{
    section,            -- groups in /wg list output (general, frame, notify)
    group,              -- TAB in the Settings panel ("Master controls", "Chat", "Popup")
    subgroup,           -- optional SUBSECTION heading inside a tab that mixes control kinds
                        --   (options-ui-§7) — drawn whenever it changes, never suppressed
    path,               -- dotted path into db.profile (e.g. "notify.delay")
    type,               -- "bool" | "number" | "string" (an enum, with `values` + `sorting`)
    label, tooltip,
    default,
    min, max, step, fmt,    -- numbers only (fmt is %s-style for /wg get formatting)
    values, sorting,        -- strings only: the enum's key→label map and its display order
    onChange,               -- optional fn(value) called by panel widget + /wg set (NOT by RestoreAllDefaults — reset skips onChange)
    solo,                   -- if true, render alone in the left half of its own row (right half empty)
    startsLine,             -- flush the pending line BEFORE this row, so a declared pair cannot split
    sessionOnly,            -- storage is the row's own get/set, never db.profile — see below
}
```

**`sessionOnly`** is what keeps the debug console off SavedVariables now that it is a schema row. `settings/Schema.lua` holds a `SESSION` table keyed by path; `Helpers.Get` and `Helpers.RawSet` consult it **in front of** `Resolve`, so a session path never reaches `db.profile` from any caller — the panel checkbox, `/wg set`, `ApplyDefault` and the reset sweep all funnel through those two functions. `BuildDefaults` skips such a row outright, and `RestoreAllDefaults` restores it row by row because `db:ResetProfile()` cannot reach it (options-ui-§12). The pair itself is `NS.DebugLog:ConsoleCheckbox()`'s, unchanged from when the checkbox was drawn by hand.

Number rows render as a slider that **commits on release** — the library's maker writes from `OnMouseUp`, snapping to `step` relative to `min`. Its opt-in live-commit path (`row.commitOn = "change"`, throttled through the descriptor's `scheduleTimer`) is not used here: nothing in this addon previews a delay while you drag it, and no `scheduleTimer` is passed.

### Action buttons (afterGroup)

Non-setting affordances live outside the schema. `Helpers.RenderTabbedSchema(ctx, pageKey, afterGroup, pairWith)` takes the same two hook tables `RenderSchema` does; this page passes only the first, `afterGroup`, with two entries:

- **`afterGroup`** — `{ [groupName] = function(ctx) ... end }`. Fires once per render, after the named group's last schema row is flushed, so the widget starts on a fresh line *below* the grid. Two entries now:
  - **`["Master controls"]`** — the composer's own tail, drawing options-ui-§15's closing **button pair**: *Reset position* (this addon is not frameless) and *Reset all settings*. The group name **is** the hook key, so renaming the group detaches the hook and nothing errors.
  - **`["Chat"]`** — the **Test** button (`Helpers.InlineButton` → `WhatGroup:RunTest()`). It followed the tab its group ended up on: "General" is the Master controls tab now, and the button's own tooltip already said it previews the chat-output toggles. It is deliberately **not** folded into the reset pair — a 160-px left-aligned action is not one of §15's two resets.

There is **no `pairWith` table any more.** It carried exactly one entry — a bespoke `SessionCheckbox` drawing the Debug console beside **Enable** — and options-ui-§15 makes that console a canonical row of the Master controls block instead. The console itself is untouched: same window, same `NS.DebugLog:ConsoleCheckbox()` `get`/`set`, reached now through `settings/Schema.lua`'s `SESSION` table rather than through a hook.

`AFTER_GROUP` is a file-scope constant. That is safe because the library's one-shot bookkeeping is *call-local* — it never consumes the caller's entries — so a re-render draws both buttons again instead of silently dropping them.

Re-sync is push, not poll: the console can be closed with its own × or ESC (or opened by `/wg debug`) while the panel is open, so `core/DebugLogSetup.lua` passes an `onVisibilityChanged` hook that calls `Helpers.RefreshAll()`. If the panel is on screen the checkbox moves immediately; if it is hidden the page is flagged dirty and re-renders on its next `OnShow`. The window is hidden at every login, so the checkbox always starts unchecked (WG-12 / debug-logging-§5).

```lua
local MASTER_ROWS, MASTER_TAIL = Helpers.MasterControls{ ... }

local AFTER_GROUP = {
    ["Master controls"] = MASTER_TAIL,     -- Reset position | Reset all settings
    ["Chat"] = function(ctx)
        Helpers.InlineButton(ctx, {
            text    = "Test",
            tooltip = "...",
            onClick = function() WhatGroup:RunTest() end,
        })
    end,
}
```

`Helpers.InlineButton` is host-owned and the only widget maker that is: the library's `InlineButtonPair` lays *two* buttons across one Flow row at `BUTTON_PAIR_REL` each, and passing it a single spec renders this button at half the panel width. A fixed 160-px left-aligned control is not expressible there, so declining was the smaller change ([`LIBKA0S-09`](https://github.com/tusharsaxena/WhatGroup/issues/9)). It still reads `Helpers.AceGUI`, `Helpers.EnsureScroll`, `Helpers.AttachTooltip`, `Helpers.AddSpacer` and `Helpers.ROW_VSPACER` off the instance rather than restating any of them — a host copy of a library constant is the copy that goes stale.

`WhatGroup:RunTest()` is the same code path `/wg test` invokes, so the two affordances stay in lockstep.

## Helpers

**`Settings.Helpers` *is* the `LibKa0s-Options-1.0` instance.** `settings/Schema.lua` runs first and hangs its data seams (`Get` / `Set` / `RawSet` / `FindSchema` / `ValidateSchema` / `ApplyDefault` / `RestoreAllDefaults` / `RefreshAll`) on a plain table; `settings/OptionsSetup.lua` then calls `lib:New(...)`, copies those members **onto the instance**, and publishes the instance as `Settings.Helpers`. So one table answers both halves, and `Helpers.X` resolves to the library's `X` unless this addon supplied one.

The direction matters. Copying the library's members onto the host's table would look equivalent and is not: `RenderRows` resolves `RenderField` from the instance at call time, so a test that swapped a member on a copy-across table would be spying on a function nobody calls. `settings/Schema.lua`'s file-local `Helpers` upvalue still points at the pre-move table — harmless, because the members are the same function objects and no state lives on either table.

The copy is unconditional, and the one collision is deliberate: **`Helpers.RestoreAllDefaults` overrides the library's member of the same name** ([`LIBKA0S-08`](https://github.com/tusharsaxena/WhatGroup/issues/10)). Copying only where the instance was nil silently handed every caller the library's row-by-row form, and the suite said so. The library's per-page `RestoreDefaults(pageKey, ctx)` is a different verb with a different arity and is untouched — nothing calls it today, because this addon's Defaults button is confirmation-gated and goes through the popup instead.

All schema reads and writes go through a private `Resolve(path, create)` helper that walks dotted paths into `db.profile` and returns `(parent, key)` so the caller can read `parent[key]` or write `parent[key] = value`. **A read does not write** (savedvariables-§2): `create` is what separates the two callers. `Helpers.RawSet` passes `true`, so a write may materialize the intermediate tables it walks through; `Helpers.Get` passes no flag and gets `(nil, nil)` for a path whose parents do not exist, rather than growing `db.profile` one empty table per segment and round-tripping the junk into SavedVariables. Public callers go through `Helpers.Get` / `Helpers.Set`.

| Helper | Purpose |
|---|---|
| `Helpers.Get(path)` | Resolve dotted path; read. A `sessionOnly` path is intercepted by the `SESSION` table before `Resolve` sees it. When `Resolve` cannot reach a parent table — `db.profile` not built yet, an empty path, or an intermediate segment that does not exist — it debug-logs `[Schema] Get: no path -> <path>` and returns nil **without creating anything**. A *typo'd* leaf under a real parent still reads as a silent nil; `ValidateSchema` is the seam that catches a bad `path`. |
| `Helpers.RawSet(path, value)` | Side-effect-free write — resolve dotted path, write, return. No `onChange`, no `RefreshAll`. Reserved for callers that genuinely need raw writes (none today); prefer `Helpers.Set` for everything else. |
| `Helpers.Set(path, value, opts)` | **Orchestrated single write-path.** Calls `RawSet`, logs one `[Set] <path> = <value>` console line (the canonical settings-change trace, debug-logging-§10), then runs the row's `onChange` (in pcall), then runs `RefreshAll`. Every caller — the CLI (`/wg set`), the library's widget makers via the descriptor's `set`, `ApplyDefault`, `RestoreAllDefaults` — routes through here so the side effects can't drift out of sync. It is two-argument by construction from the library's side: the third parameter is an options table the library never passes. `opts.skipOnChange`, `opts.skipRefresh`, and `opts.skipLog` are escape hatches; `RestoreAllDefaults` uses all three — `skipRefresh` (refresh once after the loop), `skipLog` (suppress per-row `[Set]` spam so one coalesced `[Reset]` summary stands in, debug-logging-§9), and `skipOnChange` (the default baseline is already reconciled, so per-row side effects are neither needed nor fired). |
| `Helpers.FindSchema(path)` | linear scan of `Schema` for `def.path == path` |
| `Helpers.ValidateSchema()` | walk Schema and chat-print errors for missing `path`, unknown `type`, non-string `section`/`group`/`label`. Non-fatal. Runs once, as the descriptor's `validate`, before the page builders. |
| `Helpers.ApplyDefault(row)` | Restore one row: `Helpers.Set(row.path, deepcopy(row.default))`. The single-row reset therefore takes the same write path a `/wg set` does — same `[Set]` line, same `onChange`, same refresh. Reached from `/wg reset <path>`, as the slash descriptor's `applyDefault`. It is also the options descriptor's `applyDefault` — the seam the library's `RestoreDefaults` / `RestoreAllDefaults` would call — but neither of those verbs is on a live path here (see below). |
| `Helpers.RestoreAllDefaults()` | **A profile reset** (`options-ui-§12`), and the same act as AceDBOptions' own Reset Profile. **1.** `db:ResetProfile()` — AceDB empties the active profile **in place** (so anything holding `db.profile` keeps the live table), merges the defaults back, and fires `OnProfileReset`, which `core/WhatGroup.lua` answers by re-running the migrations and refreshing every open panel. That is what drops an orphaned key a key-by-key overwrite would leave behind — a value from a removed or renamed row, or one hand-edited into SavedVariables — and it is the one mechanism that can restore a stored **array**, which a row walk can never address. **2.** Each `sessionOnly` row is then restored by hand with `{ skipRefresh, skipLog, skipOnChange }`, because a profile reset cannot reach storage that is not the db; for the debug console that means the window closes. Emits one coalesced `[Reset] active profile reset to defaults` line (debug-logging-§9). **No `RefreshAll` here** — `OnProfileReset`'s handler is the single post-reset reconcile, and calling it again would refresh twice for one action. `db.global` (schemaVersion) is left untouched: a profile reset is not a downgrade. Caller (`StaticPopup` OnAccept, `/wg resetall`) handles confirmation. Overrides the library member of the same name. |
| `Helpers.RefreshAll()` | The host's refresh *name*, kept because the write seam above calls it on every `Set` and the seam file loads first. `settings/OptionsSetup.lua` redefines it as a one-liner onto `RefreshScalars` — writing a value does not change which rows exist, so a rebuild per checkbox click would be waste. What survives in `settings/Schema.lua` is the degraded path: with no panels, a reset must still not raise. |

### Two refresh tiers

There is no `Settings._refreshers`, no `_refresherOrder` and no `_panels`. The registry is the library's and it is **per-ctx**: every widget maker appends its updater closure to the `ctx.refreshers` array of the panel it rendered into, and `ClearScroll` *reassigns* that array on a re-render, so a released widget's closure cannot survive it. Tests reach a live ctx through `Helpers.__panelFor("general")`.

| Tier | What it does |
|---|---|
| `Helpers.RefreshScalars()` | **In place.** Runs each panel's refreshers, so widgets re-read their values without a rebuild. What a plain value write needs — and what `Helpers.RefreshAll` now is. |
| `Helpers.RefreshAllPanels()` | **Structural.** Re-runs each page's declared renderer, so rows that appeared or disappeared are drawn. This addon's schema is fixed, so nothing calls it directly; the library's own `RestoreAllDefaults` would, and that one is overridden. |

Either tier skips a page that is **not on screen** — it flags the ctx dirty and the page re-renders on its next `OnShow`. That is what keeps the Debug console checkbox honest across a panel that was closed while the console was toggled.

### Panel infrastructure helpers

All library members except the last two, which are this addon's (see `settings/Panel.lua`).

| Helper | Purpose |
|---|---|
| `Helpers.CreatePanel(name, title, opts)` | Build a Frame with the unified header (breadcrumb-prefixed `GameFontNormalHuge` title + `Options_HorizontalDivider`-tinted divider + optional Defaults button at top-right) and the three Blizzard canvas callbacks. Returns a `ctx = { panel, body, scroll, refreshers, lastGroup, pageKey }`. `opts.isMain` skips the `"Ka0s WhatGroup <atlas-chevron> "` breadcrumb prefix; `opts.defaultsButton` *records* that the page wants the top-right button (`panel.wantsDefaultsButton`) — the widget itself is built later, on the panel's first show, by `EnsureDefaultsButton`. `panel.OnDefault` **forwards** to `panel.defaultsOnClick` at call time rather than aliasing it, so the Settings window's own footer Defaults control and the header button are one implementation; the page parks its handler after `CreatePanel` returns, so an alias would capture nil forever. |
| `Helpers.EnsureScroll(ctx)` / `Helpers.ClearScroll(ctx)` | Create the page's lazy AceGUI `ScrollFrame` (once), or release its children and reset `ctx.lastGroup` + `ctx.refreshers` for a re-render. The same ScrollFrame is reused. |
| `Helpers.PatchAlwaysShowScrollbar(scroll)` | Rebind an AceGUI ScrollFrame's `FixScroll` so the scrollbar (and its 20-px gutter) stays visible even when content fits — keeps left/right margins symmetric across short and long pages. Restores stock `FixScroll` / `OnRelease` on widget release so the shared AceGUI pool returns clean. |
| `Helpers.Section(ctx, label)` | AceGUI `Heading` widget at `GameFontNormalLarge`, with `SECTION_TOP_SPACER` above (skipped for the first group, where a leading gap reads as a broken top margin) and `SECTION_BOTTOM_SPACER` below. |
| `Helpers.RenderField(ctx, def, parent, relativeWidth)` | Dispatch a single schema row to the right widget maker (`bool` → CheckBox, `number` → Slider, `string` → Dropdown over the row's `values` / `sorting`). |
| `Helpers.SessionCheckbox(ctx, parent, relativeWidth, spec)` | A checkbox wired to `spec.get` / `spec.set` instead of a settings path, for runtime-only state that must never become a saved setting. Registers a refresher like any other widget. |
| `Helpers.RenderSchema(ctx, pageKey, afterGroup?, pairWith?)` | Thin wrapper over `RenderRows` for the rows of one page: emit Section headings on group transitions, pair widgets into 50/50 Flow rows, fire the two hook tables. Each row renders under its own `pcall`, so one corrupt saved value costs that row rather than the rest of the page. **Not what this addon calls** — it is `RenderTabbedSchema`'s own fallback for a page with fewer than two groups. |
| `Helpers.RenderTabbedSchema(ctx, pageKey, afterGroup?, pairWith?)` | **What the General page calls** (`options-ui-§13`). Partitions the page's rows by `group` in declaration order, draws one `TabStrip` tab per group in the page's chrome band, then renders the active group's rows through `RenderRows` with headings suppressed. A tab click is a `ClearScroll` plus a re-render of the same page — no combat gate, because redrawing widgets inside an already-open panel was never a protected action. Falls back to `RenderSchema` when the page has fewer than two groups: one tab is chrome for its own sake. |
| `Helpers.InlineButton(ctx, spec)` | **Host.** One fixed-width (160 px default) action button left-aligned in a full-width Flow row. `spec = { text, tooltip, onClick, width? }`. |
| `Helpers.BuildMainContent(ctx)` | **Host.** Render the addon-landing-page body (logo + TOC notes + Slash Commands heading + per-command Labels) as AceGUI widgets in `ctx.scroll`. Handed to the library as the descriptor's `buildMain`, so the library still owns *when* it draws. |

## `BuildDefaults`

Default *values* live in `defaults/Profile.lua` as the nested `NS.C` table (the single place a profile default is hardcoded, savedvariables-§2 / WG-24); each schema row references its value via `default = C.<path>`, and the Master controls block gets the same values through the composer's `defaults` spec. `BuildDefaults` **seeds from `NS.C`**, then walks `Schema` and threads each row's `default` into the right slot under `profile.*` (deep-copying table defaults):

```lua
function Settings.BuildDefaults()
    -- global seeds schemaVersion (WG-08) and the windows table (WG-26)
    local out = { profile = deepcopy(C),
                  global = { schemaVersion = NS.SCHEMA_VERSION or 1, windows = {} } }
    for _, def in ipairs(Schema) do
        if def.path and not def.sessionOnly then
            -- split def.path on "." into segments
            -- create empty tables along the way as needed
            -- assign def.default to the leaf
        end
    end
    return out
end
```

**The seed is not redundant.** On a full load the two halves agree key for key and the walk writes back what the seed already put there. What it buys is the *degraded* load: the Master controls block is composed by LibKa0s, so with the library absent those six rows are not in the schema at all — and a schema-only sweep would hand AceDB a profile with no `enabled` key, which reads as false and silently turns the addon off for exactly the install that is already missing a library. `tests/test_libka0s.lua` compares the two `BuildDefaults` outputs shape for shape.

A `sessionOnly` row is skipped outright: its storage is its own `set()`, and threading a default for it would materialize the very `db.profile` branch WG-12 keeps empty.

Called once in `OnInitialize` and passed to `AceDB:New("WhatGroupDB", defaults, true)`. AceDB's third arg (`true`) means a single shared `Default` profile across every character on the account.

Because `BuildDefaults` runs at every login, **a new schema row appears with its `default` value the first time the user logs in after the upgrade.** Existing keys are preserved untouched — AceDB merges saved values over the defaults rather than replacing.

## Panel renderer

The General sub-page renders the schema as a two-column AceGUI Flow layout (50/50 per row) inside an always-visible AceGUI `ScrollFrame`. The flow engine is the library's `RenderRows`; the page declares its renderer as

```lua
Helpers.SetRenderer(ctx, function(c)
    Helpers.ClearScroll(c)
    Helpers.RenderTabbedSchema(c, "general", AFTER_GROUP)
end)
```

Only the **active tab's** rows are rendered, so the pairing rules below apply within one group at a time.

Pairing rules:

- **Default**: widgets pair into rows, two per row. The engine maintains a `pendingRow` and `pendingCount`; when `pendingCount` hits 2, it flushes.
- **`solo = true`**: flushes the in-progress row first, then forces the widget onto its own row (left half occupied at 0.5 relative width, right half empty), then flushes again.
- **`group` transition**: on a tabbed page there is none to see — the strip switches groups and each render draws exactly one. (`RenderRows` still flushes and would call `Helpers.Section`; `RenderTabbedSchema` passes `noHeadings`, because the tab already names the group.)
- **`subgroup` transition**: a `Heading` **is** drawn, and is **not** suppressed (options-ui-§7). It names a kind of control inside the tab, so it says something the strip does not. Cleared at every group boundary, so the same name under two groups draws twice.
- **`startsLine = true`**: flushes the pending line *before* the row, so a declared pair cannot be split across two lines. The composer sets it on the first row of each block.
- **`afterGroup[def.group]`**: at the final row of a group (last one in source order, or the next row's group differs), flushes the in-progress row and invokes the callback.

The hook fires **once per render**, and the library tracks that in a call-local set rather than by consuming the caller's table — which is why `AFTER_GROUP` can be a file-scope constant and still survive a re-render.

Layout constants are the library's (`lib.LAYOUT`: `PADDING_X`, `HEADER_TOP`, `HEADER_HEIGHT`, `DEFAULTS_W`, `ROW_VSPACER`, `SECTION_TOP_SPACER`, `SECTION_BOTTOM_SPACER`, `SECTION_HEADING_H`, `BUTTON_PAIR_REL`), and three of them are re-published on the instance for host use (`Helpers.ROW_VSPACER`, `Helpers.SECTION_HEADING_H`, `Helpers.BUTTON_PAIR_REL`). There is deliberately **no host copy of any of them** — options-ui-§8, because a host copy is the copy that goes stale. The only constants in `settings/Panel.lua` are the landing page's own: `MAIN_LOGO_TEXTURE`, `MAIN_LOGO_SIZE` and its three gaps.

### Landing page body

`Helpers.BuildMainContent` draws the logo (WG-21 — the one non-Blizzard-default texture in the addon), the TOC `Notes` one-liner, a `Slash Commands` heading via the library's own `Section`, and one Label per command. Those rows come from `NS.SlashCommands:LandingRows()` — `LibKa0s-Slash-1.0`'s single command-row formatter, walking the same `WhatGroup.COMMANDS` table `/wg help` walks. `Sl:HelpRows()` is the identical rows with a two-space indent, so the panel and the chat help cannot drift. It re-`ClearScroll`s first, because the library re-runs a renderer when a dirty hidden page is shown again.

## Lazy panel build

AceGUI widgets must render against a non-zero panel width. `Settings.RegisterCanvasLayoutSubcategory` parents the panel into the Settings UI, but the panel doesn't get a width until Blizzard sizes it on first show.

**The library owns *when* a page draws.** `Helpers.SetRenderer(ctx, fn)` records the renderer and installs the page's `OnShow`, which builds the Defaults button, refuses (and closes the Settings window, so the refusal is legible) under `InCombatLockdown`, and then renders — on first show, and again when a refresh marked the page dirty while it was hidden. Those are the two moments only the page registry can see. The main page goes through the same seam, with `BuildMainContent` as its renderer.

**This addon adds one more frame hop**, and `settings/OptionsSetup.lua` is where. The library calls the renderer and `EnsureDefaultsButton` *synchronously* inside that `OnShow`; WhatGroup wraps both **on the instance** so the actual work runs on the next frame:

```lua
function O.EnsureDefaultsButton(panel)
    if not panel or panel.defaultsBtn or not panel.wantsDefaultsButton then return end
    if panel.__wgDefaultsScheduled then return end
    panel.__wgDefaultsScheduled = true
    C_Timer.After(0, function() baseEnsureDefaultsBtn(panel) end)
end

function O.SetRenderer(ctx, fn)
    baseSetRenderer(ctx, function(c)
        C_Timer.After(0, function()
            local ok, err = pcall(fn, c)
            ...
        end)
    end)
end
```

The `C_Timer.After(0, …)` deferral matters because Blizzard's GameMenu / Logout flows can dispatch our OnShow inside a secure-execute chain (e.g. when the Logout button's callback iterates registered Settings categories). Creating AceGUI frames synchronously inside that protected chain trips `ADDON_ACTION_FORBIDDEN ... 'callback()'`. Returning from OnShow immediately and running the build one frame later moves the frame creation out of the protected context. `tests/test_panel.lua` has pinned that contract since the fix landed.

Two details are load-bearing. Both members are wrapped **on the instance**, because the library resolves them from `O` at call time — a host-side helper sitting beside them would be bypassed by every page the shell draws. And the render is `pcall`'d **in the wrapper**: the library flipped `_rendered` / `_dirty` and returned from its own `pcall` before this hop runs, so without it a raising builder would surface as a bare Lua error with no page named.

This stayed host-local (`LIBKA0S-07`): options-ui-§9 explicitly sanctions the library's synchronous form, so the extra hop is this addon keeping a belt it had already fastened, not a standards requirement. If a second host wants it, it becomes an additive descriptor field upstream.

The **header's Defaults button is built in that same hop**, for two reasons at once. It is an AceGUI frame, so it is subject to the taint rule above. And it must not be built at registration time either: AceGUI is a *shared* library, UI skins restyle its widgets by hooking `RegisterAsWidget`, and a widget created during load — before those hooks exist — keeps Blizzard's stock red `UI-Panel-Button-Up` art for the session. `Settings.Register` runs at `PLAYER_LOGIN`, so building it there is a race against every other addon's load order that WhatGroup only wins by loading late (options-ui-§5). Its click handler is therefore parked at page-build time as `panel.defaultsOnClick` and wired by the builder.

`Helpers.EnsureScroll` (called by every render path) hooks the AceGUI ScrollFrame's `OnSizeChanged` and forwards the size into AceGUI:

```lua
scroll.frame:SetScript("OnSizeChanged", function(_, w, h)
    if scroll.OnWidthSet  then scroll:OnWidthSet(w)  end
    if scroll.OnHeightSet then scroll:OnHeightSet(h) end
    if scroll.DoLayout    then scroll:DoLayout()     end
    if scroll.FixScroll   then scroll:FixScroll()    end
end)
```

Without this forwarder, AceGUI containers parented to a Blizzard frame stay at width 0 even after Blizzard sets a width on the outer panel. The forwarder pushes Blizzard's `SetSize` events into AceGUI's layout pipeline.

See [midnight-quirks.md](./midnight-quirks.md#lazy-acegui-panel-build) for the broader rule.

## `Settings.Register()`

Idempotent (`WhatGroup._settingsRegistered` guard), and thin: it delegates to `Helpers.CreateOptionsPanel()`, which resolves AceGUI, runs the descriptor's `validate` (this addon's `ValidateSchema` — chat-prints typos, non-fatal), registers the main canvas with its landing-page renderer, then drains the page-builder queue. The General page put itself in that queue at file load with `Helpers.RegisterOptionsPage("general", "General", buildGeneralPage)`. Each builder is `pcall`'d separately, so one raising page can't leave a half-registered tree with nothing naming the culprit. `CreateOptionsPanel` is idempotent in its own right — a second call would otherwise register a second Blizzard category and permanently double the refresh fan-out.

**Not combat-guarded** (`options-ui-§9`). Registering a canvas Settings category never taints, and eager registration at load is a MUST — so `Settings.Register()` runs whether or not the player is in combat. It carried an `InCombatLockdown()` early-return until 2026-08-05, and the cost was real: a `/reload` taken mid-pull left WhatGroup out of the Settings → AddOns list for the rest of that session, since `runConfig`'s fallback call only fires if the player thinks to run `/wg config`. Opening is a different question and is refused separately, inside `Helpers.OpenOptionsPanel` — the *open* path drives Blizzard's protected category switch; the registration path does not.

**Called at login** — from `OnEnable` (PLAYER_LOGIN), so the panel is in the Settings → AddOns list from the moment the player logs in, and again as an idempotent no-op from `runConfig`. This matches every other Ka0s addon: registering a canvas Settings category at login is taint-safe. (An earlier revision deferred this to first `/wg config`, believing the registration tainted GameMenu — a misdiagnosis confounded with the since-removed AceHook closures; see [midnight-quirks.md](./midnight-quirks.md).) WhatGroup's genuine boot-taint sources — the secure teleport button and `UISpecialFrames` insert — stay deferred in `modules/Frame.lua`.



```
Ka0s WhatGroup        ← parent canvas-layout category — landing page (logo, notes, slash list)
└── General            ← subcategory — every schema widget, plus the two afterGroup blocks:
                          the Master controls reset pair and the Chat tab's Test button
```

Both pages share the same header layout (gold title + tinted divider) and the same always-visible AceGUI scrollbar. The parent's title reads `Ka0s WhatGroup` (no breadcrumb because `opts.isMain = true`); the General sub-page reads `Ka0s WhatGroup <atlas-chevron> General` (separator is the inline atlas `|A:common-icon-forwardarrow:16:16|a` — a real texture, not a font glyph, so it renders identically across font / locale fallback) and carries a Defaults button at top-right.

Defaults button → `panel.defaultsOnClick` → `StaticPopup_Show("WHATGROUP_RESET_ALL")` → on confirm → `Helpers.RestoreAllDefaults()`. `/wg resetall` shows the same popup, and the Settings window's own footer Defaults control forwards through `panel.OnDefault` to the same handler, so all three share one OnAccept body.

`WhatGroup._parentSettingsCategory` and `WhatGroup._settingsCategory` (the General subcategory) are the two handles the page build records; the open path does not use them. `/wg config` calls `Helpers.OpenOptionsPanel()`, which holds the main category's own ID, refuses under `InCombatLockdown()` — the gate lives *there* so every caller is refused, not just this verb — opens the parent, and then unfolds the sidebar tree by reaching into the same path the expand-arrow click handler uses:

```lua
Settings.OpenToCategory(mainCategoryID)

pcall(function()
    local list = SettingsPanel.GetCategoryList
        and SettingsPanel:GetCategoryList()
        or SettingsPanel.CategoryList
    if not (list and list.GetCategoryEntry) then return end
    local entry = list:GetCategoryEntry(mainCategory)
    if entry and entry.SetExpanded then
        entry:SetExpanded(true)
    end
end)
```

The integer `GetID()` is auto-assigned by the API. Don't overwrite `category.ID` with a string — it breaks the lookup. The expansion traversal targets the **CategoryEntry widget** (the visible row), not the category model — that's the object whose `SetExpanded` actually drives the tree redraw. The whole call is `pcall`-wrapped because `CategoryList` / `GetCategoryEntry` / `CategoryEntry:SetExpanded` are private Blizzard internals; if a future patch refactors any of them, the panel still opens, just without the auto-unfold.

The combat refusal is not deferred-and-replayed: Blizzard's category switch is protected, so calling it under lockdown taints the panel for the session, and a panel that opens itself the instant combat drops would steal focus during recovery. The user re-runs the command. The page's own `OnShow` carries the same guard, because the Blizzard AddOns sidebar reaches a panel without going through `OpenOptionsPanel` at all.

### When `LibKa0s-Options-1.0` is absent

`settings/OptionsSetup.lua` installs a stub and returns. It is **the one seam in this addon whose stub no-ops instead of printing an honest line per member**, and the reason is timing: this addon's load-time use of the options surface is empty — `settings/Schema.lua` builds the whole schema from `defaults/Profile.lua`, and `settings/Panel.lua` reaches the instance only inside `Settings.Register` and its page builder, both of which run at `PLAYER_LOGIN`. `tests/test_libka0s.lua` pins that by loading with the library absent and comparing every hand-written row against a full load — and, separately, comparing the two `BuildDefaults` outputs, which must be identical because the *stored* shape may not depend on whether the library is installed.

**What is genuinely lost on that path is the Master controls tab**, because its rows are the composer's. The stub answers `MasterControls` with `{}, function() end` — no rows and a hook that draws nothing — so nothing raises, the other two tabs render as usual, and the profile still arrives with every key.

Two entry points do announce, once each: `CreateOptionsPanel` (reached automatically from `OnEnable`) and `OpenOptionsPanel` (reached by `/wg config`) — separate tokens, because a single shared one would always be spent at login and leave the command a silent no-op for the rest of the session. Nothing in the stub copies a widget maker, the flow engine, the header or a layout constant.

## Persisted shape — `WhatGroupDB`

Single SavedVariables (declared in `WhatGroup.toc`). Holds an AceDB instance with the shared `Default` profile plus an account-wide `global` block. The current shape, derived from the schema (`Settings.BuildDefaults`):

```
profile = {
  -- Master controls (options-ui-§15), stored at the profile ROOT
  enabled    = true,
  visibility = "always",   -- always | inCombat | outOfCombat | never
  scale      = 1,          -- 0.5 .. 2
  alpha      = 1,          -- 0 .. 1
  locked     = false,
  frame   = { autoShow = true, width = 420, height = 260 },
  notify  = {
    enabled       = true,
    delay         = 0,
    showInstance  = true,
    showType      = true,
    showLeader    = true,
    showPlaystyle = true,
    showClickLink = true,
    showTeleport  = true,
  },
}
global = {
  schemaVersion = 1,   -- seeded here; read by NS:RunMigrations (Database.lua)
  windows = {          -- persisted standalone-window geometry (WG-26); each entry
    -- [name] = { point, relPoint, x, y }   written on drag-stop, restored on show
  },
}
```

There is **no `debug` key and no `state` table** — debug is session-only runtime state (`NS.State.debug`), off on every login, never persisted (WG-12). The Master controls tab's "Debug console" checkbox is a schema row on the path `state.debugConsole`, but it is `sessionOnly`: `settings/Schema.lua`'s `SESSION` table intercepts that path in front of `Resolve`, `BuildDefaults` skips it, and the toggle drives the console *window's* visibility only — neither a profile key nor the debug logging flag. Capture / pending state (`captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`) is likewise **session-only** and never touches SavedVariables. See [data-flow.md](./data-flow.md#state) for why.

## The tab strip

The page is **tabbed** (`options-ui-§13`). `LibKa0s-Options-1.0`'s `RenderTabbedSchema` partitions the page's rows by `group`, **in declaration order**, and draws one tab per distinct group — so the order of the `add{}` calls in `settings/Schema.lua` *is* the strip, and a group's rows must stay contiguous. There is no second field naming a tab; the group heading and the tab are the same string, which is why the tabbed renderer suppresses the headings the scrolling one drew.

| # | Tab | Rows | Subgroups | What it is for |
|---|---|---|---|---|
| 1 | **Master controls** | 6 | — | options-ui-§15's canonical block, composed rather than written: enable, general visibility, master scale, master alpha, lock frame, debug console — closed by the **Reset position | Reset all settings** button pair (`afterGroup`). It is the **first** tab, and the name is the literal §15 mandates. |
| 2 | **Chat** | 8 | `Timing`, `Text` | When the join summary fires (`notify.delay`) and what it says: the **Print to Chat** master and the six lines it can contain. Plus the **Test** button (`afterGroup`). |
| 3 | **Popup** | 3 | `Behavior`, `Layout` | The group-info window: whether it opens by itself, and how big it is. |

Two tabs mix control kinds and therefore carry **subsection headings** (options-ui-§7): a slider that says *when* standing among seven checkboxes that say *what*, and a behaviour toggle above two size sliders. The headings are declared by the rows (`subgroup`), never drawn by the builder, and a `subgroup` never repeats its own tab's name.

There is **no page banner** (`options-ui-§14`) and there cannot be one: WhatGroup has no per-window settings and no active-window state, so there is no instance for a banner to name. `db.global.windows` stores the popup's *position*, which is geometry, not a setting.

`section` is not `group`. `section` is `/wg list`'s grouping key and it did not change when the page was retabbed — `notify.delay` is edited on **Chat** and still lists under `[notify]`, because a row's tab is where it is *edited* and its path is where it is *stored*. The composed Master controls rows are stamped `section = "general"` in `settings/Panel.lua`, because the composer has no way to know a host's `/wg list` key.

## Current schema rows

Order matches panel render order — `add{}` calls in source order, which is also tab order. Layout column shows whether a row pairs (default) or stands alone (`solo`).

Rows on the **Master controls** tab are emitted by `Helpers.MasterControls` and carry no `add{}` call anywhere in this repo; `tests/test_settings.lua` asserts that `settings/Schema.lua` declares none of their paths by hand.

| Tab | Section | Path | Type | Default | Layout | Purpose |
|---|---|---|---|---|---|---|
| Master controls | general | `enabled` | bool | true | startsLine, (paired) | **Master switch**, labelled *Enable WhatGroup*. When false, `OnApplyToGroup` short-circuits — no capture, no notification, no popup. `/wg test` and `/wg show` bypass this gate. Its off-flip `onChange` wipes any in-flight capture. |
| Master controls | general | `visibility` | string | `"always"` | (paired) | *General visibility* — `always` / `inCombat` / `outOfCombat` / `never`. Gates every path the popup takes to the screen, in `WhatGroup:ShowFrame()`. `never` refuses before the frame is built; the combat-dependent values gate the `Show` only, or `Only in combat` would deadlock against the taint-driven lazy build. |
| Master controls | general | `scale` | number | 1 | startsLine, (paired) | *Master scale* (0.5–2, step 0.05). `WhatGroup:ApplyFrameScale()`, **refused in combat** — scaling the parent moves the secure teleport button. |
| Master controls | general | `alpha` | number | 1 | (paired) | *Master alpha* (0–1, step 0.05, rendered as a percentage). `WhatGroup:ApplyFrameAlpha()`, **not** refused in combat: opacity moves nothing. |
| Master controls | general | `locked` | bool | false | startsLine, (paired) | *Lock frame*. Read at drag time by the title bar's `OnMouseDown`, so it takes effect on the next mouse-down with nothing to apply. |
| Master controls | general | `state.debugConsole` | bool | false | (paired) | *Debug console*, `sessionOnly`. Shows/hides the console **window**; never `db.profile`, never the logging flag (WG-12). |
| Chat | notify | `notify.delay` | number | 0 | subgroup `Timing`, solo | Seconds (0–10, step 0.5) between joining and notifying **and** showing the popup. Default 0 = immediately; raise it to let the zone-in settle. Not one of §15's canonical eight, so it moved off the first tab to the one named for the notification it delays. |
| Chat | notify | `notify.enabled` | bool | true | subgroup `Text`, solo | Print the chat summary on group join. The master for the six rows under it. |
| Chat | notify | `notify.showInstance` | bool | true | subgroup `Text`, (paired) | Include the Instance line in chat. |
| Chat | notify | `notify.showType` | bool | true | subgroup `Text`, (paired) | Include the Type line in chat. |
| Chat | notify | `notify.showLeader` | bool | true | subgroup `Text`, (paired) | Include the Leader line in chat. |
| Chat | notify | `notify.showPlaystyle` | bool | true | subgroup `Text`, (paired) | Include the Playstyle line in chat. |
| Chat | notify | `notify.showClickLink` | bool | true | subgroup `Text`, (paired) | Include the green "[Click here to view details]" chat link. |
| Chat | notify | `notify.showTeleport` | bool | true | subgroup `Text`, (paired) | Include a Teleport line; skipped silently when `WhatGroup:GetTeleportSpell` returns nil. |
| Popup | frame | `frame.autoShow` | bool | true | subgroup `Behavior`, solo | Auto-open the popup on group join. With this off, the chat notification still prints and the user can re-open via the chat link or `/wg show`. |
| Popup | frame | `frame.width` | number | 420 | subgroup `Layout`, (paired) | Popup width in pixels (320–700, step 10). Was `FRAME_WIDTH`, a file-local in `modules/Frame.lua`; the default is the number it replaced. |
| Popup | frame | `frame.height` | number | 260 | subgroup `Layout`, (paired) | Popup height in pixels (200–520, step 10). Was `FRAME_HEIGHT`, same story. |

The popup dialog always renders every field; the `notify.show*` rows gate **chat output only**. See [scope.md](./scope.md#resolved-decisions) for why.

`frame.width` / `frame.height` are **clamped on read**, in `modules/Frame.lua`, not on write: the slider cannot produce an illegal value but SavedVariables and `/wg set frame.width 4000` both can, and a popup wider than the monitor reads as the setting being broken rather than as the value being refused. `WhatGroup:ApplyFrameSize()` is the one seam that resizes a live popup; it **refuses in combat** (the popup parents a `SecureActionButtonTemplate` button anchored off the frame's own edges) and every `ShowFrame` re-applies, so a change taken in combat lands on the next open. `scale` reads and clamps the same way, through `WhatGroup:ApplyFrameScale()`, and refuses in combat for the same reason; `alpha` does not, because opacity moves nothing.

**Reset position** (`WhatGroup:ResetFramePosition()`) does two things, and either alone is a reset the next login undoes: it drops `db.global.windows.popup` (WG-26) *and* re-anchors the live frame to the shipped `CENTER` point. The re-anchor is combat-guarded; dropping the stored point is not.

Rendered panel layout:

```
[ Master controls ] [ Chat ] [ Popup ]      <- the tab strip, in the chrome band

--- Master controls ---                      composed; options-ui-§15's canonical order
[Enable WhatGroup]    | [General visibility]
[Master scale]        | [Master alpha]
[Lock frame]          | [Debug console]
  <Reset position | Reset all settings>      afterGroup["Master controls"] = the composer's tail

--- Chat ---
-- Timing --                                 subgroup heading (options-ui-§7)
[Notification Delay]
-- Text --
[Print to Chat]
[Instance]            | [Type]
[Leader]              | [Playstyle]
[Details link]        | [Teleport spell]
  <Test button (160 px, left-aligned, afterGroup["Chat"])>

--- Popup ---
-- Behavior --
[Open Automatically]
-- Layout --
[Width]               | [Height]
```

The `Show ` prefix the six chat rows carried is gone: under a tab called **Chat**, seven labels beginning "Show" spend their first word saying what the tab already said. The **paths** are untouched — `notify.showInstance` is still `notify.showInstance` for `/wg set` and for every saved profile.

## Adding a setting

One row to `Schema`. The UI, CLI, defaults, and reset surfaces all follow automatically. See [common-tasks.md](./common-tasks.md#add-a-setting) for the recipe. A row that belongs to the **Master controls** block is the exception: that block is options-ui-§15's canonical set and is not extended by hand — a new master control is a change to `LibKa0s`'s composer, not to this addon.
