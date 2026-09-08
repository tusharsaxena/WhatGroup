# Compat layer

`core/Compat.lua` is the sole caller of the version-variant APIs this addon consumes — `C_Spell.*`,
the legacy `GetSpell*` globals, the bare `IsSpellKnown`, and `C_LFGList.GetActivityInfoTable`. It
loads first among the addon's own files, so every later file reaches `NS.Compat.X` without doing its
own detection inline. When a patch renames or moves one of these, this is the only file that changes.

**Seven shims**, counted the way `documentation-§3` counts them: entry points published on this
addon's own `Compat` table, over this file alone. The threshold is three.

| Group | Shim | Ladder | Answers with, where the API is absent |
|---|---|---|---|
| Spell | `GetSpellName(spellID)` | `C_Spell.GetSpellName` → `GetSpellInfo` | `nil` |
| | `GetSpellTexture(spellID)` | `C_Spell.GetSpellTexture` → `GetSpellTexture` | `nil` |
| | `GetSpellLink(spellID)` | `C_Spell.GetSpellLink` | `nil` |
| | `IsSpellKnown(spellID)` | the bare `IsSpellKnown` global — **and only that**; see below | `false` |
| Cooldown | `GetSpellCooldownRemaining(spellID)` | `C_Spell.GetSpellCooldown` → `GetSpellCooldown` | `0` |
| | `GetSpellCooldownTimes(spellID)` | `C_Spell.GetSpellCooldown` → `GetSpellCooldown` | `0, 0` |
| LFG | `GetActivityInfoTable(activityID)` | `C_LFGList.GetActivityInfoTable` | `nil` |

Callers: `modules/Frame.lua` draws the teleport buttons from the name, texture, cooldown remaining
and cooldown times; `core/WhatGroup.lua` builds the chat teleport line from the link and the known
check, and reads the activity table in `CaptureGroupInfo`.

## The shape, and the one rung that decides everything

Modern namespace first, legacy global second, an honest default third — and the middle rung is not
optional politeness:

```lua
function Compat.GetSpellName(spellID)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name then return name end
    end
    if GetSpellInfo then
        return (GetSpellInfo(spellID))
    end
    return nil
end
```

`GetSpellName` falls through to the legacy path when the modern API is **present and answers nil**,
which is not the same as falling through when it is absent. That is deliberate and it preserves the
old inline `A(x) or B(x)` chain the shims replaced: the client can carry `C_Spell.GetSpellName` and
still have nothing to say about a spell it has not cached, and going quiet there would blank a
teleport label that the deprecated reader would have filled in.

Both the namespace and the member are checked. `C_Spell` existing does not mean the member does —
that is exactly the state a mid-migration client is in — and `if C_Spell.GetSpellName(id)` without
the `and` is a nil-index error at the one moment the fallback was supposed to save you. Capability is
probed by presence, never by asking which client this is: there is no `WOW_PROJECT_ID` branch in this
file and there must not be one.

## `IsSpellKnown` is the odd one, on purpose, and it is being watched

Five of the six spell shims try `C_Spell.*` first. `IsSpellKnown` (`core/Compat.lua:62-67`) calls the
bare global and answers `false` when it is missing. It is the only accessor of the seven with no
modern rung, and that asymmetry is **recorded rather than fixed**.

`WHATGROUP-R-06` asks for a `C_SpellBook.IsSpellKnown` rung above the global, in the shape the
siblings use — and it conditions that on an in-client observation confirming both APIs are present
and **agree**. [smoke-tests.md § 7a](./smoke-tests.md) is that observation, and it has never been run.
Until it has been, the shim keeps the shape the finding questions, because adding the rung without
the observation would be inventing the evidence the finding asks for.

The reason it is worth a watch rather than a shrug: the degrade is safe but it is not quiet. Nothing
throws — `IsSpellKnown` absent simply reads as "not learned". Which means every teleport in the popup
draws desaturated with *Teleport spell not learned* beside it, on a character who has learned all of
them, and every chat summary row is tagged *(not learned)*. That is what patch day looks like if
Blizzard retires the global.

