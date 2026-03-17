#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# ///
"""Regenerate results tables in README.md from benchmark JSON.

Replaces content between <!-- RESULTS_START --> and <!-- RESULTS_END -->
markers. Run after updating results/z3-*.json.
"""

import json
import re
import statistics
from pathlib import Path

ROOT = Path(__file__).parent

# Use most recent z3 results file
RESULTS_DIR = ROOT / "results"
RESULTS_FILES = sorted(RESULTS_DIR.glob("z3-*.json"))
RESULTS_FILE = RESULTS_FILES[-1] if RESULTS_FILES else None

BENCH_LABELS = {
    "bfs": "BFS",
    "color_refine": "Color Refinement (1-WL)",
    "point_in_hull": "Point-in-Convex-Hull (2D)",
    "face_enum": "Face Enumeration",
}

INPUT_LABELS = {
    "sparse_100k": "sparse 100K",
    "medium_100k": "medium 100K",
    "dense_100k": "dense 100K",
    "100_100k": "100-gon",
    "1000_100k": "1000-gon",
    "10000_100k": "10000-gon",
    "5d": "5-cube",
    "6d": "6-cube",
    "7d": "7-cube",
}

LANGUAGES = ["C++", "Rust", "Haskell", "Lean"]


def fmt(values):
    if not values:
        return "—"
    m = statistics.mean(values)
    if len(values) < 2:
        return f"{m:.1f}"
    s = statistics.stdev(values)
    return f"{m:.1f} ± {s:.1f}"


def ratio(lean_vals, other_vals):
    if not lean_vals or not other_vals:
        return "—"
    return f"{statistics.mean(lean_vals) / statistics.mean(other_vals):.1f}x"


def gen_table(bench_data):
    inputs = list(bench_data.keys())
    header = "| | " + " | ".join(INPUT_LABELS.get(i, i) for i in inputs) + " |"
    sep = "|---|" + "|".join(["---:"] * len(inputs)) + "|"
    rows = [header, sep]
    for lang in LANGUAGES:
        row = f"| **{lang}** |"
        for inp in inputs:
            vals = bench_data.get(inp, {}).get(lang, [])
            row += f" {fmt(vals)} |"
        rows.append(row)
    row = "| **Lean/C++** |"
    for inp in inputs:
        lean = bench_data.get(inp, {}).get("Lean", [])
        cpp = bench_data.get(inp, {}).get("C++", [])
        row += f" **{ratio(lean, cpp)}** |"
    rows.append(row)
    return "\n".join(rows)


def main():
    if not RESULTS_FILE:
        print("No results/*.json found. Run benchmarks first.")
        return

    print(f"Using {RESULTS_FILE.name}")

    with open(RESULTS_FILE) as f:
        results = json.load(f)

    tables = ""
    for bench_key in ["bfs", "color_refine", "point_in_hull", "face_enum"]:
        if bench_key not in results:
            continue
        tables += f"### {BENCH_LABELS[bench_key]}\n\n"
        tables += gen_table(results[bench_key])
        tables += "\n\n"

    readme = ROOT / "README.md"
    content = readme.read_text()

    marker_re = r"(<!-- RESULTS_START -->\n).*?(\n<!-- RESULTS_END -->)"
    new_block = f"\\1{tables.strip()}\n\\2"

    if not re.search(marker_re, content, re.DOTALL):
        print("ERROR: markers <!-- RESULTS_START/END --> not found in README.md")
        return

    content = re.sub(marker_re, new_block, content, flags=re.DOTALL)
    readme.write_text(content)
    print(f"Updated {readme}")


if __name__ == "__main__":
    main()
