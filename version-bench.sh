#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
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

for VER in "${VERSIONS[@]}"; do
    echo ""
    echo "--- Lean $VER ---" | tee -a "$RESULTS"

    elan toolchain install "leanprover/lean4:$VER" 2>&1 | tail -1

    TDIR=$(mktemp -d)
    echo "leanprover/lean4:$VER" > "$TDIR/lean-toolchain"

    # Copy source files from version-src/
    if [[ "$VER" < "v4.20" ]]; then
        cp "$ROOT/version-src/Main-old.lean" "$TDIR/Main.lean"
    else
        cp "$ROOT/version-src/Main-new.lean" "$TDIR/Main.lean"
    fi

    if [[ "$VER" < "v4.7" ]]; then
        cp "$ROOT/version-src/lakefile-old.lean" "$TDIR/lakefile.lean"
    else
        cp "$ROOT/version-src/lakefile-new.toml" "$TDIR/lakefile.toml"
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
