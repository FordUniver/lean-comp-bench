#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RUNS="${BENCH_RUNS:-7}"
WARMUP="${BENCH_WARMUP:-2}"
FILTER="${1:-}"

should_bench() { [ -z "$FILTER" ] || [ "$FILTER" = "$1" ]; }

# ── Build ────────────────────────────────────────────────────────────────────

"$ROOT/build.sh" "$FILTER"

# ── Results directory ────────────────────────────────────────────────────────

TIMESTAMP=$(date +%Y-%m-%dT%H:%M:%S)
OUTDIR="$ROOT/results/$TIMESTAMP"
mkdir -p "$OUTDIR"

{
    echo "date: $TIMESTAMP"
    echo "host: $(uname -mnrs)"
    echo "cc: $(cc --version 2>&1 | head -1)"
    echo "c++: $(c++ --version 2>&1 | head -1)"
    echo "rustc: $(rustc --version 2>&1)"
    command -v ghc &>/dev/null && echo "ghc: $(ghc --version 2>&1)" || echo "ghc: n/a"
    echo "lean: $(cd "$ROOT/list-sort/lean" && lean --version 2>/dev/null || echo 'n/a')"
    echo "hyperfine: $(hyperfine --version)"
} > "$OUTDIR/meta.txt"

echo ""

# ── Verify checksums ─────────────────────────────────────────────────────────

if should_bench list-sort; then
    echo "=== Verifying checksums (quicksort n=10000) ==="
    CS_C=$("$ROOT/list-sort/c/sort" quick 10000 2>/dev/null | grep -o 'checksum=[0-9]*')
    CS_CPP=$("$ROOT/list-sort/cpp/sort" quick 10000 2>/dev/null | grep -o 'checksum=[0-9]*')
    CS_RS=$("$ROOT/list-sort/rust/target/release/sort" quick 10000 2>/dev/null | grep -o 'checksum=[0-9]*')
    CS_LEAN=$("$ROOT/list-sort/lean/.lake/build/bin/sortbench" quick 10000 2>/dev/null | grep -o 'checksum=[0-9]*')

    if [ "$CS_C" = "$CS_CPP" ] && [ "$CS_C" = "$CS_RS" ] && [ "$CS_C" = "$CS_LEAN" ]; then
        echo "  All match: $CS_C"
    else
        echo "  MISMATCH: C=$CS_C C++=$CS_CPP Rust=$CS_RS Lean=$CS_LEAN"
        exit 1
    fi
    echo ""
fi

# ── list-sort ────────────────────────────────────────────────────────────────

if should_bench list-sort; then
    # Collect available Haskell binary
    HS_SORT=()
    [ -x "$ROOT/list-sort/haskell/sort" ] && HS_SORT=(-n 'Haskell' "$ROOT/list-sort/haskell/sort quick 1000000")

    echo "=== Quicksort (n=1000000) ==="
    hyperfine --warmup "$WARMUP" --min-runs "$RUNS" \
        --export-json "$OUTDIR/list-sort-quicksort.json" \
        -n 'C'       "$ROOT/list-sort/c/sort quick 1000000" \
        -n 'C++'     "$ROOT/list-sort/cpp/sort quick 1000000" \
        -n 'Rust'    "$ROOT/list-sort/rust/target/release/sort quick 1000000" \
        "${HS_SORT[@]}" \
        -n 'Lean'    "$ROOT/list-sort/lean/.lake/build/bin/sortbench quick 1000000"
    echo ""

    HS_MERGE=()
    [ -x "$ROOT/list-sort/haskell/sort" ] && HS_MERGE=(-n 'Haskell' "$ROOT/list-sort/haskell/sort merge 1000000")

    echo "=== Mergesort (n=1000000) ==="
    hyperfine --warmup "$WARMUP" --min-runs "$RUNS" \
        --export-json "$OUTDIR/list-sort-mergesort.json" \
        -n 'C'       "$ROOT/list-sort/c/sort merge 1000000" \
        -n 'C++'     "$ROOT/list-sort/cpp/sort merge 1000000" \
        -n 'Rust'    "$ROOT/list-sort/rust/target/release/sort merge 1000000" \
        "${HS_MERGE[@]}" \
        -n 'Lean'    "$ROOT/list-sort/lean/.lake/build/bin/sortbench merge 1000000"
    echo ""

    # Lean version progression
    LEAN_CMDS=()
    for d in "$ROOT"/list-sort/lean-v*/; do
        [ -d "$d" ] || continue
        ver=$(basename "$d" | sed 's/lean-//')
        bin="$d/.lake/build/bin/sortbench"
        [ -f "$bin" ] || bin="$d/build/bin/sortbench"
        [ -f "$bin" ] || continue
        # Smoke test
        if "$bin" 2>/dev/null | grep -q "checksum="; then
            LEAN_CMDS+=(-n "Lean $ver" "$bin")
        fi
    done

    if [ ${#LEAN_CMDS[@]} -gt 0 ]; then
        echo "=== Quicksort — Lean version progression (n=1000000) ==="
        hyperfine --warmup "$WARMUP" --min-runs "$RUNS" \
            --export-json "$OUTDIR/list-sort-lean-versions.json" \
            -n 'C (baseline)' "$ROOT/list-sort/c/sort quick 1000000" \
            -n 'Lean (current)' "$ROOT/list-sort/lean/.lake/build/bin/sortbench quick 1000000" \
            "${LEAN_CMDS[@]}"
        echo ""
    fi
fi

# ── hashmap-insert ───────────────────────────────────────────────────────────

if should_bench hashmap-insert; then
    HS_HASH=()
    [ -x "$ROOT/hashmap-insert/haskell/hashbench" ] && HS_HASH=(-n 'Haskell' "$ROOT/hashmap-insert/haskell/hashbench")

    echo "=== Hashmap insert (10M string->int) ==="
    hyperfine --warmup "$WARMUP" --min-runs "$RUNS" \
        --export-json "$OUTDIR/hashmap-insert.json" \
        -n 'C++'     "$ROOT/hashmap-insert/cpp/benchmark" \
        -n 'Rust'    "$ROOT/hashmap-insert/rust/target/release/hashmap-bench" \
        "${HS_HASH[@]}" \
        -n 'Lean'    "$ROOT/hashmap-insert/lean/.lake/build/bin/hashbench"
    echo ""
fi

echo "=== Results saved to $OUTDIR ==="
