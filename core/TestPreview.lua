local _, NS = ...

-- core/TestPreview.lua -- the sample capture and the one-shot notify + popup preview, peeled out of
-- core/WhatGroup.lua (WHATGROUP-R-14).

local WhatGroup = NS.addon

-- ---------------------------------------------------------------------------
-- Preview / test injection
-- ---------------------------------------------------------------------------
--
-- The slash surface itself lives in settings/Slash.lua: the COMMANDS table, the
-- host verbs, and the LibKa0s-Slash-1.0 descriptor that owns the dispatcher, the
-- help renderer, the value parser and the list/get/set/reset schema verbs. What
-- stays here is the one thing two callers share — `/wg test notify` and the
-- settings panel's Test notification button both need this body, and neither should go
-- through the other's entry point.

-- The sample capture: a fresh table on every call, so no caller hands another one it then mutates.
-- Neither `/wg test notify` (RunTest, below) nor test mode (modules/Frame.lua, bare `/wg test`)
-- ever makes it the pending capture: both show it WITHOUT touching pendingInfo.
function WhatGroup:SampleInfo()
    -- mapID 2805 is Windrunner Spire — exercises the mapID-keyed teleport
    -- lookup (1254400, Path of the Windrunners). generalPlaystyle exercises
    -- the enum-based label path; leave playstyleString empty so the lookup
    -- falls through to WhatGroup.Labels.PLAYSTYLE instead of using the
    -- pre-rendered string.
    --
    -- activityID is synthetic and deliberately NOT a key in TeleportSpells:
    -- the resolver checks mapID first, so a fixture whose activityID also
    -- named a real row would still pass with the mapID path broken.
    return {
        title             = "Test Group — Windrunner Spire +12",
        leaderName        = "Testadin-Silvermoon",
        numMembers        = 3,
        voiceChat         = "",
        age               = 127,
        activityIDs       = {990001},
        activityID        = 990001,
        fullName          = "Dungeons > Mythic+ > Windrunner Spire",
        activityName      = "Windrunner Spire",
        maxNumPlayers     = 5,
        isMythicPlus      = true,
        isCurrentRaid     = false,
        isHeroicRaid      = false,
        categoryID        = 1,
        mapID             = 2805,
        generalPlaystyle  = Enum.LFGEntryGeneralPlaystyle.FunSerious,
        playstyle         = Enum.LFGEntryGeneralPlaystyle.FunSerious,
        playstyleString   = "",
        shortName         = "Mythic+",
        -- The application's role, so test mode exercises the Role row (WhatGroup#1). A role the
        -- leader assigned in a real group still wins, as it does for a live capture.
        role              = "DAMAGER",
    }
end

-- Public method so the Settings panel's Test notification button can invoke the
-- same code path as /wg test notify without going through the slash dispatch.
-- One-shot: the full notify + popup flow runs once ON THE SAMPLE, which is passed to both halves
-- and never written to pendingInfo, so a real capture the player is holding is what `/wg show`, the
-- details link and the launcher's Show window open afterwards (WG-R-03). The popup renders it as a
-- one-shot preview that ends when the popup is closed. Its ShowFrame ends test mode if it is on,
-- so the two never overlap.
--
-- STOOD DOWN, IT IS THE CHAT PREVIEW ONLY. The panel's Test notification button still reaches here with the
-- addon off, and a popup built then would add the secure teleport button and the UISpecialFrames
-- proxy to a disabled addon's session, be withheld by the gate, and come back unasked on the
-- re-enable (WG-R-04). So no frame is built, shown or withheld.
function WhatGroup:RunTest()
    local sample = self:SampleInfo()
    NS.Debug("Test", 'synthetic capture previewed "%s"', sample.title)
    self:ShowNotification(sample)
    if NS.IsStoodDown() then
        NS.Debug("Test", "popup skipped: addon stood down (chat preview only)")
        return
    end
    self:ShowFrame(sample)
end
