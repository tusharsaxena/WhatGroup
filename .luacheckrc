-- .luacheckrc — lint config for the Ka0s WhatGroup addon (lint).
-- Run `luacheck .` with 0 errors before every commit.

std = "lua51"
max_line_length = false
codes = true

-- libs/ holds vendored code, including libs/LibKa0s/ whose upstream is the LibKa0s repo, so it is
-- linted there and not here. tests/_kit/ is the same fact one level down: it is a byte copy of the
-- library's testkit/, linted in LibKa0s as source, and linting the copy too would report every
-- finding twice while letting the copy drift green as the original went red -- the one state
-- tests/test_vendor_sync.lua exists to make impossible. Everything else under tests/ is ours and is
-- linted (lint.md). Under docs/ only the FROZEN evidence bundles are excluded; a blanket docs/
-- exclude would silently drop any Lua a future doc directory carries out of the gate. _dev/ is the
-- scratch directory .pkgmeta:12 already reserves, listed here so the two config files agree about
-- it whether or not it exists today.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }

-- NO TOP-LEVEL `ignore`, and none is coming back (lint.md, `M4-11`). This file carried
-- `ignore = { "211/addonName", "212", "542" }` until `M4c-04`. All three codes named something
-- real, but a top-level ignore reaches all 41 files, so it silenced them in every file that has no
-- business producing them too. Removing the three lines reported TWENTY-FOUR findings, and FIFTEEN
-- of them were not conventions at all: ten `local addonName, NS = ...` headers over a folder name
-- the file never read, and five parameters carried into the two `hooksecurefunc` handlers in
-- core/WhatGroup.lua and never used. All fifteen are fixed in the source rather than moved into a
-- narrower suppression. The NINE that remain are below -- eight `<code>/<variable>` entries across
-- three per-file stanzas, plus one `-- luacheck: ignore 542` on the single line in
-- core/WhatGroup.lua that earns it. tests/test_lintconfig.lua is what keeps the blanket from
-- re-entering.

-- SavedVariables + the one global table the addon writes (lazily) to.
globals = {
  "WhatGroupDB",
  "StaticPopupDialogs",
}

-- The WoW API surface the addon reads. Compat.lua owns the version-variant
-- spell / LFG calls and the addon chat-link detection (LinkTypes, EventRegistry);
-- the rest are frame, settings, timer, and combat APIs.
read_globals = {
  "_G",
  "LibStub", "hooksecurefunc", "EventRegistry", "LinkTypes",
  "CreateFrame", "UIParent", "UISpecialFrames",
  "InCombatLockdown", "IsInGroup",
  "C_Timer", "C_AddOns", "GetAddOnMetadata",
  "C_Spell", "C_SpellBook", "C_LFGList",
  "IsSpellKnown", "GetSpellInfo", "GetSpellTexture", "GetSpellCooldown", "CastSpellByID",
  "GetTime",
  "Enum",
  "GROUP_FINDER_GENERAL_PLAYSTYLE1", "GROUP_FINDER_GENERAL_PLAYSTYLE2",
  "GROUP_FINDER_GENERAL_PLAYSTYLE3", "GROUP_FINDER_GENERAL_PLAYSTYLE4",
  "Settings", "SettingsPanel", "StaticPopup_Show",
  "GameTooltip", "YES", "NO",
  "wipe", "tinsert", "date",
}

-- The harness publishes its exposed table under a per-repo global, written at tests/run.lua:75 and
-- read by every suite file. It is declared HERE rather than in the top-level `read_globals` on
-- purpose: a name granted at the top level is granted to core/, modules/ and settings/ as much as
-- to a suite, and no shipped file may ever reach for the test harness. `globals` rather than
-- `read_globals` because tests/run.lua is the writer.
files["tests/"] = {
  globals = {
    "_G.WHATGROUP_TEST",
    -- The SavedVariables table, named as a field rather than bare because tests/loader.lua:91
    -- CLEARS it before each boot -- the kit's AceDB fake resolves the name against the real _G, so
    -- a previous instance's table would otherwise be adopted by the next one. The bare name is
    -- already writable above, for the shipped files that own it.
    "_G.WhatGroupDB",
  },
}

-- ---------------------------------------------------------------------------
-- The narrowed 212s (lint.md, `M4c-04`)
-- ---------------------------------------------------------------------------
--
-- Every stanza below names ONE file, and every entry inside it names the code AND the variable, in
-- luacheck's `<code>/<variable>` form. That is the whole difference from the blanket this replaced:
-- a newly-unused argument under any other name, in any of these files or in any of the other 38,
-- still reports. Measured, not assumed -- adding a dead second parameter to `WhatGroup:RunTest` in
-- core/WhatGroup.lua reports under this config and did not under the old one.
--
-- Each one is a receiver a CALLING CONVENTION forces on a body that has no use for it, which is the
-- only shape that earns a stanza here. Anything else -- an argument this addon chose to accept and
-- then did not read -- is dead code, and `M4c-04` deleted five of those rather than listing them.

-- Two capture-pipeline methods published on the addon object and reached as `self:Capture...` /
-- `self:Resolve...` from three call sites in this file and from tests/test_capture.lua. Neither
-- body touches the receiver: the capture state they read lives in this file's own locals and in
-- `NS`, not on the addon table. They stay method-sugar because they are called through `self` by
-- code that has only `self` -- docs/module-map.md lists both under this file's surface.
--
-- `212/event` is the AceEvent-3.0 handler convention: the library invokes a handler as
-- `self[event](self, event, ...)`, so `event` arrives ahead of `appID` and `newStatus` whether the
-- body reads it or not. It is not read here because the method IS the event -- one handler, one
-- event name. The sibling handler at :707 does read it, to tell the two combat edges apart.
files["core/WhatGroup.lua"] = {
  ignore = { "212/self", "212/event" },
}

-- The four `ApplyFrame*` appliers. Every one of them reads the popup through this file's `f`
-- upvalue rather than through the addon table, so the receiver is unused -- but the method form is
-- load-bearing at the call sites, not decoration. Two of them are reached through a PROBE of the
-- member on the addon table before the colon call -- settings/Schema.lua:261 (`if
-- WhatGroup.ApplyFrameSize then`) and core/WhatGroup.lua:706 (`if not self.ApplyFrameVisibility
-- then return end`) -- which is how a settings row and a combat-edge handler survive
-- modules/Frame.lua failing to load. A plain local would have nothing for those probes to find.
files["modules/Frame.lua"] = {
  ignore = { "212/self" },
}

-- AceConsole-3.0 invokes the handler registered by `RegisterChatCommand` on the addon object, so
-- `WhatGroup:OnSlashCommand(input)` receives the addon it is already defined on. The body hands the
-- input straight to the LibKa0s-Slash-1.0 instance held in this file's `Sl` upvalue.
files["settings/Slash.lua"] = {
  ignore = { "212/self" },
}
