# Settings system

A single flat array `WhatGroup.Settings.Schema` declares every option. One row drives six surfaces simultaneously, so adding a setting is a single-row diff. The schema rows and helpers live in `settings/Schema.lua`; the canvas panel renderer lives in `settings/Panel.lua`.

## Six surfaces, one row

| Surface | Mechanism |
|---|---|
| Settings panel widget | `Helpers.RenderSchema()` → `Helpers.RenderField()` → `makeCheckbox` / `makeSlider`; widgets register a refresher closure in `Settings._refreshers` keyed by `def.path` |
| `/wg list` | groups schema by `section`, prints `path = formattedValue` per row |
| `/wg get <path>` | `Helpers.FindSchema(path)` + format using `def.fmt` for numbers |
| `/wg set <path> <value>` | type-aware parse → `Helpers.Set(path, value)` (orchestrated: writes value, logs one `[Set]` line, fires `onChange`, runs `RefreshAll` in one call) |
| AceDB defaults | `Settings.BuildDefaults()` walks the schema, threads each row's `default` into the right slot under `profile.*` |
| `/wg reset` + Defaults button | `StaticPopup_Show("WHATGROUP_RESET_ALL")` → on confirm → `Helpers.RestoreDefaults()` (wipe `db.profile` to prune orphans, re-thread each row's `default` via `Set` with `{skipRefresh, skipLog, skipOnChange}`, then one final `RefreshAll`) |

The schema is settings-only — non-setting actions (the "Test" button) render via `afterGroup` callbacks in `Settings.Register`, not as schema rows. See [Action buttons](#action-buttons-aftergroup).

## Row format

```lua
{
    section,            -- groups in /wg list output (general, frame, notify)
    group,              -- heading shown in the Settings panel ("General", "Notify")
    path,               -- dotted path into db.profile (e.g. "notify.delay")
    type,               -- "bool" | "number"
    label, tooltip,
    default,
    min, max, step, fmt,    -- numbers only (fmt is %s-style for /wg get formatting)
    onChange,               -- optional fn(value) called by panel widget + /wg set (NOT by RestoreDefaults — reset skips onChange)
    solo,                   -- if true, render alone in the left half of its own row (right half empty)
}
```

### Action buttons (afterGroup)

Non-setting affordances live outside the schema. `Helpers.RenderSchema(ctx, afterGroup)` accepts a `{ [groupName] = function(ctx) ... end }` map; the callback fires once, immediately after the last schema row of that group, and before the next group's section header.

The **General** group carries two kinds of non-schema affordance:

- **afterGroup** — full-width action buttons rendered *below* the grid. Here: the **Test** button (`Helpers.InlineButton` → `WhatGroup:RunTest()`).
- **pairExtras** — `{ [groupName] = { <def>, ... } }`, non-schema rows (custom `get`/`set`, no `path`) that pack into the *same* two-column grid as the group's real rows via the shared `addToGrid`, so they pair with the group's last schema widget. Here: the session-only **Debug console** checkbox, which lands beside **Print to Chat**.

The Debug console checkbox is deliberately not a schema row. It toggles **only the console window's visibility** — `get` reads `NS.DebugLog:IsShown()`, `set` calls `NS.DebugLog:Show()`/`Hide()`. It does **not** change the debug logging flag (`NS.State.debug`) and never touches `db.profile`, so it stays off `/wg list` and never persists. Its refresher is keyed by `def.refreshKey` (`"_debugConsoleVisible"`) since it has no path; a `HookScript("OnShow")` re-runs that refresher each time the panel opens, because the window can be closed via its own X/ESC (or opened by `/wg debug`) while the panel is closed. The window is hidden at every login, so the checkbox always starts unchecked (WG-12 / debug-logging-§5).

The "Test" button is the only afterGroup affordance today, attached to the `"General"` group:

```lua
Helpers.RenderSchema(generalCtx, {
    ["General"] = function(ctxRef)
        Helpers.InlineButton(ctxRef, {
            text    = "Test",
            tooltip = "...",
            onClick = function() WhatGroup:RunTest() end,
        })
    end,
})
```

`Helpers.InlineButton` renders a single 160-px button left-aligned in a full-width Flow row. `WhatGroup:RunTest()` is the same code path `/wg test` invokes, so the two affordances stay in lockstep.

## Helpers

All schema reads and writes go through a private `Resolve(path)` helper that walks dotted paths into `db.profile` and returns `(parent, key)` so the caller can read `parent[key]` or write `parent[key] = value`. If any intermediate segment is missing, `Resolve` creates an empty table at that segment so writes don't error on first-use paths. Public callers go through `Helpers.Get` / `Helpers.Set`.

| Helper | Purpose |
|---|---|
| `Helpers.Get(path)` | Resolve dotted path; read. When `NS.State.debug` is on, debug-logs `[Schema] Get: no path -> <path>` for typo'd paths so schema-key mistakes surface in the trace. |
| `Helpers.RawSet(path, value)` | Side-effect-free write — resolve dotted path, write, return. No `onChange`, no `RefreshAll`. Reserved for callers that genuinely need raw writes (none today); prefer `Helpers.Set` for everything else. |
| `Helpers.Set(path, value, opts)` | **Orchestrated single write-path.** Calls `RawSet`, logs one `[Set] <path> = <value>` console line (the canonical settings-change trace, debug-logging-§10), then runs the row's `onChange` (in pcall), then runs `RefreshAll`. Every existing caller — CLI (`/wg set`), panel widget callbacks, `RestoreDefaults` — routes through here so the side effects can't drift out of sync. `opts.skipOnChange`, `opts.skipRefresh`, and `opts.skipLog` are escape hatches; `RestoreDefaults` uses all three — `skipRefresh` (refresh once after the loop), `skipLog` (suppress per-row `[Set]` spam so one coalesced `[Reset]` summary stands in, debug-logging-§9), and `skipOnChange` (the default baseline is already reconciled, so per-row side effects are neither needed nor fired). |
| `Helpers.FindSchema(path)` | linear scan of `Schema` for `def.path == path` |
| `Helpers.ValidateSchema()` | walk Schema and chat-print errors for missing `path`, unknown `type`, non-string `section`/`group`/`label`. Non-fatal. Runs once at registration. |
| `Helpers.RestoreDefaults()` | Two steps for a *pristine* reset. **1.** `wipe(db.profile)` drops any orphaned key a key-by-key overwrite would leave behind (a value from a removed/renamed row, or one hand-edited into SavedVariables); in-game this clears AceDB's raw overrides while its defaults metatable stays intact. **2.** For each schema row: `Helpers.Set(def.path, deepcopy(def.default), { skipRefresh = true, skipLog = true, skipOnChange = true })` — table defaults are deep-copied so the profile never aliases the schema's canonical default, and per-row `onChange` is skipped. After the loop, emits one coalesced `[Reset] restored N settings to defaults (profile wiped)` line (debug-logging-§9), then one `RefreshAll()` — the single post-reset reconcile. `db.global` (schemaVersion) is left untouched. Caller (`StaticPopup` OnAccept, slash command) handles confirmation. |
| `Helpers.RefreshAll()` | Iterate `Settings._refresherOrder` in schema (= panel render) order; for each `def.path`, look up the closure in `Settings._refreshers` and run it under `pcall`. |

`Settings._refreshers[def.path]` is set when a checkbox / slider widget is created — a closure that re-syncs the widget against `Helpers.Get(def.path)`. `Settings._refresherOrder` is a parallel array tracking the registration order; `RefreshAll` iterates the array (rather than `pairs(_refreshers)`) so the iteration order is deterministic — matching the schema source order, which is also the panel render order.

### Panel infrastructure helpers

| Helper | Purpose |
|---|---|
| `Helpers.CreatePanel(name, title, opts)` | Build a Frame with the unified header (breadcrumb-prefixed `GameFontNormalHuge` title + `Options_HorizontalDivider`-tinted divider + optional Defaults button at top-right). Returns a `ctx = { panel, body, scroll, refreshers, lastGroup, panelKey }`. `opts.isMain` skips the `"Ka0s WhatGroup <atlas-chevron> "` breadcrumb prefix (separator is the inline atlas `\|A:common-icon-forwardarrow:16:16\|a` — a real texture, not a font glyph, so it renders the same regardless of the FontString font / locale fallback); `opts.defaultsButton` adds the top-right button. |
| `Helpers.PatchAlwaysShowScrollbar(scroll)` | Rebind an AceGUI ScrollFrame's `FixScroll` so the scrollbar (and its 20-px gutter) stays visible even when content fits — keeps left/right margins symmetric across short and long pages. Restores stock `FixScroll` / `OnRelease` on widget release so the shared AceGUI pool returns clean. |
| `Helpers.Section(ctx, label)` | AceGUI `Heading` widget at `GameFontNormalLarge` with 10 px above and 6 px below. |
| `Helpers.RenderField(ctx, def, parent, relativeWidth)` | Dispatch a single schema row to the right widget maker (`bool` → CheckBox, `number` → Slider). |
| `Helpers.InlineButton(ctx, spec)` | Standalone action button rendered into the page's scroll. `spec = { text, tooltip, onClick, width? }`. |
| `Helpers.RenderSchema(ctx, afterGroup?)` | Walk the schema, emit Section headings on group transitions, pair widgets into 50/50 Flow rows, fire `afterGroup` callbacks at group boundaries. |
| `Helpers.BuildMainContent(ctx)` | Render the addon-landing-page body (logo + TOC notes + Slash Commands heading + per-command Labels) as AceGUI widgets in `ctx.scroll`. |

## `BuildDefaults`

Default *values* live in `defaults/Profile.lua` as the nested `NS.C` table (the single place a profile default is hardcoded, savedvariables-§2 / WG-24); each schema row references its value via `default = C.<path>`. `BuildDefaults` walks `Schema` and threads each row's `default` into the right slot under `profile.*` (deep-copying table defaults):

```lua
function Settings.BuildDefaults()
    local out = { profile = {} }
    for _, def in ipairs(Schema) do
        if def.path then
            -- split def.path on "." into segments
            -- create empty tables along the way as needed
            -- assign def.default to the leaf
        end
    end
    return out
end
```

Called once in `OnInitialize` and passed to `AceDB:New("WhatGroupDB", defaults, true)`. AceDB's third arg (`true`) means a single shared `Default` profile across every character on the account.

Because `BuildDefaults` runs at every login, **a new schema row appears with its `default` value the first time the user logs in after the upgrade.** Existing keys are preserved untouched — AceDB merges saved values over the defaults rather than replacing.

## Panel renderer

The General sub-page renders the schema as a two-column AceGUI Flow layout (50/50 per row) inside an always-visible AceGUI `ScrollFrame`. The renderer is `Helpers.RenderSchema(ctx, afterGroup)` in `settings/Panel.lua` — closely modeled on KickCD's `Helpers.RenderSchema`.

Pairing rules:

- **Default**: widgets pair into rows, two per row. The renderer maintains a `pendingRow` and `pendingCount`; when `pendingCount` hits 2, it flushes.
- **`solo = true`**: flushes the in-progress row first, then forces the widget onto its own row (left half occupied via `SetRelativeWidth(0.5)`, right half empty), then flushes again.
- **`group` transition**: flushes the in-progress row, calls `Helpers.Section` (10 px spacer above the heading if not the first group, then the heading at `GameFontNormalLarge`, then 6 px below), and the next widget starts a fresh row.
- **`afterGroup[def.group]`**: at the final row of a group (last one in source order, or the next row's group differs), flushes the in-progress row and invokes the callback. One-shot — removed from the table after firing.

Layout constants live at the top of `settings/Panel.lua`:

```lua
local PADDING_X     = 16
local HEADER_TOP    = 20
local HEADER_HEIGHT = 54
local DEFAULTS_W    = 110

local SECTION_TOP_SPACER    = 10
local SECTION_BOTTOM_SPACER = 6
local SECTION_HEADING_H     = 26
local ROW_VSPACER           = 8
```

## Lazy panel build

AceGUI widgets must render against a non-zero panel width. `Settings.RegisterCanvasLayoutSubcategory` parents the panel into the Settings UI, but the panel doesn't get a width until Blizzard sizes it on first show.

So both pages defer their body build to `OnShow`, and the OnShow body itself wraps the actual build in `C_Timer.After(0, …)` so it runs on the next frame in a clean execution context:

```lua
local rendered, scheduled = false, false
ctx.panel:SetScript("OnShow", function()
    if rendered or scheduled then return end
    scheduled = true
    C_Timer.After(0, function()
        if rendered then return end
        rendered = true
        -- parent: Helpers.BuildMainContent(ctx)
        -- general: Helpers.RenderSchema(ctx, { ["General"] = ... })
    end)
end)
```

The `C_Timer.After(0, …)` deferral matters because Blizzard's GameMenu / Logout flows can dispatch our OnShow inside a secure-execute chain (e.g. when the Logout button's callback iterates registered Settings categories). Creating AceGUI frames synchronously inside that protected chain trips `ADDON_ACTION_FORBIDDEN ... 'callback()'`. Returning from OnShow immediately and running the build one frame later moves the frame creation out of the protected context.

`ensureScroll` (called by every render path) hooks the AceGUI ScrollFrame's `OnSizeChanged` and forwards the size into AceGUI:

```lua
scroll.frame:SetScript("OnSizeChanged", function(_, w, h)
    if scroll.OnWidthSet  then scroll:OnWidthSet(w)  end
    if scroll.OnHeightSet then scroll:OnHeightSet(h) end
    if scroll.DoLayout    then scroll:DoLayout()     end
    if scroll.FixScroll   then scroll:FixScroll()    end
end)
```

Without this forwarder, AceGUI containers parented to a Blizzard frame stay at width 0 even after Blizzard sets a width on the outer panel. The forwarder pushes Blizzard's `SetSize` events into AceGUI's layout pipeline.

See [wow-quirks.md](./wow-quirks.md#lazy-acegui-panel-build) for the broader rule.

## `Settings.Register()`

Idempotent (`WhatGroup._settingsRegistered` guard). Validates the schema first (chat-prints typos, non-fatal), then registers two categories.

**Combat-guarded.** After the idempotent guard, `Settings.Register()` self-checks `InCombatLockdown()` and refuses with a `[WG] Cannot register settings panel during combat.` chat hint if it's mid-combat. The slash handler `runConfig` already refuses on the same condition; the in-`Register` guard is defense-in-depth so any future caller that bypasses `runConfig` doesn't reintroduce the GameMenu taint that registering Settings categories during combat causes.

**Called at login** — from `OnEnable` (PLAYER_LOGIN), so the panel is in the Settings → AddOns list from the moment the player logs in, and again as an idempotent no-op from `runConfig`. This matches every other Ka0s addon: registering a canvas Settings category at login is taint-safe. (An earlier revision deferred this to first `/wg config`, believing the registration tainted GameMenu — a misdiagnosis confounded with the since-removed AceHook closures; see [wow-quirks.md](./wow-quirks.md).) WhatGroup's genuine boot-taint sources — the secure teleport button and `UISpecialFrames` insert — stay deferred in `modules/Frame.lua`.



```
Ka0s WhatGroup        ← parent canvas-layout category — landing page (logo, notes, slash list)
└── General            ← subcategory — every schema widget + the Test button (afterGroup)
```

Both pages share the same header layout (gold title + tinted divider) and the same always-visible AceGUI scrollbar. The parent's title reads `Ka0s WhatGroup` (no breadcrumb because `opts.isMain = true`); the General sub-page reads `Ka0s WhatGroup <atlas-chevron> General` (separator is the inline atlas `|A:common-icon-forwardarrow:16:16|a` — a real texture, not a font glyph, so it renders identically across font / locale fallback) and carries a Defaults button at top-right.

Defaults button → `StaticPopup_Show("WHATGROUP_RESET_ALL")` → on confirm → `Helpers.RestoreDefaults()`. `/wg reset` shows the same popup, so both paths share one OnAccept body.

`WhatGroup._parentSettingsCategory` and `WhatGroup._settingsCategory` (the General subcategory) are the two handles. `/wg config` opens the **parent** and unfolds the sidebar tree by reaching into the same path the expand-arrow click handler uses:

```lua
Settings.OpenToCategory(self._parentSettingsCategory:GetID())

pcall(function()
    if not SettingsPanel then return end
    local list = SettingsPanel.GetCategoryList
        and SettingsPanel:GetCategoryList()
        or SettingsPanel.CategoryList
    if not (list and list.GetCategoryEntry) then return end
    local entry = list:GetCategoryEntry(self._parentSettingsCategory)
    if entry and entry.SetExpanded then
        entry:SetExpanded(true)
    end
end)
```

The integer `GetID()` is auto-assigned by the API. Don't overwrite `category.ID` with a string — it breaks the lookup. The expansion traversal targets the **CategoryEntry widget** (the visible row), not the category model — that's the object whose `SetExpanded` actually drives the tree redraw. The whole call is `pcall`-wrapped because `CategoryList` / `GetCategoryEntry` / `CategoryEntry:SetExpanded` are private Blizzard internals; if a future patch refactors any of them, the panel still opens, just without the auto-unfold. The slash command also refuses to open during `InCombatLockdown()`.

## Persisted shape — `WhatGroupDB`

Single SavedVariables (declared in `WhatGroup.toc`). Holds an AceDB instance with the shared `Default` profile plus an account-wide `global` block. The current shape, derived from the schema (`Settings.BuildDefaults`):

```
profile = {
  enabled = true,
  frame   = { autoShow = true },
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

There is **no `debug` key** — debug is session-only runtime state (`NS.State.debug`), off on every login, never persisted (WG-12). The General panel's "Debug console" checkbox toggles the console *window's* visibility only (see [Action buttons](#action-buttons-aftergroup)); it drives neither a profile key nor the debug logging flag. Capture / pending state (`captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`) is likewise **session-only** and never touches SavedVariables. See [capture-pipeline.md](./capture-pipeline.md#state) for why.

## Current schema rows

Order matches panel render order — `add{}` calls in source order. Layout column shows whether a row pairs (default) or stands alone (`solo`).

| Section | Path | Type | Default | Layout | Purpose |
|---|---|---|---|---|---|
| general | `enabled` | bool | true | (paired) | **Master switch.** When false, `OnApplyToGroup` short-circuits — no capture, no notification, no popup. `/wg test` and `/wg show` bypass this gate. |
| frame | `frame.autoShow` | bool | true | (paired) | Auto-open the popup on group join. With this off, the chat notification still prints and the user can re-open via the chat link or `/wg show`. |
| notify | `notify.enabled` | bool | true | (paired) | Print the chat summary on group join. |
| notify | `notify.delay` | number | 0 | solo | Seconds (0–10, step 0.5) between joining and notifying. Default 0 = notify immediately; raise it to let the zone-in settle. |
| notify | `notify.showInstance` | bool | true | solo | Include the Instance line in chat. |
| notify | `notify.showType` | bool | true | solo | Include the Type line in chat. |
| notify | `notify.showLeader` | bool | true | solo | Include the Leader line in chat. |
| notify | `notify.showPlaystyle` | bool | true | solo | Include the Playstyle line in chat. |
| notify | `notify.showClickLink` | bool | true | solo | Include the green "[Click here to view details]" chat link. |
| notify | `notify.showTeleport` | bool | true | solo | Include a Teleport line; skipped silently when `WhatGroup:GetTeleportSpell` returns nil. |

The popup dialog always renders every field; the `notify.show*` rows gate **chat output only**. See [scope.md](./scope.md#resolved-decisions) for why.

Rendered panel layout:

```
--- General ---
[Enable]        | [Auto Show]
[Print to Chat] |
  <Test button (160 px, left-aligned, afterGroup)>

--- Notify ---
[Notification Delay]
[Show Instance]
[Show Type]
[Show Leader]
[Show Playstyle]
[Show ClickLink]
[Show Teleport]
```

## Adding a setting

One row to `Schema`. The UI, CLI, defaults, and reset surfaces all follow automatically. See [common-tasks.md](./common-tasks.md#add-a-setting) for the recipe.
