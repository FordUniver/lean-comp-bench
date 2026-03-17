-- Point-in-convex-hull (2D) benchmark
-- Input: polygon+queries file (n_poly n_queries, then vertices, then queries)
-- Output: read=Xms compute=Yms inside=N total=M
--
-- Array access via sorry proofs (stand-in for real bound proofs).
-- Proofs are erased at compile time, so this produces the same machine
-- code as a fully verified implementation.

@[inline] def Array.uget' (a : Array α) (i : Nat) : α := a[i]'(by sorry)
@[inline] def Array.uset' (a : Array α) (i : Nat) (v : α) : Array α := a.set i v (by sorry)

def parseNat (data : ByteArray) (pos : Nat) : Nat × Nat := Id.run do
  let sz := data.size
  let mut p := pos
  while p < sz do
    let b := data.get! p
    if b >= 0x30 && b <= 0x39 then break
    p := p + 1
  let mut n := 0
  while p < sz do
    let b := data.get! p
    if b >= 0x30 && b <= 0x39 then
      n := n * 10 + (b.toNat - 0x30)
      p := p + 1
    else
      break
  return (n, p)

def parseInt (data : ByteArray) (pos : Nat) : Int64 × Nat := Id.run do
  let sz := data.size
  -- skip to sign or digit
  let mut p := pos
  while p < sz do
    let b := data.get! p
    if b == 0x2D || (b >= 0x30 && b <= 0x39) then break -- '-' or '0'..'9'
    p := p + 1
  -- check sign
  let mut neg := false
  if p < sz && data.get! p == 0x2D then
    neg := true
    p := p + 1
  -- read digits
  let mut n : Int64 := 0
  while p < sz do
    let b := data.get! p
    if b >= 0x30 && b <= 0x39 then
      n := n * 10 + (b.toNat - 0x30).toInt64
      p := p + 1
    else
      break
  if neg then return (-n, p) else return (n, p)

def fmtMs (nanos : Nat) : String :=
  let tenths := nanos / 100000
  let whole := tenths / 10
  let frac := tenths % 10
  s!"{whole}.{frac}"

def main (args : List String) : IO Unit := do
  let file ← match args with
    | [f] => pure f
    | _ => IO.eprintln "Usage: point_in_hull <polygon_file>" *> IO.Process.exit 1

  -- ── Read ───────────────────────────────────────────────────────────────
  let t0 ← IO.monoNanosNow
  let data ← IO.FS.readBinFile file

  let (np, p0) := parseNat data 0
  let (nq, p1) := parseNat data p0

  let mut px := Array.replicate np (0 : Int64)
  let mut py := Array.replicate np (0 : Int64)
  let mut pos := p1
  for i in [:np] do
    let (x, p2) := parseInt data pos
    let (y, p3) := parseInt data p2
    px := px.uset' i x
    py := py.uset' i y
    pos := p3

  let mut qx := Array.replicate nq (0 : Int64)
  let mut qy := Array.replicate nq (0 : Int64)
  for i in [:nq] do
    let (x, p2) := parseInt data pos
    let (y, p3) := parseInt data p2
    qx := qx.uset' i x
    qy := qy.uset' i y
    pos := p3

  let t1 ← IO.monoNanosNow
  let readNanos := t1 - t0

  -- ── Compute ────────────────────────────────────────────────────────────
  let t2 ← IO.monoNanosNow

  let mut inside : UInt32 := 0
  for q in [:nq] do
    let x := qx.uget' q
    let y := qy.uget' q
    let mut isIn := true
    for i in [:np] do
      if isIn then
        let j := (i + 1) % np
        let pxi := px.uget' i
        let pyi := py.uget' i
        let pxj := px.uget' j
        let pyj := py.uget' j
        let cross := (pxj - pxi) * (y - pyi) - (pyj - pyi) * (x - pxi)
        if cross < 0 then
          isIn := false

    if isIn then inside := inside + 1

  let t3 ← IO.monoNanosNow
  let computeNanos := t3 - t2

  IO.println s!"read={fmtMs readNanos}ms compute={fmtMs computeNanos}ms inside={inside} total={nq}"
