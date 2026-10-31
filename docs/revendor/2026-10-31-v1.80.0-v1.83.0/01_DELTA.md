Delta: LibKa0s v1.77.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 — Delta (consolidated span)

Written 2026-10-31 by item FX-WG-DOCS of the findings remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-31-FINDINGS_REMEDIATION/`). Four tags this addon vendored were
never given a bundle; this span records them. The newest bundle before it,
`docs/revendor/2026-10-24-v1.77.0/`, ends at the base of this one.

## The listing

The provenance line of `CLAUDE.md`, walked over its own history:

```sh
tag_at() { git show "$1:CLAUDE.md" 2>/dev/null |
  grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
  grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
git log --format=%H -- CLAUDE.md | while read -r c; do
  [ "$(tag_at "$c")" != "$(tag_at "$c^")" ] && echo "$c $(tag_at "$c^") -> $(tag_at "$c")"; done
```

The rows after the last bundle's tag:

| Commit | Move |
|---|---|
| `058a033` | v1.77.0 -> v1.80.0 |
| `7914b8c` | v1.80.0 -> v1.81.0 |
| `25386f8` | v1.81.0 -> v1.82.0 |
| `319dc10` | v1.82.0 -> v1.83.0 |

v1.78.0 and v1.79.0 were never vendored here on their own: `058a033` took v1.80.0 directly and met
their "What a consumer owes" with it. The v1.83.0 tag moved three times after `319dc10`, and each
re-cut was taken without a provenance change: `7efd03f` (Skin.lua and OptionsSkinPicker.lua),
`3fb3486` (five payload files) and `5ac9075` (the final cut, `6c816fd`). No base correction is owed.

## What moved in the addon

- `058a033`: the Options stub gains AppearanceTab, AppearanceRows, SkinPicker and HideSkinPicker. The
  loader list gains twelve files in XML order. `eye` and `settings` join the icon declaration.
- `7914b8c`: twenty-four library files move and the kit does not. The picker test reads the addon's
  name from `frame.ownerLabel`.
- `25386f8`: eleven library files move and OptionsSwitch.lua is new. The kit moves to revision 45
  with `glyphs.lua`. The Options stub gains SkinVerb, and the degraded Skin facade gains FontFlags
  and HudFontSize.
- `319dc10`: OptionsMedia.lua is new, and `skin.outline` defaults to `hud`.
