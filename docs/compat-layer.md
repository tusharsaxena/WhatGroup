# Compat layer

`core/Compat.lua` is the one surface the rest of the addon reads the version-variant APIs through —
`C_Spell.*`, the legacy `GetSpell*` globals, `C_SpellBook.IsSpellKnown` and the `IsSpellKnown` global,
and `C_LFGList.GetActivityInfoTable` — and the one place that asks whether the client has Blizzard's
addon chat-link path (`LinkTypes.AddOn` and `EventRegistry`). It loads first among the addon's own
files, so every later file reaches `NS.Compat.X` without doing its own detection inline.

Since LibKa0s v1.55.0 it answers in two ways. The spell readers two or more Ka0s addons wrote alike
come from **`LibKa0s-Compat-1.0`**: `GetSpellName` and `GetSpellTexture` *are* the library's members,
and the two cooldown shims read `startTime, duration, isEnabled` from the library's
`GetSpellCooldown` and keep this addon's policy on top. Everything else here is this addon's own. So
when a patch renames or moves one of these APIs, the fix lands in the library (and reaches this addon
on the re-vendor) or in this file, and nowhere else.

**Eight shims**, counted the way `documentation-§3` counts them: entry points published on this
addon's own `Compat` table, over this file alone. The threshold is three.

| Group | Shim | Ladder | Answers with, where the API is absent |
|---|---|---|---|
| Spell | `GetSpellName(spellID)` | **the library's**: `C_Spell.GetSpellName` → `C_Spell.GetSpellInfo(id).name` → `GetSpellInfo` | `nil` |
| | `GetSpellTexture(spellID)` | **the library's**: `C_Spell.GetSpellTexture` → `GetSpellTexture`, one value | `nil` |
| | `GetSpellLink(spellID)` | `C_Spell.GetSpellLink` | `nil` |
| | `IsSpellKnown(spellID)` | `C_SpellBook.IsSpellKnown` → `IsSpellKnown`; see below | `false` |
| Cooldown | `GetSpellCooldownRemaining(spellID)` | the library's `GetSpellCooldown`, then this file's GCD floor | `0` |
| | `GetSpellCooldownTimes(spellID)` | the library's `GetSpellCooldown`, truncated to two values | `0, 0` |
| LFG | `GetActivityInfoTable(activityID)` | `C_LFGList.GetActivityInfoTable` | `nil` |
| Chat link | `AddOnLinkType()` | `LinkTypes.AddOn`, only when `EventRegistry.RegisterCallback` is there too; see below | `nil` |

Callers: `modules/Frame.lua` draws the teleport buttons from the name, texture, cooldown remaining
and cooldown times; `core/WhatGroup.lua` builds the chat teleport line from the link and the known
check, reads the activity table in `CaptureGroupInfo`, and picks the details link's type and click
route from `AddOnLinkType` once, at file load.

## The shape, and the one rung that decides everything

Modern namespace first, legacy global second, an honest default third — and the middle rung is not
optional politeness. For the two spell readers the ladder is the library's now, and wired by
identity rather than wrapped:

```lua
local CompatLib = LibStub and LibStub("LibKa0s-Compat-1.0", true)
Compat.GetSpellName    = CompatLib and CompatLib.GetSpellName    or function() return nil end
Compat.GetSpellTexture = CompatLib and CompatLib.GetSpellTexture or function() return nil end
```

