-- tests/wow_mock.lua
-- WoW API mock builder for the headless harness (§14A.1).
--
-- Returns a builder function. Each call constructs a FRESH environment +
-- control table so suites are isolated from one another. The env is what
-- the loader hands to setfenv, so every WoW global the addon reads at load
-- or runtime resolves here first; Lua built-ins fall through to the real
-- _G via the env metatable.
--
-- The `mock` control table is the knob suites turn: seed search results /
-- activities / known spells / in-group state before driving the addon,
-- then assert against captured prints or the addon's own state.

local function build()
    local mock = {
        searchResults = {},   -- [id] -> C_LFGList.GetSearchResultInfo table
        activities    = {},   -- [id] -> C_LFGList.GetActivityInfoTable table
        knownSpells   = {},   -- [spellID] -> true when learned
        spellNames    = {},   -- [spellID] -> localized name (optional override)
        inGroup       = false,
        combat        = false,
        timers        = {},   -- queued C_Timer.After callbacks (fn list)
        prints        = {},   -- captured chat output lines
    }

    local function noop() end

    -- Universal self-returning no-op frame: any method call returns the
    -- frame so chained UI calls don't blow up in the rare suite that
    -- reaches a CreateFrame path. Not used by the pure-logic suites.
    local function makeFrame()
        local fr = {}
        return setmetatable(fr, {
            __index = function() return function() return fr end end,
        })
    end

    -- ---- Ace library fakes -------------------------------------------------

    local aceAddon = {
        _addons = {},
        NewAddon = function(self, objOrName, ...)
            local obj, name
            if type(objOrName) == "table" then
                obj  = objOrName
                name = ...
            else
                obj  = {}
                name = objOrName
            end
            for _, m in ipairs({
                "RegisterChatCommand", "RegisterEvent", "UnregisterEvent",
                "RegisterMessage", "SendMessage", "Print",
                "ScheduleTimer", "CancelTimer", "Enable", "Disable",
            }) do
                if not obj[m] then obj[m] = noop end
            end
            self._addons[name] = obj
            return obj
        end,
        GetAddon = function(self, name) return self._addons[name] end,
    }

    local function deepcopy(t)
        if type(t) ~= "table" then return t end
        local c = {}
        for k, v in pairs(t) do c[k] = deepcopy(v) end
        return c
    end

    local aceDB = {
        New = function(_, _name, defaults, _defaultProfile)
            local db = {}
            db.profile = deepcopy(defaults and defaults.profile or {})
            db.global  = deepcopy(defaults and defaults.global  or {})
            return db
        end,
    }

    local aceGUI = { Create = function() return makeFrame() end }

    -- ---- Environment -------------------------------------------------------

    local env = {}

    env.LibStub = function(name)
        if name == "AceAddon-3.0" then return aceAddon end
        if name == "AceDB-3.0"    then return aceDB   end
        if name == "AceGUI-3.0"   then return aceGUI  end
        return {}
    end

    env.hooksecurefunc   = noop
    env.CreateFrame      = function() return makeFrame() end
    env.UIParent         = makeFrame()
    env.IsInGroup        = function() return mock.inGroup and true or false end
    env.InCombatLockdown = function() return mock.combat and true or false end
    env.CastSpellByID    = noop
    env.wipe             = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.tinsert          = table.insert
    env.UISpecialFrames  = {}
    env.date             = function(fmt) return os.date(fmt) end

    env.C_Timer = {
        After = function(_delay, fn) mock.timers[#mock.timers + 1] = fn end,
    }

    env.IsSpellKnown = function(id) return mock.knownSpells[id] and true or false end

    env.C_Spell = {
        GetSpellName    = function(id) return mock.spellNames[id] or ("Spell " .. tostring(id)) end,
        GetSpellTexture = function(id) return 100000 + (tonumber(id) or 0) end,
        GetSpellLink    = function(id) return "|Hspell:" .. tostring(id) .. "|h[Spell " .. tostring(id) .. "]|h" end,
        GetSpellInfo    = function(id) return { name = "Spell " .. tostring(id), iconID = 100000 + (tonumber(id) or 0) } end,
    }

    env.C_LFGList = {
        ApplyToGroup         = noop,
        GetSearchResultInfo  = function(id) return mock.searchResults[id] end,
        GetActivityInfoTable = function(id) return mock.activities[id] end,
    }

    env.Enum = {
        LFGEntryGeneralPlaystyle = {
            None = 0, Learning = 1, FunRelaxed = 2, FunSerious = 3, Expert = 4,
        },
    }
    env.GROUP_FINDER_GENERAL_PLAYSTYLE1 = "Learning"
    env.GROUP_FINDER_GENERAL_PLAYSTYLE2 = "Fun (Relaxed)"
    env.GROUP_FINDER_GENERAL_PLAYSTYLE3 = "Fun (Serious)"
    env.GROUP_FINDER_GENERAL_PLAYSTYLE4 = "Expert"

    env.Settings = {
        RegisterCanvasLayoutCategory    = function() return {} end,
        RegisterCanvasLayoutSubcategory = function() return {} end,
        RegisterAddOnCategory           = noop,
        OpenToCategory                  = noop,
    }
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show   = noop
    env.C_AddOns = { GetAddOnMetadata = function() return "" end }
    env.GameTooltip = makeFrame()

    -- Capture every addon print so suites can assert chat output.
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        mock.prints[#mock.prints + 1] = table.concat(parts, " ")
    end

    setmetatable(env, { __index = _G })
    return env, mock
end

return build
