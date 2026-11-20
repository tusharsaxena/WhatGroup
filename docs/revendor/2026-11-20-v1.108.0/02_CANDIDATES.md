# 02 Candidates, LibKa0s v1.107.0 -> v1.108.0

Sources: `git -C ../LibKa0s log --oneline v1.107.0..v1.108.0`; LibKa0s CHANGELOG.md, the v1.108.0 block and its *What a consumer owes at its re-vendor*.

**Class A, delivered on the copy alone**
- The shared menu (WidgetsDropdown minor 3): a submenu row's arrow takes the menu palette, and a secret label is not measured. Reaches this addon's settings dropdowns through the library's rows.
- The popup's Shell (SkinPaint minor 20): no change for a window that passes no `keepEdge`; the popup's art and edges follow as before.
- Widgets minor 30's owner check: nothing is reported until a host registers `W.OwnerWarnings`; this addon builds no owner-less library widget.

**Class B, host change required**
- `W.OwnerWarnings(owner, sink)` (Widgets minor 30, 97.1): a debug-gated report of owner-less library widgets under an owned frame. Not taken in this run: every library widget this addon builds (`W.HeaderButtons`, through `owner = addonName`) already names its owner. Noted for the lead, no issue filed (the run skips the interview and filing).
- `Core.ApplySkin` `skinBands` (Core minor 19, 97.16): for a host table; the popup passes none. Not applicable.

**Class C, whole-module**: Callout, WaypointArrow and Charts stay unconsumed; nothing in this addon draws a call-out, an arrow or a chart.

**Blockers (3g)**: kit revision 58's typed-value read of the degraded `NS.SKIN` table, fixed in the copy commit (01_DELTA.md).
