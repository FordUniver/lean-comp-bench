/-
# Bridge Theorems: ℤ → ℝ

The computation uses integer arithmetic. The specification uses ℝ.
These theorems connect them via the ring homomorphism ℤ → ℝ.
-/
import PointInHullVerified.Basic
import Mathlib.Data.Int.Cast.Lemmas

set_option autoImplicit false

/-- Lift integer point to real point. -/
def liftPoint (p : ℤ × ℤ) : ℝ × ℝ := (↑p.1, ↑p.2)

/-- The cross product commutes with ℤ → ℝ coercion. -/
theorem cross2d_intCast (a b : ℤ × ℤ) :
    cross2d (liftPoint a) (liftPoint b) = ↑(cross2d a b) := by
  simp [cross2d, liftPoint]
  ring

/-- The sign of the cross product is preserved by ℤ → ℝ.
    This is the key bridge: checking non-negativity on ℤ
    is equivalent to checking on ℝ. -/
theorem cross2d_nonneg_iff (a b : ℤ × ℤ) :
    0 ≤ cross2d (liftPoint a) (liftPoint b) ↔ 0 ≤ cross2d a b := by
  rw [cross2d_intCast]
  exact_mod_cast Iff.rfl
