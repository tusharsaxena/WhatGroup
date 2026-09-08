-- tests/test_doc_structure.lua — the shapes documentation-§1 and §3 fix in place for the README
-- and the architecture hub.
--
-- WHAT IT PROVES, in five cases:
--   1. docs/ARCHITECTURE.md carries the TEN sections `documentation-§3` names for the hub.
--   2. Every mandated section that has a canonical topic doc stays inside the spill threshold.
--   3. Every markdown link pointing INTO one of the hub's headings lands on a heading that exists.
--   4. README.md carries the two player-facing history surfaces `documentation-§1` allows, and the
--      tracked markdown carries no third.
--   5. README.md's top-level sections are the ones §1 names, in the order it names them.
--
-- WHY IT EXISTS. `documentation-§3` states the hub rule as two thresholds "because 'keep it short'
-- demonstrably did not hold": a mandated section past roughly 60 lines MUST spill into its canonical
-- topic doc leaving a summary and a link, and the whole file SHOULD stay under roughly 400. The
-- failure it describes is a 1071-line hub in which "a reader looking for the settings schema has no
-- landmark, and an agent editing it rewrites sections it never needed to open". Nothing measured it,
-- so nothing stopped it, and a hub does not grow past a screen in one commit — it grows a paragraph
-- at a time, each one defensible.
--
-- WHY THE THRESHOLD CASE EXEMPTS TWO SECTIONS. `## Documentation map` and `## Documented deviations`
-- are REGISTERS: §3 makes the hub their single home, so their storage IS the hub and they have no
-- canonical topic doc to spill into. Holding them to the spill threshold would be asking them to
-- move somewhere the same section forbids. Every other mandated section has a named home —
-- Overview → scope.md, Module Map → module-map.md, Settings Schema → schema.md, Message Bus →
-- message-bus.md, Slash Commands → slash-dispatch.md, Taint Notes → midnight-quirks.md, Known
-- Limitations → scope.md, Event Subscriptions → module-map.md — and is held.
--
-- WHAT IT DOES NOT DO, DELIBERATELY. It does not assert the 400-line whole-file SHOULD: the two
-- registers are legitimately large here and the section says an audit "reports the shape, not the
-- arithmetic". It does not check heading ORDER inside ARCHITECTURE.md, does not check that
-- `## What's new` names the TOC's version (that is `wow-addon:bump-version`'s, and pinning it here
-- would redden the tree between that command's own two edits), and does not count links per section
-- — "exactly one link" is the spill's shape, but a compliant section may also cite a second doc, as
-- §3's own Module Map example does.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. No `io.popen`, no git, no ARCHITECTURE.md and no
-- README.md are each a failure, not a skip — the same bargain tests/_kit/test_eol.lua strikes.

local T = _G.WHATGROUP_TEST
local test, fail, assertTrue = T.test, T.fail, T.assertTrue
local ROOT = T.root or "."

local ARCHITECTURE = "docs/ARCHITECTURE.md"
local README       = "README.md"

-- `documentation-§3`'s ten mandated hub sections, named rather than counted because a bare count
-- goes stale silently. Matched case-insensitively: the collection is split between `## Module map`
-- and `## Module Map`, and the section names a section, not a capitalization.
local MANDATED = {
    "Overview", "Module Map", "Settings Schema", "Message Bus", "Slash Commands",
    "Event Subscriptions", "Taint Notes", "Known Limitations",
    "Documentation map", "Documented deviations",
}

-- The two of those ten whose storage IS the hub, and which therefore have nowhere to spill to.
local REGISTERS = { ["documentation map"] = true, ["documented deviations"] = true }

-- §3's spill threshold, stated there as "roughly 60 lines". Held as a hard number here because a
-- gate cannot assert "roughly"; the slack is that the rule's own failure case is 189 lines, not 61.
local SPILL_LINES = 60

