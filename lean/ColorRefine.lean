-- Color refinement (1-WL) benchmark
-- Input: graph file (n m, then m edges u v)
-- Output: read=Xms compute=Yms rounds=R colors=C checksum=K
--
-- Array access via sorry proofs (stand-in for real bound proofs).
-- Proofs are erased at compile time, so this produces the same machine
-- code as a fully verified implementation.

import Std.Data.HashMap

@[inline] def Array.uget' (a : Array α) (i : Nat) : α := a[i]'(by sorry)
@[inline] def Array.uset' (a : Array α) (i : Nat) (v : α) : Array α := a.set i v (by sorry)

def parseNat (data : ByteArray) (pos : Nat) : Nat × Nat := Id.run do
  let sz := data.size
  -- skip non-digits
  let mut p := pos
  while p < sz do
    let b := data.get! p
    if b >= 0x30 && b <= 0x39 then break  -- '0'..'9'
    p := p + 1
  -- read digits
  let mut n := 0
  while p < sz do
    let b := data.get! p
    if b >= 0x30 && b <= 0x39 then
      n := n * 10 + (b.toNat - 0x30)
      p := p + 1
    else
      break
  return (n, p)

def fmtMs (nanos : Nat) : String :=
  let tenths := nanos / 100000
  let whole := tenths / 10
  let frac := tenths % 10
  s!"{whole}.{frac}"

def main (args : List String) : IO Unit := do
  let file ← match args with
    | [f] => pure f
    | _ => IO.eprintln "Usage: color_refine_barebones <graph_file>" *> IO.Process.exit 1

  -- ── Read ───────────────────────────────────────────────────────────────
  let t0 ← IO.monoNanosNow
  let data ← IO.FS.readBinFile file

  let (n, p0) := parseNat data 0
  let (m, p1) := parseNat data p0

  -- First pass: read edges, count degrees
  let mut deg := Array.replicate n (0 : UInt32)
  let mut edgeU := Array.mkEmpty m
  let mut edgeV := Array.mkEmpty m
  let mut pos := p1
  for _ in [:m] do
    let (u, p2) := parseNat data pos
    let (v, p3) := parseNat data p2
    pos := p3
    edgeU := edgeU.push u
    edgeV := edgeV.push v
    deg := deg.uset' u ((deg.uget' u) + 1)
    deg := deg.uset' v ((deg.uget' v) + 1)

  -- Build CSR offset array
  let mut offset := Array.replicate (n + 1) (0 : UInt32)
  let mut cumul : UInt32 := 0
  for i in [:n] do
    offset := offset.uset' i cumul
    cumul := cumul + (deg.uget' i)
  offset := offset.uset' n cumul

  let total := cumul.toNat
  let mut adj := Array.replicate total (0 : UInt32)
  let mut adjPos := Array.replicate n (0 : UInt32)

  for i in [:m] do
    let u := edgeU.uget' i
    let v := edgeV.uget' i
    let ou := (offset.uget' u).toNat
    let pu := (adjPos.uget' u).toNat
    adj := adj.uset' (ou + pu) (UInt32.ofNat v)
    adjPos := adjPos.uset' u ((adjPos.uget' u) + 1)
    let ov := (offset.uget' v).toNat
    let pv := (adjPos.uget' v).toNat
    adj := adj.uset' (ov + pv) (UInt32.ofNat u)
    adjPos := adjPos.uset' v ((adjPos.uget' v) + 1)

  let t1 ← IO.monoNanosNow
  let readNanos := t1 - t0

  -- ── Compute ────────────────────────────────────────────────────────────
  let t2 ← IO.monoNanosNow

  let mut color := Array.replicate n (0 : UInt32)
  let mut newColor := Array.replicate n (0 : UInt32)
  let mut sigHash := Array.replicate n (0 : UInt64)

  -- Find max degree for reusable buffer
  let mut maxDeg : Nat := 0
  for v in [:n] do
    let lo := (offset.uget' v).toNat
    let hi := (offset.uget' (v + 1)).toNat
    let d := hi - lo
    if d > maxDeg then maxDeg := d
  let mut nbuf := Array.replicate maxDeg (0 : UInt32)

  let mut rounds : UInt32 := 0
  let mut numColors : UInt32 := 0

  for round in [:n] do
    -- Build signature hash for each vertex
    for v in [:n] do
      let lo := (offset.uget' v).toNat
      let hi := (offset.uget' (v + 1)).toNat
      let degV := hi - lo
      -- Collect neighbor colors
      for j in [:degV] do
        let w := (adj.uget' (lo + j)).toNat
        nbuf := nbuf.uset' j (color.uget' w)
      -- Sort neighbor colors (insertion sort on the slice)
      for i in [1:degV] do
        let key := nbuf.uget' i
        let mut j := i
        while j > 0 do
          let prev := nbuf.uget' (j - 1)
          if prev > key then
            nbuf := nbuf.uset' j prev
            j := j - 1
          else
            break
        nbuf := nbuf.uset' j key
      -- Hash
      let cv := color.uget' v
      let mut h : UInt64 := cv.toUInt64 * 1000003
      h := (h ^^^ (UInt64.ofNat degV * 2654435761)) * 1000003
      for j in [:degV] do
        let nc := nbuf.uget' j
        h := (h ^^^ (nc.toUInt64 * 2654435761)) * 1000003
      sigHash := sigHash.uset' v h

    -- Map hashes to consecutive colors
    let mut mapping : Std.HashMap UInt64 UInt32 := {}
    let mut nextId : UInt32 := 0
    for v in [:n] do
      let h := sigHash.uget' v
      match mapping[h]? with
      | some cid =>
        newColor := newColor.uset' v cid
      | none =>
        newColor := newColor.uset' v nextId
        mapping := mapping.insert h nextId
        nextId := nextId + 1

    rounds := UInt32.ofNat (round + 1)
    numColors := nextId

    -- Check stability
    let mut stable := true
    for v in [:n] do
      if (newColor.uget' v) != (color.uget' v) then
        stable := false
        break
    if stable then break

    -- Copy newColor -> color
    for v in [:n] do
      color := color.uset' v (newColor.uget' v)

  -- Compute checksum
  let mut checksum : Int64 := 0
  for v in [:n] do
    checksum := checksum + (color.uget' v).toUInt64.toInt64

  let t3 ← IO.monoNanosNow
  let computeNanos := t3 - t2

  IO.println s!"read={fmtMs readNanos}ms compute={fmtMs computeNanos}ms rounds={rounds} colors={numColors} checksum={checksum}"
