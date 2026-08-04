# CCN elimination — WhatGroup

Branch `feat/fix-ccn`. Design: `LibKa0s/docs/superpowers/specs/2026-08-04-ccn-elimination-design.md`.

**3 functions** with `lizard` CCN > 15. Target: every one at CCN <= 15, behavior unchanged.

## Exit criteria

1. `luacheck . --quiet` — 0 warnings, 0 errors.
2. `lua5.1 tests/run.lua` — all pass, count >= baseline.
3. `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — no CCN > 15.
4. No behavior change. No version bump, no CHANGELOG, no merge, no tag.

## Rules

- Preferred shapes, in order: table-driven dispatch; a named file-local helper for a
  self-contained block; a data table + loop replacing repeated defaulting; splitting a
  builder into N small builders.
- No dumping a body into one helper to game the metric. Every resulting function must be a
  unit a reader can name.
- Dispatch/defaults tables are **module-level**, built once at file load — never per call.
- `lizard` counts `and`/`or` as decisions, but `or` and `== nil` are **not** interchangeable and
  the metric is never a reason to swap one for the other. `x or D` replaces a stored `false` with
  `D`; `if x == nil then x = D end` keeps the `false`. Whichever the shipped code used is the
  behavior, and it stays. (`0` and `""` are TRUTHY in Lua, so `(0 or 99)` is `0` — an `or` chain
  never swallows a stored zero or empty string. Only `false` and `nil`.) Bring CCN down by
  splitting the function, not by rewriting its defaulting.
- Hot paths must not gain a per-call allocation.
- Sixteen functions across the collection have no coverage; where this file says
  `Coverage: NONE`, write a characterization test pinning current behavior **before**
  refactoring.

## Functions

### `WhatGroup (lizard label) — real name: WhatGroup:CaptureGroupInfo` — CCN 22 → target 7

`core/WhatGroup.lua:195-251` · pattern `field-defaulting` · risk **low**

**What it does.** Takes an LFG searchResultID, calls C_LFGList.GetSearchResultInfo, and normalizes the result into a flat `captured` table with every field defaulted; then, if the first activityID resolves, overlays the activity fields from NS.Compat.GetActivityInfoTable.

**Where the branches come from.** Almost pure `or`-defaulting: 8 `x = info.y or D` chains in the captured literal (one of them a two-source chain `info.generalPlaystyle or info.playstyle or 0`), plus 8 more `x = actInfo.y or D` chains inside the activity block, on top of three real branches (`if not info`, `if firstActivityID`, `if actInfo`). lizard counts every short-circuit, so ~19 of the 22 come from defaulting, not control flow.

**Fix.** Two file-local helpers, leaving CaptureGroupInfo as pure control flow. Every `or` chain moves ACROSS unchanged — the split alone is what buys the headroom.

> **Correction (repair round).** The first cut of this plan called for two module-level
> `{dest, src, default}` field tables read back through `row[1]/row[2]/row[3]`, with the loop body
> spelled `local v = info[src]; if v == nil then v = default end`. Both halves of that were wrong.
> The `== nil` swap is a real behavior change — a source field holding `false` was stored as `false`
> instead of being replaced by the default, which degrades `categoryID` to a boolean that
> `Labels.GetGroupTypeLabel` compares numerically and makes `ShowNotification` print the string
> "false" for a `shortName`. And the old equivalence note here justified it by claiming the defaults
> were "the falsy image of its own field's type (0/""/false)": `0` and `""` are **truthy** in Lua,
> so they were never at risk from `or` in the first place, and `false` — the one value that *is* at
> risk — is exactly the value the swap broke. The tables were also the only thing the swap bought,
> since the function split on its own already lands both helpers around CCN 10. They are gone; the
> literal `or` assignment lines are back.

(1) `local function buildCapture(info)` builds the whole `captured` literal exactly as CaptureGroupInfo did — the same eight `x = info.y or D` lines, including `generalPlaystyle = info.generalPlaystyle or info.playstyle or 0` and `activityIDs = info.activityIDs or {}` (this one needs a fresh table per call) — with `local unknown = NS.L["Unknown"]` resolved once at call time so locale swaps in tests still work, pre-seeds the placeholder fields (activityID/fullName/activityName/maxNumPlayers/isMythicPlus/isCurrentRaid/isHeroicRaid/categoryID/mapID) exactly as today, then sets `c.playstyle = c.generalPlaystyle` and returns c. CCN ~10.

(2) `local function applyActivityInfo(captured, actInfo)` carries the eight activity lines over verbatim — `captured.fullName = actInfo.fullName or actInfo.activityName or ""` and the seven `captured.x = actInfo.y or D` that follow — then `captured.mapID = actInfo.mapID` (no default today — keep it nil-able). CCN ~10.

(3) `CaptureGroupInfo` becomes: nil-info guard + NS.Debug + return; `local captured = buildCapture(info)`; `local firstActivityID = captured.activityIDs[1]`; `if firstActivityID then captured.activityID = firstActivityID; local actInfo = NS.Compat.GetActivityInfoTable(firstActivityID); if actInfo then applyActivityInfo(captured, actInfo) end end`; return captured. CCN 4.

Nothing new is allocated per capture: the two helpers are plain file-local functions closed over at load, and they write into the same single `captured` table the old body did.

**Must not change.** The exact key set of the returned table is a contract read by modules/Frame.lua (PopulateFields), Labels.GetGroupTypeLabel and ShowNotification — `shortName` in particular exists ONLY when an actInfo was found (it is not pre-seeded in the literal today), and that asymmetry must be preserved or `info.shortName ~= ""` in ShowNotification changes meaning. `activityIDs` must remain a distinct table per call (never a shared module-level empty table) — captures are queued in captureQueue and would alias. `captured.playstyle` must keep mirroring generalPlaystyle after the two-source `or` chain resolves. In-game-only: nothing here is game-only; every branch is reachable headless via the wow_mock LFG stubs.

**Coverage.** tests/test_capture.lua:85-180 — field mapping, activity-field mapping, nil search result, and several defaulting cases; strong characterization coverage already exists. tests/test_notify.lua:15 builds a capture-shaped fixture that pins the same key set.

---

### `WhatGroup (lizard label) — real name: WhatGroup:ShowNotification` — CCN 22 → target 11

`core/WhatGroup.lua:373-421` · pattern `gated-row-list` · risk **low**

**What it does.** Renders the chat notification for the current pendingInfo: a header line, an always-shown Group line, then six independently-toggled rows (Instance / Type / Leader / Playstyle / Teleport / click link), each gated on a db.profile.notify.showX flag and each pushed through the single secret-safe printer `p`.

**Where the branches come from.** A flat stack of seven `if n.showX then` guards, several of which carry an inner `a ~= "" and a or b` ternary or a second nested `if` (playstyle's `if playStyle ~= ""`, teleport's `if spellID` plus a `GetSpellLink(...) or fallback` and a `known and "" or note`), on top of the two entry guards (`if not info`, `if not n or not n.enabled` with its three-term `and` chain).

**Fix.** Replace the guard stack with a module-level constant row table plus one loop.

`local GOLD = "FFD700"` hoisted to file scope (it is a per-call local today).

`local function teleportValue(self, info)` — file-local named helper holding the teleport row's whole body: `local spellID, known = self:GetTeleportSpell(info.activityID, info.mapID); if not spellID then return nil end; local spellLink = NS.Compat.GetSpellLink(spellID) or ("|cff71d5ff[Spell " .. spellID .. "]|r"); local note = known and "" or (" |cff888888" .. NS.L["(not learned)"] .. "|r"); return spellLink .. note`. CCN ~5.

`local NOTIFY_ROWS = { {flag="showInstance", label="Instance:", value=function(_, info) return info.fullName ~= "" and info.fullName or NS.L["Unknown"] end}, {flag="showType", label="Type:", value=function(_, info) return info.shortName ~= "" and info.shortName or Labels.GetGroupTypeLabel(info) end}, {flag="showLeader", label="Leader:", value=function(_, info) return info.leaderName end}, {flag="showPlaystyle", label="Playstyle:", value=function(_, info) local s = Labels.GetPlaystyleLabel(info); if s == "" then return nil end; return s end}, {flag="showTeleport", label="Teleport:", omitWhenNil=true, value=teleportValue} }` — declared once at file load, after the `Labels` upvalue is bound (line 367) and before ShowNotification. Each closure's own CCN is 1-3.

Row suppression is opt-IN, via `omitWhenNil` on the Playstyle and Teleport rows only. Those two are the only rows that carry an inner `if` today. **A blanket "value returned nil means emit no row" would be a behavior change**: the Leader row has no such guard and prints `info.leaderName` unconditionally, nil included — it reaches chat as "nil" through NS.Util.print's SafeToString seam. An absent row and a row reading "nil" are different outputs, and `pendingInfo` is a plain table that RunTest and the queue can hand over without a leaderName, so the difference is observable. Pinned by `notify: the Leader row still prints when leaderName is nil` in tests/test_notify.lua.

ShowNotification body becomes: the two entry guards unchanged; `p(NS.L["You have joined a group!"])`; `p("   - " .. colorize(NS.L["Group:"], GOLD), info.title or NS.L["Unknown"])`; `for i = 1, #NOTIFY_ROWS do local row = NOTIFY_ROWS[i]; if n[row.flag] then local v = row.value(self, info); local omit = row.omitWhenNil and v == nil; if not omit then p("   - " .. colorize(NS.L[row.label], GOLD), v) end end end`; then the click-link row kept inline (`if n.showClickLink then p("   - " .. colorize(link("WhatGroup:show", NS.L["[Click here to view details]"]), "00FF7F")) end`) because it is the one row with no label and a different color, and forcing it into the table would be the kind of indirection that costs more than it saves. CCN ~11.

