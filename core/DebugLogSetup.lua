-- core/DebugLogSetup.lua — wires the addon into LibKa0s-DebugLog-1.0.
--
-- The console window, the copy window, the two line formatters, the ring buffer, the scrollbar
-- sync, the line counter and the enable seam all lived in core/DebugLog.lua (405 lines) and are now
-- the library's, shared across the collection. This file supplies only the part that is ours: the
-- frame-name prefix, the human title, the monospace font path, where the debug flag actually lives,
-- what the [Init] session summary says, and who to tell when the window opens or closes.
--
-- TOC slot: after core/WhatGroup.lua, and that is a MOVE from where core/DebugLog.lua sat. The
-- library validates `font`, `title`, `name`, `isEnabled` and `setEnabled` at :New time — where the
-- hand-written console read NS.FONT_MONO lazily, inside its frame builder — and both NS.FONT_MONO
-- and NS.State.debug are defined in core/WhatGroup.lua. That is exactly the placement
-- debug-logging-§1 asks for: after the file carrying the mono font path, after the file carrying
-- the flag, after the core printer, and before every module that calls the sink. Nothing calls
-- NS.Debug at FILE LOAD — every call site in the repo is inside a function, and core/Database.lua's
-- is additionally guarded on the member existing — so the move costs nothing.

local addonName, NS = ...

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

