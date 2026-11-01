# Refresh 1 of v1.85.0

The tag is still local-only and was re-cut for the owner's rulings of 2026-11-01 and the gate before any push, so this is a refresh and not a new re-vendor. FS-WG-GATE of Ka0sAddonsCommonTasks `docs/2026-11-01-FULL_SKINNING/`.

- **Old:** `9776130`. `libs/LibKa0s/` and `tests/_kit/` matched it before this copy.
- **New:** `2ad1a5080112cc1323fe79f7e134b00768a7ebca`, tag object `36506d6`.

| File | Constant | Old | New |
|---|---|---|---|
| `OptionsCompose.lua` | `COMPOSE_MINOR` | 17 | 18 |
| `SkinDefs.lua` | `DEFS_MINOR` | 24 | 25 |
| `SkinDefsOthers.lua` | `OTHERS_MINOR` | 6 | 7 |
| `SkinEUI.lua` | `EUI_MINOR` | 3 | 4 |
| `SkinPaint.lua` | `PAINT_MINOR` | 16 | 17 |
| `SkinPaintControls.lua` | `CONTROLS_MINOR` | 14 | 15 |
| `SkinPaintExtras.lua` | `EXTRAS_MINOR` | 15 | 16 |
| kit | `Kit.VERSION` | 49 | 50 |

`Media.lua`, `Skin.lua` and `Widgets.lua` moved too. The kit gains `skin_values.lua`, `skin_switch.lua` and their two suites.

**Blockers:** the facade's `BarBorder` and `HoverArt`, and both new suites in `tests/run.lua`; resolved in this commit. `O.LabelFont` was already in the Options stub. This addon has no Widgets stub, so `ContextMenu` owes nothing.

**Not owed:** this addon draws no bar, glow or cover and has no `<key>FromSkin` companion. It calls neither `Skin.FollowOnce` nor `S.Mark`, so no repair step and no release handling apply.

**Adopted:** `S.IconBorder` on the teleport icon's Texture replaces the host's own holder frame. `Kit.skinValues` with three rows, chat output, cause L13; `tests/test_skin_literals.lua` is deleted. `Kit.skinSwitch` over `tests/skin_surfaces.lua`, thirteen surfaces; removing each paint or repaint turned its surface red, but for the Shell re-run in `FrameSkin.TitleBar`, since the window's first Shell, through `NS.ApplySkin`, still tracks it.

**Prune:** 12 icons declared, kept 13 files, removed 5827, the declaration unchanged. After it, `diff -r` against the tag lists only the pruned icons, CRLF kept.
