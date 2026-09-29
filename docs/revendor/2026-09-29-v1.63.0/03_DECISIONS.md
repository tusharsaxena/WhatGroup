# Decisions (WhatGroup)

No adoption interview and no GitHub issues for this re-vendor: the collection plan decided the one adoption up front (owner decision D1, `Ka0sAddonsCommonTasks/docs/2026-09-29-SMOKE_REWORK_AND_PROFILE_VERB/`, item SP-WG-02, spec S3).

- **C1, Slash minor 17's profile surface: adopted, by SP-WG-02 only.** This commit carries the copy and the stub half: the degraded `Sl` in `settings/Slash.lua` gains `CliProfile` and `ProfileSwitch`, each printing the library-absent line for `/wg profile` and switching nothing (options-ui-§1 route (b), the shape `docs/api/Slash/version-17-docs.md` gives), so the surface-parity case is green again. The verb itself (the `profile` COMMANDS row, the descriptor's `profiles` field and `profile` on the live list) lands in SP-WG-02's second commit.
- **C2, `lib.ProfileNames`: not adopted.** WhatGroup has no profile sub-tree to feed; nothing is filed, because nothing is owed.
- Nothing else in v1.63.0 is new; no other surface is adopted.
- `docs/test-cases.md` regenerated (837 -> 838: one degraded-stub case in `tests/test_libka0s.lua`) and the README badge rolled with it.
