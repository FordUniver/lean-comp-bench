/-
  Sorting benchmark: quicksort and mergesort on UInt64 arrays.
  LCG PRNG (Knuth constants) — identical across C/Rust/Lean.
-/

structure Lcg where
  state : UInt64

@[inline] def Lcg.new (seed : UInt64) : Lcg := { state := seed }

@[inline] def Lcg.next (rng : Lcg) : UInt64 × Lcg :=
  let s := rng.state * 6364136223846793005 + 1442695040888963407
  (s, { state := s })

-- Unchecked array ops: getD/setIfInBounds add a branch but it's trivially predicted.
-- swap needs both indices valid; we implement via get/set.
@[inline] def g (a : Array UInt64) (i : Nat) : UInt64 := a.getD i 0

@[inline] def s (a : Array UInt64) (i : Nat) (v : UInt64) : Array UInt64 :=
  a.setIfInBounds i v

@[inline] def swp (a : Array UInt64) (i j : Nat) : Array UInt64 :=
  let vi := g a i
  let vj := g a j
  s (s a i vj) j vi

def generateArray (n : Nat) (seed : UInt64) : Array UInt64 := Id.run do
  let mut rng := Lcg.new seed
  let mut arr := Array.mkEmpty n
  for _ in [:n] do
    let (val, rng') := rng.next
    rng := rng'
    arr := arr.push val
  return arr

@[inline]
def partition (arr : Array UInt64) (lo hi : Nat) : Array UInt64 × Nat := Id.run do
  let pivot := g arr hi
  let mut a := arr
  let mut i := lo
  for j in [lo:hi] do
    if g a j <= pivot then
      a := swp a i j
      i := i + 1
  a := swp a i hi
  return (a, i)

def quicksort (arr : Array UInt64) : Array UInt64 := Id.run do
  let n := arr.size
  if n <= 1 then return arr
  let mut a := arr
  let mut stack : Array (Nat × Nat) := #[(0, n - 1)]
  while h : stack.size > 0 do
    let (lo, hi) := stack[stack.size - 1]'(by omega)
    stack := stack.pop
    if lo < hi then
      let (a', p) := partition a lo hi
      a := a'
      if p > 0 then stack := stack.push (lo, p - 1)
      if p + 1 <= hi then stack := stack.push (p + 1, hi)
  return a

def mergesort (arr : Array UInt64) : Array UInt64 := Id.run do
  let n := arr.size
  if n <= 1 then return arr
  let mut a := arr
  let mut buf := Array.replicate n (0 : UInt64)
  let mut width := 1
  while width < n do
    let mut lo := 0
    while lo < n do
      let mid := min (lo + width - 1) (n - 1)
      let hi := min (lo + 2 * width - 1) (n - 1)
      if mid < hi then
        for k in [lo:hi+1] do
          buf := s buf k (g a k)
        let mut i := lo
        let mut j := mid + 1
        let mut k := lo
        while i <= mid && j <= hi do
          if g buf i <= g buf j then
            a := s a k (g buf i)
            i := i + 1
          else
            a := s a k (g buf j)
            j := j + 1
          k := k + 1
        while i <= mid do
          a := s a k (g buf i)
          i := i + 1
          k := k + 1
        while j <= hi do
          a := s a k (g buf j)
          j := j + 1
          k := k + 1
      lo := lo + 2 * width
    width := width * 2
  return a

def checksum (a : Array UInt64) : UInt64 := Id.run do
  let mut h : UInt64 := 0
  for x in a do
    h := h * 131 + x
  return h

def main (args : List String) : IO Unit := do
  let (algo, n) ← match args with
    | [a, ns] => match ns.toNat? with
      | some n => pure (a, n)
      | none => IO.eprintln "Invalid n" *> IO.Process.exit 1
    | _ => IO.eprintln "Usage: sortbench <quick|merge> <n>" *> IO.Process.exit 1

  let arr := generateArray n 42

  let t0 ← IO.monoNanosNow
  let sorted ← match algo with
    | "quick" => pure (quicksort arr)
    | "merge" => pure (mergesort arr)
    | _ => IO.eprintln s!"Unknown algo: {algo}" *> IO.Process.exit 1
  let t1 ← IO.monoNanosNow

  let ms := (t1 - t0).toFloat / 1e6
  let cs := checksum sorted
  IO.println s!"{algo} n={n} {ms}ms checksum={cs}"
