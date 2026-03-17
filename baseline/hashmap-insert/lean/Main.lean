-- Reproducing lacker/lean4perf benchmark on current Lean (v4.28)
-- 10M string->Nat insertions into HashMap
import Batteries

def main : IO Unit := do
  let t0 ← IO.monoNanosNow

  let mut map : Std.HashMap String Nat := {}
  for n in [0:10000000] do
    map := map.insert (toString n) n

  let t1 ← IO.monoNanosNow
  let ms := (t1 - t0).toFloat / 1e6

  IO.println s!"ran {map.size} map inserts in {ms}ms"