The English label strings stay as the raw NS.L keys in the table and are indexed at call time inside the loop, so locale substitution behaves exactly as today. Building the click link lazily instead of unconditionally at the top is side-effect-free and output-identical.

**Must not change.** Row ORDER and the two-argument shape of every `p(...)` call are the contract: the label (a constant color-coded string) and the LFG-sourced value must stay SEPARATE args so NS.Util.print's SafeToString seam stringifies the value rather than the call site pre-concatenating it (WG-22/WG-23 — a combat-protected value concatenated here raises). Do not collapse them into one string. The teleport row must still be skipped entirely when GetTeleportSpell returns nil, and the playstyle row skipped when the resolved label is the empty string — these are row-absent cases, not empty-value cases. In-game only: a genuinely combat-protected leaderName/spell link can only be produced by the live client, so the secret-safety property of the two-arg form cannot be proven headless.

**Coverage.** tests/test_notify.lua:260-338 — per-row gating from db.profile.notify, one test per showX flag; :340-410 — row CONTENT including the instance/type fallbacks, the playstyle enum path and the teleport link; :423 — a pcall'd raise-containment test. This is the best-covered of the three.

---

### `Helpers.BuildMainContent` — CCN 17 → target 6

`settings/Panel.lua:91-157` · pattern `page-builder` · risk **low**

