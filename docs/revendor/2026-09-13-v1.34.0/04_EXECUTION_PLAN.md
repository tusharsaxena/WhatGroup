# 04 — Execution plan

1. **Copy.** `libs/LibKa0s/` and `tests/_kit/` come whole from `git archive v1.34.0`. Afterwards both
   diffs are empty in content and in bytes.
2. **Ripple.** Roll every live reference to the bundled version:
   - `CLAUDE.md:71`, the provenance line;
   - `docs/testing.md:250`, the sibling-checkout state sentence;
   - `docs/smoke-tests.md:683` (12a.3). It named the kit's geometry flip "revision 19 at the
     earliest". Revision 19 does not ship it, and the kit now says 20 at the earliest.

   Dated records (reviews, audits, earlier revendor bundles) stay as they are. The test total does
   not move, so `docs/test-cases.md` and the README test badge do not move either.
3. **Gate.** `lua tests/run.lua`, `luacheck .` and `lizard -C 15`, all green; CR == LF on every
   edited and new file.
4. **Commit.** One commit on top of `0fb1ef9`, carrying both payloads, the provenance line, its
   references and this bundle.
