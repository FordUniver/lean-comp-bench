#!/usr/bin/env bash
# Run BFS benchmarks across all languages and input sizes.
# Usage: ./bench.sh [--warmup N] [--runs N] [--filter LANG]
#
# Generates inputs if missing, builds all languages, then runs hyperfine
# for each benchmark × input combination. Results go to results/<timestamp>/.
set -euo pipefail

cd "$(dirname "$0")"

WARMUP=1
RUNS=5
FILTER=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --warmup) WARMUP="$2"; shift 2 ;;
        --runs)   RUNS="$2"; shift 2 ;;
        --filter) FILTER="$2"; shift 2 ;;
        *)        echo "Unknown option: $1"; exit 1 ;;
    esac
done

match() { [[ -z "$FILTER" ]] || [[ "$1" == *"$FILTER"* ]]; }

# ── Generate inputs if missing ──────────────────────────────────────────────
GRAPH_COUNT=$(find input -maxdepth 1 -name 'graph_*.txt' 2>/dev/null | wc -l | tr -d ' ')
if [[ "$GRAPH_COUNT" -eq 0 ]]; then
    echo "Generating inputs..."
    ./input/gen_input.py
    echo ""
fi

# ── Build ───────────────────────────────────────────────────────────────────
./build.sh "$FILTER"

# ── Benchmark ───────────────────────────────────────────────────────────────
TIMESTAMP=$(gdate -u +%Y%m%d-%H%M%S 2>/dev/null || date -u +%Y%m%d-%H%M%S)
OUTDIR="results/$TIMESTAMP"
mkdir -p "$OUTDIR"

# Collect binaries
declare -A BINS
if match cpp;     then BINS[cpp]="cpp/bfs_barebones"; fi
if match rust;    then BINS[rust]="rust/target/release/bfs_barebones"; fi
if match haskell; then BINS[haskell]="haskell/bfs_barebones"; fi
if match lean;    then BINS[lean]="lean/.lake/build/bin/bfs_barebones"; fi

# Collect graph inputs (sorted by name for reproducibility)
mapfile -t INPUTS < <(find input -maxdepth 1 -name 'graph_*.txt' -print | sort)

echo ""
echo "=== Benchmarking (warmup=$WARMUP, runs=$RUNS) ==="
echo "Languages: ${!BINS[*]}"
echo "Inputs: ${#INPUTS[@]} graph files"
echo "Output: $OUTDIR/"
echo ""

for INPUT in "${INPUTS[@]}"; do
    INAME=$(basename "$INPUT" .txt)
    echo "── $INAME ──"

    # Build hyperfine command args
    HFARGS=(--warmup "$WARMUP" --runs "$RUNS" --export-json "$OUTDIR/$INAME.json")
    NAMES=()
    CMDS=()
    for LANG in $(echo "${!BINS[@]}" | tr ' ' '\n' | sort); do
        BIN="${BINS[$LANG]}"
        if [[ -x "$BIN" ]]; then
            NAMES+=("$LANG")
            CMDS+=("$BIN $INPUT")
        fi
    done

    if [[ ${#CMDS[@]} -eq 0 ]]; then
        echo "  No binaries found, skipping."
        continue
    fi

    # Add --command-name and commands
    for i in "${!CMDS[@]}"; do
        HFARGS+=(--command-name "${NAMES[$i]}" "${CMDS[$i]}")
    done

    hyperfine "${HFARGS[@]}"
    echo ""
done

echo "Results saved to $OUTDIR/"
