#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
FILTER="${1:-}"

should_build() { [ -z "$FILTER" ] || [ "$FILTER" = "$1" ]; }

# ── list-sort ────────────────────────────────────────────────────────────────

if should_build list-sort; then
    echo "=== Building list-sort ==="

    echo "  C..."
    cc -O2 -o "$ROOT/list-sort/c/sort" "$ROOT/list-sort/c/sort.c"

    echo "  C++..."
    c++ -O2 -o "$ROOT/list-sort/cpp/sort" "$ROOT/list-sort/cpp/sort.cpp"

    echo "  Rust..."
    cargo build --release --manifest-path "$ROOT/list-sort/rust/Cargo.toml" --quiet

    if command -v ghc &>/dev/null; then
        echo "  Haskell..."
        (cd "$ROOT/list-sort/haskell" && ghc -O2 Sort.hs -o sort -v0)
    else
        echo "  Haskell... SKIP (ghc not found)"
    fi

    echo "  Lean (current)..."
    (cd "$ROOT/list-sort/lean" && lake build --quiet 2>/dev/null)

    for d in "$ROOT"/list-sort/lean-v*/; do
        [ -d "$d" ] || continue
        ver=$(basename "$d")
        echo "  Lean ($ver)..."
        (cd "$d" && lake build --quiet 2>/dev/null) || echo "    FAILED: $ver"
    done
fi

# ── hashmap-insert ───────────────────────────────────────────────────────────

if should_build hashmap-insert; then
    echo "=== Building hashmap-insert ==="

    echo "  C++..."
    c++ -O3 -o "$ROOT/hashmap-insert/cpp/benchmark" "$ROOT/hashmap-insert/cpp/benchmark.cpp"

    echo "  Rust..."
    cargo build --release --manifest-path "$ROOT/hashmap-insert/rust/Cargo.toml" --quiet

    if command -v ghc &>/dev/null; then
        echo "  Haskell..."
        (cd "$ROOT/hashmap-insert/haskell" && ghc -O2 HashBench.hs -o hashbench -v0)
    else
        echo "  Haskell... SKIP (ghc not found)"
    fi

    echo "  Lean (current)..."
    (cd "$ROOT/hashmap-insert/lean" && lake build --quiet 2>/dev/null)
fi

echo ""
echo "=== Build complete ==="
