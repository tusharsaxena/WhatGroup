-- core/MediaSetup.lua — wires the addon into LibKa0s-Media-1.0.
--
-- Two things this addon used to own now arrive with the library payload: the
-- monospace face the debug console renders in, and the small square marks its
-- title bars draw. Both are published here as one-line seams, for the same
-- reason core/CoreSetup.lua exists — the part that is ours is which folder is
-- asking and what happens when the library is not there.
--
-- ── Why the library has to be told our name ────────────────────────────────
--
-- A texture path is absolute from `Interface\AddOns\`, and LibKa0s is VENDORED:
-- every consumer carries its own copy at its own path, and a copy cannot work
-- out which addon folder it was copied into. So the library asks, and this file
-- is where the answer lives — `addonName`, the first vararg every TOC-loaded
-- file gets. Not the frame-name prefix, not the `## Title`, not a hand-typed
-- constant: the FOLDER name, because that is what the path is built from. A
-- wrong one draws nothing and raises nothing.
--
-- ── Why this TOC slot is load-bearing ──────────────────────────────────────
--
-- core/WhatGroup.lua resolves NS.FONT_MONO from NS.MediaFont AT LOAD, and
-- core/DebugLogSetup.lua hands that value to the library's `:New` descriptor,
-- which validates it as a string. Both would see nil if this file published
-- later, so it sits immediately after core/CoreSetup.lua and before either —
-- one of the few files in core/ whose TOC position is a constraint rather than
-- a convention.
--
-- ── What a degraded install gets ───────────────────────────────────────────
--
-- No LibKa0s means no art and no face: they are inside the payload that is
-- missing. `NS.Icon` answers nil, which every call site treats as "draw what
-- you drew before" — the library falls back to a multiplication sign for its
-- own close controls, and modules/Frame.lua simply skips the mark beside its
-- footer label. `NS.MediaFont` answers nil, which core/WhatGroup.lua turns into
-- the client's own STANDARD_TEXT_FONT. Neither is an error. Chrome degrades;
-- the group information the window exists to show stays readable.
--
-- NIL IS A REAL ANSWER TWICE OVER — no library, or no such name — and both mean
-- the same thing to a caller. Never route around one by building a path with
-- concatenation: a plausible path to a texture that is not there is a control
-- that is silently, permanently absent.
--
-- This file does NO frame work, which is why registering at file load is safe
-- here. modules/Frame.lua records what file-load frame work cost this addon
-- once already (the UISpecialFrames taint that surfaced on Logout).

local addonName, NS = ...

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon, or nil.
---
--- EXTENSIONLESS by the library's contract: it answers `...\media\icons\close`
--- and the client appends `.tga` itself. A path carrying the extension is one of
--- the spellings that draws nothing.
---
--- The library's `Icon` takes an optional third `vendorPath`; it is deliberately
--- not forwarded, because this addon vendors LibKa0s at the standard
--- `libs/LibKa0s/` and the library's own default is exactly that. A consumer
--- that moved the payload would be the one that needs to pass it.
---
--- @param name string  an entry of the library's `ICONS` catalog, e.g. "close"
--- @return string|nil
function NS.Icon(name)
    if not Media then return nil end
    return Media.Icon(addonName, name)
end

--- The path of one shipped font face, or nil when the library is absent.
---
--- Same deliberate omission of the optional `vendorPath` as `NS.Icon`, for the
--- same reason. A FONT path keeps its extension — unlike an icon path — because
--- `SetFont` is handed the file, not a texture name the client completes.
---
--- @param name string  a key of the library's `FONTS`, e.g. "JetBrains Mono"
--- @return string|nil
function NS.MediaFont(name)
    if not Media then return nil end
    return Media.Font(addonName, name)
end

-- AT FILE LOAD, not at PLAYER_LOGIN. LibSharedMedia is vendored under libs/ and
-- has therefore already run by the time the TOC reaches core/, while
-- core/WhatGroup.lua names the face at load time too — deferring would open a
-- window in which the console asked LSM for a key nobody had registered.
--
-- This replaces the addon's own `LSM:Register("font", "JetBrains Mono", ...)`,
-- which pointed at a copy under this addon's media/fonts/. The library's call is
-- idempotent and points every Ka0s addon at ONE set of bytes under one key,
-- which is what makes two of them registering "JetBrains Mono" agree instead of
-- collide. `vendorPath` is again left at its default.
if Media then Media.RegisterLSM(addonName) end
