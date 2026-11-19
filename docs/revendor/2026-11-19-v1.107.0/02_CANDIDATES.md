# 02 Candidates, LibKa0s v1.106.0 -> v1.107.0

Sources: `git -C ../LibKa0s log --oneline v1.106.0..v1.107.0`; LibKa0s CHANGELOG.md, the v1.107.0 block and its *What a consumer owes at its re-vendor*.

**Class A, delivered on the copy alone**
- Nothing visible in this addon. The strip changes (marks [?][settings][close], settings on by default, close only with `onClose`, the header's tints, the tighter pitch, the tooltip always above) reach only a `DragHandle`, and this addon builds none.

**Class B, host change required**: none. `tooltipPlace` is retired, and this addon never passed it to a strip.

**Class C, whole-module**: none new.

**Blockers (3g)**: none.
