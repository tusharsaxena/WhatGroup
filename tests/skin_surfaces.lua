-- tests/skin_surfaces.lua — this addon's painted surfaces, declared for the kit's skin-switch test
-- (tests/_kit/test_skin_switch.lua, kit revision 50, skinning-§1). tests/run.lua sets Kit.skinSwitch
-- from it. Loaded with dofile (it registers no case of its own).
--
-- WHAT IS HERE. Everything this addon's own code paints, one entry per painted object, because a
-- surface passes on any change under it and the whole popup would pass on its first recolored
-- string: the popup's window, title bar, title, a label, a value, a placeholder, the teleport note,
-- the Close button and the teleport icon's edge, and on the settings pages the two AceGUI surfaces
-- this addon paints itself, the Test notification button and the tree the Profiles page draws.
--
-- WHAT IS NOT. The Teleport icon and the role icons are game art (causes A6, A7). The debug console,
-- the first-run picker and every row the Options instance draws are the library's, and its own suite
-- holds them. No surface carries a companion: this addon has no `<key>FromSkin` row, no bar and no
-- HUD string.
--
-- THE INSTANCE. tests/run.lua builds a fresh addon per case, but the kit runs one owner on one
-- library, so this file keeps one enabled instance of its own, built on the first question and
-- handed to no case. The popup is lazy and built once on it, so each popup surface answers the
-- same strings; the kit takes its spies back off after each.
--
-- THE FIXTURES. The popup's frames stay on this addon's own mock, whose regions the spy never walks,
-- which is the point: each entry answers its own objects and nothing else. The kit's AceGUI widgets
-- are recorders with no regions, so a settings row is dressed in the frame and label the real widget
-- has, from the kit's paint recorder, for SkinAce to paint. A skin switch re-renders a settings page
-- and the row is a new widget each time, so the spy has no one object to watch: each surface answers
-- one mirror string, and its `paint` hands the mirror the color the newest row's label was given. An
-- unpainted row keeps the recorder's stock color under every skin, so the mirror goes red. The title's
-- brand span takes a mirror too, for the one thing it draws that its string's color would hide. The
-- recorder stays installed only while a settings surface runs; `reset`, which the kit runs after
-- every surface whatever it raised, takes it off.

