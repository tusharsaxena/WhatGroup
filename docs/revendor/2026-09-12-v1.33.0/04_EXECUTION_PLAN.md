# 04 — Execution plan

1. **Copy.** `libs/LibKa0s/` and `tests/_kit/` come whole from `git archive v1.33.0`. Afterwards both
   diffs are empty in content and in bytes.
2. **Ripple.** Roll every live reference to the bundled version:
   - `CLAUDE.md:71`, the provenance line;
   - `docs/testing.md:250`, the sibling-checkout state sentence;
   - `docs/smoke-tests.md:661` (12a.3), which named the kit's geometry flip "revision 18 at the earliest"; revision 18 does not ship it, and the kit now says 19 at the earliest;
   - and the comments that described kit revision 17's `OnProfileCopied` key:
     - `tests/test_debuglog.lua:436`;
     - `core/WhatGroup.lua:198`;

   Dated records (reviews, audits, earlier revendor bundles) stay as they are. The test total does
   not move, so `docs/test-cases.md` and any README test badge do not move either.
3. **Gate.** `lua tests/run.lua`, `luacheck .` and `lizard -C 15`, all green; CR == LF on every
   edited and new file.
4. **Commit.** One commit carrying both payloads, the provenance line, its references, the comment
   corrections and this bundle.
