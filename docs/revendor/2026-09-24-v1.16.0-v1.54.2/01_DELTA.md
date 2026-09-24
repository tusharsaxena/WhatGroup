Delta: LibKa0s v1.16.0 -> v1.54.2 (span: v1.16.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2)

# 01 — Delta: the consolidated span bundle

Written 2026-09-24 for plan item WG-29 of the 2026-09-23 review and standards-audit remediation
(finding WHATGROUP-A-10, audit row WG-71), on branch `feat/2026-09-23-review-audit-remediation`.
It is the sanctioned record for a lapsed span (`audit-review-history`, standard v2.65.0): one folder
named for the first and last unrecorded tags, holding `01_DELTA.md` and `05_SUMMARY.md` only. The
re-vendors it records were each done and gated when they landed; nothing is re-vendored here and no
code changes. The per-tag deliberation files (02 to 04) are absent on purpose: a span carried by
sweeps had none to record, and per-tag back-fill folders are not written.

## The true previous base

The span's line-1 endpoints are the first and last **unrecorded** tags, not a delta base. The last
tag this store recorded before the span is **v1.15.0** (`docs/revendor/2026-08-25/`, the store's
first bundle and the audit horizon). The payload at the start of the span, vendored at `8edf4f4`
("chore(libs): re-vendor LibKa0s v1.15.0"), is that tag. Read as a delta, the span runs
**v1.15.0 -> v1.54.2**, and the next recorded bundle, `docs/revendor/2026-09-23-v1.55.0/`, correctly
names v1.54.2 as its base (vendored at `7f38ddd`).

Seven tags inside that range already have their own bundles and are **not** in the span list:
v1.25.0 (`2026-09-03/`), v1.30.0 (`2026-09-12/`), v1.31.0, v1.32.0, v1.33.0 (`2026-09-12-v1.3x.0/`)
and v1.34.0 (`2026-09-13-v1.34.0/`). Two of the bare-dated ones name a second tag on line 1 as their
base (v1.24.0 in `2026-09-03/`, v1.29.0 in `2026-09-12/`). The audit check reads only the last tag of
a bare-dated line 1, so those two count as unrecorded and are listed here.

Tags the library cut that this addon never vendored are not in the span either, because nothing
here ever carried them: v1.17.0, v1.20.0, v1.21.0, v1.22.0, v1.40.0, v1.41.0, v1.46.0, v1.48.0,
v1.48.1, v1.49.0, v1.49.1, v1.54.0 and v1.54.1.

## How the list was derived

The `AUDIT.md` re-vendor comparison (WowAddonStandards v2.65.0), run before this bundle existed:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)          # -> 2026-08-25
git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit | while read -r c; do
  git show "$c:CLAUDE.md" 2>/dev/null |
    grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
    grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1
