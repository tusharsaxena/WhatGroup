-- tests/test_register.lua — the deviation register's citations are checkable, so they are checked.
--
-- `documentation-§3` gives a ratified deviation exactly one home, `docs/ARCHITECTURE.md`'s
-- `## Documented deviations`, and `audit-review-history` says what a row owes: a rule citation that
-- resolves against the current standard, a re-check trigger a reader can evaluate, and an evidence
-- id that resolves. The first is a human's to read and the second is prose. The third is not, and
-- this suite is the third.

local T = _G.WHATGROUP_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function readFile(path)
  local f = io.open(path, "r")
  assertTrue(f ~= nil, "cannot open " .. path .. " (tests run from the repo root)")
  local body = f:read("*a")
  f:close()
  return body
end

--- Shell glob -> list of paths. `ls` is enough: the suite already runs from a POSIX shell.
local function glob(pattern)
  local out, p = {}, io.popen("ls -1 " .. pattern .. " 2>/dev/null")
  if not p then return out end
  for line in p:lines() do
    if line ~= "" then out[#out + 1] = line end
  end
  p:close()
  return out
end

-- ── The deviation register's own citations resolve ─────────────────────────────

-- `audit-review-history`'s third MUST: an id a register row cites in **Why** has to resolve -- a
-- deviation id into `docs/audits/`, a finding id into `docs/reviews/`, an issue number onto this
-- repo. An id that resolves to nothing is worse than no citation at all, because it reads as
-- evidence and leads to none, and it survives every re-read by a maintainer who knows the shape of
-- an id and never goes looking for what it names.
--
-- The check is deliberately NOT "the string appears somewhere under `docs/audits/`". A bundle that
-- REPORTS a dead citation quotes the dead id while doing so, so a substring search goes green on
-- the very defect it was written for -- `testing-§12`'s failure mode, sitting inside the gate for
-- it. What counts is the id being ASSIGNED: standing at the head of a heading or of a table row's
-- FIRST cell, which is where every bundle in this repo puts a row's own id. A bullet, or a later
-- cell, is where a bundle QUOTES an id while reporting it -- 2026-09-08's fix table and bullets
-- both quote the dead `WG-A-08` that way -- so neither counts.
--
-- Two id families are cited, and both are checked. A **deviation** id (`WG-NN`, `WG-A-NN`) is
-- this repo's own audit-bundle prefix and resolves in `docs/audits/`. A **review** finding id
-- (`F-NNN`, `WHATGROUP-R-NN`, or the `WG-R-NN` shorthand for the latter) resolves in a review
-- bundle's `01_FINDINGS.md` -- but review ids restart at `F-001` in every bundle, so a bare one
-- names a different finding in each and "resolves" to whichever a reader happens to open. That is
-- how a row once cited `WG-R-06` for the English-only decision while the id it expands to is the
-- `Compat.IsSpellKnown` finding. So a review id MUST name its dated bundle
-- directly after it (`F-006 (docs/reviews/2026-08-05/)`) and is resolved in THAT bundle only; a
-- deviation id that names one (`WG-37 (docs/audits/2026-08-05/)`) is resolved in that bundle only,
-- too. Only the table rows are read: the preamble explains the shapes with example ids.
--
-- An audit bundle's `## Recorded deviations` section is an ECHO of this register: it quotes the
-- register's own Why-cell ids back as its table cells. Counting it as an assignment makes the gate
-- circular -- a dead id cited here is echoed there by the next audit and then "resolves" against
-- its own echo -- so everything under such a heading is out of the corpus.

local DEVIATION_ID = { "%f[%w]WG%-[%u%-]*%d+", "%f[%w]WHATGROUP%-[%u%-]*%d+" }
local REVIEW_ID = { "%f[%w]F%-%d%d%d", "%f[%w]WG%-R%-%d+", "%f[%w]WHATGROUP%-R%-%d+" }

--- A heading whose body echoes another bundle's register rather than assigning ids.
local ECHO_HEADING = "^Recorded deviations"

--- Does `id` head `s` (after leading markup), and end there?
local function heads(s, id)
  s = s:gsub("^[%s%*`%[]+", "")
  return s:sub(1, #id) == id and not s:sub(#id + 1, #id + 1):match("[%w%-]")
end

--- Does `id` head the FIRST cell of table row `line` -- the cell a bundle puts a row's own id in?
local function headsCell(line, id)
  local first = line:match("^|([^|]*)|")
  return first ~= nil and heads(first, id)
end

--- Does `id` head a heading or a table row's first cell in `path`, outside an echo section?
local function assignedIn(id, path)
  local echoDepth
  for line in (readFile(path) .. "\n"):gmatch("([^\n]*)\n") do
    local trimmed = line:gsub("^%s+", ""):gsub("\r$", "")
    local hashes, title = trimmed:match("^(#+)%s*(.*)$")
    if hashes and echoDepth and #hashes <= echoDepth then echoDepth = nil end
    if hashes and not echoDepth and title:find(ECHO_HEADING) then echoDepth = #hashes end
    if not echoDepth then
      if title and heads(title, id) then return true end
      if trimmed:sub(1, 1) == "|" and headsCell(trimmed, id) then return true end
    end
  end
  return false
end

local function isAssigned(id, files)
  for _, path in ipairs(files) do
    if assignedIn(id, path) then return true end
  end
  return false
end

--- The register's cells: its table rows split on unescaped pipes. The preamble is prose that
--- explains the id shapes with examples, so it is not a citation and is not read.
local function cellsOf(section)
  local cells = {}
  for line in (section .. "\n"):gmatch("([^\n]*)\n") do
    if line:match("^%s*|") then
      for field in (line:gsub("\\|", "\1") .. "|"):gmatch("([^|]*)|") do cells[#cells + 1] = field end
    end
  end
  return cells
end

--- Every id matching `patterns` in `cell` that is not the tail of a longer id, each with the text
--- that follows it (where its dated bundle, if it names one, stands).
local function idsIn(cell, patterns)
  local out = {}
  for _, pattern in ipairs(patterns) do
    for pos, id in cell:gmatch("()(" .. pattern .. ")") do
      if cell:sub(pos - 1, pos - 1) ~= "-" then
        out[#out + 1] = { id = id, after = cell:sub(pos + #id) }
      end
    end
  end
  return out
end

--- The dated bundle named directly after an id -- `ID (docs/<kind>/<date>/)`, backticks allowed.
local function bundleAfter(after, kind)
  return after:match("^[`%s%(]*docs/" .. kind .. "/(%d%d%d%d%-%d%d%-%d%d)/")
end

--- Resolve one review id; returns nil, or why it does not resolve.
local function reviewFailure(id, after)
  local bundle = bundleAfter(after, "reviews")
  if not bundle then return id .. " (no dated docs/reviews/<date>/ bundle named beside it)" end
  local full = id:gsub("^WG%-R%-", "WHATGROUP-R-")
  if not isAssigned(full, glob("docs/reviews/" .. bundle .. "/01_FINDINGS.md")) then
    return id .. " (not a finding in docs/reviews/" .. bundle .. "/01_FINDINGS.md)"
  end
end

--- Resolve one deviation id; returns nil, or why it does not resolve.
local function deviationFailure(id, after)
  local bundle = bundleAfter(after, "audits")
  local files = glob("docs/audits/" .. (bundle or "*") .. "/*.md")
  if not isAssigned(id, files) then
    return id .. " (assigned by no bundle under docs/audits/" .. (bundle and bundle .. "/" or "") .. ")"
  end
end

--- Check every id of one family across the cells; returns how many were cited.
local function checkFamily(cells, patterns, failure, offenders, skip)
  local cited = 0
  for _, cell in ipairs(cells) do
    for _, hit in ipairs(idsIn(cell, patterns)) do
      if not (skip and skip(hit.id)) then
        cited = cited + 1
        offenders[#offenders + 1] = failure(hit.id, hit.after)
      end
    end
  end
  return cited
end

-- red under: restoring WG-A-08 in the events-frames-taint-§8 row's Why cell (it is assigned only by
-- the 2026-09-07 bundle's `## Recorded deviations` echo), or restoring the bare `WG-R-06` in the
-- localization-§1 row.
test("every evidence id the register cites is assigned by its bundle in docs/audits/ or docs/reviews/", function()
  -- The sentinel is what lets the register be the file's LAST `##` section without the slice
  -- silently coming back nil and the case passing on an empty string.
  local body = readFile("docs/ARCHITECTURE.md") .. "\n## \n"
  local section = body:match("\n## Documented deviations\r?\n(.-)\r?\n## ")
  assertTrue(section ~= nil,
    "docs/ARCHITECTURE.md has no `## Documented deviations` section to read")
  assertTrue(#glob("docs/audits/*/*.md") > 0,
    "no bundle files under docs/audits/ -- nothing to resolve against")

  local cells, offenders = cellsOf(section), {}
  local isReview = function(id) return id:find("%-R%-") ~= nil end
  local deviations = checkFamily(cells, DEVIATION_ID, deviationFailure, offenders, isReview)
  local reviews = checkFamily(cells, REVIEW_ID, reviewFailure, offenders)

  assertTrue(deviations > 0,
    "the register cites no deviation id at all -- either the rows changed or DEVIATION_ID did")
  assertTrue(reviews > 0,
    "the register cites no review finding id at all -- either the rows changed or REVIEW_ID did")
  assertEqual(#offenders, 0,
    "cited by a register row and not resolved: " .. table.concat(offenders, "; "))
end)
