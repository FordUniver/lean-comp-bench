/-
# Specification Theorems

The main theorem: for a convex CCW polygon, the cross product test
characterizes convex hull membership.

The forward direction (hull ⊆ half-planes) is provable.
The backward direction (half-planes ⊆ hull) requires fan triangulation — sorry'd.
-/
import PointInHullVerified.Basic
import Mathlib.Topology.Algebra.Module.Basic

set_option autoImplicit false

open scoped Convex

/-! ## Linearity of `cross2d` in the second argument -/

/-- `cross2d` distributes over addition in the second argument. -/
theorem cross2d_add_right {α : Type*} [CommRing α] (a b c : α × α) :
    cross2d a (b + c) = cross2d a b + cross2d a c := by
  unfold cross2d
  simp [Prod.fst_add, Prod.snd_add]
  ring

/-- `cross2d` commutes with scalar multiplication in the second argument. -/
theorem cross2d_smul_right (a : ℝ × ℝ) (r : ℝ) (b : ℝ × ℝ) :
    cross2d a (r • b) = r * cross2d a b := by
  unfold cross2d
  simp [Prod.smul_fst, Prod.smul_snd]
  ring

/-- `cross2d` distributes over subtraction in the second argument. -/
theorem cross2d_sub_right {α : Type*} [CommRing α] (a b c : α × α) :
    cross2d a (b - c) = cross2d a b - cross2d a c := by
  unfold cross2d
  simp [Prod.fst_sub, Prod.snd_sub]
  ring

/-! ## Convexity of half-planes defined by `cross2d` -/

/-- The half-plane `{q | 0 ≤ cross2d edge (q - v)}` is convex.

    Proof: `q ↦ cross2d edge (q - v)` is an affine function (linear + constant),
    so its upper level set is convex. We verify the convex combination condition
    directly using linearity of `cross2d` in the second argument. -/
theorem convex_cross2d_halfplane (edge v : ℝ × ℝ) :
    Convex ℝ {q : ℝ × ℝ | 0 ≤ cross2d edge (q - v)} := by
  rw [convex_iff_add_mem]
  intro x hx y hy a b ha hb hab
  show 0 ≤ cross2d edge (a • x + b • y - v)
  -- Key identity: a • x + b • y - v = a • (x - v) + b • (y - v)
  -- since a + b = 1, so v = a • v + b • v
  have hv : a • x + b • y - v = a • (x - v) + b • (y - v) := by
    have hv1 : (a + b) • v = v := by rw [hab, one_smul]
    calc a • x + b • y - v
        = a • x + b • y - (a + b) • v := by rw [hv1]
      _ = a • x + b • y - (a • v + b • v) := by rw [add_smul]
      _ = a • (x - v) + b • (y - v) := by simp [smul_sub]; abel
  rw [hv, cross2d_add_right, cross2d_smul_right, cross2d_smul_right]
  exact add_nonneg (mul_nonneg ha hx) (mul_nonneg hb hy)

/-! ## All vertices lie in each half-plane (from convex polygon structure)

This is the geometric content: for a convex polygon with CCW-ordered vertices,
every vertex lies on the non-negative side of every directed edge. The CCW
condition in `ConvexPolygonCCW` asserts only consecutive triples turn left;
deriving the global property requires induction on the polygon structure.

This is left as `sorry` — it is the main gap, and proving it from the
consecutive-triple CCW condition is a real theorem about convex polygons
that requires careful induction (roughly: going around the polygon, vertices
can only move further into the half-plane, never cross the edge line). -/
theorem allVerticesInHalfPlane
    {n : ℕ} (P : ConvexPolygonCCW n) (i j : Fin n) :
    0 ≤ cross2d (P.vertices i.nextMod - P.vertices i)
                (P.vertices j - P.vertices i) := by
  sorry -- NONTRIVIAL: requires induction on convex polygon structure

/-- Forward direction: any point in the convex hull satisfies all cross product
    conditions. Each half-plane is convex and contains all vertices, so
    `convexHull_min` gives the result. -/
theorem convexHull_subset_halfplanes
    {n : ℕ} (P : ConvexPolygonCCW n) (q : ℝ × ℝ)
    (hq : q ∈ convexHull ℝ (Set.range P.vertices)) :
    allCrossNonneg P.vertices q := by
  intro i
  -- Define the half-plane for edge i
  let H := {q : ℝ × ℝ | 0 ≤ cross2d (P.vertices i.nextMod - P.vertices i) (q - P.vertices i)}
  -- It suffices to show the convex hull is contained in H
  suffices h : convexHull ℝ (Set.range P.vertices) ⊆ H from h hq
  apply convexHull_min
  · -- All vertices are in H
    intro x hx
    obtain ⟨j, rfl⟩ := hx
    exact allVerticesInHalfPlane P i j
  · -- H is convex
    exact convex_cross2d_halfplane _ _

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
    (hcross : allCrossNonneg P.vertices q) :
    q ∈ convexHull ℝ (Set.range P.vertices) := by
  sorry -- RESEARCH-LEVEL: needs fan triangulation

/-- The full characterization. -/
theorem mem_convexHull_iff_allCrossNonneg
    {n : ℕ} (P : ConvexPolygonCCW n) (q : ℝ × ℝ) :
    q ∈ convexHull ℝ (Set.range P.vertices) ↔
      allCrossNonneg P.vertices q :=
  ⟨convexHull_subset_halfplanes P q, halfplanes_subset_convexHull P q⟩
