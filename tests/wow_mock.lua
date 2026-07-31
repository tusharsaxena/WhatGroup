-- tests/wow_mock.lua
-- WoW API mock builder for the headless harness (testing-§1).
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
--
-- ---------------------------------------------------------------------------
-- Mock fidelity is load-bearing
-- ---------------------------------------------------------------------------
--
-- Four pieces of this file model REAL client behaviour rather than no-op'ing
-- it, and must not be "simplified" back into blanket stubs — each one is the
-- only reason a whole class of addon bug is catchable headlessly:
--
--  1. FRAME VISIBILITY. A blanket self-returning no-op makes IsShown() return
--     the frame — permanently truthy — so "the console closed" is untestable
--     and a window that never hides looks identical to one that does. Real
--     frames track a shown flag; Show / Hide / SetShown flip it, so the stub
--     does too (DebugLog:Toggle and the Settings panel's session-only "Debug
--     console" checkbox both read it).
--
--  2. FRAME GEOMETRY. Window position is persisted to SavedVariables and
--     restored on the next login (WG-26). With GetPoint() handing back the
--     frame, "we saved the position" and "we saved garbage" are the same
--     assertion. SetPoint's two overloads are both modelled because
--     modules/Frame.lua and NS.Windows.Restore use different ones.
--
--  3. THE ACETIMER QUEUE. `ScheduleTimer` as a no-op silently deletes the
--     whole delayed-notify pipeline (_TryFireJoinNotify): the delay, the
--     supersede check, and WipeCapture's CancelTimer all become untestable and
--     a broken debounce looks exactly like a working one. Timers land in a
--     fireable queue that honours cancellation, so a test can prove that a
--     cancelled notify does NOT fire.
--
--  4. FONT STRINGS ARE DISTINCT OBJECTS. CreateFontString returning the parent
--     frame collapses every label in the popup into one SetText sink, so
--     "Leader shows the leader's name" cannot be distinguished from "every
--     field shows the same string". Each call returns a fresh stub with its
--     own recorded text.

local function build()
    local mock = {
        searchResults = {},   -- [id] -> C_LFGList.GetSearchResultInfo table
        applications  = {},   -- [appID] -> searchResultID (GetApplicationInfo)
        activities    = {},   -- [id] -> C_LFGList.GetActivityInfoTable table
        knownSpells   = {},   -- [spellID] -> true when learned
        spellNames    = {},   -- [spellID] -> localized name (optional override)
        inGroup       = false,
        combat        = false,
        timers        = {},   -- queued C_Timer.After callbacks (fn list)
        aceTimers     = {},   -- queued AceTimer handles (fireable, cancellable)
        prints        = {},   -- captured chat output lines
        hooks         = {},   -- [name] -> { fn, ... } recorded by hooksecurefunc
        frames        = {},   -- every CreateFrame'd stub, creation order (+ keyed by name)
        fontStrings   = {},   -- every CreateFontString'd stub, creation order
        textures      = {},   -- every CreateTexture'd stub, creation order
        popups        = {},   -- StaticPopup_Show(name) calls, in order
        categories    = {},   -- Settings.Register*Category calls, in order
        openedTo      = {},   -- Settings.OpenToCategory(id) calls, in order
        metadata      = {     -- C_AddOns.GetAddOnMetadata fields
            Version = "1.3.0",
            Notes   = "Tells you what group you just joined.",
        },
        aceWidgets    = {},   -- every AceGUI:Create'd widget, creation order
        chatCommands  = {},   -- [verb] -> handler name, via RegisterChatCommand
        addonEvents   = {},   -- [event] -> true, via the addon's RegisterEvent
    }

    local function noop() end

    -- ---- Stateful frame stub ----------------------------------------------
    --
    -- Models the frame state the addon actually reads back (see the fidelity
    -- note above): shown flag, anchor points, size, text, secure attributes,
    -- scripts and registered events. Everything else falls through to the
    -- catch-all, which returns a self-returning no-op for any PascalCase key
    -- (WoW frame methods are always PascalCase) and nil otherwise — so addon
    -- code doing `if not f.someCustomField then f.someCustomField = ... end`
    -- still works.
    --
    -- The catch-all deliberately returns the FRAME (not a number) from
    -- unmodelled getters. core/DebugLog.lua's §11 scroll sync type-guards
    -- exactly that case, so the guard stays exercised.

    local stubFrame   -- forward declaration (CreateFontString creates children)

    -- SetPoint has two shapes in the wild and modules/Frame.lua uses both:
    --   (point, x, y)                              -- implicit parent
    --   (point, relativeTo, relativePoint, x, y)
    local function recordPoint(point, ...)
        local a, b, c, d = ...
        if type(a) == "number" or a == nil then
            return { point = point, relativeTo = nil, relativePoint = point,
                     x = a or 0, y = b or 0 }
        end
        return { point = point, relativeTo = a, relativePoint = b or point,
                 x = c or 0, y = d or 0 }
    end

    function stubFrame(kind, name, template)
        local f = {
            __kind      = kind or "Frame",
            __name      = name,
            __template  = template,
            __shown     = true,
            __points    = {},
            __w         = 100,
            __h         = 100,
            __text      = nil,
            __attrs     = {},
            __scripts   = {},
            __hooks     = {},
            __events    = {},
            __children  = {},
            __textures  = {},
            __fontStrings = {},
            __desaturated = nil,
            __alpha     = 1,
            __texture   = nil,
        }

        local api = {}

        -- visibility
        api.Show      = function() f.__shown = true;  return f end
        api.Hide      = function()
            local was = f.__shown
            f.__shown = false
            if was then
                for _, fn in ipairs(f.__hooks.OnHide or {}) do fn(f) end
                if f.__scripts.OnHide then f.__scripts.OnHide(f) end
            end
            return f
        end
        api.SetShown  = function(_, v) if v then api.Show() else api.Hide() end return f end
        api.IsShown   = function() return f.__shown end
        api.IsVisible = function() return f.__shown end

        -- geometry
        api.SetPoint = function(_, point, ...)
            f.__points[#f.__points + 1] = recordPoint(point, ...)
            return f
        end
        api.ClearAllPoints = function() f.__points = {}; return f end
        api.GetPoint = function(_, i)
            local pt = f.__points[i or 1]
            if not pt then return nil end
            return pt.point, pt.relativeTo, pt.relativePoint, pt.x, pt.y
        end
        api.GetNumPoints = function() return #f.__points end
        api.SetSize   = function(_, w, h) f.__w, f.__h = w, h; return f end
        api.SetWidth  = function(_, w) f.__w = w; return f end
        api.SetHeight = function(_, h) f.__h = h; return f end
        api.GetWidth  = function() return f.__w end
        api.GetHeight = function() return f.__h end
        -- Screen-space getters must be NUMBERS: modules/Frame.lua derives the
        -- secure teleport button's offsets from (label:GetLeft() - f:GetLeft()),
        -- which is arithmetic and would raise on a self-returning stub.
        api.GetLeft   = function() return 0 end
        api.GetRight  = function() return f.__w end
        api.GetTop    = function() return 0 end
        api.GetBottom = function() return -f.__h end

        -- text (FontStrings, Buttons, EditBoxes)
        api.SetText = function(_, t) f.__text = t; return f end
        api.GetText = function() return f.__text end
        api.GetTextColor = function() return 1, 0.82, 0, 1 end

        -- secure attributes
        api.SetAttribute = function(_, k, v) f.__attrs[k] = v; return f end
        api.GetAttribute = function(_, k) return f.__attrs[k] end

        -- scripts
        api.SetScript = function(_, script, handler) f.__scripts[script] = handler; return f end
        api.GetScript = function(_, script) return f.__scripts[script] end
        api.HookScript = function(_, script, handler)
            f.__hooks[script] = f.__hooks[script] or {}
            f.__hooks[script][#f.__hooks[script] + 1] = handler
            return f
        end

        -- events
        api.RegisterEvent = function(_, event) f.__events[event] = true; return f end
        api.UnregisterEvent = function(_, event) f.__events[event] = nil; return f end
        api.UnregisterAllEvents = function() f.__events = {}; return f end
        api.IsEventRegistered = function(_, event) return f.__events[event] and true or false end

        -- children
        api.CreateFontString = function(_, fsName, _layer, fontTemplate)
            local fs = stubFrame("FontString", fsName, fontTemplate)
            f.__fontStrings[#f.__fontStrings + 1] = fs
            mock.fontStrings[#mock.fontStrings + 1] = fs
            return fs
        end
        api.CreateTexture = function(_, texName, _layer)
            local tex = stubFrame("Texture", texName)
            f.__textures[#f.__textures + 1] = tex
            mock.textures[#mock.textures + 1] = tex
            return tex
        end

        -- textures / appearance the addon reads back
        api.SetTexture      = function(_, t) f.__texture = t; return f end
        api.GetTexture      = function() return f.__texture end
        api.SetDesaturated  = function(_, v) f.__desaturated = v and true or false; return f end
        api.IsDesaturated   = function() return f.__desaturated end
        api.SetAlpha        = function(_, a) f.__alpha = a; return f end
        api.GetAlpha        = function() return f.__alpha end

        -- Fire a script/hook the way the client would. Test-only seam.
        f.__fire = function(script, ...)
            if f.__scripts[script] then f.__scripts[script](f, ...) end
            for _, fn in ipairs(f.__hooks[script] or {}) do fn(f, ...) end
        end

        return setmetatable(f, {
            __index = function(_, k)
                local v = api[k]
                if v ~= nil then return v end
                -- WoW frame methods are always PascalCase; anything else must
                -- miss through to nil so `f.customField` stays assignable.
                if type(k) == "string" and k:match("^%u") then
                    return function() return f end
                end
                return nil
            end,
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
                "RegisterMessage", "SendMessage", "Print", "Enable", "Disable",
            }) do
                if not obj[m] then obj[m] = noop end
            end

            -- Record the AceConsole / AceEvent registrations so a suite can
            -- assert the addon wired up the surface it claims to (the slash
            -- verbs it answers, the events it listens for) rather than only
            -- that the handlers work when called by hand.
            obj.RegisterChatCommand = function(_, cmd, handler)
                mock.chatCommands[cmd] = handler
            end
            obj.RegisterEvent = function(_, event)
                mock.addonEvents[event] = true
            end
            obj.UnregisterEvent = function(_, event)
                mock.addonEvents[event] = nil
            end

            -- A REAL, fireable timer queue. AceTimer as a no-op deletes the
            -- entire delayed-notify pipeline from the test surface (see the
            -- fidelity note at the top of this file): the notify delay, the
            -- "superseded" identity check, and WipeCapture's CancelTimer all
            -- become unobservable, so a broken debounce passes.
            obj.ScheduleTimer = function(_, callback, delay)
                local handle = { callback = callback, delay = delay, cancelled = false }
                mock.aceTimers[#mock.aceTimers + 1] = handle
                return handle
            end
            obj.CancelTimer = function(_, handle)
                if type(handle) == "table" then handle.cancelled = true end
            end

            self._addons[name] = obj
            return obj
        end,
        GetAddon = function(self, name) return self._addons[name] end,
    }

    -- Run every AceTimer scheduled so far. Cancelled handles are skipped (that
    -- is the whole point). Returns how many actually fired, so a test can prove
    -- N rapid joins produce exactly ONE notify.
    mock.fireAceTimers = function()
        local due = mock.aceTimers
        mock.aceTimers = {}
        local fired = 0
        for _, handle in ipairs(due) do
            if not handle.cancelled then
                fired = fired + 1
                handle.callback()
            end
        end
        return fired
    end

    -- Run every queued C_Timer.After callback (the panel's secure-defer hops).
    mock.fireCTimers = function()
        local due = mock.timers
        mock.timers = {}
        for _, fn in ipairs(due) do fn() end
        return #due
    end

    -- Invoke the post-hooks recorded by hooksecurefunc, the way the client
    -- would after the original function has run.
    mock.fireHook = function(key, ...)
        for _, fn in ipairs(mock.hooks[key] or {}) do fn(...) end
    end

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
            db.GetCurrentProfile = function() return "Default" end
            return db
        end,
    }

    -- ---- AceGUI widget stub ------------------------------------------------
    --
    -- settings/Panel.lua renders the entire schema through AceGUI, so a
    -- `Create` that returns a bare no-op frame makes 800 lines untestable.
    -- The stub records the properties the panel sets (label, value, width,
    -- children) and keeps callbacks live, so a test can drive a checkbox's
    -- OnValueChanged exactly as a click would and assert the write landed in
    -- db.profile.
    local function aceWidget(widgetType)
        local w = {
            type       = widgetType,
            frame      = stubFrame("Frame", nil, "AceGUI-" .. widgetType),
            children   = {},
            callbacks  = {},
            label      = stubFrame("FontString"),
            value      = nil,
            text       = nil,
            labelText  = nil,
            width      = nil,
            relWidth   = nil,
            fullWidth  = false,
            height     = nil,
            layout     = nil,
            released   = false,
        }

        function w:SetLabel(v) self.labelText = v; return self end
        function w:SetText(v) self.text = v; return self end
        function w:SetValue(v) self.value = v; return self end
        function w:GetValue() return self.value end
        function w:SetWidth(v) self.width = v; return self end
        function w:SetHeight(v) self.height = v; return self end
        function w:SetFullWidth(v) self.fullWidth = v and true or false; return self end
        function w:SetRelativeWidth(v) self.relWidth = v; return self end
        function w:SetLayout(v) self.layout = v; return self end
        function w:SetIsPercent() return self end
        function w:SetSliderValues(minV, maxV, step)
            self.sliderMin, self.sliderMax, self.sliderStep = minV, maxV, step
            return self
        end
        function w:SetCallback(event, fn) self.callbacks[event] = fn; return self end
        function w:AddChild(child)
            self.children[#self.children + 1] = child
            child.parentWidget = self
            return self
        end
        function w:DoLayout() self.layoutRuns = (self.layoutRuns or 0) + 1; return self end
        -- Test seam: drive a callback the way a real click/drag would.
        function w:Fire(event, ...)
            local fn = self.callbacks[event]
            if fn then return fn(self, event, ...) end
        end

        -- ScrollFrame carries the internals Helpers.PatchAlwaysShowScrollbar
        -- reaches into. Modelled (rather than stubbed) so the patch's
        -- enable/disable and OnRelease-restore paths are both reachable.
        if widgetType == "ScrollFrame" then
            w.scrollframe = stubFrame("ScrollFrame")
            w.content     = stubFrame("Frame")
            w.content.original_width = 400
            w.scrollbar   = stubFrame("Slider")
            w.scrollbar.__enabled = true
            w.scrollbar.Enable  = function(s) s.__enabled = true end
            w.scrollbar.Disable = function(s) s.__enabled = false end
            w.scrollbar.SetValue = function(s, v) s.__value = v end
            w.scrollbar.GetThumbTexture = function() return stubFrame("Texture") end
            w.scrollbar.GetName = function() return nil end
            w.localstatus = { offset = 0 }
            w.FixScroll  = function(self) self.stockFixScrollRuns = (self.stockFixScrollRuns or 0) + 1 end
            w.MoveScroll = function(self) self.stockMoveScrollRuns = (self.stockMoveScrollRuns or 0) + 1 end
            w.OnRelease  = function(self) self.released = true end
            w.SetScroll  = function() end
        end

        mock.aceWidgets[#mock.aceWidgets + 1] = w
        return w
    end

    local aceGUI = { Create = function(_, widgetType) return aceWidget(widgetType) end }

    -- Find the first AceGUI widget matching a predicate — the seam suites use
    -- to reach "the checkbox for notify.showLeader" without walking the tree.
    mock.findWidget = function(predicate)
        for _, w in ipairs(mock.aceWidgets) do
            if predicate(w) then return w end
        end
    end

    -- ---- Environment -------------------------------------------------------

    local env = {}

    env.LibStub = setmetatable({
        GetLibrary = function(_, name) return env.LibStub(name) end,
    }, {
        __call = function(_, name, _silent)
            if name == "AceAddon-3.0" then return aceAddon end
            if name == "AceDB-3.0"    then return aceDB   end
            if name == "AceGUI-3.0"   then return aceGUI  end
            -- LibSharedMedia is looked up with the `silent` flag; returning nil
            -- exercises the "no LSM present" branch of the font registration.
            if name == "LibSharedMedia-3.0" then return nil end
            return {}
        end,
    })

    -- Record post-hooks so a suite can fire them the way the client does after
    -- the original runs. Both call shapes are supported:
    --   hooksecurefunc(table, "Method", fn)  and  hooksecurefunc("Global", fn)
    env.hooksecurefunc = function(a, b, c)
        local key, fn
        if type(a) == "string" then key, fn = a, b else key, fn = b, c end
        mock.hooks[key] = mock.hooks[key] or {}
        mock.hooks[key][#mock.hooks[key] + 1] = fn
    end

    env.CreateFrame = function(kind, name, _parent, template)
        local f = stubFrame(kind, name, template)
        mock.frames[#mock.frames + 1] = f
        if name then mock.frames[name] = f end
        return f
    end
    env.UIParent         = stubFrame("Frame", "UIParent")
    env.UIParent:SetSize(1920, 1080)
    env.IsInGroup        = function() return mock.inGroup and true or false end
    env.InCombatLockdown = function() return mock.combat and true or false end
    env.CastSpellByID    = noop
    env.wipe             = function(t) for k in pairs(t) do t[k] = nil end return t end
    env.tinsert          = table.insert
    env.UISpecialFrames  = {}
    env.date             = function(fmt) return os.date(fmt) end

    -- Blizzard font objects the panel hands to SetFontObject. Present (rather
    -- than nil) so the `_G.GameFontNormalLarge and …` branches are exercised.
    env.GameFontNormalLarge = stubFrame("Font", "GameFontNormalLarge")
    env.GameFontHighlight   = stubFrame("Font", "GameFontHighlight")
    env.YES = "Yes"
    env.NO  = "No"

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
        -- F-004: the documented appID → searchResultID bridge. Returns the
        -- mapped id (multi-return, like retail) or nothing when unmapped, so a
        -- test can exercise the fall-back-to-appID branch by leaving it empty.
        GetApplicationInfo   = function(appID)
            local id = mock.applications[appID]
            if id == nil then return nil end
            return id, "applied", nil, 0, nil
        end,
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

    -- Category handles carry a GetID, which is what `/wg config` opens against.
    local nextCategoryID = 0
    local function makeCategory(label)
        nextCategoryID = nextCategoryID + 1
        local id = nextCategoryID
        local cat = { label = label, GetID = function() return id end }
        mock.categories[#mock.categories + 1] = cat
        return cat
    end

    env.Settings = {
        RegisterCanvasLayoutCategory    = function(_panel, label) return makeCategory(label) end,
        RegisterCanvasLayoutSubcategory = function(_parent, _panel, label) return makeCategory(label) end,
        RegisterAddOnCategory           = function(cat) mock.registeredCategory = cat end,
        OpenToCategory                  = function(id) mock.openedTo[#mock.openedTo + 1] = id end,
    }
    env.StaticPopupDialogs = {}
    env.StaticPopup_Show   = function(name) mock.popups[#mock.popups + 1] = name end
    env.C_AddOns = {
        GetAddOnMetadata = function(_addon, field) return mock.metadata[field] end,
    }
    env.GameTooltip = stubFrame("GameTooltip", "GameTooltip")

    -- Capture every addon print so suites can assert chat output.
    env.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        mock.prints[#mock.prints + 1] = table.concat(parts, " ")
    end

    setmetatable(env, { __index = _G })

    -- In-game `_G` IS the table the WoW API lives in, and settings/Panel.lua
    -- reads several APIs through it explicitly (`_G.Settings`,
    -- `_G.GameFontNormalLarge`, `_G[scrollbarName .. "ScrollUpButton"]`).
    -- Without this the chunk's `_G` would resolve to the real Lua globals via
    -- the metatable, where none of those exist — so Settings.Register would
    -- silently early-return and the entire panel would look untestable rather
    -- than broken. Pointing `_G` back at the env makes the mock self-consistent
    -- (and real Lua built-ins still reach through the metatable above).
    env._G = env

    return env, mock
end

return build