-- The history surfaces `documentation-§1` does NOT allow, as case-insensitive headings. A fourth
-- spelling someone invents is caught by none of these, which is why the two ALLOWED forms are
-- asserted positively below rather than this list being the whole gate.
local FORBIDDEN_HISTORY = {
    "unreleased", "changelog", "change log", "release notes", "upcoming",
    "next release", "recent changes", "in development",
}

-- `documentation-§1`'s README section list, in its order. Item 4 (Description) and the badge row are
-- not headings, so the sequence starts at item 5. `## How <it> works` is domain-titled by the
-- section's own instruction, which is why it is a pattern and not a name. `required = false` marks
-- the SHOULD and MAY sections — omit one only when it would be empty, but when present the relative
-- order MUST hold.
local README_ORDER = {
    { pattern = "^What's new in ",              required = true,  name = "## What's new in <X.Y.Z>" },
    { pattern = "^Screenshots$",                required = false, name = "## Screenshots" },
    { pattern = "^Usage$",                      required = true,  name = "## Usage" },
    { pattern = "^How .+ works?$",              required = true,  name = "## How <it> works" },
    { pattern = "^FAQ$",                        required = false, name = "## FAQ" },
    { pattern = "^Troubleshooting$",            required = false, name = "## Troubleshooting" },
    { pattern = "^Issues and feature requests$",required = true,  name = "## Issues and feature requests" },
    { pattern = "^Version History$",            required = true,  name = "## Version History" },
    { pattern = "^Credits$",                    required = false, name = "## Credits" },
}

--- A file's contents with line endings normalized, or a failure.
local function read(rel)
    local fh = io.open(ROOT .. "/" .. rel, "r")
    if not fh then fail("doc gate: " .. rel .. " could not be opened", 2) end
    local body = fh:read("*a") or ""
    fh:close()
    return (body:gsub("\r\n", "\n"))
end

