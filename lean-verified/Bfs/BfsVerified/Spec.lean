/-
# Specification Theorems

BFS correctness: the computed distance array equals `SimpleGraph.dist`
for reachable vertices and `-1` for unreachable ones.

The main theorem is research-level and sorry'd — it requires induction
on the BFS loop invariant and connecting the layer structure to
`SimpleGraph.dist` (shortest path metric in mathlib).
-/
import BfsVerified.Basic
import BfsVerified.Algorithm
import Mathlib.Combinatorics.SimpleGraph.Metric
import Mathlib.Combinatorics.SimpleGraph.Connectivity.Connected

set_option autoImplicit false

/-! ## BFS Correctness -/

/-- For reachable vertices, BFS computes the correct distance.

    STATUS: Research-level. Requires:
    1. BFS loop invariant: after processing layer `d`, all vertices at
       distance ≤ d have been discovered with correct distances.
    2. Connection between the queue layer structure and `SimpleGraph.Walk`
       length, relating to `SimpleGraph.dist`.

    Proof approach: define a loop invariant predicate on
    `(visited, dist, queue, qhead, qtail)` and show it is preserved by
    each iteration. The post-condition gives the theorem. -/
theorem bfs_correct_reachable {n : ℕ} (hn : 0 < n) (G : CsrGraph n) (start : Fin n)
    (result : Array Int64)
    (hresult : result = bfsCompute G start hn)
    (v : Fin n)
    (hreach : G.toSimpleGraph.Reachable start v)
    (hv : v.val < result.size) :
    result[v.val] = Int64.ofNat (G.toSimpleGraph.dist start v) := by
  sorry -- RESEARCH: needs BFS invariant induction

/-- For unreachable vertices, BFS returns -1.

    STATUS: Research-level. Follows from the invariant that only
    reachable vertices are ever enqueued (by induction on the BFS
    exploration), so unreachable vertices keep their initial value. -/
theorem bfs_correct_unreachable {n : ℕ} (hn : 0 < n) (G : CsrGraph n) (start : Fin n)
    (result : Array Int64)
    (hresult : result = bfsCompute G start hn)
    (v : Fin n)
    (hunreach : ¬G.toSimpleGraph.Reachable start v)
    (hv : v.val < result.size) :
    result[v.val] = -1 := by
  sorry -- RESEARCH: needs BFS invariant induction

/-- Combined correctness statement using classical logic. -/
theorem bfs_correct {n : ℕ} (hn : 0 < n) (G : CsrGraph n) (start : Fin n)
    (result : Array Int64)
    (hresult : result = bfsCompute G start hn)
    (v : Fin n) (hv : v.val < result.size) :
    (G.toSimpleGraph.Reachable start v →
      result[v.val] = Int64.ofNat (G.toSimpleGraph.dist start v)) ∧
    (¬G.toSimpleGraph.Reachable start v →
      result[v.val] = -1) :=
  ⟨fun hr => bfs_correct_reachable hn G start result hresult v hr hv,
   fun hu => bfs_correct_unreachable hn G start result hresult v hu hv⟩
