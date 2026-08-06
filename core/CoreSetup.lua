-- core/CoreSetup.lua — wires the addon into LibKa0s-Core-1.0.
--
-- The secret-value guard, the concat-safe stringifier, the prefixed [WG] chat printer and the
-- shared window skin used to live in core/Util.lua. They are the same four things in every Ka0s
-- addon — and were subtly different in several of them — so they now live in libs/LibKa0s/Core.lua
-- and this file is only the part that is ours: which tag the lines carry, where they land, and what
-- happens when the library is not there.
--
-- ── Why this TOC slot ──────────────────────────────────────────────────────
--
-- FIRST in the `# Core` block, and three constraints put it there:
--
--   * it MUST load BEFORE core/WhatGroup.lua, which takes the printer as a file-scope upvalue
--     (`local p = NS.Util.print`). A seam that published after that line would be a silent no-op
--     while appearing to work;
--   * it MUST publish onto `NS.Util.print`, never `NS.Print`. core/WhatGroup.lua passes NS to
--     AceAddon:NewAddon with "AceConsole-3.0", so AceConsole's `:Print` mixin lands on the
--     namespace and clobbers a same-named custom printer (anti-patterns #36). `NS.Util.print` is
--     out of its reach, and core/WhatGroup.lua's own `NS.Print = p` line is the reclaim;
--   * it MUST NOT read NS.PREFIX at load — that constant is defined in core/WhatGroup.lua, which
--     loads later. Hence the FUNCTION form of `prefix` below, which Core re-reads on every call.
--
-- What stays in core/Util.lua is NS.Windows, the standalone-window geometry persistence (WG-26),
-- which is genuinely this addon's and has no library equivalent.

local addonName, NS = ...

-- The one cause clause, shared by every seam that has to explain the same absence: this file,
-- core/DebugLogSetup.lua, settings/OptionsSetup.lua and settings/Slash.lua. Each appends its own
-- "so <what> is unavailable" and its own terminal punctuation, so a degraded install says the same
-- thing about WHY at every site and a different thing about WHAT at each one. Set OUTSIDE the
-- branch below, because the later seams read it on both paths, and set HERE because
-- core/CoreSetup.lua is the first of the four the TOC loads.
NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of Ka0s WhatGroup " ..
    "(expected in libs/LibKa0s)"

NS.Util = NS.Util or {}

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
    -- A missing vendored lib must degrade, not error at load. Silence is not an option for this
    -- one the way it is for a diagnostics harness: every user-facing line in the addon goes through
    -- NS.Util.print, and answering nil would take the whole chat and slash surface down. So the
    -- fallbacks work — they are the pre-library implementations, kept short — and the honest "it is
    -- not installed" line is said ONCE, on the first line the addon prints, rather than stapled to
    -- every one of them.
    local function probeConcat(v) return table.concat({ v }) end

    function NS.IsConcatSafe(v)
        return (pcall(probeConcat, v))
    end

    function NS.SafeToString(v)
        if v == nil then return "nil" end
        if type(v) == "boolean" then return tostring(v) end
        if NS.IsConcatSafe(v) then return tostring(v) end
        return "<secret>"
    end

    local announced = false
    function NS.Util.print(...)
        if not announced then
            announced = true
            print(NS.PREFIX, NS.LIBKA0S_MISSING .. "; running on reduced built-in fallbacks.")
        end
        local n = select("#", ...)
        local parts = {}
        for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
        print(NS.PREFIX, table.concat(parts, " "))
    end

    -- Exported with no production caller ON PURPOSE: `NS.Util.format` is the parity half of the
    -- library's printer surface, and the fallback must publish everything the library path does.
    -- Nothing calls Format today, which is exactly why its absence would go unnoticed — the first
    -- caller added later would work in every install that has the library and be nil in the one
    -- this branch exists for. Keep it, or delete it from BOTH paths in the same change.
    function NS.Util.format(fmt, ...)
        local n = select("#", ...)
        if n == 0 then return NS.Util.print(fmt) end
        local parts = {}
        for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
        NS.Util.print(NS.SafeToString(fmt):format(unpack(parts)))
    end

    -- The window chrome, degraded to a plain dark panel. Deliberately NOT a hand-copy of Core's
    -- SKIN values: standalone-windows makes the Ka0s window edge normative and copying the hex
    -- codes into a fallback is exactly the drift the shared table exists to end (anti-patterns
    -- #47). A degraded install gets a readable window, not a pixel-accurate one.
    NS.SKIN = { bg = { 0.06, 0.06, 0.08, 0.92 }, border = { 0, 0, 0, 1 } }
    function NS.ApplySkin(frame)
        if not (frame and frame.SetBackdrop) then return end
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8",
            edgeSize = 1, insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frame:SetBackdropColor(unpack(NS.SKIN.bg))
        frame:SetBackdropBorderColor(unpack(NS.SKIN.border))
    end
    function NS.MakeCloseButton() return nil end
    return
end

-- Published under the keys the addon already reads. Bound to the library's own function objects
-- rather than wrapped, so `NS.SafeToString` and the value a descriptor forwards to are provably the
-- same implementation.
NS.IsConcatSafe = lib.IsConcatSafe
NS.SafeToString = lib.SafeToString

-- The window chrome seam (standalone-windows). `NS.SKIN` is the library's table, not a copy, and
-- `ApplySkin` takes an OPTIONAL override rather than the caller's own backdrop — the old
-- two-argument form let each window carry its own border geometry, which is precisely how the
-- collection's five windows stopped reading as one suite of addons. Supersedes the WG-28 accepted
-- deviation recorded in closed issue #6 (PLAN-02): the shared table now carries the backdrop
-- fields as well as the colors, so there is nothing left to justify keeping apart.
NS.SKIN            = lib.SKIN
NS.ApplySkin       = lib.ApplySkin
NS.MakeCloseButton = lib.MakeCloseButton

-- The prefix is a FUNCTION, not the value of NS.PREFIX: this file loads before core/WhatGroup.lua
-- defines that constant, so the string form would capture nil forever. Core re-reads it on every
-- call, which is what makes an early-loading seam legal.
--
-- `sink` is explicit because this addon's chat output has always gone through the Lua global
-- `print` rather than DEFAULT_CHAT_FRAME:AddMessage (Core's default). Both land in the same chat
-- frame in game — but the headless harness captures the global, so without this every chat
-- assertion in the suite would go silent while still passing.
local printer = lib:New({
    prefix = function() return NS.PREFIX end,
    sink   = function(line) print(line) end,
})

-- The one user-facing chat path, under the name ~40 call sites already use. core/WhatGroup.lua
-- aliases it to its file-local `p`, to NS.Print (reclaiming the name from AceConsole's embed) and
-- to WhatGroup._print.
NS.Util.print  = printer.Print

-- No production caller, deliberately: this is the parity half of the printer surface, published so
-- the degraded branch above and this one expose the same keys. See that branch's note before
-- removing — either both go or neither does.
NS.Util.format = printer.Format
