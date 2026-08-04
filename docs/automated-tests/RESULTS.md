# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

| Run | Version | Lint w/e | Tests | Perf | CCN warn | Max CCN | Verdict |
|---|---|---|---|---|---|---|---|
| [`20260804-122705`](20260804-122705/) | 1.3.0 | 0/0 | 415/415 | skip | 3 | 22 | **green** |

## Complexity watch list

Current state as of [`20260804-122705`](20260804-122705/) — not that run's diff.
Every function `lizard` warned on and every file in `layout-§1`'s 1000–1500 on-notice band,
each with a one-line disposition.

| `WhatGroup:CaptureGroupInfo` | 22 | `core/WhatGroup.lua` | **Accepted.** Twenty-odd `or` fallbacks in one flat table constructor — breadth, not depth. |
| `WhatGroup:ShowNotification` | 22 | `core/WhatGroup.lua` | **Accepted.** Nine independent toggle guards mapping 1:1 onto the Notifications panel. |
| `Helpers.BuildMainContent` | 17 | `settings/Panel.lua` | **Peel next** — the lowest-value of the three; the logo and description blocks lift out cleanly. |

**Files in the 1000–1500 band:** None.
