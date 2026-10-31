local _, NS = ...

-- modules/FrameBinding.lua -- the Show window key binding, peeled out of modules/Frame.lua
-- (WHATGROUP-R-14). Runs at load, unlike the popup: the button is plain, and the client reads the
-- binding's labels at registration.

local L = NS.L

-- ---------------------------------------------------------------------------
-- The Show window key binding (launcher-§6)
-- ---------------------------------------------------------------------------
--
-- Bindings.xml (the addon root, never in the TOC) carries ONE `CLICK <button>:LeftButton` line,
-- and this is the button. A CLICK binding on a named frame rather than a Lua body or a global
-- function, so the key, the launcher menu's Show window entry and the Close button all reach one
-- handler, WhatGroup:ToggleFrame, the one core/LauncherSetup.lua's toggleWindow calls.
--
--   * NO SECURE TEMPLATE. The popup is non-secure; ToggleFrame already knows how to close it in
--     combat (the alpha-0 soft hide) and when to defer opening it. A secure button would add
--     combat rules the window does not have.
--   * AnyDown, and only that: the client's default is the up edge, and registering both would
--     toggle twice per press.
--   * THE NAME IS PERMANENT. The client stores a player's key against the binding's name, so
--     renaming this button silently unbinds every player's key.
--   * Not the taint source buildEscapeProxy and buildFrame keep off the load path: this frame is
--     created at load but is plain and is NEVER added to UISpecialFrames, so it enters no Blizzard
--     secure-execute list.
--
-- While stood down the press refuses through NS.StandDownRefusal, the addon's one refusal helper
-- (slash-commands-§7), because a key cannot be grayed the way the menu entry is. ToggleFrame itself
-- does not refuse: the menu grays Show window while disabled, so it never needed to.
NS.TOGGLE_BUTTON  = "WhatGroupTogglePopup"
NS.TOGGLE_COMMAND = ("CLICK %s:LeftButton"):format(NS.TOGGLE_BUTTON)

do
    local button = CreateFrame("Button", NS.TOGGLE_BUTTON, UIParent)
    button:RegisterForClicks("AnyDown")
    button:SetScript("OnClick", function()
        local line = NS.StandDownRefusal()
        if line then return NS.Print(line) end
        NS.addon:ToggleFrame()
    end)
    button:Hide()
end

-- The two labels Options -> Keybindings shows, assigned at file scope because the client reads them
-- at registration. Bindings.xml files the binding in this addon's own category,
-- BINDING_HEADER_WHATGROUP, and the client titles the section with that global, so it is the brand
-- (launcher-§1), read from NS.BRAND_NAME (core/CoreSetup.lua) rather than retyped. The action comes
-- through the locale, with no article and no brand because the section carries the brand
-- (launcher-§6); its name holds a space and a colon, hence rawset.
BINDING_HEADER_WHATGROUP = NS.BRAND_NAME
rawset(_G, "BINDING_NAME_" .. NS.TOGGLE_COMMAND, L["Toggle group popup"])

-- THE ONE BINDINGS TABLE (launcher-§6): every Bindings.xml command, in that file's order, the Show
-- window binding first. settings/Panel.lua hands it to the library's O.KeybindingsTab for the
-- General page's Keybindings tab (options-ui-§20), whose rows follow it, and tests/test_keybinds.lua
-- checks Bindings.xml against it through Kit.assertBindingsXml.
NS.BINDINGS = {
    { command = NS.TOGGLE_COMMAND, tooltip = L["Shows or hides the group popup."] },
}
