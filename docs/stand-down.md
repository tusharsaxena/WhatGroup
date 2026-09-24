# The stand-down

What WhatGroup does when it is switched off, and what it deliberately keeps alive. A Tier 3 doc
(see [ARCHITECTURE.md → Documentation map](./ARCHITECTURE.md#documentation-map)); the hub keeps a
summary under [`## The stand-down`](./ARCHITECTURE.md#the-stand-down). The latch itself is
`LibKa0s-Lifecycle-1.0`'s and is documented by the library (LibKa0s `docs/api/Lifecycle/`); this
page holds only how this addon wires and relies on it.

## Disabled means not running

**Disabled means the addon is not running** (`slash-commands-§7`). Not hidden, not quiet, not
skipping a repaint — every event unregistered, every timer canceled, nothing drawn and nothing
written from a game event. Only the surface that can turn it back on is left alive.

Until 2026-09-16 this addon implemented disabled as a **draw gate**: two reads of
`db.profile.enabled`, at `OnApplyToGroup` and at the `inviteaccepted` arm, and the four event
registrations stayed exactly where they were. From the outside that is indistinguishable from
standing down, which is how the shape survived several audits. It is not the same thing: an early
return means the addon **did not stop watching — it stopped reacting**, and the client still walked
its registration list on every `GROUP_ROSTER_UPDATE`, built the argument frame, entered Lua and ran
the comparison that decided to leave. That cost is what a player switching an addon off is trying
to stop paying, and it is invisible from every surface they can see.

## One latch, two named holds

`core/LifecycleSetup.lua` builds **one** `LibKa0s-Lifecycle-1.0` instance. Two holds sit on it:

| Hold | Taken by | Lifetime |
|---|---|---|
| `disabled` | the stored `enabled` path — the Master controls checkbox, `/wg enable` / `/wg disable`, `/wg set enabled false`, and a profile switch that carries a different answer | **persisted**, because surviving a `/reload` is the point of that setting |
| `perf` | `LibKa0s-Perf-1.0`, for a capture's suspended arm. This addon **declines Perf** ([LIBKA0S-15](https://github.com/tusharsaxena/WhatGroup/issues/7)), so nothing takes it today | **session-only**, never persisted |

The addon is **down whenever at least one hold is taken** and stands up **only when the last one is
released**. There is no `:StandUp()` member on the latch at all, and its absence is the feature:
`/wg disable` is a live verb, so a player can switch the addon off during a suspended perf arm, and
a `resume` that called a bare stand-up would bring it back mid-capture and silently ruin the run.
**Releasing one hold must not resurrect an addon the other is still holding down.**

Standing up rebuilds **from current state**, never from a snapshot taken on the way down. The whole
schema CLI answers while the addon is off, so a setting changed there has to be what the rebuild
reflects.

## What goes down, and what survives

`NS.StandDown` (`core/WhatGroup.lua`) and `NS.FrameStandDown` (`modules/Frame.lua`) are the whole of
the teardown, and the latch is their only caller.

**Down:** all four AceEvent registrations actually `UnregisterEvent`'d; the chat link's
`EventRegistry` `"SetItemRef"` callback actually `UnregisterCallback`'d (and re-registered by
`NS.StandUp`); the notify timer and the teleport cooldown ticker canceled; the capture state wiped; the popup and its ESC proxy off screen,
with `visibilityAllows` answering **no at the source** so a combat edge, a settings change or a
`/wg test` cannot re-show them behind the switch's back; the combat-end queue wiped, along with
the stashes its deferred teleport configure and deferred first show read.

**The one sanctioned exception is a hook that cannot be undone.** `hooksecurefunc` has no un-hook,
so the `C_LFGList.ApplyToGroup` post-hook and the degraded client's `SetItemRef` post-hook gate
their own bodies on `NS.IsStoodDown()` and return. That carve-out exists because the API is one-way
and **does not generalize** to anything with a real unregister — which is why the `EventRegistry`
chat-link callback is unregistered rather than gated (anti-pattern #85).

**Survives, because it is SETUP and not a feature:** the chat command registration, the dispatcher
and the `COMMANDS` table; the settings-category registration and the panel body; the AceDB handle,
the single write seam and AceDB's `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset`
callbacks (a profile switch can flip `enabled` with nothing else touched, so the latch is
re-evaluated there); and the launcher's registration — the minimap button stays on the minimap,
because `minimap.hide` is a per-installation display preference and says nothing about whether the
addon is running.

## Secure work under lockdown

The popup parents a `SecureActionButtonTemplate` teleport button, so `Hide` on it — and on every
ancestor — is refused in combat. A stand-down taken mid-fight therefore takes `hidePopup`'s alpha-0
route and **owes** the real `Hide` to the next legal edge. It keeps `PLAYER_REGEN_ENABLED` registered
for exactly that, which is the **one** registration a disabled addon is permitted to hold, and
`WhatGroup:OnDisabledCombatEnded` unregisters it the moment it fires. Attempting the protected call
anyway is strictly worse than deferring: the frame does not hide either way, and the player
additionally gets a red error naming this addon.

## The launcher click

Left-click is **refused** while the addon is disabled — WhatGroup is on launcher rung (a), so the
left button drives the primary window, which is a feature. It prints `Sl:DisabledLine()` and does
nothing else: no frame shown and, above all, **no SavedVariables write**. **The gate is the
library's, and the line is the dispatcher's**: the descriptor hands `LibKa0s-Launcher-1.0` (minor 2)
`isEnabled` → `not NS.IsStoodDown()` and `disabledLine` → `NS.SlashCommands:DisabledLine()`, and
the library refuses the click before `onClick` — now the bare `WhatGroup:ToggleFrame` — is ever
called. The launcher spells no refusal of its own (slash-commands-§7). The rung-(c) carve-out
does not reach it; a rung-(c) left-click opens the settings panel and nothing else, which is why
that one is unchanged. **Right-click still opens the panel, in either state** — the ruling narrows
the *slash* surface and a mouse click is not a slash command.

## The slash surface is unchanged

Every reserved verb answers while the addon is off and the bare `/wg` opens the panel; only this
addon's own feature verbs (`show`, `test`) refuse, on one line. That is `slash-commands-§7`'s ruling
after the v2.56.0 narrowing was reversed at v2.57.0, and it is documented in full in
[slash-dispatch.md](./slash-dispatch.md). **It is not the stand-down.** The dispatcher and the
settings registration are setup, so keeping them live costs nothing the stand-down was reclaiming.

`tests/test_disabled.lua` is the conformance suite (`slash-commands-§7` MUST). Every assertion in it
is on the **registration set**, the live timer set, the shown-frame set, the SavedVariables diff or
the printed lines — never on a handler's return value, because a suite written that way certifies
the draw gate it exists to catch.
