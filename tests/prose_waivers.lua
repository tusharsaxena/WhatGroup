-- tests/prose_waivers.lua -- the per-file, per-word waivers the kit's prose gate reads
-- (tests/_kit/test_prose.lua, localization-5).
--
-- A waiver is localization-5's MAY for a British spelling that is not this repository's English to
-- correct, under its three MUSTs: per file AND per word, never per file alone; the reason written
-- beside it; and it waives, it never extends -- nothing here adds to BRITISH or removes from
-- ALLOWED, which stay the section's alone. The kit skips this file by name, so a reason may name the
-- word it is about.
--
-- These four entries are the ones the hand-written tests/test_prose.lua carried until the kit's gate
-- replaced it, moved here unchanged in scope. A spelling that IS this repository's prose is fixed,
-- not waived: the one such line the kit's gate found (core/WhatGroup.lua, the stand-down comment
-- about the notify timer) was respelled rather than added here, and the waiver below does not
-- cover it, because it covers the one word in that file that is Blizzard's.

return {
    waived = {
        -- Blizzard's token. LFG_LIST_APPLICATION_STATUS_UPDATED delivers the application status as
        -- a string and the client spells it with two Ls; the APPLICATION_ENDED table matches it
        -- verbatim. Respelling it is a lookup that never matches and a capture that never clears
        -- (WG-R-07 is what that bug looked like the first time).
        ["core/WhatGroup.lua"]     = { cancelled = true },
        -- The same token, fired at the handler with the value the client sends.
        ["tests/test_capture.lua"] = { cancelled = true },
        -- The same token, documented as one of the statuses the handler clears on.
        ["docs/data-flow.md"]      = { cancelled = true },
        -- AceTimer's field name, carried on the mock's timer handle and read off it by
        -- tests/_kit/mock_record.lua's live-timer survey. Respelling it would stop the survey
        -- seeing a canceled timer as canceled, and the assertion that the superseded notify timer
        -- is dead would go unfalsifiable.
        ["tests/test_notify.lua"]  = { cancelled = true },
    },
}
