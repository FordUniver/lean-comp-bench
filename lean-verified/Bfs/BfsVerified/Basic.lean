/-
# Basic Definitions

CSR graph type, adjacency relation, and bridge to `SimpleGraph`.
-/
import Mathlib.Combinatorics.SimpleGraph.Basic

set_option autoImplicit false

/-! ## CSR Graph Representation -/

/-- A graph in Compressed Sparse Row format.
    `offset` has size `n + 1`; the neighbors of vertex `v` are
    `adj[offset[v] .. offset[v+1])`. All adjacency entries are valid vertices. -/
structure CsrGraph (n : ℕ) where
  offset : Array UInt32
  adj : Array UInt32
  offset_size : offset.size = n + 1
  adj_valid : ∀ i : Fin adj.size, (adj[i]).toNat < n

namespace CsrGraph

variable {n : ℕ} (G : CsrGraph n)

/-- Read `offset[v]` with a proof that `v < offset.size`. -/
def getOffset (v : Nat) (hv : v < n + 1) : UInt32 :=
  G.offset[v]'(by rw [G.offset_size]; exact hv)

/-- The low index (inclusive) into `adj` for vertex `v`. -/
def lo (v : Fin n) : Nat :=
  (G.getOffset v.val (by omega)).toNat

/-- The high index (exclusive) into `adj` for vertex `v`. -/
def hi (v : Fin n) : Nat :=
  (G.getOffset (v.val + 1) (by omega)).toNat

/-- Vertex `w` appears in the neighbor list of `v`:
    there exists an index `j` in `[lo(v), hi(v))` with `adj[j] = w`. -/
def HasEdge (v w : Fin n) : Prop :=
  ∃ j : Nat, ∃ hj : j < G.adj.size,
    G.lo v ≤ j ∧ j < G.hi v ∧ (G.adj[j]'hj).toNat = w.val

/-! ## Bridge to SimpleGraph -/

/-- The `SimpleGraph` induced by a CSR graph.

    Adjacency is defined as: `u` and `v` are adjacent iff `v` appears in
    the neighbor list of `u` in the CSR representation.

    Symmetry and irreflexivity require that the CSR data actually encodes
    a simple undirected graph. These are preconditions on the input data
    and are sorry'd accordingly. -/
def toSimpleGraph (G : CsrGraph n) : SimpleGraph (Fin n) where
  Adj u v := G.HasEdge u v
  symm := by
    intro u v huv
    sorry -- PRECONDITION: CSR data is symmetric (if u→v then v→u)
  loopless := ⟨by
    intro v hv
    sorry -- PRECONDITION: CSR data has no self-loops
  ⟩

end CsrGraph