`GetSpellName` falls through to the next rung when a rung is **present and answers nil or a plain
`""`**, which is not the same as falling through when it is absent. That preserves the old inline
`A(x) or B(x)` chain the shims replaced: the client can carry `C_Spell.GetSpellName` and still have
nothing to say about a spell it has not cached, and going quiet there would blank a teleport label
that another reader would have filled in. The library adds a middle rung (`C_Spell.GetSpellInfo(id)`'s
name), treats a plain `""` as no answer (the host's own ladder returned it), asks `IsSecret` before it
compares a name with `""`, and answers `nil` for an id that is not a number or a string without
calling the client. Every id this addon passes is a number from `defaults/TeleportSpells.lua`.

Both the namespace and the member are checked. `C_Spell` existing does not mean the member does —
that is exactly the state a mid-migration client is in — and `if C_Spell.GetSpellName(id)` without
the `and` is a nil-index error at the one moment the fallback was supposed to save you. Capability is
probed by presence, never by asking which client this is: there is no `WOW_PROJECT_ID` branch in this
file or in the library, and there must not be one.

**Without the library** (a load missing `libs/LibKa0s`), the two readers take the reader arm of
LibKa0s `docs/api/Compat/version-1-docs.md`, *Degradation*: they answer the value the library
documents for a client with no rung at all (`nil`, and `0, 0, false` for the cooldown read), and copy
none of its ladder. A degraded install draws the teleport button with the question-mark icon, no
spell name and no cooldown, and never raises. `tests/test_compat.lua`'s degraded case pins it with the
library's files skipped, and `tests/test_surface_parity.lua` holds `NS.Compat` to the library's
member set, less the members this addon does not wire.

## `IsSpellKnown`: built from the API docs, not yet confirmed in a client

`IsSpellKnown` lives in a different namespace from its siblings. Its modern rung is
`C_SpellBook.IsSpellKnown`, not a `C_Spell.*` member, and it was the last of the spell shims to get one
(`WHATGROUP-R-06`, issue #15).

The rung is built from Blizzard's generated API documentation rather than from a client.
`Interface/AddOns/Blizzard_APIDocumentationGenerated/SpellBookDocumentation.lua` on the `live`
branch of Gethe/wow-ui-source, read at `8ea15b61` (12.1.0, build 69587), documents it as:

```
C_SpellBook.IsSpellKnown(spellID: number, spellBank: SpellBookSpellBank = "Player") -> isKnown: bool
```

`SpellBookSpellBank` is `Player` (0) or `Pet` (1). The shim passes only the spellID and lets the
bank default to `Player`, which is where teleports live. The legacy global takes `(spellID, isPet)`,
and the shim passes it only the spellID too.

A `false` from the modern rung is the answer. It does not fall through to the global the way a `nil`
from `C_Spell.GetSpellName` does. A boolean has no "no answer" value, and falling through on `false`
would turn the ladder into "either reader says yes", which would hide a disagreement.

What the documentation cannot say is whether the two readers **agree** on a real character. The
finding originally made the rung conditional on that observation. The owner chose on 2026-09-12 to
build from the documentation and keep the observation as a smoke-test step instead:
[smoke-tests.md § 7a](./smoke-tests.md) checks it, and it has not been run. If it ever finds the two
disagreeing, the ladder is wrong, and the shim needs a decision about which reader is right.

The reason this matters: the degrade is safe but it is not quiet. If both readers are gone, or the
one in use says `false` wrongly, every teleport in the popup draws desaturated with *Teleport spell
not learned* beside it on a character who has learned all of them, and every chat summary row is
tagged *(not learned)*. `tests/test_compat.lua` walks all three rungs. No headless case can show that
the rung in use gives the right answer.

## `AddOnLinkType`: whether a click on an addon chat link can reach us

This shim calls nothing. It answers one question once, at file load: can this client deliver a
click on Blizzard's `addon` link type? The answer decides both the details link's type and how its
click is heard (see [data-flow.md](./data-flow.md)).

The route it detects is Blizzard's. `LinkTypes.AddOn` is `"addon"` (`Blizzard_SharedXML/LinkUtil.lua:4`
at 12.1.0), and Blizzard registers a handler for it
(`Blizzard_UIPanels_Game/Shared/ItemRefHandlersShared.lua:278-281`) that raises `EventRegistry`'s
`"SetItemRef"` event and counts as Handled, so `SetItemRef` returns before its ItemRef-tooltip
fallthrough. Both 12.0.7 and 12.1.0 carry it.

**Both halves or neither.** A link of that type with no `EventRegistry.RegisterCallback` to subscribe
through is a link nothing can hear, so the shim answers `LinkTypes.AddOn` only when the member is
there too, and probes namespace and member separately for the same reason `GetSpellName` does. `nil`
sends `core/WhatGroup.lua` back to what shipped before 2026-09-12: the unregistered `WhatGroup:show`
link and a `hooksecurefunc("SetItemRef", …)` post-hook. That is the only click route such a client
has, and it runs after Blizzard's fallthrough. What the shim cannot probe is whether the handler
itself is registered: `LinkUtil.IsLinkHandlerRegistered` exists, but asking it would couple this
file to a second Blizzard internal for a case no client has shipped.

## Why the two cooldown readers are not one reader

`GetSpellCooldownRemaining` and `GetSpellCooldownTimes` read the same client API through the same
library member, `LibKa0s-Compat-1.0`'s `GetSpellCooldown`, which normalizes retail's info table and the
legacy multi-return and always answers five values. They answer different questions on top of it and
must not be collapsed. Both stay this addon's, and the library's document records why: a GCD-floored
remainder is one addon's policy, not a shape two addons agree on.

**`GetSpellCooldownRemaining` applies a 1.5-second floor.** The global cooldown is a cooldown as far
as the API is concerned, and it is the one every spell shares. Without the floor, casting anything at
all would make an eight-hour teleport report "on cooldown" for a second and a half — a flicker that
says nothing true. No real teleport cooldown is anywhere near that short, so the floor costs no
accuracy. It also never returns nil and never returns a negative, so a caller can treat any positive
number as "cannot cast yet" without a second guard.

**`GetSpellCooldownTimes` applies no floor at all.** It hands the raw `(start, duration)` pair to the
cooldown swipe, which draws whatever it is given — a swipe is the one readout that can afford to be
literal, because it is a shape rather than a sentence. It is truncated to **two** values: the caller
spreads it into `Cooldown:SetCooldown`, whose third parameter is `modRate`, and the library's third
return is the enabled flag.

`GetSpellCooldownRemaining` treats `isEnabled == false` as ready. That flag means "do not draw a
cooldown" — the spell is mid-cast — and that is not a wait the player can be told to sit out. The
library reads a legacy `isEnabled` of `0` as disabled and a missing one as enabled, which is the
reading this file had.

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
- **`nil` for `AddOnLinkType`**, because `core/WhatGroup.lua` reads it as the fork itself: a type
  string means "build the `addon:` link and register the callback", and `nil` means "the old link
  and the post-hook". A default link type string here would build a link nothing can hear.

## What is deliberately not here

Shims `LibKa0s` supplies are **not** counted against this file's trigger and are not restated on this
page — the library documents its own substrate once, and an addon page repeating it is a copy going
stale in eight places.

The case worth knowing is TOC metadata. The version-and-Notes ladder is `LibKa0s-Env-1.0`'s, reached
through `core/EnvSetup.lua`, and it was **never** in `core/Compat.lua` — it lived inline in
`settings/Slash.lua` and `settings/Panel.lua`, which is what made it worth finding: an audit of the
shim files alone would have reported this addon as carrying no copy of a ladder that had been written
eleven times across nine addons. `core/EnvSetup.lua`'s header carries that history. What it also
explains is why this file keeps what it keeps. The spell name, texture and cooldown reads were the
same in several addons and moved to `LibKa0s-Compat-1.0` at v1.55.0; the spell link, the known check
(whose final-answer ladder another addon disagrees with), the GCD floor, the activity reader and the
chat-link probe are genuinely WhatGroup's and behave like nobody else's, which is exactly the test for
whether a shim belongs to an addon or to the library.

## Adding a shim

First check `LibKa0s-Compat-1.0`: if the library has the member, wire it the way `GetSpellName` is
wired and add it to the parity case's wired set. Otherwise, one `function Compat.X(...)` in
`core/Compat.lua`, modern rung first, namespace and member guarded
separately, and the degrade default chosen from what the caller does with the answer. Then one case
per rung in `tests/test_compat.lua` — the suite nils globals out of the mock to walk the ladders, and
a shim with no absent-API case is a shim whose fallback has never run.

## See also

- [midnight-quirks.md](./midnight-quirks.md) — the client behavior these shims sit under.
- [module-map.md](./module-map.md) — where `core/Compat.lua` sits in the load order.
- [smoke-tests.md](./smoke-tests.md) — § 7a, the in-client check that the two `IsSpellKnown` readers agree.
- [frame.md](./frame.md) — the teleport buttons that consume five of the eight.
- [data-flow.md](./data-flow.md) — the details chat link `AddOnLinkType` picks the route for.
