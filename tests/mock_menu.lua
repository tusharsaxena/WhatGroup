-- tests/mock_menu.lua — a headless stand-in for the client's context-menu API (11.0+).
--
-- MODELED ON LibKa0s's own tests/mock_menu.lua at v1.58.0, which is repo-local there and so never
-- arrives with the kit: the library's Launcher version-4 doc tells a host that pins its menu
-- entries to install its own fake, shaped on that file. This is that fake, kept to the library's
-- member names so a case here reads like a case there.
--
-- LibKa0s-Launcher-1.0's right click (minor 4, launcher-§2) opens the client's own context menu,
-- `MenuUtil.CreateContextMenu(ownerRegion, generator)`. The generator is handed a root description
-- and builds the menu on it: `root:CreateTitle(text)` and
-- `root:CreateCheckbox(text, isSelected, setSelected, data)`, the second answering an element
-- description whose `SetEnabled(false)` grays the entry. Clicking an enabled checkbox calls
-- `setSelected(data)`, and what it returns is the menu's response (`MenuResponse.Close` closes).
--
-- INSTALLED BY DEFAULT, from tests/wow_mock.lua, as `mock.menu`: the live client has MenuUtil,
-- so a harness without it would measure the library's degraded right click (the settings panel)
-- on every case. A case that wants that degraded path calls `mock.menu.remove()`.
--
-- FIDELITY. Two things the real API does that a convenient fake would not, and both matter:
--   * a disabled element is never clicked. `Click` refuses a grayed entry the way the client does,
--     so a case that wants to prove the library's own gate calls `ForceClick` and says so;
--   * `CreateContextMenu` runs the generator when the menu opens, once per open. A host that
--     cached state across opens would read stale here as it would in the client.

return function(mocks)
  local M = { menus = {}, opens = 0 }

  local RESPONSE = { Close = 1, Refresh = 2, Open = 3 }

  --- One opened menu: the owner it anchors to, its title and its entries in creation order.
  local function newRoot(owner)
    local menu = { owner = owner, titles = {}, entries = {} }
    local root = {}
    root.CreateTitle = function(_, text)
      menu.titles[#menu.titles + 1] = text
      return {}
    end
    root.CreateCheckbox = function(_, text, isSelected, setSelected, data)
      local entry = { text = text, isSelected = isSelected, setSelected = setSelected,
        data = data, enabled = true }
      local element = {}
      element.SetEnabled = function(_, on) entry.enabled = on and true or false end
      element.IsEnabled = function() return entry.enabled end
      menu.entries[#menu.entries + 1] = entry
      return element
    end

    --- The entries' texts, in order.
    function menu:Texts()
      local out = {}
      for i, e in ipairs(self.entries) do out[i] = e.text end
      return out
    end
    --- The entry whose text starts with `prefix`, or nil.
    function menu:Find(prefix)
      for _, e in ipairs(self.entries) do
        if e.text:sub(1, #prefix) == prefix then return e end
      end
    end
    --- Whether an entry draws checked, as the client asks it.
    function menu:Checked(prefix)
      local e = self:Find(prefix)
      return e and e.isSelected(e.data) and true or false
    end
    --- Click an entry as a player can: a grayed one does nothing and answers nil.
    function menu:Click(prefix)
      local e = assert(self:Find(prefix), "no menu entry " .. prefix)
      if not e.enabled then return nil end
      return e.setSelected(e.data)
    end
    --- Run an entry's handler regardless of its gray, to reach the module's own gate.
    function menu:ForceClick(prefix)
      local e = assert(self:Find(prefix), "no menu entry " .. prefix)
      return e.setSelected(e.data)
    end
    return root, menu
  end

  M.MenuUtil = {
    CreateContextMenu = function(owner, generator)
      if owner == nil then error("CreateContextMenu: an owner region is required", 2) end
      local root, menu = newRoot(owner)
      M.opens = M.opens + 1
      generator(owner, root)
      M.menus[#M.menus + 1] = menu
      M.last = menu
      return menu
    end,
  }

  --- Put the fake API in the environment, or take it away (`MenuUtil` absent, as on a client
  --- before 11.0 or one where the menu system failed to load).
  function M.install()
    mocks.MenuUtil = M.MenuUtil
    mocks.MenuResponse = RESPONSE
  end
  function M.remove()
    mocks.MenuUtil = nil
    mocks.MenuResponse = nil
  end
  function M.reset()
    M.menus, M.opens, M.last = {}, 0, nil
  end

  M.RESPONSE = RESPONSE
  M.install()
  return M
end
