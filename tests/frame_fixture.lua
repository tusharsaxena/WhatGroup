-- tests/frame_fixture.lua — the popup helpers tests/test_frame.lua and
-- tests/test_frame_visibility.lua both use: a pending capture, the popup and its Close button, the
-- drag handle, the ESC proxy and a simulated Escape. Not a suite: each suite `dofile`s it and takes
-- the members it needs as locals, so the cases themselves read exactly as they did before the split.

local function pending(overrides)
    local i = {
        title            = "Stonevault Speedrun",
        leaderName       = "Testadin-Silvermoon",
        numMembers       = 3,
        voiceChat        = "",
        age              = 0,
        activityIDs      = { 2516 },
        activityID       = 2516,
        fullName         = "Dungeons > Mythic+ > The Stonevault",
        activityName     = "The Stonevault",
        maxNumPlayers    = 5,
        isMythicPlus     = true,
        isCurrentRaid    = false,
        isHeroicRaid     = false,
        categoryID       = 1,
        mapID            = 2652,
        generalPlaystyle = 3,
        playstyleString  = "",
        shortName        = "",
    }
    for k, v in pairs(overrides or {}) do i[k] = v end
    return i
end

local function popup(mock) return mock.frames["WhatGroupFrame"] end

-- The Close button is anonymous, so it is found by the thing that identifies it to a player: its
-- label. Anchored to the popup rather than searched globally, so a second button with the same text
-- elsewhere in the addon could not silently become the one under test.
local function closeButton(mock)
    local f = popup(mock)
    if not f then return nil end
    for _, kid in ipairs(f.__children or {}) do
        if kid.__text == "Close" and kid.__scripts and kid.__scripts.OnClick then return kid end
    end
    return nil
end

-- The title bar is the drag handle, and the only frame carrying an OnMouseUp.
local function dragHandle(mock)
    for _, fr in ipairs(mock.frames) do
        if fr.__scripts.OnMouseUp then return fr end
    end
end

-- The ESC proxy (the standalone-windows row in docs/ARCHITECTURE.md's register). UISpecialFrames
-- holds the name of a small unprotected frame that mirrors "the popup is on screen", never the
-- popup's own name: Escape's CloseWindows calls a bare `:Hide()` on every shown entry, and on
-- WhatGroupFrame -- which parents a SecureActionButtonTemplate -- that call is refused in combat.
local PROXY = "WhatGroupFrameEscape"
local function proxy(mock) return mock.frames[PROXY] end

-- Blizzard's CloseWindows, as far as it concerns us: every name in UISpecialFrames whose frame is
-- SHOWN gets a bare `:Hide()`, and a hit means the press was spent closing a window -- so the game
-- menu does not open on it. `mock.frames[name]` stands in for `_G[name]`: the mock's CreateFrame
-- records named frames there rather than in the sandbox's globals. The mock's Hide already refuses
-- (and records in mock.blocked) a Hide on a frame holding a protected descendant during combat,
-- which is the client's ADDON_ACTION_BLOCKED.
local function pressEscape(mock)
    local found = false
    for _, name in ipairs(mock.UISpecialFrames) do
        local fr = mock.frames[name]
        if fr and fr:IsShown() then
            fr:Hide()
            found = true
        end
    end
    return found
end

return {
    pending     = pending,
    popup       = popup,
    closeButton = closeButton,
    dragHandle  = dragHandle,
    PROXY       = PROXY,
    proxy       = proxy,
    pressEscape = pressEscape,
}