`tests/test_compat.lua:143` nils the global and asserts the shim answers `false`. That proves the
shim degrades as designed; it cannot prove that `false` is the right answer on a client where a
modern API knows better. No headless case can.

## Why the two cooldown readers are not one reader

`GetSpellCooldownRemaining` and `GetSpellCooldownTimes` read the same client API and normalize the
same two shapes — retail's info table and the legacy multi-return — but they answer different
questions and must not be collapsed.

**`GetSpellCooldownRemaining` applies a 1.5-second floor.** The global cooldown is a cooldown as far
as the API is concerned, and it is the one every spell shares. Without the floor, casting anything at
all would make an eight-hour teleport report "on cooldown" for a second and a half — a flicker that
says nothing true. No real teleport cooldown is anywhere near that short, so the floor costs no
accuracy. It also never returns nil and never returns a negative, so a caller can treat any positive
number as "cannot cast yet" without a second guard.

**`GetSpellCooldownTimes` applies no floor at all.** It hands the raw `(start, duration)` pair to the
cooldown swipe, which draws whatever it is given — a swipe is the one readout that can afford to be
literal, because it is a shape rather than a sentence.

Both treat `isEnabled == false` as ready. That flag means "do not draw a cooldown" — the spell is
mid-cast — and that is not a wait the player can be told to sit out.

## Why every reader answers rather than raises

Each default is chosen from its caller's direction, not from habit:

- **`nil` for the three name/texture/link readers**, because each caller supplies its own placeholder
  and they are not the same placeholder. The popup falls back to icon `134400`, the question mark, so
  a missing texture stays visible instead of leaving a blank square; the chat line renders a plain
  `[Spell <id>]` tag where the link is missing. A shared default here would be wrong somewhere.
- **`false` for `IsSpellKnown`**, normalized to a plain boolean so the teleport known/unknown branch
  can use it directly rather than asking about truthiness at two call sites.
- **`0` and `0, 0` for the cooldown readers**, because their callers do arithmetic and comparison on
  the result. A `nil` there is a guard at every call site for a case the caller cannot act on.
- **`nil` for `GetActivityInfoTable`**, because "this activity is unknown" and "this client has no
  LFG reader" are the same thing to `CaptureGroupInfo`: there is no group to describe either way.

## What is deliberately not here

Shims `LibKa0s` supplies are **not** counted against this file's trigger and are not restated on this
page — the library documents its own substrate once, and an addon page repeating it is a copy going
stale in eight places.

The case worth knowing is TOC metadata. The version-and-Notes ladder is `LibKa0s-Env-1.0`'s, reached
through `core/EnvSetup.lua`, and it was **never** in `core/Compat.lua` — it lived inline in
`settings/Slash.lua` and `settings/Panel.lua`, which is what made it worth finding: an audit of the
shim files alone would have reported this addon as carrying no copy of a ladder that had been written
eleven times across nine addons. `core/EnvSetup.lua`'s header carries that history. What it also
explains is why this file keeps what it keeps: the spell and LFG shims are genuinely WhatGroup's and
behave like nobody else's, which is exactly the test for whether a shim belongs to an addon or to the
library.

## Adding a shim

One `function Compat.X(...)` in `core/Compat.lua`, modern rung first, namespace and member guarded
separately, and the degrade default chosen from what the caller does with the answer. Then one case
per rung in `tests/test_compat.lua` — the suite nils globals out of the mock to walk the ladders, and
a shim with no absent-API case is a shim whose fallback has never run.

## See also

- [midnight-quirks.md](./midnight-quirks.md) — the client behavior these shims sit under.
- [module-map.md](./module-map.md) — where `core/Compat.lua` sits in the load order.
- [smoke-tests.md](./smoke-tests.md) — § 7a, the observation `IsSpellKnown` is waiting on.
- [frame.md](./frame.md) — the teleport buttons that consume five of the seven.
