#!/usr/bin/env bash
# Build all benchmark languages (or a subset via filter argument).
# Usage: ./build.sh [filter]
#   filter: substring match on language name (cpp, rust, haskell, lean)
set -euo pipefail

cd "$(dirname "$0")"
FILTER="${1:-}"

match() { [[ -z "$FILTER" ]] || [[ "$1" == *"$FILTER"* ]]; }

echo "=== Compiler versions ==="

if match cpp; then
    echo -n "C++: "; c++ --version 2>&1 | head -1
fi
if match rust; then
    echo -n "Rust: "; rustc --version
fi
if match haskell; then
    echo -n "GHC: "; ghc --version
fi
if match lean; then
    echo -n "Lean: "; lake --version 2>&1 | head -1
fi

echo ""

# ── C++ ─────────────────────────────────────────────────────────────────────
if match cpp; then
    echo "Building C++..."
    c++ -O2 -std=c++17 -o cpp/bfs_barebones cpp/bfs_barebones.cpp
    echo "  cpp/bfs_barebones"
fi

# ── Rust ────────────────────────────────────────────────────────────────────
if match rust; then
    echo "Building Rust..."
    cargo build --release --manifest-path rust/Cargo.toml
    echo "  rust/target/release/bfs_barebones"
fi

# ── Haskell ─────────────────────────────────────────────────────────────────
if match haskell; then
    echo "Building Haskell..."
    ghc -O2 -XStrict -o haskell/bfs_barebones haskell/BfsBarebones.hs
    echo "  haskell/bfs_barebones"
fi

# ── Lean ────────────────────────────────────────────────────────────────────
if match lean; then
    echo "Building Lean..."
    lake -d lean build
    echo "  lean/.lake/build/bin/bfs_barebones"
fi

echo ""
echo "Build complete."
