-- tests/wow_mock.lua
--
-- WhatGroup's EXTENDER over the shared kit's `mock_base` (testing-§1). The base builder owns
-- everything universal — LibStub with a real `NewLibrary` (without which every LibKa0s seam
-- silently measures its own fallback stub), AceDB's merge-in-place `copyDefaults`, AceConsole's
-- `:Print` clobber, the AceGUI widget recorder, the Settings registrars and the timer queue. This
-- file overwrites the keys WhatGroup genuinely needs differently and adds the ones the base
-- deliberately omits.
--
-- Returns a BUILDER. Each call constructs a fresh, isolated environment so suites are isolated
-- from one another; `M._G = M`, so the table a suite reads as `mock` and the table the chunk reads
-- as `_G` are the same object (settings/Panel.lua and the library both reach several APIs through
-- an explicit `_G.`).
--
-- ---------------------------------------------------------------------------
-- Mock fidelity is load-bearing
-- ---------------------------------------------------------------------------
--
-- Four pieces of this file model REAL client behaviour rather than no-op'ing it, and must not be
-- "simplified" back into blanket stubs — each one is the only reason a whole class of addon bug is
-- catchable headlessly. All four are also why this is an extender rather than a swap: the kit's own
-- README names the last of them as a divergence it deliberately keeps.
--
--  1. FRAME VISIBILITY. A blanket self-returning no-op makes IsShown() return the frame —
--     permanently truthy — so "the console closed" is untestable and a window that never hides
--     looks identical to one that does. Real frames track a shown flag; Show / Hide / SetShown flip
--     it, and Hide fires OnHide so the console's visibility callback is reachable.
--
--  2. FRAME GEOMETRY. Window position is persisted to SavedVariables and restored on the next
--     login (WG-26). With GetPoint() handing back the frame, "we saved the position" and "we saved
--     garbage" are the same assertion. SetPoint's two overloads are both modelled because
--     modules/Frame.lua and NS.Windows.Restore use different ones. GetLeft/Right/Top/Bottom answer
--     real NUMBERS because modules/Frame.lua derives the secure teleport button's offsets by
--     subtracting them.
--
--  3. THE ACETIMER QUEUE. `ScheduleTimer` as a no-op silently deletes the whole delayed-notify
--     pipeline (_TryFireJoinNotify): the delay, the supersede check, and WipeCapture's CancelTimer
--     all become untestable and a broken debounce looks exactly like a working one. AceTimer
--     handles land in their OWN fireable, cancellable queue — separate from the C_Timer queue the
--     panel's secure-defer hop uses, because a suite has to be able to fire one without the other.
--
--  4. FONT STRINGS AND TEXTURES ARE DISTINCT OBJECTS. The base answers CreateFontString /
--     CreateTexture from the frame stub's metatable, so they return THE FRAME ITSELF; its README
--     records that WhatGroup's mock is right to differ. The popup collapses every label into one
--     SetText sink otherwise, so "Leader shows the leader's name" cannot be distinguished from
--     "every field shows the same string" — and the debug console's title, ON/OFF toggle and line
--     counter all hang off one title bar.

local base = dofile("tests/_kit/mock_base.lua")