--- A file's lines, in order.
local function lines(rel)
    local out = {}
    for line in (read(rel) .. "\n"):gmatch("([^\n]*)\n") do out[#out + 1] = line end
    return out
end

--- Every heading in a file, as { level, text }, in document order.
local function headings(rel)
    local out = {}
    for _, line in ipairs(lines(rel)) do
        local hashes, text = line:match("^(#+)%s+(.-)%s*$")
        if hashes then out[#out + 1] = { level = #hashes, text = text } end
    end
    return out
end

--- `## <Name>` as a case-insensitive whole-line pattern.
local function heading(name)
    return "^##%s+" .. name:gsub("%a", function(c)
        return "[" .. c:upper() .. c:lower() .. "]"
    end):gsub(" ", "%%s+") .. "%s*$"
end

--- GitHub's heading-fragment slug: lowercased, formatting and punctuation dropped, spaces hyphened.
local function slug(text)
    local s = text:lower():gsub("`", "")
    s = s:gsub("[^%w%s%-]", "")
    s = s:gsub("%s+", "-")
    return s
end

--- Every markdown path git tracks, minus the vendored and frozen trees.
---
--- `git ls-files` rather than a directory walk: Lua 5.1 has no directory API, and the tracked set is
--- the right set anyway. `libs/` and `tests/_kit/` are vendored whole and byte-pinned by
--- tests/test_vendor_sync.lua; the dated bundles under `docs/audits/`, `docs/reviews/`,
--- `docs/automated-tests/`, `docs/revendor/`, `docs/perf-analysis/` and `docs/superpowers/` are
--- frozen records of the tree as it stood on their stamp, so a heading this repository no longer
--- carries is history inside one of them rather than a defect.
local function trackedMarkdown()
    if not io.popen then
        fail("doc gate: io.popen is unavailable, so this gate cannot run and must not be reported "
            .. "as passing", 2)
    end
    local p = io.popen("git ls-files '*.md' 2>/dev/null")
    if not p then
        fail("doc gate: io.popen returned no handle, so this gate cannot run and must not be "
            .. "reported as passing", 2)
    end
    local out = {}
    for path in p:lines() do
        local frozen = path:match("^libs/") or path:match("^tests/_kit/")
            or path:match("^docs/audits/") or path:match("^docs/reviews/")
            or path:match("^docs/automated%-tests/") or path:match("^docs/revendor/")
            or path:match("^docs/perf%-analysis/") or path:match("^docs/superpowers/")
        if not frozen then out[#out + 1] = path end
    end
    p:close()
    if #out == 0 then
        fail("doc gate: git tracks no markdown outside the vendored and frozen trees, which cannot "
            .. "be true here — treating a blind gate as a failure", 2)
    end
    return out
end

test("docs/ARCHITECTURE.md carries the ten sections documentation-§3 names", function()
    local body, missing = read(ARCHITECTURE), {}
    for _, name in ipairs(MANDATED) do
        local pattern, found = heading(name), false
        for line in (body .. "\n"):gmatch("([^\n]*)\n") do
            if line:match(pattern) then found = true break end
        end
        if not found then missing[#missing + 1] = "## " .. name end
    end
    assertTrue(#missing == 0, ARCHITECTURE .. " is missing " .. table.concat(missing, ", ")
        .. " — §3 names all ten rather than counting them, because a count goes stale in silence")
end)

test("every mandated hub section that has a topic doc has spilled into it", function()
    local all, over = lines(ARCHITECTURE), {}
    local current, start
    local function close(at)
        if current and not REGISTERS[current:lower()] then
            local span = at - start
            if span > SPILL_LINES then
                over[#over + 1] = string.format("## %s (%d lines)", current, span)
            end
        end
    end
    for i, line in ipairs(all) do
        local text = line:match("^##%s+(.-)%s*$")
        if text and not line:match("^###") then
            close(i)
            current, start = nil, nil
            for _, name in ipairs(MANDATED) do
                if line:match(heading(name)) then current, start = text, i break end
            end
        end
    end
    close(#all + 1)
    assertTrue(#over == 0, "hub sections past the " .. SPILL_LINES .. "-line spill threshold: "
        .. table.concat(over, ", ") .. ". §3: a mandated section that exceeds roughly 60 lines MUST "
        .. "spill into its canonical topic doc, leaving a summary and a link. The two registers "
        .. "(Documentation map, Documented deviations) are exempt — the hub is their single home")
end)

test("every anchor pointing into docs/ARCHITECTURE.md resolves to a heading", function()
    local slugs = {}
    for _, h in ipairs(headings(ARCHITECTURE)) do slugs[slug(h.text)] = true end
    local dead = {}
    for _, path in ipairs(trackedMarkdown()) do
        local body = read(path)
        for frag in body:gmatch("%]%([^%)%s]-ARCHITECTURE%.md#([^%)%s]+)%)") do
            if not slugs[frag] then dead[#dead + 1] = path .. " -> #" .. frag end
        end
        if path == ARCHITECTURE then
            for frag in body:gmatch("%]%(#([^%)%s]+)%)") do
                if not slugs[frag] then dead[#dead + 1] = path .. " -> #" .. frag end
            end
        end
    end
    assertTrue(#dead == 0, "anchors into " .. ARCHITECTURE .. " that land on no heading: "
        .. table.concat(dead, ", "))
end)

test("the player-facing history has the two homes documentation-§1 allows, and no third", function()
    local whatsNew, versionHistory = 0, 0
    for _, h in ipairs(headings(README)) do
        if h.level == 2 then
            if h.text:match("^What's new in ") then whatsNew = whatsNew + 1 end
            if h.text:lower() == "version history" then versionHistory = versionHistory + 1 end
        end
    end
    assertTrue(whatsNew == 1, README .. " must carry exactly one `## What's new in <X.Y.Z>`; found "
        .. whatsNew)
    assertTrue(versionHistory == 1, README .. " must carry exactly one `## Version History`; found "
        .. versionHistory)

    -- And nowhere in the tracked markdown — §3's "docs/ is not where a forbidden root doc goes to
    -- live" is the same rule one directory down.
    local extra = {}
    for _, path in ipairs(trackedMarkdown()) do
        for _, h in ipairs(headings(path)) do
            local text = h.text:lower():gsub("[^%a%s]", ""):gsub("^%s+", ""):gsub("%s+$", "")
            for _, word in ipairs(FORBIDDEN_HISTORY) do
                if text == word then extra[#extra + 1] = path .. " -> ## " .. h.text end
            end
        end
        if path:match("CHANGELOG%.md$") then extra[#extra + 1] = path end
    end
    assertTrue(#extra == 0, "a third player-facing history surface, which documentation-§1 gives "
        .. "exactly two homes: " .. table.concat(extra, ", "))
end)

test("README.md's top-level sections are the ones documentation-§1 names, in its order", function()
    local cursor, out, seen = 1, {}, {}
    for _, h in ipairs(headings(README)) do
        if h.level == 2 then
            local at
            for i = cursor, #README_ORDER do
                if h.text:match(README_ORDER[i].pattern) then at = i break end
            end
            if at then
                cursor, seen[at] = at, true
            else
                out[#out + 1] = "## " .. h.text
            end
        end
    end
    assertTrue(#out == 0, README .. " carries a top-level section §1 does not name, or names in a "
        .. "different position: " .. table.concat(out, ", ") .. ". Detail that wants a home of its "
        .. "own folds into the listed section it belongs to, or moves under docs/")

    local absent = {}
    for i, entry in ipairs(README_ORDER) do
        if entry.required and not seen[i] then absent[#absent + 1] = entry.name end
    end
    assertTrue(#absent == 0, README .. " is missing " .. table.concat(absent, ", "))
end)

test("the README's settings table is page-granular, not per-tab", function()
    local rows = {}
    for _, line in ipairs(lines(README)) do
        local first = line:match("^|%s*%*?%*?([%w ]-)%*?%*?%s*|")
        if first and first:lower():gsub("%s+", "") == "tab" then rows[#rows + 1] = line end
    end
    assertTrue(#rows == 0, README .. " carries a `| Tab |` table: " .. table.concat(rows, " / ")
        .. ". documentation-§1 keeps the README's `### Settings panel` table at PAGE granularity — "
        .. "one row per settings subcategory, and this addon has one — and puts the per-tab "
        .. "breakdown in docs/settings-panel.md, which is where options-ui-§13's strip makes it "
        .. "derivable")
end)

test("every settings tab the README sends a player to exists in the schema", function()
    -- The tab names the schema actually declares, read out of the source rather than restated
    -- here. `Master controls` is added because its rows are composed by
    -- `LibKa0s-Options-1.0`'s `MasterControls` and carry no `group =` line in this repo at all —
    -- options-ui-§15 mandates the name, and settings/Panel.lua hooks it by the library's constant.
    local groups = { ["Master controls"] = true }
    for name in read("settings/Schema.lua"):gmatch("group%s*=%s*\"([^\"]+)\"") do
        groups[name] = true
    end

    -- "under <Tab>" is how this README points a player at one, in both its bold and its plain
    -- form. It is the phrasing that went wrong: the 1.3.0 Version History row said "add a delay
    -- under Notify" while the same feature's `## What's new` bullet said Chat, and `notify.delay`
    -- is filed under group Chat. `notify` is the row's SECTION — where the value is stored and
    -- how `/wg list` groups it — not the tab it is edited on, and a player reading the README has
    -- no way to know the difference.
    local body, wrong = read(README), {}
    local ARROW = "→"   -- the breadcrumb separator this README uses, as its own bytes
    for phrase in body:gmatch("under%s+%*%*([^%*]+)%*%*") do
        -- A bold run may be a breadcrumb: `**Chat → Notification Delay**` names the tab and then
        -- the row on it. Only the first segment is a tab name.
        local at = phrase:find(ARROW, 1, true)
        local name = at and phrase:sub(1, at - 1) or phrase
        name = name:match("^%s*(.-)%s*$")
        if not groups[name] then wrong[#wrong + 1] = name end
    end
    for name in body:gmatch("under%s+(%u%a+)") do
        if not groups[name] then wrong[#wrong + 1] = name end
    end
    assertTrue(#wrong == 0, README .. " sends a player to a settings tab that does not exist: "
        .. table.concat(wrong, ", ") .. ". Declared tabs are the `group` values in "
        .. "settings/Schema.lua plus the composed `Master controls`")
end)

-- ── The smoke suite's non-English-client section ───────────────────────────────

-- WHAT IT PROVES, AND WHAT IT DOES NOT. That docs/smoke-tests.md still carries a section addressed
-- to a non-English client, that the section names the locale to run it on, and that it says what a
-- failure looks like rather than only what a pass does. It proves nothing whatever about that
-- section having been RUN -- a checklist is a checklist, and this repository has no client.
--
-- WHY THIS REPOSITORY IN PARTICULAR. Everything this addon puts on screen about a group comes out
-- of the client in the player\'s language: the activity name, the short name, the playstyle string,
-- and the spell name that goes into the teleport button\'s `/cast` macrotext. tests/wow_mock.lua
-- answers enUS for all of it, and core/WhatGroup.lua\'s own test fixture spells the activity name
-- out in English, so nothing here has ever seen a German one. The section is also where session 6
-- schedules § 7a, the observation WHATGROUP-R-06 is gated on.
--
-- The failure vocabulary is matched loosely on purpose: this file says "Fail" in some sections and
-- "Expected" in others, and pinning one spelling would redden the tree for a rewording.
local LOCALE_HEADING = "[Nn]on%-English client"
local FAILURE_WORDS = { "Fail", "failure", "Failure", "the finding" }

test("docs/smoke-tests.md carries a non-English-client section", function()
    local body = read("docs/smoke-tests.md")

    local capture, level, section = false, nil, {}
    for line in (body .. "\n"):gmatch("([^\n]*)\n") do
        local hashes = line:match("^(#+)%s")
        if hashes and capture and #hashes <= level then break end
        if hashes and not capture and line:match(LOCALE_HEADING) then
            capture, level = true, #hashes
        end
        if capture then section[#section + 1] = line end
    end
    assertTrue(capture, "docs/smoke-tests.md has no heading naming a non-English client. The step "
        .. "is unconditional (M5-08): where an addon reads nothing localized the section still "
        .. "ships and says what it checked and why it came back empty")

    local text = table.concat(section, "\n")
    assertTrue(text:find("deDE", 1, true) or text:find("frFR", 1, true),
        "the non-English-client section names no client to run it on -- deDE and frFR are the two "
        .. "the collection\'s other locale steps use")

    local named = false
    for _, word in ipairs(FAILURE_WORDS) do
        if text:find(word, 1, true) then named = true break end
    end
    assertTrue(named, "the non-English-client section says what passing looks like and never what "
        .. "failing looks like. A step whose only outcome is \'it works\' is unfalsifiable in a "
        .. "client the operator booted specially")

    assertTrue(#section >= 10, "the non-English-client section is " .. #section .. " lines -- a "
        .. "heading with a sentence under it records the gap as coverage, which is the failure "
        .. "M5-08 was filed for")

    -- Session 6 owns § 7a as well as this section: one login, both jobs. The finding it is gated
    -- on has waited through five milestones for want of someone being in a client at the time, so
    -- the pointer is part of the section rather than a nicety.
    assertTrue(text:find("C_SpellBook.IsSpellKnown", 1, true),
        "session 6 owns § 7a -- the C_SpellBook.IsSpellKnown observation WHATGROUP-R-06 is gated "
        .. "on -- and the locale section is what schedules it. Naming it here is what stops the "
        .. "one login this repository needs from being spent without it")
end)