return function(enableAddon)
    local NS, mock

    -- AceDBOptions, AceConfig and AceConfigDialog as fakes whose Open draws one raw CheckBox, as
    -- AceConfigDialog acquires from AceGUI itself (tests/test_skin_tools.lua's profileLibs).
    local function profileLibs(m)
        m.__libs["AceDBOptions-3.0"] = { GetOptionsTable = function() return { type = "group" } end }
        m.__libs["AceConfig-3.0"] = { RegisterOptionsTable = function() end }
        m.__libs["AceConfigDialog-3.0"] = { Open = function(_, _, container)
            container:ReleaseChildren()
            container:AddChild(m.__libs["AceGUI-3.0"]:Create("CheckBox"))
        end }
    end

    --- The surfaces' one instance: enabled, chat swallowed, the popup built with a teleport to draw.
    local function instance()
        if NS then return NS, mock end
        local env
        NS, env, mock = enableAddon({ mock = profileLibs })
        NS.Print = function() end
        NS.TeleportSpells[2652] = 445269
        NS.addon:ShowFrame()
        return NS, mock, env
    end

    local function skinLib() return select(2, instance()).LibStub("LibKa0s-Skin-1.0") end

    local undo = {}
    local buttonLabel, rowLabel   -- the settings surfaces' readers, set by their `build`
    local function later(fn) undo[#undo + 1] = fn end

    local function reset()
        for i = #undo, 1, -1 do undo[i]() end
        undo = {}
    end

    --- The popup and the strings of its content frame, in modules/FrameLayout.lua's order: six
    --- label and value pairs, the Teleport label and the note (tests/test_frame_skin.lua's strings).
    local function popup()
        local _, m = instance()
        local content, most = nil, 0
        for _, f in ipairs(m.frames) do
            if f.__fontStrings and #f.__fontStrings > most then content, most = f, #f.__fontStrings end
        end
        return m.frames["WhatGroupFrame"], content.__fontStrings
    end

    --- The title bar: the only frame carrying an OnMouseUp (tests/frame_fixture.lua's dragHandle).
    local function titleBar()
        local _, m = instance()
        for _, f in ipairs(m.frames) do
            if f.__scripts and f.__scripts.OnMouseUp then return f end
        end
    end

    local function button(template)
        local _, m = instance()
        for _, f in ipairs(m.frames) do
            if f.__template == template then return f end
        end
    end

    --- `target` and every region the library's record of it keeps: the mock's regions are out of the
    --- spy's reach, so the record is how a band, a fill or an edge is answered.
    local function withRegions(target, key)
        local rec = skinLib().painted[key or target]
        local out = { target }
        for _, region in pairs(rec and rec.regions or {}) do
            if type(region) == "table" then out[#out + 1] = region end
        end
        return unpack(out)
    end

    --- The icon's Texture, the one the library recorded with IconBorder.
    local function iconTexture()
        local _, m = instance()
        for _, tex in ipairs(m.textures) do
            local rec = skinLib().painted[tex]
            if rec and rec.calls.IconBorder then return tex end
        end
    end

    --- The paint recorder on, and every `wtype` AceGUI hands out wearing a frame and label of its
    --- own before the host's paint reaches it. Answers a function reading the newest label. Both
    --- come off at `reset`.
    local function dressed(wtype)
        local _, m = instance()
        later(dofile("tests/_kit/mock_paint.lua")(m))
        local label
        local AceGUI = m.LibStub("AceGUI-3.0")
        local real = AceGUI.Create
        AceGUI.Create = function(self, t)
            local w = real(self, t)
            if t == wtype then
                w.frame = m.CreateFrame(wtype == "Button" and "Button" or "Frame")
                label = w.frame:CreateFontString(nil, "OVERLAY")
                w.text = label
            end
            return w
        end
        later(function() AceGUI.Create = real end)
        return function() return label end
    end

    --- The redraw a skin switch asks of a shown page: the Options instance's re-render a frame later,
    --- and the host's own hop into the AceGUI frames (settings/OptionsSetup.lua's taint fix) a frame after that.
    local function renderPage()
        local _, m = instance()
        while m.fireCTimers() > 0 do end
    end

    --- The string that mirrors a row's label.
    local function mirror()
        local _, m = instance()
        return m.CreateFrame("Frame"):CreateFontString(nil, "OVERLAY")
    end

    --- The General page open on its Notifications tab, drawn through the raw AceGUI-3.0, as
    --- tests/test_skin_tools.lua's testButton draws it: only the host's own call paints it.
    local function openNotifications()
        local _, m = instance()
        local H = NS.addon.Settings.Helpers
        local proxy = H.AceGUI
        H.AceGUI = m.LibStub("AceGUI-3.0")
        later(function() H.AceGUI = proxy end)
        m.frames["WhatGroupGeneralPanel"]:Show()
        m.fireCTimers()
        for _, f in ipairs(m.frames) do
            if f.__kind == "Button" and f.__text == "Notifications" then f.__fire("OnClick") end
        end
    end

    return {
        owner = "WhatGroup",
        skin = skinLib,
        reset = reset,
        surfaces = {
            { name = "the popup's window",
              build = function() return withRegions((popup())) end },

            { name = "the popup's title bar",
              build = function() return withRegions(titleBar()) end },

            { name = "the popup's title",
              build = function() return popup().title end },

            -- The markup alone: the string's color above would hide a brand span left in the old
            -- skin. Its escape is baked in, so modules/FrameSkin.lua's reskin re-sets it by hand.
            { name = "the title's brand span",
              build = function() return mirror() end,
              paint = function(fs) fs:SetText(popup().title:GetText()) end },

            { name = "a field label",
              build = function()
                  local _, fs = popup()
                  return fs[1]
              end },

            { name = "a field value",
              build = function()
                  local _, fs = popup()
                  NS.FrameSkin.Value(fs[2], "Sample")
                  return fs[2]
              end },

            { name = "a placeholder value",
              build = function()
                  local _, fs = popup()
                  NS.FrameSkin.Value(fs[4], "No data", true)
                  return fs[4]
              end },

            { name = "the Teleport label",
              build = function()
                  local _, fs = popup()
                  return fs[13]
              end },

            { name = "the teleport note",
              build = function()
                  local _, fs = popup()
                  return fs[14]
              end },

            { name = "the Close button",
              build = function() return withRegions(button("UIPanelButtonTemplate")) end },

            { name = "the teleport icon's edge",
              build = function()
                  local tex = iconTexture()
                  return withRegions(skinLib().painted[tex].regions.holder, tex)
              end },

            { name = "the Test notification button", scope = "panel",
              build = function()
                  buttonLabel = dressed("Button")
                  openNotifications()
                  return mirror()
              end,
              paint = function(fs)
                  renderPage()
                  fs:SetTextColor(buttonLabel():GetTextColor())
              end },

            { name = "the Profiles page's tree", scope = "panel",
              build = function()
                  rowLabel = dressed("CheckBox")
                  local _, m = instance()
                  m.frames["WhatGroupProfilesPanel"]:Show()
                  m.fireCTimers()
                  return mirror()
              end,
              paint = function(fs)
                  NS.addon.Settings.RefreshProfilesPage()
                  renderPage()
                  fs:SetTextColor(rowLabel():GetTextColor())
              end },
        },
    }
end
