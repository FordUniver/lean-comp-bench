/-
# Specification Theorems

The main theorem: for a convex CCW polygon, the cross product test
characterizes convex hull membership.

The forward direction (hull ⊆ half-planes) is provable.
The backward direction (half-planes ⊆ hull) requires fan triangulation — sorry'd.
-/
import PointInHullVerified.Basic

set_option autoImplicit false

open scoped Convex

/-- Forward direction: any point in the convex hull satisfies all cross product
    conditions. Each half-plane is convex and contains all vertices, so
    `convexHull_min` gives the result.

    STATUS: Provable with ~1 page of Lean. Key steps:
    1. The set {q | 0 ≤ cross2d edge (q - v)} is convex (preimage of [0,∞) under linear map)
    2. All vertices lie in each half-plane (from the CCW condition)
    3. Apply convexHull_min -/
theorem convexHull_subset_halfplanes
    {n : ℕ} (P : ConvexPolygonCCW n) (q : ℝ × ℝ)
    (hq : q ∈ convexHull ℝ (Set.range P.vertices)) :
    allCrossNonneg n P.vertices q := by
  sorry -- PROVABLE: ~2-3 days effort

/-- Backward direction: if all cross product conditions hold, the point
    is in the convex hull.

    STATUS: Research-level. Requires showing the intersection of half-planes
    defined by a convex CCW polygon equals its convex hull. Proof approaches:
    - Fan triangulation from vertex 0: find triangle v_0, v_i, v_{i+1}
      containing q (using binary search on angles), express q as convex
      combination of the three vertices.
    - Special case of Weyl-Minkowski theorem (H-rep = V-rep for polytopes).

    Neither approach has mathlib infrastructure. This is a research target
    for the proposal. -/
theorem halfplanes_subset_convexHull
    {n : ℕ} (P : ConvexPolygonCCW n) (q : ℝ × ℝ)
    (hcross : allCrossNonneg n P.vertices q) :
    q ∈ convexHull ℝ (Set.range P.vertices) := by
  sorry -- RESEARCH-LEVEL: needs fan triangulation

/-- The full characterization. -/
theorem mem_convexHull_iff_allCrossNonneg
    {n : ℕ} (P : ConvexPolygonCCW n) (q : ℝ × ℝ) :
    q ∈ convexHull ℝ (Set.range P.vertices) ↔
      allCrossNonneg n P.vertices q :=
  ⟨convexHull_subset_halfplanes P q, halfplanes_subset_convexHull P q⟩
