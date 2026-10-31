local _, NS = ...

-- core/Labels.lua -- the labels the chat notification and the popup share, peeled out of
-- core/WhatGroup.lua (WHATGROUP-R-14). core/WhatGroup.lua creates WhatGroup.Labels, because its
-- notification rows bind the table at file scope; this file fills it, and every read is at call time.

local WhatGroup = NS.addon

-- Keyed by Enum.LFGEntryGeneralPlaystyle so the labels match the LFG UI's
-- own "Learning / Fun (Relaxed) / Fun (Serious) / Expert" wording, pulled
-- from Blizzard's localized GROUP_FINDER_GENERAL_PLAYSTYLE1..4 globals.
WhatGroup.Labels.PLAYSTYLE = {
    [Enum.LFGEntryGeneralPlaystyle.Learning]   = GROUP_FINDER_GENERAL_PLAYSTYLE1,
    [Enum.LFGEntryGeneralPlaystyle.FunRelaxed] = GROUP_FINDER_GENERAL_PLAYSTYLE2,
    [Enum.LFGEntryGeneralPlaystyle.FunSerious] = GROUP_FINDER_GENERAL_PLAYSTYLE3,
    [Enum.LFGEntryGeneralPlaystyle.Expert]     = GROUP_FINDER_GENERAL_PLAYSTYLE4,
}

function WhatGroup.Labels.GetGroupTypeLabel(info)
    if info.isMythicPlus then
        return NS.L["Mythic+"]
    elseif info.isCurrentRaid then
        return NS.L["Raid (Current)"]
    elseif info.isHeroicRaid then
        return NS.L["Heroic Raid"]
    elseif info.categoryID == 2 then
        return NS.L["PvP"]
    elseif info.categoryID == 1 then
        return NS.L["Dungeon"]
    elseif info.maxNumPlayers and info.maxNumPlayers >= 10 then
        return NS.L["Raid"]
    elseif info.maxNumPlayers and info.maxNumPlayers > 0 then
        return NS.L["Dungeon"]
    else
        return NS.L["Group"]
    end
end

function WhatGroup.Labels.GetPlaystyleLabel(info)
    if info.playstyleString and info.playstyleString ~= "" then
        return info.playstyleString
    end
    return WhatGroup.Labels.PLAYSTYLE[info.generalPlaystyle] or ""
end

-- The role the player signed up as (WhatGroup#1), as Blizzard's localized role name with the tiny
-- role icon in front. Most authoritative first: the role the leader assigned (read now, so a
-- leader's change after the join shows), then the role the application carried at the invite,
-- then the roles offered at apply time joined with " / ". "" when none of the three is known.
local ROLE_NAMES = { TANK = TANK, HEALER = HEALER, DAMAGER = DAMAGER }
local OFFERED = { { "tank", "TANK" }, { "healer", "HEALER" }, { "damage", "DAMAGER" } }

local function roleText(token)
    return NS.Compat.RoleIconMarkup(token) .. (ROLE_NAMES[token] or token)
end

local function offeredText(applied)
    if type(applied) ~= "table" then return "" end
    local parts = {}
    for _, pair in ipairs(OFFERED) do
        if applied[pair[1]] == true then parts[#parts + 1] = roleText(pair[2]) end
    end
    return table.concat(parts, " / ")
end

function WhatGroup.Labels.GetRoleLabel(info)
    local token = NS.Compat.AssignedRole() or NS.Compat.RoleToken(info.role)
    if token then return roleText(token) end
    return offeredText(info.appliedRoles)
end
