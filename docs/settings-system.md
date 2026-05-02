# Settings system

A single flat array `WhatGroup.Settings.Schema` declares every option. One row drives six surfaces simultaneously, so adding a setting is a single-row diff. Everything in this doc lives in `WhatGroup_Settings.lua`.

## Six surfaces, one row

| Surface | Mechanism |
|---|---|
| Settings panel widget | `renderSchema()` → `makeField()` → `makeCheckbox` / `makeSlider` / `makeActionButton`; value widgets register a refresher closure in `Settings._refreshers` (action buttons skip this since they have no value) |
| `/wg list` | groups schema by `section`, prints `path = formattedValue` per row (skips action rows — they have no path / value) |
| `/wg get <path>` | `Helpers.FindSchema(path)` + format using `def.fmt` for numbers |
| `/wg set <path> <value>` | type-aware parse → `Helpers.Set` → `def.onChange(value)` → `Helpers.RefreshAll()` |
| AceDB defaults | `Settings.BuildDefaults()` walks the schema, threads each row's `default` into the right slot under `profile.*` |
| `/wg reset` | `Helpers.RestoreDefaults()` resets every row to its `default`, runs `def.onChange(default)`, refreshes panel widgets |

## Row format

```lua
{
    section,            -- groups in /wg list output (general, frame, notify, …)
    group,              -- heading shown in the Settings panel ("General", "Notify", …)
    path,               -- dotted path into db.profile (e.g. "notify.delay"). Omit for type="action".
    type,               -- "bool" | "number" | "action"
    label, tooltip,
    default,                -- omit for type="action"
    min, max, step, fmt,    -- numbers only (fmt is %s-style for /wg get formatting)
    onChange,               -- optional fn(value) called by both panel widget and /wg set / restoreDefaults
    onClick,                -- type="action" only: fn() called when the panel button is clicked
    solo,                   -- if true, render alone in the left half of its own row (right half empty)
    spacerBefore,           -- if true, insert a blank row before this widget
    panelHidden,            -- if true, skip the row in the panel renderer (still in /wg list/get/set)
}
```

### Action rows (`type = "action"`)

Render as an AceGUI Button widget that participates in the two-column pairing — placing an action row immediately before a bool / number row puts both on the same line. Action rows have no `path` and no value, so `BuildDefaults` / `RestoreDefaults` / `/wg list` / `/wg get` / `/wg set` skip them.

The current Test row is the only action; its `onClick` calls `WhatGroup:RunTest()` — the same code path as `/wg test`, so the two affordances stay in lockstep.

## Helpers

All schema reads and writes go through `Helpers.Resolve(path)`, which walks dotted paths into `db.profile` and returns `(parent, key)` so the caller can read `parent[key]` or write `parent[key] = value`. If any intermediate segment is missing, `Resolve` creates an empty table at that segment so writes don't error on first-use paths.

