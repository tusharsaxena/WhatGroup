-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0.
--
-- What moved out of settings/Panel.lua: the canvas factory and its header, the breadcrumb, the
-- lazily-built Defaults button, the always-shown-scrollbar patch, the AceGUI ScrollFrame, the
-- tooltip helper, the spacer helper, the section heading, the two widget makers, the two-column
-- flow engine, the page registry, the panel-open with its combat gate, and the refresh fan-out.
--
-- What stayed the host's, and why, is recorded below the descriptor and in this repo's GitHub issues.
--
-- TOC slot: after settings/Schema.lua, whose Get/Set/FindSchema the descriptor reads, and before
-- settings/Panel.lua, which registers its page at file load (options-ui-§1).

local addonName, NS = ...
local WhatGroup = NS.addon
local Settings  = WhatGroup.Settings

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

if not lib then
    -- The ONE documented exception to the member-answering stub every other Ka0s setup file uses
    -- (options-ui-§1). The rule there is about WHEN the missing code is reached: a page file that
    -- calls a helper inside a schema-row literal at FILE LOAD raises with the member nil, its rows
    -- never register, and a third of the schema silently disappears — taking `list`, `get`, `set`
    -- and `reset` with it.
    --
    -- WhatGroup's measured load-time set is EMPTY. settings/Schema.lua builds the whole schema from
    -- defaults/Profile.lua and touches nothing here; settings/Panel.lua reaches this table only
    -- inside `Settings.Register` and inside its page builder, both of which run at PLAYER_LOGIN.
    -- tests/test_libka0s.lua pins that by loading with the library absent and comparing the schema
    -- row count against a full load — those two numbers agreeing is the whole thing standing
    -- between this stub and a silent half-load.
    --
    -- So everything here is a no-op or one honest line, and NOTHING copies a widget maker, the flow
    -- engine, the header or a layout constant (anti-patterns #47).
    local missing = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."

    -- ONE announce per ENTRY POINT, not one for the whole seam. CreateOptionsPanel is called
    -- automatically from OnEnable, so a single shared token is always spent at login — and
    -- `/wg config`, the one path a user actually asks for, would then be a silent no-op for the
    -- rest of the session. slash-commands-§1 requires every lost verb to NAME the missing library
    -- rather than go quiet.
    local function announcer()
        local said = false
        return function()
            if said then return end
            said = true
            if NS.Print then NS.Print(missing) end
        end
    end
    local sayAtLoad, sayOnConfig = announcer(), announcer()

    local H = Settings.Helpers
    H.CreatePanel          = function() return { refreshers = {} } end
    H.EnsureDefaultsButton = function() end
    H.EnsureScroll         = function() return nil end
    H.ClearScroll          = function() end
    H.AddSpacer            = function() end
    H.Section              = function() end
    H.AttachTooltip        = function() end
    H.InlineButtonPair     = function() end
    H.RenderField          = function() end
    H.SessionCheckbox      = function() end
    H.RenderRows           = function() end
    H.RenderSchema         = function() end
    H.RenderGrid           = function() end
    H.SetRenderer          = function() end
    H.RegisterOptionsPage  = function() end
    H.RefreshAllPanels     = function() end
    H.RefreshScalars       = function() end
    H.RestoreAllDefaults   = function() end
    H.LSMValues            = function() return function() return {} end end
    H.PatchAlwaysShowScrollbar = function() end
    H.__pages              = function() return {} end
    H.__panels             = function() return {} end
    H.__panelFor           = function() return nil end
    H.CreateOptionsPanel   = function() sayAtLoad() end
    H.OpenOptionsPanel     = function() sayOnConfig() end
    -- No ROW_VSPACER / SECTION_HEADING_H / BUTTON_PAIR_REL here. options-ui-§1 forbids carrying the
    -- library's layout constants into the stub and options-ui-§8 forbids a host copy of them
    -- anywhere, precisely because a host copy is the copy that goes stale. Every consumer of them
    -- in settings/Panel.lua sits behind a maker that is a no-op on this path, so a nil reaches
    -- nothing.
    return
end

-- The instance IS the namespace member (options-ui-§1). settings/Schema.lua ran first and hung its
-- data seams — Get / Set / FindSchema / RestoreDefaults / RefreshAll / ValidateSchema — on
-- Settings.Helpers, so those move ONTO the instance here and the instance is what gets published.
-- The other direction (copying the library's members into the host's table) would look equivalent
-- and is not: RenderRows resolves O.RenderField from the instance at call time, so a suite that
-- swapped a member on a copy-across table would be spying on a function nobody calls.
--
-- settings/Schema.lua's file-local `Helpers` upvalue still points at the pre-move table. That is
-- deliberate and harmless: the members are the same FUNCTION OBJECTS, and no state lives on either
-- table — the refreshers and the panel registry are the library's, per-ctx.
local host = Settings.Helpers

local O = lib:New({
    parentTitle = "Ka0s WhatGroup",
    -- The main canvas keeps the name settings/Panel.lua gave it, so /framestack still attributes it
    -- to this addon and any saved layout keyed on it survives. It is the one descriptor field the
    -- library validates, and it raises rather than defaulting.
    mainPanelName = "WhatGroupParentPanel",

    print = function(line) NS.Print(line) end,
    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

    -- The single write seam (options-ui-§1). A panel checkbox takes exactly the path `/wg set`
    -- takes: the same [Set] debug line, the same row `onChange`, the same refresh. Two-argument by
    -- construction, so no adapter is needed — `Helpers.Set`'s third parameter is an options table
    -- the library never passes, which is the shape that makes this fit rather than a coincidence.
    get          = function(path) return host.Get(path) end,
    set          = function(path, value) host.Set(path, value) end,
    applyDefault = function(row) host.ApplyDefault(row) end,

    -- One page, so the page key is ignored and every row belongs to it. `filter` (ctx.unit) is
    -- never set: this addon has no per-unit pages.
    rowsForPage = function() return Settings.Schema end,
    allRows     = function() return Settings.Schema end,

    -- Runs once, before the page builders. settings/Schema.lua's own shape check, which PRINTS its
    -- errors rather than raising — a broken row is an addon-author bug, and the right user-visible
    -- behavior is "the option you wanted is missing AND a chat error tells you why".
    validate = function() host.ValidateSchema() end,

    -- The landing page's body — the logo, the TOC notes line and the command list — is the host's
    -- half by design (options-ui-§5), handed over as a hook so the library still owns WHEN it draws.
    buildMain = function(ctx) Settings.Helpers.BuildMainContent(ctx) end,

    -- Deliberately NOT passed, each for a reason worth writing down rather than leaving as an
    -- absence:
    --
    --   colorDecode / colorEncode — the schema is bool and number only, so there is no stored
    --     color shape to declare.
    --   getLSM / scheduleTimer    — no media pickers and no color pickers, and the one slider is
    --     release-only, so nothing reaches either.
    --   skipRestoreAll / afterRestoreAll — the global reset is host-owned (see below), so the
    --     library's row-by-row RestoreAllDefaults is not on the path.
    --   onAceGUI                  — settings/Panel.lua reads O.AceGUI off this instance at call
    --     time instead, which is the same handle without a second LibStub lookup.
})

-- ---------------------------------------------------------------------------
-- The one adapter: the panel body still builds on the NEXT frame
-- ---------------------------------------------------------------------------
--
-- The library's SetRenderer wires its own OnShow and calls the renderer — and EnsureDefaultsButton
-- — SYNCHRONOUSLY inside it. This addon does not, and the reason is written down at length in
-- docs/midnight-quirks.md: Blizzard's GameMenu / Logout flows can dispatch a settings canvas's OnShow
-- inside a secure-execute chain, and creating AceGUI frames there was tripping
-- ADDON_ACTION_FORBIDDEN on the Logout button. Keeping OnShow itself a no-op and building on the
-- next frame moves the work out of the protected context entirely, and `tests/test_panel.lua` has
-- pinned that contract since the fix landed.
--
-- This is a HOST-shaped misfit, so it belongs here rather than upstream: one addon wants the extra
-- hop today, and it is expressible as a wrapper over two instance members. Both are wrapped ON THE
-- INSTANCE, because the library resolves them from `O` at call time — a host-side helper sitting
-- beside them would be bypassed by every page the shell draws. If a second host ever needs the same
-- deferral, that is the signal it should become a descriptor field instead.
--
-- (options-ui-§9 sanctions the library's synchronous form: "a host whose builder is reached from
-- the library's lazy first-OnShow already satisfies this". The extra hop is this addon keeping a
-- belt it already fastened, not a standards requirement.)
do
    local baseSetRenderer        = O.SetRenderer
    local baseEnsureDefaultsBtn  = O.EnsureDefaultsButton

    function O.EnsureDefaultsButton(panel)
        if not panel or panel.defaultsBtn or not panel.wantsDefaultsButton then return end
        if panel.__wgDefaultsScheduled then return end
        panel.__wgDefaultsScheduled = true
        C_Timer.After(0, function() baseEnsureDefaultsBtn(panel) end)
    end

    function O.SetRenderer(ctx, fn)
        baseSetRenderer(ctx, function(c)
            -- The library already flipped _rendered/_dirty and is inside its own pcall, which
            -- returns before this hop runs — so the render is pcall'd HERE instead, or a raising
            -- builder would surface as a bare Lua error with no page named.
            C_Timer.After(0, function()
                local ok, err = pcall(fn, c)
                if not ok then
                    NS.Print(("settings page '%s' failed to render: %s")
                        :format(tostring(c.pageKey or "?"), tostring(err)))
                end
            end)
        end)
    end
end

-- The move: every data seam settings/Schema.lua published lands on the instance, and the instance
-- becomes Settings.Helpers.
--
-- UNCONDITIONAL, and the one collision is the point. `RestoreAllDefaults` exists on both sides and
-- the HOST's wins, deliberately (issue #10, LIBKA0S-08): the library's is row-by-row
-- over every row, while this addon's wipes `db.profile` first — which is what drops a key from a
-- removed or renamed schema row instead of leaving it in the profile forever — and coalesces the
-- per-row [Set] lines into one [Reset] summary (debug-logging-§9). Copying only where the instance
-- was nil silently gave the library's, and the suite said so.
--
-- The library's per-page `RestoreDefaults(pageKey, ctx)` is a DIFFERENT verb with a different
-- arity, and it is left alone.
for k, v in pairs(host) do
    O[k] = v
end
Settings.Helpers = O

-- The host's refresh name, kept because settings/Schema.lua's write seam calls it on every Set.
-- SCALARS, not the structural tier: writing a value does not change which rows exist, and a rebuild
-- per checkbox click is anti-patterns #39.
function O.RefreshAll() O.RefreshScalars() end
