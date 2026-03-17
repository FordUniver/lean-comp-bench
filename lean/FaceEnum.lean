-- Face enumeration from vertex-facet incidence benchmark
-- Input: incidence file (n_vertices n_facets, then one line per facet)
-- Output: read=Xms compute=Yms faces=N checksum=K
--
-- Faces represented as bitsets (8 × UInt64, up to 512 vertices).
-- Enumerates all faces by closing facets under intersection.
--
-- Array access via sorry proofs (stand-in for real bound proofs).

import Std.Data.HashMap

@[inline] def Array.uget' (a : Array α) (i : Nat) : α := a[i]'(by sorry)
@[inline] def Array.uset' (a : Array α) (i : Nat) (v : α) : Array α := a.set i v (by sorry)

-- Face as 8 × UInt64 (supports up to 512 vertices)
structure Face where
  w0 : UInt64
  w1 : UInt64
  w2 : UInt64
  w3 : UInt64
  w4 : UInt64
  w5 : UInt64
  w6 : UInt64
  w7 : UInt64
  deriving BEq, Hashable

instance : Ord Face where
  compare a b :=
    match compare a.w7 b.w7 with
    | .eq => match compare a.w6 b.w6 with
      | .eq => match compare a.w5 b.w5 with
        | .eq => match compare a.w4 b.w4 with
          | .eq => match compare a.w3 b.w3 with
            | .eq => match compare a.w2 b.w2 with
              | .eq => match compare a.w1 b.w1 with
                | .eq => compare a.w0 b.w0
                | r => r
              | r => r
            | r => r
          | r => r
        | r => r
      | r => r
    | r => r

def Face.empty : Face := ⟨0, 0, 0, 0, 0, 0, 0, 0⟩

def Face.setBit (f : Face) (v : Nat) : Face :=
  let idx := v / 64
  let bit := (1 : UInt64) <<< (v % 64).toUInt64
  match idx with
  | 0 => { f with w0 := f.w0 ||| bit }
  | 1 => { f with w1 := f.w1 ||| bit }
  | 2 => { f with w2 := f.w2 ||| bit }
  | 3 => { f with w3 := f.w3 ||| bit }
  | 4 => { f with w4 := f.w4 ||| bit }
  | 5 => { f with w5 := f.w5 ||| bit }
  | 6 => { f with w6 := f.w6 ||| bit }
  | _ => { f with w7 := f.w7 ||| bit }

def Face.intersect (a b : Face) : Face :=
  ⟨a.w0 &&& b.w0, a.w1 &&& b.w1, a.w2 &&& b.w2, a.w3 &&& b.w3,
   a.w4 &&& b.w4, a.w5 &&& b.w5, a.w6 &&& b.w6, a.w7 &&& b.w7⟩

-- Popcount via Kernighan's bit-counting
def popcount64 (x : UInt64) : Nat := Id.run do
  let mut v := x
  let mut c := 0
  while v != 0 do
    v := v &&& (v - 1)
    c := c + 1
  return c

def Face.popcount (f : Face) : Nat :=
  popcount64 f.w0 + popcount64 f.w1 + popcount64 f.w2 + popcount64 f.w3 +
  popcount64 f.w4 + popcount64 f.w5 + popcount64 f.w6 + popcount64 f.w7

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

-- Skip to next line
def skipLine (data : ByteArray) (pos : Nat) : Nat := Id.run do
  let sz := data.size
  let mut p := pos
  while p < sz do
    if data.get! p == 0x0A then return p + 1  -- '\n'
    p := p + 1
  return p

-- Parse all vertex indices on current line
def parseFacetLine (data : ByteArray) (pos : Nat) : Face × Nat := Id.run do
  let sz := data.size
  let mut p := pos
  let mut face := Face.empty
  while p < sz do
    let b := data.get! p
    if b == 0x0A || b == 0x0D then  -- newline
      break
    if b >= 0x30 && b <= 0x39 then
      let (v, p') := parseNat data p
      face := face.setBit v
      p := p'
    else
      p := p + 1
  -- skip newline
  while p < sz do
    let b := data.get! p
    if b == 0x0A || b == 0x0D then p := p + 1
    else break
  return (face, p)

def fmtMs (nanos : Nat) : String :=
  let tenths := nanos / 100000
  let whole := tenths / 10
  let frac := tenths % 10
  s!"{whole}.{frac}"

def main (args : List String) : IO Unit := do
  let file ← match args with
    | [f] => pure f
    | _ => IO.eprintln "Usage: face_enum <incidence_file>" *> IO.Process.exit 1

  -- ── Read ───────────────────────────────────────────────────────────────
  let t0 ← IO.monoNanosNow
  let data ← IO.FS.readBinFile file

  let (_nv, p0) := parseNat data 0
  let (nf, p1) := parseNat data p0

  -- Skip rest of first line
  let mut pos := skipLine data p1

  let mut facets := Array.mkEmpty nf
  for _ in [:nf] do
    let (face, p') := parseFacetLine data pos
    facets := facets.push face
    pos := p'

  let t1 ← IO.monoNanosNow
  let readNanos := t1 - t0

  -- ── Compute ────────────────────────────────────────────────────────────
  let t2 ← IO.monoNanosNow

  -- Use HashMap as a set (map Face -> Unit)
  let mut allFaces : Std.HashMap Face Unit := {}
  let mut worklist := Array.mkEmpty (nf * 100)

  for i in [:nf] do
    let f := facets.uget' i
    if allFaces[f]? == none then
      allFaces := allFaces.insert f ()
      worklist := worklist.push f

  let mut processed := 0
  while h : processed < worklist.size do
    let current := worklist.uget' processed
    processed := processed + 1
    for j in [:processed] do
      let other := worklist.uget' j
      let inter := current.intersect other
      if inter.w0 != 0 || inter.w1 != 0 || inter.w2 != 0 || inter.w3 != 0 ||
         inter.w4 != 0 || inter.w5 != 0 || inter.w6 != 0 || inter.w7 != 0 then
        if allFaces[inter]? == none then
          allFaces := allFaces.insert inter ()
          worklist := worklist.push inter

  let mut checksum : Int64 := 0
  for i in [:worklist.size] do
    checksum := checksum + (worklist.uget' i).popcount.toInt64

  let t3 ← IO.monoNanosNow
  let computeNanos := t3 - t2

  IO.println s!"read={fmtMs readNanos}ms compute={fmtMs computeNanos}ms faces={allFaces.size} checksum={checksum}"
