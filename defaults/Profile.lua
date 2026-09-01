-- defaults/Profile.lua
-- Profile default VALUES (savedvariables-§2): the single place any profile
-- default is hardcoded. Each schema row in settings/Schema.lua references its
-- value here via `default = NS.C.<path>`, so the schema stays the single source
-- of STRUCTURE (widgets, /wg list|get|set, reset) while the values live here —
-- reconciling savedvariables-§2 (values in defaults/Profile.lua) with
-- architecture-§5 (schema-driven settings). Settings.BuildDefaults deep-copies
-- these into the AceDB `profile` table.
--
-- Loaded before settings/Schema.lua (see the .toc Defaults section). Adding a
-- setting is still one schema row — with its default value declared here.

local addonName, NS = ...

NS.C = {
    -- General
    enabled = true,                 -- master switch
    frame = {
        autoShow = true,            -- open the popup automatically on join
        -- The popup's own size, promoted out of modules/Frame.lua's FRAME_WIDTH /
        -- FRAME_HEIGHT file-locals. THE NUMBERS ARE THE ONES THEY REPLACED, exactly:
        -- a profile that touches neither slider draws the 420x260 popup that shipped.
        -- modules/Frame.lua clamps both on read, because a value hand-edited into
        -- SavedVariables reaches SetSize with nothing else between it and the frame.
        width    = 420,             -- popup width  in pixels (clamped 320..700)
        height   = 260,             -- popup height in pixels (clamped 200..520)
    },
    notify = {
        enabled      = true,        -- print the chat summary on join
        delay        = 0,           -- seconds to wait before notify + popup
        showInstance = true,
        showType     = true,
        showLeader   = true,
        showPlaystyle = true,
        showClickLink = true,
        showTeleport = true,
    },
}