**What it does.** Renders the settings landing page body into the library's lazy ScrollFrame: the 300px brand logo, the TOC Notes one-liner as a left-justified full-width Label, a "Slash Commands" section heading, and one Label per command row from NS.SlashCommands:LandingRows().

**Where the branches come from.** Four independent sub-parts inlined into one function, each carrying its own guard cluster: the entry guard `if not (AceGUI and scroll)`, the metadata resolution `(C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata` plus `(meta and meta(...)) or ""`, two three-term font/justify guards on the desc Label (`if desc.label and desc.label.SetFontObject and _G.GameFontHighlight`, `if desc.label and desc.label.SetJustifyH`), and inside the row loop a third copy of the same justify guard plus `Sl and Sl:LandingRows() or {}`. The justify guard alone is written twice.

**Fix.** Split the one builder into three file-local sub-builders plus one shared micro-helper that kills the duplicated guard, and leave BuildMainContent as the four-line orchestrator. This is the (d) shape — N independent sub-parts, N small builders — not a code-move.

`local function justifyLeft(widget)` — `local fs = widget.label; if fs and fs.SetJustifyH then fs:SetJustifyH("LEFT") end`. CCN 3. Called by both the notes Label and every command row, replacing the two copies.

`local function addLogo(AceGUI, scroll)` — the SimpleGroup + CreateTexture + SetSize/SetPoint block (lines 103-112) verbatim, then `Helpers.AddSpacer(scroll, MAIN_GAP_AFTER_LOGO)`. Straight-line, CCN 1. The four MAIN_* constants stay where they are at file scope.