done | sort -uV > vendored.txt                                        # 37 tags, 38 commits
# recorded.txt: the recorded-side loop over docs/revendor/*/           # 9 tags
grep -vxF -f recorded.txt vendored.txt                                 # 28 tags, the span above
```

Every in-scope commit resolved a tag from its `CLAUDE.md` provenance line, so no README.md
fallback was needed. After this bundle, the same comparison prints nothing.

**Correction to the item text.** WG-29 and the audit (WG-71) named 25 tags, v1.18.0 to v1.53.0.
That count used a bare-date `--since`, which drops the horizon day's own commits (v1.16.0,
`ce69ccc`, on 2026-08-25), and walked `libs/LibKa0s` alone, which misses the kit-only v1.43.0 and
v1.54.2 re-vendors. The v2.65.0 comparison finds 28 tags in 28 commits. The folder is named for the
span it actually covers, `2026-09-24-v1.16.0-v1.54.2`, not the item's `v1.18.0-v1.53.0`.

## The 28 vendoring commits

"Sweep" means the tag was re-vendored across the collection in a bulk pass rather than on a
deliberation of its own. "Folded" means the copy rode inside a WhatGroup feature commit rather than
standing alone (`versioning-git` makes that a SHOULD, not a MUST). The finding's three folded
commits are `f98ef41` (v1.18.0), `127baa1` (v1.24.0) and `f74893a` (v1.42.0); `7f38ddd` (v1.54.2)
is a fourth, a kit-only copy folded into the prose-gate swap.

| Tag | Commit | Date | Subject | Carried by |
|---|---|---|---|---|
| v1.16.0 | `ce69ccc` | 2026-08-25 | Re-vendor LibKa0s v1.16.0 | sweep |
| v1.18.0 | `f98ef41` | 2026-08-26 | Adopt options-ui-§12: the global reset is a profile reset, and wire the profile callbacks it needs | folded |
| v1.18.1 | `497c96f` | 2026-08-26 | Re-vendor LibKa0s v1.18.1: the landing logo stops pooling its texture | sweep |
| v1.19.0 | `5a61ddd` | 2026-08-27 | Carry LibKa0s v1.19.0 | sweep |
| v1.23.0 | `0b7d49d` | 2026-09-01 | Re-vendor LibKa0s v1.23.0: the tabbed options page arrives | standalone |
| v1.24.0 | `127baa1` | 2026-09-02 | feat(settings): master controls and the mandatory tab strip | folded (feat/settings-revamp-v2, merged `9b35a23`) |
| v1.26.0 | `caf1cbd` | 2026-09-08 | M3-05: re-vendor LibKa0s v1.26.0 | 2026-09-07 remediation plan (merged `58bc280`) |
| v1.27.0 | `a8ef42c` | 2026-09-08 | M4-01: adopt LibKa0s v1.27.0, and wire the gate that came with it | 2026-09-07 remediation plan (merged `58bc280`) |
| v1.28.0 | `4bccc0e` | 2026-09-09 | re-vendor LibKa0s v1.28.0 — the perf usage block renders correctly | sweep |
| v1.29.0 | `e581517` | 2026-09-09 | re-vendor LibKa0s v1.29.0 — the JSON dump folds into the report step | sweep |
| v1.35.0 | `cab07ec` | 2026-09-14 | Re-vendor LibKa0s v1.35.0 (Options 18.16.5.3, kit 20) | chore/2026-09-14-libka0s-v1.35.0 (merged `0c14082`) |
| v1.36.0 | `1294cd1` | 2026-09-15 | Re-vendor LibKa0s v1.36.0 | chore/2026-09-14-revendor-v1.36.0 (merged `763533f`) |
| v1.36.1 | `6d707ec` | 2026-09-15 | Re-vendor LibKa0s v1.36.1: fix pooled CheckBox gold-fill leak | same branch |
| v1.36.2 | `1d4256a` | 2026-09-15 | Re-vendor LibKa0s v1.36.2: drop grid-cell yellow fill, ASCII-only strings | same branch |
| v1.37.0 | `f6ae5fd` | 2026-09-16 | Re-vendor LibKa0s v1.37.0 | sweep |
| v1.38.0 | `130676c` | 2026-09-16 | Re-vendor LibKa0s v1.38.0: a bare /wg opens the settings panel | sweep |
| v1.39.0 | `f4a7763` | 2026-09-16 | Re-vendor LibKa0s v1.39.0: the launcher major and the tab peel | sweep |
| v1.42.0 | `f74893a` | 2026-09-17 | Disabling the addon stands it down, and a perf run takes the same latch | folded (the stand-down feature) |
| v1.43.0 | `c0c03a6` | 2026-09-17 | Re-vendor LibKa0s v1.43.0: kit revision 23 bounds every run and stops holding built instances | sweep (kit only) |
| v1.44.0 | `b6d86d9` | 2026-09-19 | Re-vendor LibKa0s v1.44.0 | chore/libka0s-v1.44.0 (merged `c4abfbf`) |
| v1.45.0 | `fca457d` | 2026-09-19 | Re-vendor LibKa0s v1.45.0 | chore/libka0s-v1.45.0 (merged `ad0b09d`) |
| v1.46.1 | `f2dfddc` | 2026-09-19 | Re-vendor LibKa0s v1.46.1 | chore/libka0s-v1.46.1 (merged `e250cce`) |
| v1.47.0 | `8f2af6f` | 2026-09-20 | Re-vendor LibKa0s v1.47.0 | chore/revendor-libka0s-v1.47.0 (merged `1eeb9a4`) |
| v1.50.0 | `3f76728` | 2026-09-21 | Re-vendor LibKa0s v1.50.0 | sweep |
| v1.51.0 | `cd4c36d` | 2026-09-22 | Re-vendor LibKa0s v1.51.0 | sweep |
| v1.52.0 | `2746e8a` | 2026-09-22 | Re-vendor LibKa0s v1.52.0 | sweep |
| v1.53.0 | `6246775` | 2026-09-22 | Re-vendor LibKa0s v1.53.0 | sweep |
| v1.54.2 | `7f38ddd` | 2026-09-22 | Adopt the kit's US-English gate, and delete the copy this repo was keeping | folded (kit revision 24; library bytes identical to v1.53.0) |

Each commit copied both payloads whole from the tag and rolled the provenance line in the same
commit, which `tests/test_vendor_sync.lua` enforces. Each was green on lint and the headless suite
when it landed; the commit bodies record the counts.