local function build()
    local M = base()

    local mock = M          -- one table: the suites' `env` and their `mock` are the same object

    -- Per-instance control surface. Everything a suite seeds before driving the addon, and
    -- everything it reads back afterwards.
    mock.searchResults = {}   -- [id] -> C_LFGList.GetSearchResultInfo table
    mock.applications  = {}   -- [appID] -> searchResultID (GetApplicationInfo)
    mock.activities    = {}   -- [id] -> C_LFGList.GetActivityInfoTable table
    mock.knownSpells   = {}   -- [spellID] -> true when learned
    mock.spellNames    = {}   -- [spellID] -> localized name (optional override)
    mock.inGroup       = false
    mock.combat        = false
    mock.timers        = {}   -- queued C_Timer.After callbacks (fn list)
    mock.aceTimers     = {}   -- queued AceTimer handles (fireable, cancellable)
    mock.prints        = {}   -- captured chat output lines
    mock.hooks         = {}   -- [name] -> { fn, ... } recorded by hooksecurefunc
    mock.frames        = {}   -- every CreateFrame'd stub, creation order (+ keyed by name)
    mock.fontStrings   = {}   -- every CreateFontString'd stub, creation order
    mock.textures      = {}   -- every CreateTexture'd stub, creation order
    mock.popups        = {}   -- StaticPopup_Show(name) calls, in order
    mock.categories    = {}   -- Settings.Register*Category calls, in order
    mock.openedTo      = {}   -- Settings.OpenToCategory(id) calls, in order
    mock.metadata      = {    -- C_AddOns.GetAddOnMetadata fields
        Version = "1.3.0",
        Notes   = "Tells you what group you just joined.",
    }
    mock.aceWidgets    = {}   -- every AceGUI:Create'd widget, creation order
    mock.chatCommands  = {}   -- [verb] -> handler name, via RegisterChatCommand
    mock.addonEvents   = {}   -- [event] -> true, via the addon's RegisterEvent

    local function noop() end

    -- ---- Stateful frame stub ----------------------------------------------
    --
    -- Models the frame state the addon actually reads back (see the fidelity note above): shown
    -- flag, anchor points, size, text, secure attributes, scripts and registered events.
    -- Everything else falls through to the catch-all, which returns a self-returning no-op for any
    -- PascalCase key (WoW frame methods are always PascalCase) and nil otherwise — so addon code
    -- doing `if not f.someCustomField then f.someCustomField = ... end` still works.
    --
    -- The catch-all deliberately returns the FRAME (not a number) from unmodelled getters.
    -- LibKa0s-DebugLog-1.0's scroll sync type-guards exactly that case, so the guard stays
    -- exercised.

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
            __messages  = {},
            __desaturated = nil,
            __alpha     = 1,
            __texture   = nil,
        }

        local api = {}

        -- visibility
        api.Show      = function()
            local was = f.__shown
            f.__shown = true
            if not was then
                if f.__scripts.OnShow then f.__scripts.OnShow(f) end
                for _, fn in ipairs(f.__hooks.OnShow or {}) do fn(f) end
            end
            return f
        end
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
        api.GetName   = function() return f.__name end
        -- Screen-space getters must be NUMBERS: modules/Frame.lua derives the secure teleport
        -- button's offsets from (label:GetLeft() - f:GetLeft()), which is arithmetic and would
        -- raise on a self-returning stub.
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

        -- ScrollingMessageFrame line sink. Recorded rather than discarded so the console's log
        -- content is assertable; the scroll getters stay UNMODELLED on purpose, so they answer the
        -- frame from the catch-all and the library's type-guarded scroll sync takes its no-op path
        -- (anti-patterns #41).
        api.AddMessage = function(_, msg) f.__messages[#f.__messages + 1] = msg; return f end
        api.Clear      = function()
            for i = #f.__messages, 1, -1 do f.__messages[i] = nil end
            return f
        end

        -- GameTooltip body, recorded so a tooltip is assertable.
        api.AddLine = function(_, text)
            f.__lines = f.__lines or {}
            f.__lines[#f.__lines + 1] = text
            return f
        end

        -- Fire a script/hook the way the client would. Test-only seam. `__fire` is the kit's own
        -- name for it, so a suite written to either idiom drives the same handler.
        f.__fire = function(script, ...)
            if f.__scripts[script] then f.__scripts[script](f, ...) end
            for _, fn in ipairs(f.__hooks[script] or {}) do fn(f, ...) end
        end

        return setmetatable(f, {
            __index = function(_, k)
                local v = api[k]
                if v ~= nil then return v end
                -- WoW frame methods are always PascalCase; anything else must miss through to nil
                -- so `f.customField` stays assignable.
                if type(k) == "string" and k:match("^%u") then
                    return function() return f end
                end
                return nil
            end,
        })
    end

    -- Published so the kit's own consumers (and any suite that needs an extra frame-shaped object)
    -- build THIS stub rather than the base's thinner one.
    mock.__stubFrame = stubFrame

    -- ---- Ace library fakes -------------------------------------------------
    --
    -- The base's AceAddon is kept for its AceConsole `:Print` clobber (anti-patterns #36) and
    -- replaced for everything else: it no-ops RegisterChatCommand and CancelTimer, and it pushes
    -- AceTimer handles into the SAME queue as C_Timer.After — which would make the panel's
    -- secure-defer hop and the notify delay indistinguishable.

    local baseNewAddon = M.__libs["AceAddon-3.0"].NewAddon
    local addons = {}

    M.__libs["AceAddon-3.0"] = {
        NewAddon = function(self, objOrName, ...)
            local obj, name
            if type(objOrName) == "table" then
                obj  = objOrName
                name = ...
            else
                obj  = {}
                name = objOrName
            end
            baseNewAddon(self, obj)
            for _, m in ipairs({ "RegisterMessage", "SendMessage", "Enable", "Disable" }) do
                if not obj[m] then obj[m] = noop end
            end

            -- Record the AceConsole / AceEvent registrations so a suite can assert the addon wired
            -- up the surface it claims to (the slash verbs it answers, the events it listens for)
            -- rather than only that the handlers work when called by hand.
            obj.RegisterChatCommand = function(_, cmd, handler)
                mock.chatCommands[cmd] = handler
            end
            obj.RegisterEvent = function(_, event)
                mock.addonEvents[event] = true
            end
            obj.UnregisterEvent = function(_, event)
                mock.addonEvents[event] = nil
            end

            -- A REAL, fireable timer queue, separate from C_Timer's. AceTimer as a no-op deletes
            -- the entire delayed-notify pipeline from the test surface (fidelity note 3).
            obj.ScheduleTimer = function(_, callback, delay)
                local handle = { callback = callback, delay = delay, cancelled = false }
                mock.aceTimers[#mock.aceTimers + 1] = handle
                return handle
            end
            obj.CancelTimer = function(_, handle)
                if type(handle) == "table" then handle.cancelled = true end
            end

            addons[name] = obj
            return obj
        end,
        GetAddon = function(_, name) return addons[name] end,
    }

    -- Run every AceTimer scheduled so far. Cancelled handles are skipped (that is the whole point).
    -- Returns how many actually fired, so a test can prove N rapid joins produce exactly ONE notify.
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

    -- Invoke the post-hooks recorded by hooksecurefunc, the way the client would after the original
    -- function has run.
    mock.fireHook = function(key, ...)
        for _, fn in ipairs(mock.hooks[key] or {}) do fn(...) end
    end

    -- ---- AceGUI widget stub ------------------------------------------------
    --
    -- LibKa0s-Options-1.0 renders the entire schema through AceGUI, so a `Create` that returns a
    -- bare no-op frame makes the whole panel layer untestable. The base's recorder is close, but it
    -- lacks the `.label` FontString the Heading/Label font branches key off, the `Fire` alias this
    -- repo's suites drive, and a ScrollFrame modelled richly enough for the always-shown-scrollbar
    -- patch's enable/disable and OnRelease-restore paths to be reachable.

    local aceGUI = M.__libs["AceGUI-3.0"]
    local baseCreate = aceGUI.Create

    aceGUI.Create = function(self, widgetType)
        local w = baseCreate(self, widgetType)
        w.frame = stubFrame("Frame", nil, "AceGUI-" .. widgetType)
        w.label = stubFrame("FontString")
        w.Fire  = w.__fire
        w.relWidth = nil
        local baseSetRelativeWidth = w.SetRelativeWidth
        function w:SetRelativeWidth(v)
            self.relWidth = v
            return baseSetRelativeWidth(self, v)
        end
        function w:SetSliderValues(minV, maxV, step)
            self.sliderMin, self.sliderMax, self.sliderStep = minV, maxV, step
            self.min, self.max, self.step = minV, maxV, step
            return self
        end
        function w:ReleaseChildren() self.children = {}; return self end

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
            w.FixScroll  = function(s) s.stockFixScrollRuns = (s.stockFixScrollRuns or 0) + 1 end
            w.MoveScroll = function(s) s.stockMoveScrollRuns = (s.stockMoveScrollRuns or 0) + 1 end
            w.OnRelease  = function(s) s.released = true end
            w.SetScroll  = function() end
        end

        mock.aceWidgets[#mock.aceWidgets + 1] = w
        return w
    end

    -- Find the first AceGUI widget matching a predicate — the seam suites use to reach "the
    -- checkbox for notify.showLeader" without walking the tree.
    mock.findWidget = function(predicate)
        for _, w in ipairs(mock.aceWidgets) do
            if predicate(w) then return w end
        end
    end

    -- ---- Environment -------------------------------------------------------

    -- LibSharedMedia is looked up with the `silent` flag; leaving it unregistered exercises the
    -- "no LSM present" branch of the font registration.

    -- Record post-hooks so a suite can fire them the way the client does after the original runs.
    -- Both call shapes are supported:
    --   hooksecurefunc(table, "Method", fn)  and  hooksecurefunc("Global", fn)
    mock.hooksecurefunc = function(a, b, c)
        local key, fn
        if type(a) == "string" then key, fn = a, b else key, fn = b, c end
        mock.hooks[key] = mock.hooks[key] or {}
        mock.hooks[key][#mock.hooks[key] + 1] = fn
    end

    mock.CreateFrame = function(kind, name, _parent, template)
        local f = stubFrame(kind, name, template)
        mock.frames[#mock.frames + 1] = f
        if name then mock.frames[name] = f end
        return f
    end
    mock.UIParent = stubFrame("Frame", "UIParent")
    mock.UIParent:SetSize(1920, 1080)
    mock.IsInGroup        = function() return mock.inGroup and true or false end
    mock.InCombatLockdown = function() return mock.combat and true or false end
    mock.CastSpellByID    = noop
    mock.UISpecialFrames  = {}
    mock.date             = function(fmt) return os.date(fmt) end

    -- Blizzard font objects the panel hands to SetFontObject. Present (rather than nil) so the
    -- `_G.GameFontNormalLarge and …` branches are exercised.
    mock.GameFontNormalLarge = stubFrame("Font", "GameFontNormalLarge")
    mock.GameFontHighlight   = stubFrame("Font", "GameFontHighlight")
    mock.YES = "Yes"
    mock.NO  = "No"

    mock.C_Timer = {
        After = function(_delay, fn) mock.timers[#mock.timers + 1] = fn end,
    }

    mock.IsSpellKnown = function(id) return mock.knownSpells[id] and true or false end

    mock.C_Spell = {
        GetSpellName    = function(id) return mock.spellNames[id] or ("Spell " .. tostring(id)) end,
        GetSpellTexture = function(id) return 100000 + (tonumber(id) or 0) end,
        GetSpellLink    = function(id) return "|Hspell:" .. tostring(id) .. "|h[Spell " .. tostring(id) .. "]|h" end,
        GetSpellInfo    = function(id) return { name = "Spell " .. tostring(id), iconID = 100000 + (tonumber(id) or 0) } end,
    }

    mock.C_LFGList = {
        ApplyToGroup         = noop,
        GetSearchResultInfo  = function(id) return mock.searchResults[id] end,
        GetActivityInfoTable = function(id) return mock.activities[id] end,
        -- F-004: the documented appID → searchResultID bridge. Returns the mapped id
        -- (multi-return, like retail) or nothing when unmapped, so a test can exercise the
        -- fall-back-to-appID branch by leaving it empty.
        GetApplicationInfo   = function(appID)
            local id = mock.applications[appID]
            if id == nil then return nil end
            return id, "applied", nil, 0, nil
        end,
    }

    mock.Enum = {
        LFGEntryGeneralPlaystyle = {
            None = 0, Learning = 1, FunRelaxed = 2, FunSerious = 3, Expert = 4,
        },
    }
    mock.GROUP_FINDER_GENERAL_PLAYSTYLE1 = "Learning"
    mock.GROUP_FINDER_GENERAL_PLAYSTYLE2 = "Fun (Relaxed)"
    mock.GROUP_FINDER_GENERAL_PLAYSTYLE3 = "Fun (Serious)"
    mock.GROUP_FINDER_GENERAL_PLAYSTYLE4 = "Expert"

    -- Category handles carry a GetID, which is what `/wg config` opens against.
    local nextCategoryID = 0
    local function makeCategory(label)
        nextCategoryID = nextCategoryID + 1
        local id = nextCategoryID
        local cat = { label = label, GetID = function() return id end }
        mock.categories[#mock.categories + 1] = cat
        return cat
    end

    mock.Settings = {
        RegisterCanvasLayoutCategory    = function(_panel, label) return makeCategory(label) end,
        RegisterCanvasLayoutSubcategory = function(_parent, _panel, label) return makeCategory(label) end,
        RegisterAddOnCategory           = function(cat) mock.registeredCategory = cat end,
        OpenToCategory                  = function(id) mock.openedTo[#mock.openedTo + 1] = id end,
    }
    mock.StaticPopupDialogs = {}
    mock.StaticPopup_Show   = function(name) mock.popups[#mock.popups + 1] = name end
    mock.C_AddOns = {
        GetAddOnMetadata = function(_addon, field) return mock.metadata[field] end,
    }
    mock.GameTooltip = stubFrame("GameTooltip", "GameTooltip")

    -- Capture every addon print so suites can assert chat output. WhatGroup's printer sinks to the
    -- Lua global `print` rather than DEFAULT_CHAT_FRAME (core/CoreSetup.lua passes an explicit
    -- `sink` that keeps it there), so this is where every user-facing line lands.
    mock.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
            parts[i] = tostring((select(i, ...)))
        end
        mock.prints[#mock.prints + 1] = table.concat(parts, " ")
    end

    -- In-game `_G` IS the table the WoW API lives in, and both settings/Panel.lua and the library
    -- read several APIs through it explicitly (`_G.Settings`, `_G.GameFontNormalLarge`,
    -- `_G[scrollbarName .. "ScrollUpButton"]`). Pointing `_G` back at the mock makes it
    -- self-consistent; real Lua built-ins still reach through the kit loader's env metatable.
    mock._G = mock

    return mock
end

return build
