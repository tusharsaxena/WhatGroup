# Settings system

A single flat array `WhatGroup.Settings.Schema` declares every option. One row drives six surfaces simultaneously, so adding a setting is a single-row diff. Everything in this doc lives in `WhatGroup_Settings.lua`.

## Six surfaces, one row

| Surface | Mechanism |
|---|---|
| Settings panel widget | `Helpers.RenderSchema()` → `Helpers.RenderField()` → `makeCheckbox` / `makeSlider`; widgets register a refresher closure in `Settings._refreshers` keyed by `def.path` |
| `/wg list` | groups schema by `section`, prints `path = formattedValue` per row |
| `/wg get <path>` | `Helpers.FindSchema(path)` + format using `def.fmt` for numbers |
| `/wg set <path> <value>` | type-aware parse → `Helpers.Set` → `def.onChange(value)` → `Helpers.RefreshAll()` |
| AceDB defaults | `Settings.BuildDefaults()` walks the schema, threads each row's `default` into the right slot under `profile.*` |
| `/wg reset` + Defaults button | `StaticPopup_Show("WHATGROUP_RESET_ALL")` → on confirm → `Helpers.RestoreDefaults()` (resets every row to its `default`, runs `def.onChange(default)`, refreshes panel widgets) |

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
    onChange,               -- optional fn(value) called by panel widget, /wg set, RestoreDefaults
    solo,                   -- if true, render alone in the left half of its own row (right half empty)
}
```

### Action buttons (afterGroup)

Non-setting affordances live outside the schema. `Helpers.RenderSchema(ctx, afterGroup)` accepts a `{ [groupName] = function(ctx) ... end }` map; the callback fires once, immediately after the last schema row of that group, and before the next group's section header.

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
| `Helpers.Get(path)` | resolve dotted path; read |
| `Helpers.Set(path, value)` | resolve dotted path; write (no `onChange`, no refresh — those are the caller's job) |
| `Helpers.FindSchema(path)` | linear scan of `Schema` for `def.path == path` |
| `Helpers.ValidateSchema()` | walk Schema and chat-print errors for missing `path`, unknown `type`, non-string `section`/`group`/`label`. Non-fatal. Runs once at registration. |
| `Helpers.RestoreDefaults()` | for each row: `Set(def.path, def.default)` + `pcall(def.onChange, def.default)`; then `RefreshAll()`. Caller (`StaticPopup` OnAccept, slash command) handles confirmation. |
| `Helpers.RefreshAll()` | invoke every refresher in `Settings._refreshers` (each is a `pcall`-guarded closure) |

`Settings._refreshers[def.path]` is set when a checkbox / slider widget is created — a closure that re-syncs the widget against `Helpers.Get(def.path)`. `RefreshAll` walks every entry.

### Panel infrastructure helpers

| Helper | Purpose |
|---|---|
| `Helpers.CreatePanel(name, title, opts)` | Build a Frame with the unified header (breadcrumb-prefixed `GameFontNormalHuge` title + `Options_HorizontalDivider`-tinted divider + optional Defaults button at top-right). Returns a `ctx = { panel, body, scroll, refreshers, lastGroup, panelKey }`. `opts.isMain` skips the `"Ka0s WhatGroup  \|  "` breadcrumb prefix; `opts.defaultsButton` adds the top-right button. |
| `Helpers.PatchAlwaysShowScrollbar(scroll)` | Rebind an AceGUI ScrollFrame's `FixScroll` so the scrollbar (and its 20-px gutter) stays visible even when content fits — keeps left/right margins symmetric across short and long pages. Restores stock `FixScroll` / `OnRelease` on widget release so the shared AceGUI pool returns clean. |
| `Helpers.Section(ctx, label)` | AceGUI `Heading` widget at `GameFontNormalLarge` with 10 px above and 6 px below. |
| `Helpers.RenderField(ctx, def, parent, relativeWidth)` | Dispatch a single schema row to the right widget maker (`bool` → CheckBox, `number` → Slider). |
| `Helpers.InlineButton(ctx, spec)` | Standalone action button rendered into the page's scroll. `spec = { text, tooltip, onClick, width? }`. |
| `Helpers.RenderSchema(ctx, afterGroup?)` | Walk the schema, emit Section headings on group transitions, pair widgets into 50/50 Flow rows, fire `afterGroup` callbacks at group boundaries. |
| `Helpers.BuildMainContent(ctx)` | Render the addon-landing-page body (logo + TOC notes + Slash Commands heading + per-command Labels) as AceGUI widgets in `ctx.scroll`. |

## `BuildDefaults`

Walks `Schema` and threads each row's `default` into the right slot under `profile.*`:

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

The General sub-page renders the schema as a two-column AceGUI Flow layout (50/50 per row) inside an always-visible AceGUI `ScrollFrame`. The renderer is `Helpers.RenderSchema(ctx, afterGroup)` in `WhatGroup_Settings.lua` — closely modeled on KickCD's `Helpers.RenderSchema`.

Pairing rules:

- **Default**: widgets pair into rows, two per row. The renderer maintains a `pendingRow` and `pendingCount`; when `pendingCount` hits 2, it flushes.
- **`solo = true`**: flushes the in-progress row first, then forces the widget onto its own row (left half occupied via `SetRelativeWidth(0.5)`, right half empty), then flushes again.
- **`group` transition**: flushes the in-progress row, calls `Helpers.Section` (10 px spacer above the heading if not the first group, then the heading at `GameFontNormalLarge`, then 6 px below), and the next widget starts a fresh row.
- **`afterGroup[def.group]`**: at the final row of a group (last one in source order, or the next row's group differs), flushes the in-progress row and invokes the callback. One-shot — removed from the table after firing.

Layout constants live at the top of the panel-rendering section in `WhatGroup_Settings.lua`:

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

So both pages defer their body build to `OnShow`:

```lua
local rendered = false
ctx.panel:SetScript("OnShow", function()
    if rendered then return end
    rendered = true
    -- parent: Helpers.BuildMainContent(ctx)
    -- general: Helpers.RenderSchema(ctx, { ["General"] = ... })
end)
```

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

Idempotent (`WhatGroup._settingsRegistered` guard). Validates the schema first (chat-prints typos, non-fatal), then registers two categories:

```
Ka0s WhatGroup        ← parent canvas-layout category — landing page (logo, notes, slash list)
└── General            ← subcategory — every schema widget + the Test button (afterGroup)
```

Both pages share the same header layout (gold title + tinted divider) and the same always-visible AceGUI scrollbar. The parent's title reads `Ka0s WhatGroup` (no breadcrumb because `opts.isMain = true`); the General sub-page reads `Ka0s WhatGroup  |  General` and carries a Defaults button at top-right.

Defaults button → `StaticPopup_Show("WHATGROUP_RESET_ALL")` → on confirm → `Helpers.RestoreDefaults()`. `/wg reset` shows the same popup, so both paths share one OnAccept body.

`WhatGroup._parentSettingsCategory` and `WhatGroup._settingsCategory` (the General subcategory) are the two handles. `/wg config` opens the **subcategory**:

```lua
Settings.OpenToCategory(self._settingsCategory:GetID())
```

The integer `GetID()` is auto-assigned by the API. Don't overwrite `category.ID` with a string — it breaks the lookup.

## Persisted shape — `WhatGroupDB`

Single SavedVariables (declared in `WhatGroup.toc`). Holds an AceDB instance with the shared `Default` profile. The current `db.profile` shape, derived from the schema:

```
profile = {
  enabled = true,
  debug   = false,
  frame   = { autoShow = true },
  notify  = {
    enabled       = true,
    delay         = 1.5,
    showInstance  = true,
    showType      = true,
    showLeader    = true,
    showPlaystyle = true,
    showClickLink = true,
    showTeleport  = true,
  },
}
```

Capture / pending state (`captureQueue`, `pendingApplications`, `pendingInfo`, `wasInGroup`) is **session-only** and never touches SavedVariables. See [capture-pipeline.md](./capture-pipeline.md#state) for why.

## Current schema rows

Order matches panel render order — `add{}` calls in source order. Layout column shows whether a row pairs (default) or stands alone (`solo`).

| Section | Path | Type | Default | Layout | Purpose |
|---|---|---|---|---|---|
| general | `enabled` | bool | true | (paired) | **Master switch.** When false, `OnApplyToGroup` short-circuits — no capture, no notification, no popup. `/wg test` and `/wg show` bypass this gate. |
| frame | `frame.autoShow` | bool | true | (paired) | Auto-open the popup on group join. With this off, the chat notification still prints and the user can re-open via the chat link or `/wg show`. |
| notify | `notify.enabled` | bool | true | (paired) | Print the chat summary on group join. |
| general | `debug` | bool | false | (paired) | Verbose event/hook logging (mirrors to `WhatGroup.debug` via `onChange`). |
| notify | `notify.delay` | number | 1.5 | solo | Seconds (0–10, step 0.5) between joining and notifying. Lets the zone-in settle. |
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
[Print to Chat] | [Debug]
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