`local function addNotesLine(AceGUI, scroll)` — the metadata resolution and the desc Label (lines 117-131), ending in `justifyLeft(desc)` and the AFTER_DESC spacer. Keeps the font-object guard inline since it is specific to this one widget. CCN ~6.

`local function addCommandRows(AceGUI, scroll)` — `local Sl = NS.SlashCommands; for _, line in ipairs(Sl and Sl:LandingRows() or {}) do local row = AceGUI:Create("Label"); row:SetFullWidth(true); row:SetText(line); justifyLeft(row); scroll:AddChild(row) end`. CCN ~4.

`Helpers.BuildMainContent(ctx)` keeps the entry guard, the ClearScroll/EnsureScroll re-render dance (lines 97-98 — this MUST stay in the orchestrator, before any sub-builder runs), then `addLogo(AceGUI, scroll)`, `addNotesLine(AceGUI, scroll)`, `Helpers.Section(ctx, "Slash Commands")`, `Helpers.AddSpacer(scroll, MAIN_GAP_BELOW_HEAD)`, `addCommandRows(AceGUI, scroll)`. The Section call stays at the orchestrator level because it takes `ctx`, not `scroll`, and reads as the page's outline. CCN ~3.

Each helper takes `AceGUI` and `scroll` explicitly rather than re-deriving them, so EnsureScroll is still called exactly twice per render, as today.

**Must not change.** The ClearScroll → EnsureScroll re-acquire at the top must stay ahead of every widget creation: the library re-runs this renderer when a hidden page is marked dirty and shown again, and skipping it stacks a second logo and a second command list. Widget ADD ORDER into the scroll is the visual layout — logo, spacer, notes, spacer, heading, spacer, rows — and the spacer sizes (MAIN_GAP_AFTER_LOGO / AFTER_DESC / BELOW_HEAD) must land between the same pairs. The logo texture is anchored TOPLEFT at native 300x300 inside a full-width SimpleGroup with `SetLayout(nil)`; that nil layout is deliberate (pixel-exact, left-aligned regardless of panel width) and must not become "List". In-game only: actual pixel alignment, font rendering and scrollbar extent can only be confirmed by opening Settings → AddOns → Ka0s WhatGroup in the client.

**Coverage.** tests/test_panel.lua:459-466 asserts the TOC Notes Label is rendered from mock metadata; :469-480 asserts the "Slash Commands" heading and that a texture matching whatgroup.logo is created. tests/test_libka0s.lua:229 only asserts the symbol BuildMainContent exists. NO test currently asserts the per-command Label rows come from Sl:LandingRows(), and none asserts the left-justification or the spacer ordering — add a characterization test over the rendered widget list (types + texts in order) before splitting.

---
