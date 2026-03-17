/-
# Basic Definitions

2D cross product, convex polygon type, and the all-edges predicate.
-/
import Mathlib.Analysis.Convex.Hull
import Mathlib.Analysis.Convex.Combination

set_option autoImplicit false

/-- The 2D cross product (signed area of parallelogram).
    Positive when `b` is counterclockwise from `a`. -/
def cross2d {α : Type*} [Ring α] (a b : α × α) : α :=
  a.1 * b.2 - a.2 * b.1

/-- Wrap index modulo n, for polygon edge indexing. -/
def Fin.nextMod (i : Fin n) : Fin n :=
  ⟨(i.val + 1) % n, Nat.mod_lt _ (Nat.pos_of_ne_zero (by omega))⟩

/-- A convex polygon with vertices in counterclockwise order.
    The convexity condition says every consecutive triple turns left. -/
structure ConvexPolygonCCW (n : ℕ) where
  vertices : Fin n → ℝ × ℝ
  n_ge_3 : 3 ≤ n
  ccw : ∀ i : Fin n,
    0 ≤ cross2d
      (vertices i.nextMod - vertices i)
      (vertices i.nextMod.nextMod - vertices i)

/-- The cross product test: point `q` has non-negative cross product
    with every directed edge of the polygon. -/
def allCrossNonneg (n : ℕ) (vertices : Fin n → ℝ × ℝ) (q : ℝ × ℝ) : Prop :=
  ∀ i : Fin n,
    0 ≤ cross2d (vertices i.nextMod - vertices i) (q - vertices i)
