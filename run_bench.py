#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# ///
"""
Benchmark runner. Interleaves languages within each run to avoid systematic bias.

Usage:
    ./run_bench.py                     # 5 runs, all benchmarks, 100K graphs
    ./run_bench.py --runs 10           # 10 runs
    ./run_bench.py --bench bfs         # BFS only
    ./run_bench.py --graphs medium_100k sparse_100k
"""

import argparse
import json
import os
import random
import re
import subprocess
import statistics
import sys
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent

LANGUAGES = {
    "C++": {
        "bfs": ROOT / "cpp" / "bfs",
        "color_refine": ROOT / "cpp" / "color_refine",
        "point_in_hull": ROOT / "cpp" / "point_in_hull",
        "face_enum": ROOT / "cpp" / "face_enum",
    },
    "Rust": {
        "bfs": ROOT / "rust" / "target" / "release" / "bfs",
        "color_refine": ROOT / "rust" / "target" / "release" / "color_refine",
        "point_in_hull": ROOT / "rust" / "target" / "release" / "point_in_hull",
        "face_enum": ROOT / "rust" / "target" / "release" / "face_enum",
    },
    "Haskell": {
        "bfs": ROOT / "haskell" / "Bfs",
        "color_refine": ROOT / "haskell" / "ColorRefine",
        "point_in_hull": ROOT / "haskell" / "PointInHull",
        "face_enum": ROOT / "haskell" / "FaceEnum",
    },
    "Lean": {
        "bfs": ROOT / "lean" / ".lake" / "build" / "bin" / "bfs",
        "color_refine": ROOT / "lean" / ".lake" / "build" / "bin" / "color_refine",
        "point_in_hull": ROOT / "lean" / ".lake" / "build" / "bin" / "point_in_hull",
        "face_enum": ROOT / "lean" / ".lake" / "build" / "bin" / "face_enum",
    },
}

GRAPHS = [
    "sparse_1k", "medium_1k", "dense_1k",
    "sparse_100k", "medium_100k", "dense_100k",
    "sparse_1000k", "medium_1000k",
]

POLYGONS = [
    "100_10k", "100_100k", "100_1000k",
    "1000_10k", "1000_100k", "1000_1000k",
    "10000_10k", "10000_100k", "10000_1000k",
]

# Map benchmark -> (input prefix, default inputs, checksum key)
BENCH_CONFIG = {
    "bfs":           ("graph_",   lambda: [g for g in GRAPHS if "100k" in g], "checksum"),
    "color_refine":  ("graph_",   lambda: [g for g in GRAPHS if "100k" in g], "checksum"),
    "point_in_hull": ("polygon_", lambda: ["100_100k", "1000_100k", "10000_100k"], "inside"),
    "face_enum":     ("cube_",    lambda: ["5d", "6d", "7d"], "checksum"),
}


def parse_output(output: str) -> dict:
    """Parse benchmark output line into dict."""
    result = {}
    for match in re.finditer(r"(\w+)=([\d.]+)", output):
        key, val = match.group(1), match.group(2)
        result[key] = float(val) if "." in val else int(val)
    return result


def run_once(binary: Path, input_file: Path) -> dict | None:
    """Run a single benchmark invocation."""
    try:
        proc = subprocess.run(
            [str(binary), str(input_file)],
            capture_output=True, text=True, timeout=300,
        )
        if proc.returncode != 0:
            return None
        return parse_output(proc.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def fmt_ms(values: list[float]) -> str:
    """Format mean ± stddev."""
    if not values:
        return "—"
    mean = statistics.mean(values)
    if len(values) < 2:
        return f"{mean:.1f}"
    sd = statistics.stdev(values)
    return f"{mean:.1f} ± {sd:.1f}"


def main():
    parser = argparse.ArgumentParser(description="Run benchmarks")
    parser.add_argument("--runs", type=int, default=5, help="Number of runs (default: 5)")
    parser.add_argument("--bench", nargs="*", default=list(BENCH_CONFIG.keys()),
                        help="Benchmarks to run (default: all)")
    parser.add_argument("--inputs", nargs="*", default=None,
                        help="Input names (default: per-benchmark defaults)")
    parser.add_argument("--warmup", type=int, default=1, help="Warmup runs (default: 1)")
    args = parser.parse_args()

    # Check binaries exist
    for lang, binaries in LANGUAGES.items():
        for bench in args.bench:
            if bench in binaries and not binaries[bench].exists():
                print(f"WARNING: {lang} {bench} binary not found at {binaries[bench]}")

    # Collect results: results[bench][input_name][lang] = [compute_ms, ...]
    results = {}

    for bench in args.bench:
        if bench not in BENCH_CONFIG:
            print(f"WARNING: unknown benchmark {bench}, skipping")
            continue
        prefix, default_inputs_fn, checksum_key = BENCH_CONFIG[bench]
        input_names = args.inputs if args.inputs else default_inputs_fn()

        results[bench] = {}
        for input_name in input_names:
            input_file = ROOT / "input" / f"{prefix}{input_name}.txt"
            if not input_file.exists():
                print(f"WARNING: {input_file} not found, skipping")
                continue

            results[bench][input_name] = {lang: [] for lang in LANGUAGES}
            langs = [lang for lang in LANGUAGES if bench in LANGUAGES[lang]]

            # Warmup
            for _ in range(args.warmup):
                for lang in langs:
                    run_once(LANGUAGES[lang][bench], input_file)

            # Measured runs: interleave languages within each run
            for run_idx in range(args.runs):
                run_order = langs.copy()
                random.shuffle(run_order)

                for lang in run_order:
                    binary = LANGUAGES[lang][bench]
                    out = run_once(binary, input_file)
                    if out and "compute" in out:
                        results[bench][input_name][lang].append(out["compute"])

                done = run_idx + 1
                print(f"\r  {bench} / {input_name}: run {done}/{args.runs}", end="", flush=True)
            print()

            # Verify checksums match across languages
            checksums = set()
            for lang in langs:
                out = run_once(LANGUAGES[lang][bench], input_file)
                if out and checksum_key in out:
                    checksums.add(out[checksum_key])
            if len(checksums) > 1:
                print(f"  WARNING: checksum mismatch on {input_name}: {checksums}")

    # Print tables
    print("\n" + "=" * 80)
    for bench in args.bench:
        if bench not in results:
            continue
        print(f"\n{bench.upper().replace('_', ' ')} — compute time (ms), mean ± stddev, {args.runs} runs\n")

        graphs = list(results[bench].keys())
        header = "| | " + " | ".join(graphs) + " |"
        sep = "|---|" + "|".join(["---"] * len(graphs)) + "|"
        print(header)
        print(sep)

        for lang in LANGUAGES:
            row = f"| **{lang}** |"
            for graph in graphs:
                values = results[bench].get(graph, {}).get(lang, [])
                row += f" {fmt_ms(values)} |"
            print(row)

        # Lean/C++ ratio
        print(f"| **Lean/C++** |", end="")
        for graph in graphs:
            lean_vals = results[bench].get(graph, {}).get("Lean", [])
            cpp_vals = results[bench].get(graph, {}).get("C++", [])
            if lean_vals and cpp_vals:
                ratio = statistics.mean(lean_vals) / statistics.mean(cpp_vals)
                print(f" {ratio:.1f}x |", end="")
            else:
                print(" — |", end="")
        print()

    # Save raw results
    outdir = ROOT / "results" / datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    outdir.mkdir(parents=True, exist_ok=True)
    with open(outdir / "results.json", "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nRaw results saved to {outdir}/results.json")


if __name__ == "__main__":
    main()
