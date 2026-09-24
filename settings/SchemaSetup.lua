-- settings/SchemaSetup.lua — resolves LibKa0s-Schema-1.0, or the host's degradation stub.
--
-- The settings schema's RUNTIME -- the path walk, the row index, the single write seam, the bulk
-- bracket, the profile reset's count and the shape check -- is LibKa0s-Schema-1.0's (WhatGroup#22).
-- settings/Schema.lua declares the rows and builds ONE instance over them with `:New`, at file
-- scope; this file only decides which library that `:New` is called on, and publishes it as
-- `WhatGroup.Settings.SchemaLib`. The instance is `NS.SchemaRuntime`.
--
-- TOC slot: directly above settings/Schema.lua, which reads Settings.SchemaLib at FILE SCOPE.
-- Load-bearing.
--
-- ── The degradation stub ──────────────────────────────────────────────────────────────────────
--
-- A DELIBERATE, DOCUMENTED DUPLICATION, named by LibKa0s docs/api/Schema/version-2-docs.md,
-- "The degradation stub". It is the library's `referenceStub` (LibKa0s tests/test_schema.lua at
-- v1.56.0), trimmed of what WhatGroup never hands it. It is WRITE-COMPLETING and LOG-SILENT:
-- reads, writes, the row's onChange, the announce and the reset sweep's veto all work, because a
-- player reaches them through Reset all settings, which never needed Options or Slash
-- (options-ui-§1 keeps it real in the Options stub). The `[Set]` line, the bracket's tally and the reset count are not
-- reproduced: the degraded DebugLog stub discards the lines they feed.
--
-- NO `writeThrough`. The library's minor 2 lets a host name row-less paths its verbs still write
-- when the composer that would have declared their rows is absent (options-ui-§1's route (a)).
-- WhatGroup takes route (b) under the owner's ruling on WhatGroup#22: the degraded `/wg enable`,
-- `/wg disable` and `/wg test` print the library-absent line instead (settings/Slash.lua), and the
-- SHOULD deviation is recorded in docs/ARCHITECTURE.md. So this stub, like the live instance, is
-- handed no list, and every row-less path is refused here as it is there.
--
-- The instance members are DOT-CALLED closures, as the library's are: the Options and Slash
-- descriptors take them as values. tests/test_surface_parity.lua pins both levels -- the instance
-- against a live one, the stub library against the library's own member set.

local _, NS = ...
local WhatGroup = NS.addon

WhatGroup.Settings = WhatGroup.Settings or {}
local Settings = WhatGroup.Settings

local BRAND = "Ka0s WhatGroup"

local HostSchemaStub = {}

local function copy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = copy(x) end
    return out
end

function HostSchemaStub.SplitPath(path)
    local parts = {}
    if path ~= nil then
        for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
    end
    return parts
end

local function partsOf(p) return type(p) == "table" and p or HostSchemaStub.SplitPath(p) end

function HostSchemaStub.Read(root, p, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return nil end
    for i = first, #parts do
        if type(node) ~= "table" then return nil end
        node = node[parts[i]]
    end
    return node
end

function HostSchemaStub.Write(root, p, value, first)
    local parts, node = partsOf(p), root
    first = first or 1
    if type(root) ~= "table" or #parts < first then return end
    for i = first, #parts - 1 do
        if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

function HostSchemaStub.SameValue(a, b)
    if a == b then return true end
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    for k, v in pairs(a) do if not HostSchemaStub.SameValue(v, b[k]) then return false end end
    for k in pairs(b) do if a[k] == nil then return false end end
    return true
end

-- The instance's registry and read half. Real: rows by reference, a linear first-match FindRow.
local function addReads(S, d, rows)
    local function resolve(parts, id)
        if type(d.resolveRoot) ~= "function" then return nil end
        return d.resolveRoot(parts, id)
    end
    function S.AllRows() return rows end
    function S.FindRow(path)
        if type(path) ~= "string" then return nil end
        for _, row in ipairs(rows) do
            if type(row) == "table" and row.path == path then return row end
        end
    end
    function S.AddRows(list, at)
        if type(list) ~= "table" then return 0 end
        at = type(at) == "number" and math.floor(at) or #rows + 1
        if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
        for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
        return #list
    end
    function S.Reindex() end
    function S.Get(path, id)
        local row = S.FindRow(path)
        if row and type(row.get) == "function" then return row.get(id) end
        if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
        local parts = HostSchemaStub.SplitPath(path)
        local root, first = resolve(parts, id)
        if type(root) ~= "table" then return nil end
        return HostSchemaStub.Read(root, parts, first)
    end
    return resolve
end

-- The write seam's order without its log and tally: refuse a path no row declares, validate,
-- normalize, refuse a missing root, store, react, announce. `prepare` answers a plan, or nil and
-- the refusal in this addon's own words; Set and SetMany share it.
local function addWrites(S, d, resolve)
    local function prepare(path, value, id)
        local row = S.FindRow(path)
        if not row then return nil, BRAND .. ": no setting " .. tostring(path) end
        local w = { row = row, path = path, value = value, rid = id }
        w.stored = type(row.set) ~= "function" and not row.sessionOnly
        if w.stored then
            w.parts = HostSchemaStub.SplitPath(path)
            local r, f, got = resolve(w.parts, id)
            if type(r) == "table" then w.root, w.first = r, f end
            if got ~= nil then w.rid = got end
        end
        if type(row.validate) == "function" then
            local ok, why = row.validate(value, w.rid)
            if not ok then return nil, BRAND .. ": invalid value for " .. path, why end
        end
        if type(row.normalize) == "function" then
            local out, why = row.normalize(value, w.rid)
            if out == nil then return nil, BRAND .. ": invalid value for " .. path, why end
            w.value = out
        end
        if w.stored and not w.root then return nil, BRAND .. ": nowhere to store " .. path end
        return w
    end
    local function store(w)
        if type(w.row.set) == "function" then
            w.row.set(w.value)
        elseif w.stored then
            HostSchemaStub.Write(w.root, w.parts, copy(w.value), w.first)
        end
    end
    local function react(w)
        if type(w.row.onChange) == "function" then w.row.onChange(w.value, w.rid) end
    end
    function S.Set(path, value, id)
        local w, err, why = prepare(path, value, id)
        if not w then return false, err, why end
        store(w)
        react(w)
        if type(d.announce) == "function" then d.announce(w.row, path, w.value, w.rid) end
        return true
    end
    -- All or nothing, as the library's. Nothing in WhatGroup batches; it is carried because the
    -- parity pin requires the member. Log-silent, so `act` is not read.
    function S.SetMany(entries, opts)
        local id = type(opts) == "table" and opts.instanceId or nil
        local ws = {}
        for i, e in ipairs(type(entries) == "table" and entries or {}) do
            if type(e) ~= "table" then e = {} end
            local w, err, why = prepare(e.path, e.value, id)
            if not w then return false, err, why, i end
            ws[i] = w
        end
        for _, w in ipairs(ws) do store(w) end
        for _, w in ipairs(ws) do react(w) end
        if #ws > 0 and type(d.announce) == "function" then
            for _, w in ipairs(ws) do d.announce(w.row, w.path, w.value, w.rid) end
        end
        return true
    end
end

-- Defaults and the depth-only bracket. The depth is kept because ApplyDefault's sweep veto reads
-- it (launcher-§3's minimap row); it counts nothing.
local function addBracket(S, d)
    local depth = 0
    function S.Default(path)
        local row = S.FindRow(path)
        return row and copy(row.default)
    end
    function S.ApplyDefault(row, id)
        if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then
            return false
        end
        local exempt = d.resetExempt
        if depth > 0 and type(exempt) == "table" and exempt[row.path] then return false end
        return S.Set(row.path, copy(row.default), id)
    end
    function S.BulkBegin() depth = depth + 1 end
    function S.BulkEnd() if depth > 0 then depth = depth - 1 end end
    function S.BulkRun(act, scope, fn)
        S.BulkBegin(act, scope)
        local ok, err = pcall(fn, { profileReset = false })
        S.BulkEnd(act, scope)
        if not ok then error(err, 0) end
    end
    function S.BulkAdd() end
    function S.InBulk() return depth > 0 end
    function S.CountOffDefault() return 0 end
    function S.ResetCounted(fn) fn() end
    function S.ConsumeResetCount() return nil end
    function S.Validate()
        if type(d.print) == "function" then
            d.print(BRAND .. ": LibKa0s-Schema-1.0 is missing, so the schema was not checked")
        end
        return 0, 0, 0
    end
end

-- Colon-called as the library's is (`SchemaLib:New{...}`); the stub library carries no state, so
-- the receiver is unused.
function HostSchemaStub.New(_, d)
    local S = {}
    local rows = d.rows
    local resolve = addReads(S, d, rows)
    addWrites(S, d, resolve)
    addBracket(S, d)
    return S
end

Settings.SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or HostSchemaStub
