#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RUNS="${BENCH_RUNS:-7}"
WARMUP="${BENCH_WARMUP:-2}"

# ── Build ─────────────────────────────────────────────────────────────────────

echo "=== Building ==="

echo "  C (list-sort)..."
cc -O2 -o "$ROOT/list-sort/c/sort" "$ROOT/list-sort/c/sort.c"

echo "  C++ (list-sort, hashmap-insert)..."
c++ -O2 -o "$ROOT/list-sort/cpp/sort" "$ROOT/list-sort/cpp/sort.cpp"
c++ -O3 -o "$ROOT/hashmap-insert/c/benchmark" "$ROOT/hashmap-insert/c/benchmark.cpp"

echo "  Rust (list-sort)..."
cargo build --release --manifest-path "$ROOT/list-sort/rust/Cargo.toml" --quiet

echo "  Rust (hashmap-insert)..."
cargo build --release --manifest-path "$ROOT/hashmap-insert/rust/Cargo.toml" --quiet

echo "  Haskell (list-sort)..."
(cd "$ROOT/list-sort/haskell" && ghc -O2 Sort.hs -o sort -v0)

echo "  Haskell (hashmap-insert)..."
(cd "$ROOT/hashmap-insert/haskell" && ghc -O2 HashBench.hs -o hashbench -v0)

echo "  Lean (list-sort)..."
(cd "$ROOT/list-sort/lean" && lake build --quiet 2>/dev/null)

echo "  Lean (hashmap-insert)..."
(cd "$ROOT/hashmap-insert/lean" && lake build --quiet 2>/dev/null)

echo ""

# ── Verify checksums ──────────────────────────────────────────────────────────

echo "=== Verifying checksums (quicksort n=10000) ==="
CS_C=$("$ROOT/list-sort/c/sort" quick 10000 | grep -o 'checksum=[0-9]*')
CS_CPP=$("$ROOT/list-sort/cpp/sort" quick 10000 | grep -o 'checksum=[0-9]*')
CS_RS=$("$ROOT/list-sort/rust/target/release/sort" quick 10000 | grep -o 'checksum=[0-9]*')
CS_HS=$("$ROOT/list-sort/haskell/sort" quick 10000 | grep -o 'checksum=[0-9]*')
CS_LEAN=$("$ROOT/list-sort/lean/.lake/build/bin/sortbench" quick 10000 | grep -o 'checksum=[0-9]*')

if [ "$CS_C" = "$CS_CPP" ] && [ "$CS_C" = "$CS_RS" ] && [ "$CS_C" = "$CS_HS" ] && [ "$CS_C" = "$CS_LEAN" ]; then
    echo "  All match: $CS_C"
else
    echo "  MISMATCH: C=$CS_C C++=$CS_CPP Rust=$CS_RS Haskell=$CS_HS Lean=$CS_LEAN"
    exit 1
fi
echo ""

# ── Benchmark ─────────────────────────────────────────────────────────────────

echo "=== Quicksort (n=1000000) ==="
hyperfine --warmup "$WARMUP" --min-runs "$RUNS" \
    -n 'C'       "$ROOT/list-sort/c/sort quick 1000000" \
    -n 'C++'     "$ROOT/list-sort/cpp/sort quick 1000000" \
    -n 'Rust'    "$ROOT/list-sort/rust/target/release/sort quick 1000000" \
    -n 'Haskell' "$ROOT/list-sort/haskell/sort quick 1000000" \
    -n 'Lean'    "$ROOT/list-sort/lean/.lake/build/bin/sortbench quick 1000000"
echo ""

echo "=== Mergesort (n=1000000) ==="
hyperfine --warmup "$WARMUP" --min-runs "$RUNS" \
    -n 'C'       "$ROOT/list-sort/c/sort merge 1000000" \
    -n 'C++'     "$ROOT/list-sort/cpp/sort merge 1000000" \
    -n 'Rust'    "$ROOT/list-sort/rust/target/release/sort merge 1000000" \
    -n 'Haskell' "$ROOT/list-sort/haskell/sort merge 1000000" \
    -n 'Lean'    "$ROOT/list-sort/lean/.lake/build/bin/sortbench merge 1000000"
echo ""

echo "=== Hashmap insert (10M string->int) ==="
hyperfine --warmup "$WARMUP" --min-runs "$RUNS" \
    -n 'C++'     "$ROOT/hashmap-insert/c/benchmark" \
    -n 'Rust'    "$ROOT/hashmap-insert/rust/target/release/hashmap-bench" \
    -n 'Haskell' "$ROOT/hashmap-insert/haskell/hashbench" \
    -n 'Lean'    "$ROOT/hashmap-insert/lean/.lake/build/bin/hashbench"
