local addonName, NS = ...

-- core/EnvSetup.lua — wires the addon into LibKa0s-Env-1.0 (library-stack-§7).
--
-- The seam where this addon's own version and its TOC Notes line come from. Two members only:
-- WhatGroup stamps neither a zone nor a map id, so NS.Zone and NS.PlayerMapID have no host here.
--
-- ── WHAT THIS REPLACED ───────────────────────────────────────────────────────────────────────
--
-- Two INLINE copies of the TOC-metadata ladder — settings/Slash.lua's `version()` and
-- settings/Panel.lua's `addNotesLine`. Neither was ever in core/Compat.lua, which is exactly what
-- made them worth finding: an audit of the shim files would have reported this addon as having no
-- copy at all. Collection-wide the same ladder had been written ELEVEN times across nine addons
-- before the library had it, six in a core/Compat.lua in four different spellings and five more
-- inlined at the call site like these two. Not one of the eleven behaved differently from any
-- other, and that sameness is the whole case: it is what makes the reader the library's business
-- rather than this addon's, and it is why core/Compat.lua KEEPS its spell and LFG shims, which are
-- genuinely WhatGroup's and behave like nobody else's.
--
-- ── WHY THE LIBRARY HAS TO BE TOLD OUR NAME ──────────────────────────────────────────────────
--
-- Same reason core/MediaSetup.lua passes it: LibKa0s is VENDORED, so a copy cannot know which addon
-- folder it sits in. `addonName` is the FIRST VARARG every TOC-loaded file gets — not the `## Title`
-- and not a hand-typed literal. Here those read "WhatGroup" and "Ka0s WhatGroup", and only the
-- first is the folder. The deleted settings/Panel.lua copy typed it as a literal, which is the
-- spelling that goes stale the day the folder is renamed and answers nil without raising a thing.
--
-- ── WHY THE FALLBACKS ARE WRITTEN OUT RATHER THAN LEFT TO ANSWER nil ─────────────────────────
--
-- Because this is a seam, not a feature. An install missing LibKa0s must get exactly what this
-- addon got before the library existed: both helpers below repeat the ladder the deleted inline
-- copies ran, so such an install still reads its own TOC. Nil here would raise nothing and look
-- fine — it is a blank Notes line on the options panel and a blank version in the slash banner.
--
-- ── TOC SLOT ─────────────────────────────────────────────────────────────────────────────────
--
-- After core\Compat.lua, and before settings\Panel.lua and settings\Slash.lua. Nothing here is
-- resolved at load beyond the LibStub lookup, and both call sites read inside a function, so the
-- position is conventional rather than load-bearing — unlike core\MediaSetup.lua just above it.

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC manifest, or nil.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent AND the client may expose no reader
--- at all, which is what a headless run looks like. A field the TOC does not carry also answers nil
--- on a perfectly healthy client. Callers that need a value supply their own — settings/Panel.lua
--- supplies "" and settings/Slash.lua supplies the in-code constant.
---
--- @param field string  a TOC key: "Version", "Title", "Notes", "Author", …
--- @return string|nil
function NS.Meta(field)
    if Env then return Env.GetAddOnMetadata(addonName, field) end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if type(GetAddOnMetadata) == "function" then
        return GetAddOnMetadata(addonName, field)
    end
    return nil
end

--- This addon's version string, preferring the TOC over the in-code constant. Never nil.
---
--- The fallback stays visible HERE rather than inside the library because which constant this addon
--- falls back to is genuinely its own business — and because a packaged addon whose TOC can be read
--- should never report the constant somebody forgot to edit (slash-commands-§3).
---
--- The constant is `WhatGroup.VERSION` rather than the `NS.version` most of the collection uses,
--- and it is read at CALL time, not captured as an upvalue: core/WhatGroup.lua publishes it and
--- loads after this file.
---
--- @return string
function NS.Version()
    local fallback = NS.addon and NS.addon.VERSION
    if Env then return Env.Version(addonName, fallback) or "?" end
    return NS.Meta("Version") or fallback or "?"
end
