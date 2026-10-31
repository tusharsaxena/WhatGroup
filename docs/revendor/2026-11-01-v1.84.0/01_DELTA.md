Delta: LibKa0s v1.83.0 -> v1.84.0

Taken from the local tag `v1.84.0` (`0c32e37`, not pushed yet), extracted with
`git -C ../LibKa0s archive v1.84.0 LibKa0s testkit tools`.

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` named v1.83.0, and so did the provenance line at the last payload
commit (`git log -1 -- libs/LibKa0s tests/_kit` gives `5ac9075`). `diff -rq` against the extract of
v1.83.0 was clean apart from the undeclared icons, so the claim and the payload agree. The range is
`git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`: 26 commits.

Step 0, run for this addon only: the newest single-tag bundle, `2026-10-24-v1.77.0`, states base
v1.76.0. No correction is owed.

## 3c. Per-file minors

From the loop over the tag's `LibKa0s.xml`. No file is behind its claimed tag, so there is no skew.

| File | v1.83.0 | v1.84.0 |
|---|---|---|
| Schema | 2 | 3 |
| Charts | new | 1 |
| ChartsRender | new | 1 |
| Skin | 10 | 11 |
| SkinOwnerTokens | new | 1 |
| SkinDefs | 18 | 19 |
| SkinDefsOthers | new | 1 |
| WidgetsDragHandle | 8 | 10 |
| DebugLogDiagnostics | 5 | 6 |
| Slash | 20 | 21 |
| Options | 34 | 35 |
| OptionsWidgets | 38 | 40 |
| OptionsFlow | new | 2 |
| OptionsIds | 5 | 6 |
| OptionsIdSuggest | new | 1 |
| OptionsTabs | 11 | 13 |
| OptionsTabbed | new | 2 |
| OptionsCompose | 14 | 15 |
| OptionsSkinPicker | 4 | 5 |
| OptionsSkinPickerRows | new | 1 |
| SimPanel | 8 | 9 |
| SimPanelRender | new | 1 |

## 3d. Diffs

`diff -r --strip-trailing-cr` for both payloads was empty after the copy and before the prune.

## 3e. Consumption

Lookups in addon code: Core, Compat, DebugLog, Env, Launcher, Lifecycle, Media, Options, Schema, Skin
and Slash. Charts is not looked up.

## 3f. Kit

`Kit.VERSION` moves from 46 to 47, in the same commit as the library. The pairing rule holds by
construction, because both payloads are copied whole.

## 3g. Contract delta

Documents read, each diffed against the one before it at the tag: Options
`version-34.4.38.5.7.11.3.14.9.4.3.6.5.4.1.1` to `version-35.4.40.2.6.1.7.13.2.3.15.9.4.3.6.5.5.1.1.1`,
Skin `10.18.13.7.11.2.5` to `11.1.19.1.13.7.11.2.5`, Schema 2 to 3, Slash 20.2 to 21.2, DebugLog
22.5.1.2 to 22.6.1.2, Widgets 17.3.8.5.5.2 to 17.3.10.5.5.2.

`grep -rn '__Attach' --include='*.lua'` outside `libs/` and `tests/_kit/` finds no host call site, so
no host-supplied member moved.

### Blockers

One, met in the re-vendor commit:

- **The Options stub owes `O.PositionBlock`.** Options document, *What changed at this version: the
  flow seams*: "A new public member, `O.PositionBlock`, is owed by every consumer's degradation stub
  at the re-vendor." `settings/OptionsSetup.lua` answers `{}, nil`, the shape of the live call with
  no rows and no `onReset`.

Consumer pins moved in the same commit: `tests/loader.lua` gains the nine new files in XML order, and
`tests/test_libka0s.lua`'s `MODULES` expectations name them and the Charts major. No suite here pins
`DebugLogDiagnostics 5` or a composite key.

## 3h. Unrecorded tags

The audit's listing prints only v1.84.0, this bundle's own tag: every earlier vendored tag has a
bundle, the last four in the span bundle `2026-10-31-v1.80.0-v1.83.0`.

## 3i. Icons

`grep -n 'LibKa0s icons:' CLAUDE.md`: the declaration stays `close, copy, clear, eye, settings.`,
directly under the provenance line. Nothing in this range draws a new name here. A pruned icon still
resolves to a path and draws blank, and hand lists have drifted before, so the owner's in-client
smoke remains the backstop.

## 3j. Tests that assume the whole folder

`tests/test_mediasetup.lua` reads declared names only and stays green after the prune. No blocker.
