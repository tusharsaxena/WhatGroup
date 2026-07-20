-- core/DebugLog.lua
-- On-screen debug console (Ka0s standard, debug-logging). Debug output
-- (NS.Debug) renders here in a monospace font instead of spamming the chat
-- frame — required because WhatGroup ships a main window (modules/Frame.lua),
-- so the chat fallback (debug-logging-§7) is not available to us. Session-only: the enabled
-- state lives in NS.State.debug and resets on every reload/login (debug-logging-§5).

local addonName, NS = ...
NS.DebugLog = NS.DebugLog or {}
local D = NS.DebugLog
local frame

-- Chat ack seam. NS.Print is set by WhatGroup.lua (loads after this file, but
-- these acks only fire at runtime, by which point it exists). Fall back to a
-- prefixed print so a stray early call still lands somewhere visible.
local function ack(msg)
    if NS.Print then NS.Print(msg) else print(NS.PREFIX, msg) end
end

-- Plain-text mirror of the log (no colour codes), for the Copy window. Capped
-- like the log so a long session can't grow the buffer without bound.
D.buffer = D.buffer or {}
local MAX_BUFFER = 500

-- Chrome reserved at the log's edges for the §11 scrollbar + line counter.
local STATUS_H = 16   -- window-bottom band for the line-counter status bar
local BAR_W    = 8    -- right-edge scrollbar (Slider) track width

