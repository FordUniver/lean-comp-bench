-- Sorting benchmark for Lean v4.0–v4.19 (uses get!/swap!)
structure Lcg where
  state : UInt64

@[inline] def Lcg.new (seed : UInt64) : Lcg := { state := seed }

@[inline] def Lcg.next (rng : Lcg) : UInt64 × Lcg :=
  let s := rng.state * 6364136223846793005 + 1442695040888963407
  (s, { state := s })

def generateArray (n : Nat) (seed : UInt64) : Array UInt64 := Id.run do
  let mut rng := Lcg.new seed
  let mut arr := Array.mkEmpty n
  for _ in [:n] do
    let (v, r) := rng.next
    rng := r
    arr := arr.push v
  return arr

@[inline]
def doPartition (arr : Array UInt64) (lo hi : Nat) : Array UInt64 × Nat := Id.run do
  let pivot := arr.get! hi
  let mut a := arr
  let mut i := lo
  for j in [lo:hi] do
    if a.get! j <= pivot then
      a := a.swap! i j
      i := i + 1
  a := a.swap! i hi
  return (a, i)

partial def doQuicksort (a : Array UInt64) (lo hi : Int) : Array UInt64 :=
  if lo >= hi then a
  else
    let (ap, p) := doPartition a lo.toNat hi.toNat
    let a2 := doQuicksort ap lo (p - 1)
    doQuicksort a2 (Int.ofNat (p + 1)) hi

def checksum (a : Array UInt64) : UInt64 := Id.run do
  let mut h : UInt64 := 0
  for x in a do
    h := h * 131 + x
  return h

def main : IO Unit := do
  let n := 1000000
  let arr := generateArray n 42
  let t0 ← IO.monoNanosNow
  let sorted := doQuicksort arr 0 (n - 1)
  let cs := checksum sorted
  let t1 ← IO.monoNanosNow
  let ms := (t1 - t0).toFloat / 1e6
  IO.println s!"quick n={n} {ms}ms checksum={cs}"
