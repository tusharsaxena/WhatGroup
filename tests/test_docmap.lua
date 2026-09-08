-- tests/test_docmap.lua — the Tier 2 documentation map says what docs/ actually holds
-- (documentation-§3).
--
-- WHAT IT PROVES. That every row in docs/ARCHITECTURE.md's `### Conditional (documentation-§3,
-- Tier 2)` table agrees with the directory: a doc filed **Present** exists, and a doc filed
-- **Not applicable** does not.
--
-- WHY IT EXISTS. `documentation-§3` makes *Not applicable* a valid state that MUST be stated rather
-- than inferred from an empty directory, and that is the right rule — `ls docs/` alone cannot tell
-- "this addon does not need the page" from "nobody has written it yet". The cost is that the row
-- becomes the only witness, and a wrong row is then worse than a missing page. This repo carried
-- one: `compat-layer.md` read "no addon-specific shim to document separately" against the seven
-- shims in core/Compat.lua, and it read that through every audit, because the register was the
-- thing being read.
--
-- WHAT IT DELIBERATELY DOES NOT DO: judge whether a trigger has fired. That is prose and
-- measurement — "beyond what LibKa0s supplies", "of the addon's own" — and it stays a human's to
-- make and the table's to record. The STATUS is not prose. It is the half a machine can hold.
--
-- IT FAILS RATHER THAN PASSES WHEN IT CANNOT LOOK. An unreadable ARCHITECTURE.md, a missing
-- Conditional heading, or a table that parses to nothing is red and not a skip — a gate that goes
-- quiet when it is blind reports success, which is worse than not existing. Same bargain
-- tests/_kit/test_eol.lua strikes.

local T = _G.WHATGROUP_TEST
local test, fail, assertEqual = T.test, T.fail, T.assertEqual
local ROOT = T.root or "."

local function readArchitecture()
    local fh = io.open(ROOT .. "/docs/ARCHITECTURE.md", "r")
    if not fh then
        fail("doc-map gate: docs/ARCHITECTURE.md could not be opened, so this gate cannot run and "
            .. "must not be reported as passing", 2)
    end
    local body = fh:read("*a") or ""
    fh:close()
    return (body:gsub("\r\n", "\n"))
end

local function docExists(name)
    local fh = io.open(ROOT .. "/docs/" .. name, "r")
    if fh then fh:close() return true end
    return false
end

test("docmap: every Tier 2 row agrees with what docs/ holds", function()
    local body = readArchitecture()
    -- Reading stops at the next heading of any level, so the Verification table below cannot leak in.
    local section = body:match("### Conditional[^\n]*\n(.-)\n##")
    if not section then
        fail("doc-map gate: docs/ARCHITECTURE.md has no `### Conditional ...` section followed by "
            .. "another heading, so the Tier 2 rows cannot be read", 2)
    end

    local rows, offenders = 0, {}
    for doc, status in section:gmatch("|%s*`([^`]+)`%s*|%s*([^|]-)%s*|") do
        if status == "Present" or status == "Not applicable" then
            rows = rows + 1
            local present = docExists(doc)
            if status == "Present" and not present then
                offenders[#offenders + 1] = doc .. ": filed Present, docs/" .. doc .. " is absent"
            elseif status == "Not applicable" and present then
                offenders[#offenders + 1] = doc .. ": filed Not applicable, docs/" .. doc .. " exists"
            end
        end
    end

    if rows < 5 then
        fail("doc-map gate: read " .. rows .. " Tier 2 rows with a status this gate understands; "
            .. "the table carried seven when this was written, so either its shape changed or a "
            .. "status cell now says something other than Present / Not applicable", 2)
    end

    assertEqual(#offenders, 0, "Tier 2 row(s) disagree with the directory. The row is the only "
        .. "thing an audit reads, so a wrong one is worse than a missing page: "
        .. table.concat(offenders, "; "))
end)