-- Backdrop shared by the console + copy windows so they read like the addon's
-- own main frame (modules/Frame.lua uses the same colours).
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local function applySkin(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    f:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
end

-- Small flat text button for the title bar (Copy / Clear).
local function makeTextButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.82, 0) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function makeCloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER")
    fs:SetText("\195\151")  -- multiplication sign ×
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.3, 0.3) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function EnsureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "WhatGroupDebugWindow", UIParent, "BackdropTemplate")
    frame:SetSize(700, 344)
    frame:SetPoint("CENTER", 220, -80)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        NS.Windows.Save("debug", frame)   -- persist geometry (WG-26)
    end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER")
    title:SetText("Ka0s WhatGroup \226\128\148 Debug")
    frame.title = title

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(0, 0, 0, 1)
    frame.divider = divider

    local close = makeCloseButton(titleBar, function() D:Hide() end)
    close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

    local clear = makeTextButton(titleBar, "Clear", 42, function() D:Clear() end)
    clear:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local copy = makeTextButton(titleBar, "Copy", 40, function() D:ShowCopy() end)
    copy:SetPoint("RIGHT", clear, "LEFT", -6, 0)

    -- Left-aligned debug on/off toggle: resting colour reflects state (green ON /
    -- red OFF); clicking flips state through the shared SetEnabled seam.
    local toggleBtn = CreateFrame("Button", nil, titleBar)
    toggleBtn:SetSize(80, 18)
    toggleBtn:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    local toggleFS = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toggleFS:SetPoint("LEFT")
    toggleBtn:SetScript("OnEnter", function() toggleFS:SetTextColor(1, 0.82, 0) end)
    toggleBtn:SetScript("OnLeave", function() D:RefreshHeader() end)
    local function onToggleClick() D:SetEnabled(not (NS.State and NS.State.debug)) end
    toggleBtn:SetScript("OnClick", onToggleClick)
    frame.debugToggle = toggleFS
    frame.debugToggleBtn = toggleBtn
    D._toggleClickForTest = onToggleClick   -- test seam (mock stubs GetScript)

    local log = CreateFrame("ScrollingMessageFrame", nil, frame)
    log:SetPoint("TOPLEFT", 8, -(26 + 6))
    -- Right inset clears the scrollbar gutter; bottom inset clears the status
    -- bar (and keeps the newest line's descenders off the window border).
    log:SetPoint("BOTTOMRIGHT", -(BAR_W + 8), STATUS_H + 4)
    log:SetFont(NS.FONT_MONO, 10, "")
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(MAX_BUFFER)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
        D:UpdateScrollBar()   -- keep the thumb in step with wheel scrolling
    end)
    frame.log = log

    -- Thin flat scrollbar synced to the message frame's offset (debug-logging-§11
    -- MUST). A ScrollingMessageFrame has no native scrollbar (wheel-only), so a
    -- plain vertical Slider drives its scroll offset. Always shown, going inert
    -- (mouse off, thumb parked) when the whole log fits — matching the options
    -- panel's always-shown scrollbar (options-ui-§10) so the gutter stays a
    -- constant width. Vertical-Slider convention: value 0 = thumb top = oldest;
    -- the message-frame offset is inverted (0 = newest/bottom), so
    -- offset = maxOffset - value (and value = maxOffset - offset on sync back).
    local bar = CreateFrame("Slider", nil, frame)
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(BAR_W)
    bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(26 + 6))
    bar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, STATUS_H + 4)
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetObeyStepOnDrag(true)
    bar:SetValue(0)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints()
    track:SetColorTexture(0.24, 0.24, 0.27, 0.30)
    local thumb = bar:CreateTexture(nil, "ARTWORK")
    thumb:SetColorTexture(0.5, 0.5, 0.55, 0.85)
    thumb:SetSize(BAR_W, 36)
    bar:SetThumbTexture(thumb)
    bar:SetScript("OnValueChanged", function(_, value)
        -- Re-entrancy guard: UpdateScrollBar's SetValue would otherwise loop
        -- back through here into SetScrollOffset (debug-logging-§11).
        if frame._syncing then return end
        local l = frame.log
        if not (l.GetMaxScrollRange and l.SetScrollOffset) then return end
        local maxOffset = l:GetMaxScrollRange()
        if type(maxOffset) ~= "number" then return end
        l:SetScrollOffset(maxOffset - math.floor(value + 0.5))
    end)
    frame.scrollBar = bar

    -- Bottom status bar: a 1px divider + a right-aligned "N / MAX lines" counter
    -- in the SAME monospace font as the log (debug-logging-§11 MUST).
    local statusDivider = frame:CreateTexture(nil, "ARTWORK")
    statusDivider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, STATUS_H)
    statusDivider:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, STATUS_H)
    statusDivider:SetHeight(1)
    statusDivider:SetColorTexture(0.24, 0.24, 0.27, 0.85)

    local lineCount = frame:CreateFontString(nil, "OVERLAY")
    lineCount:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 3)
    lineCount:SetFont(NS.FONT_MONO, 10, "")
    lineCount:SetJustifyH("RIGHT")
    lineCount:SetTextColor(0.6, 0.6, 0.62)
    frame.lineCount = lineCount

    applySkin(frame)
    frame:HookScript("OnShow", function() D:RefreshHeader() end)
    D:RefreshHeader()

    -- Restore the saved position over the default CENTER,220,-80 if the player
    -- has moved the console before (WG-26; no-op on a fresh profile).
    NS.Windows.Restore("debug", frame)

    frame:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "WhatGroupDebugWindow")
    end

    -- Initial scrollbar/counter sync LAST (debug-logging-§11 build-order): run it
    -- after the header, RefreshHeader, and the UISpecialFrames insert so a
    -- frame-API surprise inside the sync can never abort the rest of the console
    -- setup (blank header / ESC-to-close never registered).
    D:UpdateScrollBar()
    D:UpdateStatus()
    return frame
end

-- Pure plain-text line formatter (no frames, no colour codes): "<ts> | [<tag>] <msg>".
-- This is what the Copy buffer mirrors — clean text with the tag verbatim (debug-logging-§3).
function D.FormatPlain(ts, tag, msg)
    return ("%s | [%s] %s"):format(tostring(ts), tostring(tag or ""), tostring(msg))
end

