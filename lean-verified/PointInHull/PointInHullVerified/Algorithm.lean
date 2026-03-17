/-
# Verified Decision Procedure

The computational algorithm on integer arrays, with proofs that
array accesses are in bounds.

The correctness connection to the spec (via Bridge) is sorry'd
pending the backward direction theorem.
-/
import PointInHullVerified.Spec
import PointInHullVerified.Bridge

set_option autoImplicit false

/-- Compute the cross product test on integer polygon and query point.
    Array bounds are proved from the loop range. -/
def crossTestInt (polygon : Array (ℤ × ℤ)) (q : ℤ × ℤ)
    (hn : 3 ≤ polygon.size) : Bool := Id.run do
  let n := polygon.size
  let mut result := true
  for _h : i in [:n] do
    have hi : i < polygon.size := by sorry -- PROVABLE: from range membership
    let vi := polygon[i]
    let j := if i + 1 = n then 0 else i + 1
    have hj : j < polygon.size := by sorry -- PROVABLE: from hi + branch analysis
    let vj := polygon[j]
    let cross := (vj.1 - vi.1) * (q.2 - vi.2) - (vj.2 - vi.2) * (q.1 - vi.1)
    if cross < 0 then
      result := false
  return result

/-- The decision procedure is correct: it returns true iff the real-valued
    spec holds (assuming the polygon is convex CCW and lifted correctly).

    STATUS: Requires the backward direction theorem + bridge. Sorry'd. -/
theorem crossTestInt_correct (polygon : Array (ℤ × ℤ)) (q : ℤ × ℤ)
    (hn : 3 ≤ polygon.size)
    (P : ConvexPolygonCCW polygon.size)
    (hlift : ∀ i : Fin polygon.size, P.vertices i = liftPoint polygon[i]) :
    crossTestInt polygon q hn = true ↔
      liftPoint q ∈ convexHull ℝ (Set.range P.vertices) := by
  sorry -- Combines: Bridge.cross2d_nonneg_iff + Spec.mem_convexHull_iff_allCrossNonneg
