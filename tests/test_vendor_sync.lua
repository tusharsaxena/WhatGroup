-- tests/test_vendor_sync.lua — the vendored-payload gate. The whole implementation lives in
-- `tests/_kit/vendor_sync.lua`, inside the payload it checks; this file is the call.
--
-- WHAT IT CHECKS: that `libs/LibKa0s/` and `tests/_kit/` in this repo are exactly what the LibKa0s
-- repo published at the tag THIS README says it bundles.
--
-- THE PROVENANCE LINE IS AN INPUT, NOT A CONSTANT. It is read out of README.md rather than
-- hardcoded: a provenance line and a vendored payload that disagree is precisely the drift this
-- gate exists to catch, so the claim has to be the thing under test. Bump the line and the bytes
-- in the same commit.
--
-- ONE NORMALIZATION, AND ONLY ONE: `git show` hands back the stored blob, which is LF, while the
-- working tree is CRLF because `.gitattributes` pins `* text=auto eol=crlf`. CR is stripped from
-- the working-tree side so the file is compared to the blob it round-trips to. Nothing else is
-- normalized — a real fork in content still fails. (Carried in verbatim from
-- AbsorbTracker/tests/test_vendor_sync.lua, which is where the paragraph was written; the strip
-- itself now lives in the kit module.)
--
-- A MISSING SIBLING CHECKOUT IS A SKIP, NOT A PASS: when `../LibKa0s` is not there the cases
-- report SKIP with the reason naming the absent checkout, and the run's exit code stays 0.

local VendorSync = dofile("tests/_kit/vendor_sync.lua")

VendorSync.register(_G.WHATGROUP_TEST, {})
