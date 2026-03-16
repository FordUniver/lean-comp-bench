#!/usr/bin/env bash
set -euo pipefail

ROOT="/scratch/htc/cspiegel/lean-comp-bench"
RESULTS="$ROOT/version-results.txt"
export PATH="$HOME/.local/bin:$PATH"

VERSIONS=(v4.0.0 v4.4.0 v4.8.0 v4.12.0 v4.18.0 v4.24.0 v4.28.0)

# Build C baseline
echo "Building C baseline..."
cc -O2 -o "$ROOT/list-sort/c/sort" "$ROOT/list-sort/c/sort.c"

echo "" > "$RESULTS"
echo "=== Lean version progression (quicksort n=1000000) ===" | tee -a "$RESULTS"
echo "C baseline:" | tee -a "$RESULTS"
hyperfine --warmup 1 --min-runs 5 -n "C" "$ROOT/list-sort/c/sort quick 1000000" 2>&1 | tee -a "$RESULTS"

# Lean source with get!/swap! (old API, v4.0-v4.19)
OLD_LEAN='structure Lcg where state : UInt64
@[inline] def Lcg.new (seed : UInt64) : Lcg := { state := seed }
@[inline] def Lcg.next (rng : Lcg) : UInt64 × Lcg :=
  let s := rng.state * 6364136223846793005 + 1442695040888963407; (s, { state := s })
def generateArray (n : Nat) (seed : UInt64) : Array UInt64 := Id.run do
  let mut rng := Lcg.new seed; let mut arr := Array.mkEmpty n
  for _ in [:n] do let (v, r) := rng.next; rng := r; arr := arr.push v; return arr
@[inline] def doPartition (arr : Array UInt64) (lo hi : Nat) : Array UInt64 × Nat := Id.run do
  let pivot := arr.get! hi; let mut a := arr; let mut i := lo
  for j in [lo:hi] do if a.get! j <= pivot then a := a.swap! i j; i := i + 1
  a := a.swap! i hi; return (a, i)
partial def doQuicksort (a : Array UInt64) (lo hi : Int) : Array UInt64 :=
  if lo >= hi then a else
  let (ap, p) := doPartition a lo.toNat hi.toNat
  doQuicksort (doQuicksort ap lo (p - 1)) (Int.ofNat (p + 1)) hi
def checksum (a : Array UInt64) : UInt64 := Id.run do
  let mut h : UInt64 := 0; for x in a do h := h * 131 + x; return h
def main : IO Unit := do
  let n := 1000000; let arr := generateArray n 42
  let t0 <- IO.monoNanosNow; let sorted := doQuicksort arr 0 (n - 1)
  let cs := checksum sorted; let t1 <- IO.monoNanosNow
  let ms := (t1 - t0).toFloat / 1e6
  IO.println s!"quick n={n} {ms}ms checksum={cs}"'

# Lean source with getD/setIfInBounds (new API, v4.20+)
NEW_LEAN='structure Lcg where state : UInt64
@[inline] def Lcg.new (seed : UInt64) : Lcg := { state := seed }
@[inline] def Lcg.next (rng : Lcg) : UInt64 × Lcg :=
  let s := rng.state * 6364136223846793005 + 1442695040888963407; (s, { state := s })
def generateArray (n : Nat) (seed : UInt64) : Array UInt64 := Id.run do
  let mut rng := Lcg.new seed; let mut arr := Array.mkEmpty n
  for _ in [:n] do let (v, r) := rng.next; rng := r; arr := arr.push v; return arr
@[inline] def g (a : Array UInt64) (i : Nat) : UInt64 := a.getD i 0
@[inline] def s (a : Array UInt64) (i : Nat) (v : UInt64) : Array UInt64 := a.setIfInBounds i v
@[inline] def swp (a : Array UInt64) (i j : Nat) : Array UInt64 :=
  let vi := g a i; let vj := g a j; s (s a i vj) j vi
@[inline] def doPartition (arr : Array UInt64) (lo hi : Nat) : Array UInt64 × Nat := Id.run do
  let pivot := g arr hi; let mut a := arr; let mut i := lo
  for j in [lo:hi] do if g a j <= pivot then a := swp a i j; i := i + 1
  a := swp a i hi; return (a, i)
partial def doQuicksort (a : Array UInt64) (lo hi : Int) : Array UInt64 :=
  if lo >= hi then a else
  let (ap, p) := doPartition a lo.toNat hi.toNat
  doQuicksort (doQuicksort ap lo (p - 1)) (Int.ofNat (p + 1)) hi
def checksum (a : Array UInt64) : UInt64 := Id.run do
  let mut h : UInt64 := 0; for x in a do h := h * 131 + x; return h
def main : IO Unit := do
  let n := 1000000; let arr := generateArray n 42
  let t0 <- IO.monoNanosNow; let sorted := doQuicksort arr 0 (n - 1)
  let cs := checksum sorted; let t1 <- IO.monoNanosNow
  let ms := (t1 - t0).toFloat / 1e6
  IO.println s!"quick n={n} {ms}ms checksum={cs}"'

# Old lakefile format (v4.0-v4.6)
OLD_LAKE='import Lake
open Lake DSL
package SortBench
@[default_target]
lean_exe sortbench where root := `Main'

# New lakefile format (v4.7+)
NEW_LAKE='name = "SortBench"
version = "0.1.0"
[[lean_exe]]
name = "sortbench"
root = "Main"'

for VER in "${VERSIONS[@]}"; do
    echo ""
    echo "--- Lean $VER ---" | tee -a "$RESULTS"

    elan toolchain install "leanprover/lean4:$VER" 2>&1 | tail -1

    TDIR=$(mktemp -d)
    echo "leanprover/lean4:$VER" > "$TDIR/lean-toolchain"

    # Select API version
    if [[ "$VER" < "v4.20" ]]; then
        echo "$OLD_LEAN" > "$TDIR/Main.lean"
    else
        echo "$NEW_LEAN" > "$TDIR/Main.lean"
    fi

    # Select lakefile format
    if [[ "$VER" < "v4.7" ]]; then
        echo "$OLD_LAKE" > "$TDIR/lakefile.lean"
    else
        echo "$NEW_LAKE" > "$TDIR/lakefile.toml"
    fi

    echo "  Building Lean $VER..."
    if (cd "$TDIR" && lake build 2>&1 | tail -3); then
        BIN="$TDIR/.lake/build/bin/sortbench"
        [ -f "$BIN" ] || BIN="$TDIR/build/bin/sortbench"
        if [ -f "$BIN" ]; then
            SMOKE=$("$BIN" 2>&1 || true)
            echo "  Smoke: $SMOKE"
            if echo "$SMOKE" | grep -q "checksum="; then
                hyperfine --warmup 1 --min-runs 5 -n "Lean $VER" "$BIN" 2>&1 | tee -a "$RESULTS"
            else
                echo "  SKIP: binary crashed" | tee -a "$RESULTS"
            fi
        else
            echo "  SKIP: binary not found" | tee -a "$RESULTS"
        fi
    else
        echo "  SKIP: build failed" | tee -a "$RESULTS"
    fi

    rm -rf "$TDIR"
done

echo ""
echo "=== Done ===" | tee -a "$RESULTS"