| Helper | Purpose |
|---|---|
| `Helpers.Resolve(path)` | walk dotted path; returns `(parent, key)` |
| `Helpers.Get(path)` | `Resolve` + read |
| `Helpers.Set(path, value)` | `Resolve` + write (no `onChange`, no refresh — those are the caller's job) |
| `Helpers.FindSchema(path)` | linear scan of `Schema` for `def.path == path` |
| `Helpers.RestoreDefaults()` | for each row with a path: `Set(def.path, def.default)` + `pcall(def.onChange, def.default)`; then `RefreshAll()` |
| `Helpers.RefreshAll()` | invoke every refresher in `Settings._refreshers` (each is a `pcall`-guarded closure) |

`Settings._refreshers[def.path]` is set when a checkbox / slider widget is created — a closure that re-syncs the widget against `Helpers.Get(def.path)`. `RefreshAll` walks every entry. Action buttons don't register a refresher because they have no value to sync.

## `BuildDefaults`

Walks `Schema` and threads each row's `default` into the right slot under `profile.*`:

```lua
function Settings.BuildDefaults()
    local out = { profile = {} }
    for _, def in ipairs(Schema) do
        if def.path then   -- skip action rows
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

The General subcategory renders the schema as a two-column AceGUI Flow layout (50%/50% per row). The renderer is `renderSchema(container)` in `WhatGroup_Settings.lua` — a scaled-down port of KickCD's `Helpers.RenderSchema` (no `valueGate`, no `afterGroup`, no `panelKey`).

Pairing rules:

- **Default**: widgets pair into rows, two per row. The renderer maintains a `pendingRow` and `pendingCount`; when `pendingCount` hits 2, it flushes.
- **`solo = true`**: flushes the in-progress row first, then forces the widget onto its own row (left half occupied via `SetRelativeWidth(0.5)`, right half empty), then flushes again.
- **`spacerBefore = true`**: flushes the in-progress row, inserts a blank `SimpleGroup` (height `ROW_VSPACER * 2`), then continues.
- **`group` transition**: flushes the in-progress row, inserts a section-top spacer (height `SECTION_TOP`) if not the first group, emits an AceGUI `Heading` with the new group name, and the next widget starts a fresh row.

Constants live at the top of `WhatGroup_Settings.lua`:

```lua
local PADDING       = 16
local HEADER_HEIGHT = 56
local ROW_VSPACER   = 6
local SECTION_TOP   = 10
```

## Lazy panel build

AceGUI widgets must render against a non-zero panel width. `Settings.RegisterCanvasLayoutSubcategory` parents the subcategory's panel into the Settings UI, but the panel doesn't get a width until Blizzard sizes it on first show.

So the General subcategory's body is built lazily:

```lua
local built = false
local container
generalPanel:SetScript("OnShow", function()
    if built then return end
    built = true
    container = AceGUI:Create("SimpleGroup")
    -- … parent container.frame to generalPanel, set anchors
    container.frame:SetScript("OnSizeChanged", function(_, w, h)
        if container.OnWidthSet  then container:OnWidthSet(w)  end
        if container.OnHeightSet then container:OnHeightSet(h) end
        if container.DoLayout    then container:DoLayout()     end
    end)
    renderSchema(container)
end)
```

Without the `OnSizeChanged` forwarder, AceGUI containers parented to a Blizzard frame stay at width 0 even after Blizzard sets a width on the outer panel. The forwarder pushes Blizzard's `SetSize` events into AceGUI's layout pipeline.

See [wow-quirks.md](./wow-quirks.md#lazy-acegui-panel-build) for the broader rule.

## `Settings.Register()`

Idempotent (`WhatGroup._settingsRegistered` guard). Registers two categories:

```
Ka0s WhatGroup        ← parent canvas-layout category (registered with Settings.RegisterAddOnCategory)
└── General            ← subcategory; hosts every schema widget
```

The parent panel is intentionally a thin landing page — in WoW 12.0 a parent category with subcategories hides its own widgets, so widgets there would never display. The parent shows the addon name + a "go to General" hint.

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
| notify | `notify.delay` | number | 1.5 | (paired) | Seconds (0–10, step 0.5) between joining and notifying. Lets the zone-in settle. |
| general | _(Test)_ | action | — | (paired) | Action button — calls `WhatGroup:RunTest()`. No path/value. |
| general | `debug` | bool | false | (paired) | Verbose event/hook logging (mirrors to `WhatGroup.debug` via `onChange`). |
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
[Print to Chat] | [Notification Delay]
[Test]          | [Debug]

--- Notify ---
[Show Instance]
[Show Type]
[Show Leader]
[Show Playstyle]
[Show ClickLink]
[Show Teleport]
```

## Adding a setting

One row to `Schema`. The UI, CLI, defaults, and reset surfaces all follow automatically. See [common-tasks.md](./common-tasks.md#add-a-setting) for the recipe.