-- Pure colour-coded line formatter for the console view: timestamp muted
-- steel-blue (6f8faf), [tag] muted tan/gold (c9a66b); the "|" separator and
-- message stay default white. "||" renders one literal pipe in the string (debug-logging-§3).
function D.FormatColored(ts, tag, msg)
    return ("|cff6f8faf%s|r || |cffc9a66b[%s]|r %s"):format(
        tostring(ts), tostring(tag or ""), tostring(msg))
end

function D:Add(tag, msg)
    local f = EnsureFrame()
    local ts = date("%H:%M:%S")
    f.log:AddMessage(D.FormatColored(ts, tag, msg))
    D.buffer[#D.buffer + 1] = D.FormatPlain(ts, tag, msg)
    if #D.buffer > MAX_BUFFER then table.remove(D.buffer, 1) end
    D:UpdateScrollBar()
    D:UpdateStatus()
end

-- Sync the scrollbar thumb/range to the message frame's current offset, using
-- the Lua ScrollingMessageFrameMixin API (GetMaxScrollRange / GetScrollOffset),
-- where offset 0 = bottom (newest) and offset == maxRange = top (oldest). The
-- old C getters (GetNumLinesDisplayed / GetCurrentScroll) are nil on this mixin
-- and MUST NOT be used (debug-logging-§11 / anti-pattern #41). No-op until the
-- frame exists; also a clean no-op under the headless mock, whose stub methods
-- return non-numbers — the type guard catches that.
function D:UpdateScrollBar()
    if not (frame and frame.log and frame.scrollBar) then return end
    local log, bar = frame.log, frame.scrollBar
    if not (log.GetMaxScrollRange and log.GetScrollOffset) then return end
    local maxOffset, off = log:GetMaxScrollRange(), log:GetScrollOffset()
    if type(maxOffset) ~= "number" or type(off) ~= "number" then return end
    frame._syncing = true   -- suppress the OnValueChanged → SetScrollOffset loop
    bar:SetMinMaxValues(0, maxOffset)
    bar:SetValue(maxOffset - off)
    frame._syncing = false
    bar:EnableMouse(maxOffset > 0)   -- inert (but still shown) when everything fits
end

-- Update the bottom status bar's line counter. #D.buffer is the live line count,
-- capped at MAX_BUFFER in lock-step with the log's SetMaxLines (debug-logging-§11).
function D:UpdateStatus()
    if frame and frame.lineCount then
        frame.lineCount:SetText(("%d / %d lines"):format(#D.buffer, MAX_BUFFER))
    end
end

function D:Clear()
    if frame and frame.log then frame.log:Clear() end
    wipe(D.buffer)
    D:UpdateScrollBar()
    D:UpdateStatus()
end

-- ── Copy window: read-through EditBox holding the whole log as plain text (debug-logging-§6) ──
local copyFrame
local function EnsureCopyFrame()
    if copyFrame then return copyFrame end

    copyFrame = CreateFrame("Frame", "WhatGroupDebugCopyWindow", UIParent, "BackdropTemplate")
    copyFrame:SetSize(560, 360)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("FULLSCREEN")
    copyFrame:EnableMouse(true)
    copyFrame:SetMovable(true)
    copyFrame:SetClampedToScreen(true)

    local tbar = CreateFrame("Frame", nil, copyFrame)
    tbar:SetPoint("TOPLEFT", 1, -1)
    tbar:SetPoint("TOPRIGHT", -1, -1)
    tbar:SetHeight(26)
    tbar:EnableMouse(true)
    tbar:RegisterForDrag("LeftButton")
    tbar:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
    tbar:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)
    local t = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER")
    t:SetText("Copy log \226\128\148 Ctrl+C, then Esc")
    copyFrame.title = t

    local cclose = makeCloseButton(tbar, function() copyFrame:Hide() end)
    cclose:SetPoint("RIGHT", tbar, "RIGHT", -6, 0)

    local scroll = CreateFrame("ScrollFrame", "WhatGroupDebugCopyScroll", copyFrame,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    copyFrame.scroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFont(NS.FONT_MONO, 10, "")
    edit:SetAutoFocus(false)
    edit:SetWidth(510)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); copyFrame:Hide() end)
    scroll:SetScrollChild(edit)
    copyFrame.edit = edit

    applySkin(copyFrame)
    copyFrame:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "WhatGroupDebugCopyWindow")
    end
    return copyFrame
end

function D:ShowCopy()
    local f = EnsureCopyFrame()
    f.edit:SetWidth(f.scroll:GetWidth() > 0 and f.scroll:GetWidth() or 510)
    f.edit:SetText(table.concat(D.buffer, "\n"))
    f.edit:SetCursorPosition(0)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

function D:Show() EnsureFrame():Show() end
function D:Hide() if frame then frame:Hide() end end
function D:Toggle()
    local f = EnsureFrame()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- Is the console window currently visible? Drives the Settings panel's
-- "Debug console" checkbox, which toggles window visibility only. False
-- before the frame is ever created (no EnsureFrame side effect here).
function D:IsShown() return (frame and frame:IsShown()) and true or false end

-- Single seam for changing debug state. The slash command and the header toggle
-- both call this so the chat ack and the header label stay consistent.
-- Session-only (debug-logging-§5).
function D:SetEnabled(on)
    on = not not on
    NS.State.debug = on
    D:RefreshHeader()
    -- Colour-coded chat ack (debug-logging-§5 MUST): ON green (40ff40) / OFF red
    -- (ff4040), matching the title-bar toggle so the flag reads identically in
    -- chat and on the console header. Routed through NS.PREFIX via ack().
    ack("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
    -- Bracket every session with a console line at both ends. Write through
    -- D:Add rather than NS.Debug so the "logging disabled" line still lands
    -- after NS.State.debug has flipped off (NS.Debug is gated on the flag,
    -- D:Add is not).
    D:Add("Debug", on and "logging enabled" or "logging disabled")
    -- On enable, emit a one-line [Init] session summary immediately after the
    -- bracket (debug-logging-§5 MUST) — addon/version, schema, active profile —
    -- so a pasted log is self-identifying. Via the raw D:Add (not the gated
    -- NS.Debug sink), and only on enable: the flag is session-only and off at
    -- login, so the SetEnabled seam is the only current, visible point (debug-logging-§8).
    if on and NS.addon and NS.addon.InitSummary then
        D:Add("Init", NS.addon:InitSummary())
    end
end

function D:RefreshHeader()
    if not (frame and frame.debugToggle) then return end
    local on = NS.State and NS.State.debug
    frame.debugToggle:SetText(on and "Debug: ON" or "Debug: OFF")
    -- Matches the colour-coded chat ack (debug-logging-§5): ON 40ff40, OFF ff4040.
    if on then frame.debugToggle:SetTextColor(0.25, 1.0, 0.25)
    else frame.debugToggle:SetTextColor(1.0, 0.25, 0.25) end
end

-- Global debug sink. No-op (zero alloc) when debug is off; otherwise appends to
-- the console. The tag is the first argument so every call site self-documents
-- its category: NS.Debug("Capture", "title=%s", title).
function NS.Debug(tag, fmt, ...)
    if not (NS.State and NS.State.debug) then return end
    local msg
    if select("#", ...) > 0 then
        -- Secret-safe (WG-22 / events-frames-taint-§8): a combat-protected value
        -- passed to string.format raises, and on the notify path that freezes
        -- the feature until /reload. pcall the format so the raise is caught;
        -- on failure, rebuild the line from SafeToString'd args so it still
        -- lands with "<secret>" in place of the offending value.
        local ok, out = pcall(string.format, fmt, ...)
        if ok then
            msg = out
        else
            local parts = { fmt }
            for i = 1, select("#", ...) do
                parts[#parts + 1] = NS.SafeToString((select(i, ...)))
            end
            msg = table.concat(parts, " ")
        end
    else
        msg = fmt
    end
    D:Add(tag, msg)
end
