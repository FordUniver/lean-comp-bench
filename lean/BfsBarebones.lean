-- BFS benchmark — barebones (set! for writes, getD for reads)
-- Input: graph file (n m, then m edges u v)
-- Output: read=Xms compute=Yms checksum=C visited=V

def parseNat (s : String) (pos : Nat) : Nat × Nat := Id.run do
  -- skip non-digits
  let mut p := pos
  while h : p < s.length do
    if (s.get ⟨p⟩).isDigit then break
    p := p + 1
  -- read digits
  let mut n := 0
  while h : p < s.length do
    let c := s.get ⟨p⟩
    if c.isDigit then
      n := n * 10 + (c.toNat - '0'.toNat)
      p := p + 1
    else
      break
  return (n, p)

def main (args : List String) : IO Unit := do
  let file ← match args with
    | [f] => pure f
    | _ => IO.eprintln "Usage: bfs_barebones <graph_file>" *> IO.Process.exit 1

  -- ── Read ───────────────────────────────────────────────────────────────
  let t0 ← IO.monoNanosNow
  let contents ← IO.FS.readFile file

  let (n, p0) := parseNat contents 0
  let (m, p1) := parseNat contents p0

  -- First pass: read edges, count degrees
  let mut deg := Array.replicate n (0 : UInt32)
  let mut edgeU := Array.mkEmpty m
  let mut edgeV := Array.mkEmpty m
  let mut pos := p1
  for _ in [:m] do
    let (u, p2) := parseNat contents pos
    let (v, p3) := parseNat contents p2
    pos := p3
    edgeU := edgeU.push u
    edgeV := edgeV.push v
    deg := deg.set! u ((deg.getD u 0) + 1)
    deg := deg.set! v ((deg.getD v 0) + 1)

  -- Build CSR offset array
  let mut offset := Array.replicate (n + 1) (0 : UInt32)
  for i in [:n] do
    offset := offset.set! (i + 1) ((offset.getD (i + 1) 0) + (offset.getD i 0) + (deg.getD i 0))
  -- Fix: offset[i+1] = offset[i] + deg[i], built cumulatively above but wrong.
  -- Redo properly:
  offset := Array.replicate (n + 1) (0 : UInt32)
  let mut cumul : UInt32 := 0
  for i in [:n] do
    offset := offset.set! i cumul
    cumul := cumul + (deg.getD i 0)
  offset := offset.set! n cumul

  let total := cumul.toNat
  let mut adj := Array.replicate total (0 : UInt32)
  let mut adjPos := Array.replicate n (0 : UInt32)

  for i in [:m] do
    let u := edgeU.getD i 0
    let v := edgeV.getD i 0
    let ou := (offset.getD u 0).toNat
    let pu := (adjPos.getD u 0).toNat
    adj := adj.set! (ou + pu) (UInt32.ofNat v)
    adjPos := adjPos.set! u ((adjPos.getD u 0) + 1)
    let ov := (offset.getD v 0).toNat
    let pv := (adjPos.getD v 0).toNat
    adj := adj.set! (ov + pv) (UInt32.ofNat u)
    adjPos := adjPos.set! v ((adjPos.getD v 0) + 1)

  let t1 ← IO.monoNanosNow
  let readMs := (t1 - t0).toFloat / 1e6

  -- ── Compute ────────────────────────────────────────────────────────────
  let t2 ← IO.monoNanosNow

  let mut visited := Array.replicate n false
  let mut dist := Array.replicate n (0 : Int64)
  let mut queue := Array.mkEmpty n
  visited := visited.set! 0 true
  queue := queue.push (0 : UInt32)
  let mut qhead := 0
  let mut distSum : Int64 := 0

  while h : qhead < queue.size do
    let v := (queue.getD qhead 0).toNat
    qhead := qhead + 1
    let lo := (offset.getD v 0).toNat
    let hi := (offset.getD (v + 1) 0).toNat
    let dv := dist.getD v 0
    for j in [lo:hi] do
      let w := (adj.getD j 0).toNat
      if visited.getD w false == false then
        visited := visited.set! w true
        let dw := dv + 1
        dist := dist.set! w dw
        distSum := distSum + dw
        queue := queue.push (UInt32.ofNat w)

  let t3 ← IO.monoNanosNow
  let computeMs := (t3 - t2).toFloat / 1e6

  IO.println s!"read={readMs}ms compute={computeMs}ms checksum={distSum} visited={queue.size}"
