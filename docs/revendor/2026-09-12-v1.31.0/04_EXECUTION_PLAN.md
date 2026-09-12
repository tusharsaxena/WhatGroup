# 04 — Execution plan

Written before code was touched, one commit per adopted candidate. Every step ran the green gate
(`lua tests/run.lua`, `luacheck .` 0/0) and made CR count equal LF count in every file it edited.
No production code is touched by either candidate.

## B-1 — Harness onto the kit's Ace fakes (#19, option 1)

- **Characterization first.** The existing suites already pin the behavior the migration must keep:
  the combat edges dispatched by event name to one shared handler (`test_frame`), the notify
  debounce with supersede and cancel (`test_notify`), the repeating cooldown ticker that stops
  itself (`test_frame`), and both slash verbs routed to `OnSlashCommand` (`test_lifecycle`). All 573
  were green before any edit.
- **Red first.** Five cases were added to `tests/test_harness.lua`, written against the kit's contract.
  Each was **red** on the local recorder:
  the addon is a named AceAddon (`tostring`, `GetAddon`); its registrations reach `M.__fireEvent`;
  `UnregisterAllEvents` silences that dispatcher; a registration naming a missing method is refused;
  its AceTimer handles are the kit's and queue on `M.__timers`, apart from `mock.timers`.
- **Change.** Delete the AceAddon replacement, `fireAddonEvent`, `fireAceTimers`, `mock.aceTimers`,
  `mock.chatCommands` and `mock.addonEvents` from `tests/wow_mock.lua`, and keep the frame stub, the
  AceGUI wrap, `hooksecurefunc`, the `C_Timer.After` queue, `C_LFGList`, the Settings registry and
  `_G = mock`. Port the suites: `mock.addonEvents[e]` becomes `NS.addon.__events[e]`;
  `mock.fireAddonEvent(NS.addon, e)` becomes `mock.__fireEvent(e)`, and where the old call was
  asserted truthy, `assertEqual(..., 1)`, because a count of 0 is truthy in Lua; `mock.fireAceTimers()`
  becomes `mock.__fireTimers()`; `#mock.aceTimers` becomes `#mock.__timers`; a queued handle is
  `mock.__timers[i].timer`; the chat-command check asserts `AceConsole.commands` and drives both verbs
  through `AceConsole:__slash` into a spy on `OnSlashCommand`.
- **Proof.** The five red cases go green, and every ported assertion still holds at 578.
- **Commit boundary.** One commit, "for #19".

## B-2 — `C_SpellBook` in the mock

- **Red first.** Add `mock.C_SpellBook.IsSpellKnown` reading `mock.knownSpells`. "compat: IsSpellKnown
  normalizes to a plain boolean" goes **red**, because the modern rung answers first. "returns false
  when the API is missing" stays green but becomes vacuous.
- **Change.** Both cases clear `C_SpellBook` as well as the global. A new case sets the global to nil
  and asserts a learned and an unlearned spell still answer correctly, which they can only do
  through `C_SpellBook`.
- **Commit boundary.** One commit, "for #19". 578 → 579.
