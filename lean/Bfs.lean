-- BFS benchmark
-- Input: graph file (n m, then m edges u v)
-- Output: read=Xms compute=Yms checksum=C visited=V
--
-- Array access via sorry proofs (stand-in for real bound proofs).
-- Proofs are erased at compile time, so this produces the same machine
-- code as a fully verified implementation.
--
-- Uses USize for loop counters to avoid boxed Nat heap allocation per iteration.

@[inline] def Array.uget' (a : Array α) (i : Nat) : α := a[i]'(by sorry)
@[inline] def Array.uset' (a : Array α) (i : Nat) (v : α) : Array α := a.set i v (by sorry)

-- Parse into USize to avoid boxed Nat per-digit allocation
def parseNat (data : ByteArray) (pos : USize) : USize × USize := Id.run do
  let sz := data.size.toUSize
  let mut p := pos
  while p < sz do
    let b := data.uget p (by sorry)
    if b >= 0x30 && b <= 0x39 then break
    p := p + 1
  let mut n : USize := 0
  while p < sz do
    let b := data.uget p (by sorry)
    if b >= 0x30 && b <= 0x39 then
      n := n * 10 + (b.toUSize - 0x30)
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
    | _ => IO.eprintln "Usage: bfs <graph_file>" *> IO.Process.exit 1

  -- ── Read ───────────────────────────────────────────────────────────────
  let t0 ← IO.monoNanosNow
  let data ← IO.FS.readBinFile file

  let (n', p0) := parseNat data 0
  let (m', p1) := parseNat data p0
  let n := n'.toNat
  let m := m'.toNat

  let mut deg := Array.replicate n (0 : UInt32)
  let mut edgeU := Array.mkEmpty m
  let mut edgeV := Array.mkEmpty m
  let mut pos := p1
  let mut i : USize := 0
  while i < m' do
    let (u', p2) := parseNat data pos
    let (v', p3) := parseNat data p2
    pos := p3
    let u := u'.toNat
    let v := v'.toNat
    edgeU := edgeU.push u
    edgeV := edgeV.push v
    deg := deg.uset' u (deg.uget' u + 1)
    deg := deg.uset' v (deg.uget' v + 1)
    i := i + 1

  let mut offset := Array.replicate (n + 1) (0 : UInt32)
  let mut cumul : UInt32 := 0
  i := 0
  while i < n' do
    let idx := i.toNat
    offset := offset.uset' idx cumul
    cumul := cumul + deg.uget' idx
    i := i + 1
  offset := offset.uset' n cumul

  let total := cumul.toNat
  let mut adj := Array.replicate total (0 : UInt32)
  let mut adjPos := Array.replicate n (0 : UInt32)

  i := 0
  while i < m' do
    let idx := i.toNat
    let u := edgeU.uget' idx
    let v := edgeV.uget' idx
    let ou := (offset.uget' u).toNat
    let pu := (adjPos.uget' u).toNat
    adj := adj.uset' (ou + pu) (UInt32.ofNat v)
    adjPos := adjPos.uset' u (adjPos.uget' u + 1)
    let ov := (offset.uget' v).toNat
    let pv := (adjPos.uget' v).toNat
    adj := adj.uset' (ov + pv) (UInt32.ofNat u)
    adjPos := adjPos.uset' v (adjPos.uget' v + 1)
    i := i + 1

  let t1 ← IO.monoNanosNow
  let readNanos := t1 - t0

  -- ── Compute ────────────────────────────────────────────────────────────
  let t2 ← IO.monoNanosNow

  let mut visited := Array.replicate n false
  let mut dist := Array.replicate n (0 : Int64)
  let mut queue := Array.mkEmpty n
  visited := visited.uset' 0 true
  queue := queue.push (0 : UInt32)
  let mut qhead : USize := 0
  let mut distSum : Int64 := 0

  while qhead < queue.size.toUSize do
    let v := (queue.uget' qhead.toNat).toNat
    qhead := qhead + 1
    let lo := (offset.uget' v).toNat
    let hi := (offset.uget' (v + 1)).toNat
    let dv := dist.uget' v
    let mut j : USize := lo.toUSize
    let hiU := hi.toUSize
    while j < hiU do
      let w := (adj.uget' j.toNat).toNat
      if visited.uget' w == false then
        visited := visited.uset' w true
        let dw := dv + 1
        dist := dist.uset' w dw
        distSum := distSum + dw
        queue := queue.push (UInt32.ofNat w)
      j := j + 1

  let t3 ← IO.monoNanosNow
  let computeNanos := t3 - t2

  IO.println s!"read={fmtMs readNanos}ms compute={fmtMs computeNanos}ms checksum={distSum} visited={queue.size}"