-- ---------------------------------------------------------------------------
-- The §2 fetch-failure fallback
-- ---------------------------------------------------------------------------
--
-- debug-logging-§2 asks for a Blizzard font "as the fetch-failure fallback" behind the vendored
-- TTF, and the reason is that a fetch failure is SILENT. `SetFont` answers `false` when the client
-- cannot load the file — a packager that dropped the library's media/, a corrupt TTF, a path
-- case-mangled on a case-sensitive filesystem — and does not raise. Without a fallback the console
-- then comes up in whatever font the FontString already carried, i.e. a proportional one: the
-- aligned `HH:MM:SS | [tag] …` columns that the §2 monospace MUST exists for are gone, and
-- nothing in the error log says why.
--
-- The library takes ONE resolved string (`descriptor.font`, fed straight to SetFont at
-- DebugLog.lua's log / line-counter / copy-box builds) and the addon is the side that ships the
-- file, so the probe belongs here, on the host's side of the seam. `CreateFont` rather than a
-- throwaway frame: a Font object is the lightest thing in the API that carries `SetFont`, it is
-- never parented or shown, and probing it cannot disturb a Blizzard font object the way reusing
-- `GameFontNormal` would. Resolved once at load, because `:New` validates `font` as a string.
local FONT_FALLBACK = "Fonts\\ARIALN.TTF"

local function resolveConsoleFont(path)
    if type(path) ~= "string" then return FONT_FALLBACK end
    if type(_G.CreateFont) ~= "function" then return path end
    local probe = _G.CreateFont("WhatGroupFontProbe")
    if not (probe and probe.SetFont) then return path end
    -- pcall'd as well as return-checked: SetFont is documented to answer false, but a nil-safe
    -- probe must survive a client that raises on a malformed path instead.
    local ok, applied = pcall(probe.SetFont, probe, path, 10, "")
    if ok and applied ~= false then return path end
    return FONT_FALLBACK
end

if not lib then
    -- A missing vendored lib must degrade, not error at load. The stub covers every member the
    -- addon calls — core/WhatGroup.lua's `/wg debug`, settings/Panel.lua's console checkbox,
    -- settings/Schema.lua's and modules/Frame.lua's trace calls — and the FLAG itself still works,
    -- because NS.State.debug is ours and a user who types `/wg debug on` must not be told nothing
    -- happened. What is lost is the window, and the stub says so once, honestly.
    local missing = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."

    -- ONE announce per ENTRY POINT. A single shared token is spent by whichever path the user
    -- happens to take first — `/wg debug on` burns it, and then the very next `/wg debug`, which is
    -- the verb that actually asks for the WINDOW, says nothing at all. Each surface that silently
    -- does less than it looks like it does explains itself once.
    local function announcer()
        local said = false
        return function()
            if said then return end
            said = true
            if NS.Print then NS.Print(missing) end
        end
    end
    local sayOnEnable, sayOnWindow, sayOnCopy = announcer(), announcer(), announcer()

    -- No formatters here, deliberately. Nothing in the addon calls them outside the library's own
    -- Add, and hand-copying the exact strings whose seven-way drift this extraction exists to end
    -- is the one duplicate debug-logging-§3 and testing-§8 most specifically forbid.
    NS.DebugLog = {
        buffer          = {},
        Add             = function() end,
        Debug           = function() end,
        Clear           = function() end,
        Show            = function() sayOnWindow() end,
        Hide            = function() end,
        Toggle          = function() sayOnWindow() end,
        IsShown         = function() return false end,
        IsEnabled       = function() return (NS.State and NS.State.debug) and true or false end,
        RefreshHeader   = function() end,
        ShowCopy        = function() sayOnCopy() end,
        UpdateScrollBar = function() end,
        UpdateStatus    = function() end,
        BufferSize      = function() return 0 end,
        LastLine        = function() return nil end,
        FindLine        = function() return nil end,
        CopyText        = function() return "" end,
        MakeCloseButton = function() return nil end,
        Text            = function(_, key) return key end,
        SetEnabled      = function(_, on)
            on = not not on
            if NS.State then NS.State.debug = on end
            if NS.Print then
                NS.Print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
            end
            if on then sayOnEnable() end
        end,
        ConsoleCheckbox = function()
            return {
                label   = "Debug console",
                tooltip = missing,
                get     = function() return false end,
                set     = function() sayOnWindow() end,
            }
        end,
    }
    NS.Debug = NS.DebugLog.Debug
    return
end

NS.DebugLog = lib:New({
    -- Seeds WhatGroupDebugWindow / WhatGroupDebugCopyWindow / WhatGroupDebugCopyScroll — the same
    -- three frame globals the hand-written console used, so /framestack and any Esc-close muscle
    -- memory are unchanged.
    name  = addonName,
    -- THE FOLDER NAME, which is a different question from the one above even though this addon
    -- answers both with the same string. `name` seeds frame globals; `addonName` is what the
    -- library builds a TEXTURE PATH from, so the console's own close, clear and copy controls draw
    -- this collection's marks instead of a multiplication sign and two words. A vendored library
    -- cannot work it out for itself -- there is no one path to it -- and a host where the two
    -- strings diverge would hand it a path into nowhere, which draws nothing and raises nothing.
    -- Passed explicitly for that reason rather than left to be inferred from `name`. It reaches the
    -- copy window's close button too.
    addonName = addonName,
    -- The library appends its own " — Debug", so this is the bare brand.
    title = "Ka0s WhatGroup",
    -- The library's own JetBrains Mono, or a Blizzard font if this client cannot fetch it
    -- (debug-logging-§2). NS.FONT_MONO is never nil — it falls back to STANDARD_TEXT_FONT —
    -- which matters because the library validates this field as a string at :New time.
    font  = resolveConsoleFont(NS.FONT_MONO),
    slash = "/wg",

    -- The flag stays ours. NS.State.debug is session-only (debug-logging-§5, WG-12) and is read by
    -- the settings panel and the slash verb as well as by the console, so a second copy inside the
    -- library would be a second truth.
    isEnabled  = function() return (NS.State and NS.State.debug) and true or false end,
    setEnabled = function(on) if NS.State then NS.State.debug = on end end,

    -- Thin call-time forwarders, never captured references (debug-logging-§1). Freezing either at
    -- load would mean acknowledging through whatever happened to exist at that instant — and
    -- NS.Print in particular is not final until core/WhatGroup.lua:84 reclaims the name from
    -- AceConsole's embed (core/CoreSetup.lua publishes NS.Util.print, deliberately out of its
    -- reach; anti-patterns #36).
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

    -- The one-line [Init] session summary. The library owns WHEN it is emitted — on enable,
    -- because the flag is session-only and off at login, so a load-time summary would always be
    -- gated off and never render — and only the addon can know what it says (debug-logging-§5/§8).
    initSummary = function()
        local addon = NS.addon
        if addon and addon.InitSummary then return addon:InitSummary() end
    end,

    -- The General page's console checkbox mirrors the window's visibility, so a console closed with
    -- Esc or the × has to move a checkbox on a panel that is already open. Guarded because
    -- settings/ loads after core/.
    onVisibilityChanged = function()
        local H = NS.addon and NS.addon.Settings and NS.addon.Settings.Helpers
        if H and H.RefreshAll then H.RefreshAll() end
    end,

    -- No `L`: this addon translates none of the console's strings, so omitting the field is both
    -- the common case and the safe one — a locale table here answers EVERY key with the key itself,
    -- and the console would render DEBUG_ON / LINES / COPY_TITLE in place of English.
    --
    -- No `skin`, no `applySkin`, no `makeCloseButton` either, and that is a decision rather than an
    -- omission. As of Core minor 3 the library's own default draws the normative Ka0s window edge
    -- (standalone-windows), which is what the addon's popup now wears too, and the close control on
    -- a window the library draws is the library's — a host must not push its own onto it. That is
    -- also why the mark arrives through `addonName` above rather than through a host-supplied
    -- button: the library keeps drawing it, and is merely told where the art lives.
})

-- The global gated sink (debug-logging-§4), published under the name the addon's 26 existing call
-- sites already use. Bound BARE rather than wrapped: it is a plain function precisely so
-- `NS.Debug("Set", "%s = %s", path, value)` keeps working.
NS.Debug = NS.DebugLog.Debug
