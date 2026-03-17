#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# ///
"""Unified benchmark tool: generate inputs, build, run benchmarks, update README.

Usage:
    ./bench.py gen-inputs              # generate all input files
    ./bench.py build                   # build all languages
    ./bench.py run --runs 7            # run benchmarks (default 5 runs)
    ./bench.py run --build --runs 7    # build then run
    ./bench.py run --bench bfs         # single benchmark
    ./bench.py readme                  # regenerate README tables
"""

import argparse
import json
import math
import random
import re
import statistics
import subprocess
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).parent

# ── Configuration ──────────────────────────────────────────────────────────

BENCHMARKS = {
    "bfs": {
        "label": "BFS",
        "input_prefix": "graph_",
        "checksum_key": "checksum",
        "inputs": ["sparse_100k", "medium_100k", "dense_100k"],
    },
    "color_refine": {
        "label": "Color Refinement (1-WL)",
        "input_prefix": "graph_",
        "checksum_key": "checksum",
        "inputs": ["sparse_100k", "medium_100k", "dense_100k"],
    },
    "point_in_hull": {
        "label": "Point-in-Convex-Hull (2D)",
        "input_prefix": "polygon_",
        "checksum_key": "inside",
        "inputs": ["100_100k", "1000_100k", "10000_100k"],
    },
    "face_enum": {
        "label": "Face Enumeration",
        "input_prefix": "cube_",
        "checksum_key": "checksum",
        "inputs": ["6d", "7d", "8d"],
    },
}

LANGUAGES = ["C++", "Rust", "Haskell", "Lean"]

INPUT_LABELS = {
    "sparse_100k": "sparse 100K",
    "medium_100k": "medium 100K",
    "dense_100k": "dense 100K",
    "100_100k": "100-gon",
    "1000_100k": "1000-gon",
    "10000_100k": "10000-gon",
    "6d": "6-cube",
    "7d": "7-cube",
    "8d": "8-cube",
}

GRAPH_SPECS = {
    "sparse_100k": (100_000, 150_000),
    "medium_100k": (100_000, 500_000),
    "dense_100k": (100_000, 5_000_000),
    "sparse_1000k": (1_000_000, 1_500_000),
    "medium_1000k": (1_000_000, 5_000_000),
}

POLYGON_SPECS = {
    "100_100k": (100, 100_000),
    "100_1000k": (100, 1_000_000),
    "1000_100k": (1_000, 100_000),
    "1000_1000k": (1_000, 1_000_000),
    "10000_100k": (10_000, 100_000),
    "10000_1000k": (10_000, 1_000_000),
}

CUBE_DIMS = [6, 7, 8]


# ── Binary path derivation ────────────────────────────────────────────────


def binary_path(lang: str, bench: str) -> Path:
    if lang == "C++":
        return ROOT / "cpp" / bench
    elif lang == "Rust":
        return ROOT / "rust" / "target" / "release" / bench
    elif lang == "Haskell":
        # snake_case -> CamelCase: color_refine -> ColorRefine, bfs -> Bfs
        camel = "".join(w.capitalize() for w in bench.split("_"))
        return ROOT / "haskell" / camel
    elif lang == "Lean":
        return ROOT / "lean" / ".lake" / "build" / "bin" / bench
    raise ValueError(f"Unknown language: {lang}")


# ── Input generation ───────────────────────────────────────────────────────


def gen_graph(n: int, m: int, seed: int, path: Path):
    """Random simple graph with n vertices, m edges."""
    max_edges = n * (n - 1) // 2
    if m > max_edges:
        print(f"  SKIP {path.name}: m={m} exceeds max edges {max_edges} for n={n}")
        return
    rng = random.Random(seed)
    edges = set()
    while len(edges) < m:
        u = rng.randint(0, n - 1)
        v = rng.randint(0, n - 1)
        if u != v and (u, v) not in edges and (v, u) not in edges:
            edges.add((u, v))
    with open(path, "w") as f:
        f.write(f"{n} {m}\n")
        for u, v in sorted(edges):
            f.write(f"{u} {v}\n")
    size_mb = path.stat().st_size / 1e6
    print(f"  {path.name}: n={n} m={m} ({size_mb:.1f} MB)")


def gen_polygon_queries(n_poly: int, n_queries: int, seed: int, path: Path):
    """Convex polygon (regular n-gon scaled to integers) + random query points."""
    rng = random.Random(seed)
    scale = 1_000_000
    poly = []
    for i in range(n_poly):
        angle = 2 * math.pi * i / n_poly
        x = int(scale * math.cos(angle))
        y = int(scale * math.sin(angle))
        poly.append((x, y))
    queries = []
    for _ in range(n_queries):
        x = rng.randint(-scale * 2, scale * 2)
        y = rng.randint(-scale * 2, scale * 2)
        queries.append((x, y))
    with open(path, "w") as f:
        f.write(f"{n_poly} {n_queries}\n")
        for x, y in poly:
            f.write(f"{x} {y}\n")
        for x, y in queries:
            f.write(f"{x} {y}\n")
    size_mb = path.stat().st_size / 1e6
    print(f"  {path.name}: {n_poly}-gon, {n_queries} queries ({size_mb:.1f} MB)")


def gen_cube_incidence(d: int, path: Path):
    """Vertex-facet incidence of d-dimensional hypercube."""
    n_vertices = 2**d
    n_facets = 2 * d
    with open(path, "w") as f:
        f.write(f"{n_vertices} {n_facets}\n")
        for facet in range(n_facets):
            coord = facet // 2
            value = facet % 2
            verts = [v for v in range(n_vertices) if ((v >> coord) & 1) == value]
            f.write(" ".join(str(v) for v in verts) + "\n")
    print(f"  {path.name}: {d}-cube, {n_vertices} vertices, {n_facets} facets")


def cmd_gen_inputs(_args):
    """Generate all input files."""
    out = ROOT / "input"
    out.mkdir(exist_ok=True)
    seed = 42

    print("Graphs:")
    for name, (n, m) in GRAPH_SPECS.items():
        gen_graph(n, m, seed, out / f"graph_{name}.txt")

    print("\nPolygons:")
    for name, (n_poly, n_queries) in POLYGON_SPECS.items():
        gen_polygon_queries(n_poly, n_queries, seed, out / f"polygon_{name}.txt")

    print("\nCubes:")
    for d in CUBE_DIMS:
        gen_cube_incidence(d, out / f"cube_{d}d.txt")


# ── Build ──────────────────────────────────────────────────────────────────


def build():
    """Build all languages."""
    print("=== Building ===")

    # C++
    cpp_dir = ROOT / "cpp"
    for src in sorted(cpp_dir.glob("*.cpp")):
        name = src.stem
        out = cpp_dir / name
        subprocess.run(
            ["c++", "-O2", "-std=c++17", "-o", str(out), str(src)], check=True
        )
        print(f"  C++ {name}")

    # Rust
    subprocess.run(
        [
            "cargo",
            "build",
            "--release",
            "--manifest-path",
            str(ROOT / "rust" / "Cargo.toml"),
            "--quiet",
        ],
        check=True,
    )
    print("  Rust (all)")

    # Haskell (via cabal)
    hs_dir = ROOT / "haskell"
    if (hs_dir / "bench.cabal").exists():
        result = subprocess.run(
            ["cabal", "build", "all"], capture_output=True, text=True, cwd=str(hs_dir)
        )
        if result.returncode == 0:
            print("  Haskell (all via cabal)")
            for bench_name in BENCHMARKS:
                exe_name = bench_name.replace("_", "-")
                list_result = subprocess.run(
                    ["cabal", "list-bin", exe_name],
                    capture_output=True,
                    text=True,
                    cwd=str(hs_dir),
                )
                if list_result.returncode == 0:
                    bin_path = list_result.stdout.strip()
                    target = binary_path("Haskell", bench_name)
                    subprocess.run(["cp", bin_path, str(target)])
        else:
            print(f"  Haskell SKIP (cabal build failed: {result.stderr[-200:]})")
    else:
        print("  Haskell SKIP (no bench.cabal found)")

    # Lean
    result = subprocess.run(
        ["lake", "-d", str(ROOT / "lean"), "build"], capture_output=True, text=True
    )
    if result.returncode == 0:
        print("  Lean (all)")
    else:
        print(f"  Lean FAILED: {result.stderr[-200:]}")

    # Generate inputs if missing
    input_dir = ROOT / "input"
    if not list(input_dir.glob("graph_*.txt")):
        print("\n=== Generating inputs ===")
        cmd_gen_inputs(None)

    print()


def cmd_build(_args):
    """Build subcommand."""
    build()


# ── Benchmark runner ───────────────────────────────────────────────────────


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
            capture_output=True,
            text=True,
            timeout=300,
        )
        if proc.returncode != 0:
            return None
        return parse_output(proc.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return None


def fmt_ms(values: list[float]) -> str:
    """Format mean +/- stddev."""
    if not values:
        return "—"
    mean = statistics.mean(values)
    if len(values) < 2:
        return f"{mean:.1f}"
    sd = statistics.stdev(values)
    return f"{mean:.1f} ± {sd:.1f}"


def cmd_run(args):
    """Run benchmarks."""
    if args.build:
        build()

    bench_names = [args.bench] if args.bench else list(BENCHMARKS.keys())

    # Check binaries exist
    for lang in LANGUAGES:
        for bench in bench_names:
            bp = binary_path(lang, bench)
            if not bp.exists():
                print(f"WARNING: {lang} {bench} binary not found at {bp}")

    # Collect results: results[bench][input_name][lang] = [compute_ms, ...]
    results = {}

    for bench in bench_names:
        if bench not in BENCHMARKS:
            print(f"WARNING: unknown benchmark {bench}, skipping")
            continue
        cfg = BENCHMARKS[bench]
        prefix = cfg["input_prefix"]
        checksum_key = cfg["checksum_key"]
        input_names = cfg["inputs"]

        results[bench] = {}
        for input_name in input_names:
            input_file = ROOT / "input" / f"{prefix}{input_name}.txt"
            if not input_file.exists():
                print(f"WARNING: {input_file} not found, skipping")
                continue

            results[bench][input_name] = {lang: [] for lang in LANGUAGES}
            langs = list(LANGUAGES)

            # Warmup
            for lang in langs:
                run_once(binary_path(lang, bench), input_file)

            # Measured runs: interleave languages within each run
            for run_idx in range(args.runs):
                run_order = langs.copy()
                random.shuffle(run_order)

                for lang in run_order:
                    out = run_once(binary_path(lang, bench), input_file)
                    if out and "compute" in out:
                        results[bench][input_name][lang].append(out["compute"])

                done = run_idx + 1
                print(
                    f"\r  {bench} / {input_name}: run {done}/{args.runs}",
                    end="",
                    flush=True,
                )
            print()

            # Verify checksums match across languages
            checksums = set()
            for lang in langs:
                out = run_once(binary_path(lang, bench), input_file)
                if out and checksum_key in out:
                    checksums.add(out[checksum_key])
            if len(checksums) > 1:
                print(f"  WARNING: checksum mismatch on {input_name}: {checksums}")

    # Print tables
    print("\n" + "=" * 80)
    for bench in bench_names:
        if bench not in results:
            continue
        label = BENCHMARKS[bench]["label"]
        print(f"\n{label} — compute time (ms), mean ± stddev, {args.runs} runs\n")

        inputs = list(results[bench].keys())
        header = "| | " + " | ".join(inputs) + " |"
        sep = "|---|" + "|".join(["---"] * len(inputs)) + "|"
        print(header)
        print(sep)

        for lang in LANGUAGES:
            row = f"| **{lang}** |"
            for inp in inputs:
                values = results[bench].get(inp, {}).get(lang, [])
                row += f" {fmt_ms(values)} |"
            print(row)

        # Lean/C++ ratio
        print("| **Lean/C++** |", end="")
        for inp in inputs:
            lean_vals = results[bench].get(inp, {}).get("Lean", [])
            cpp_vals = results[bench].get(inp, {}).get("C++", [])
            if lean_vals and cpp_vals:
                r = statistics.mean(lean_vals) / statistics.mean(cpp_vals)
                print(f" {r:.1f}x |", end="")
            else:
                print(" — |", end="")
        print()

    # Save raw results
    outdir = ROOT / "results" / datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    outdir.mkdir(parents=True, exist_ok=True)
    with open(outdir / "results.json", "w") as f:
        json.dump(results, f, indent=2)
    print(f"\nRaw results saved to {outdir}/results.json")


# ── README generation ──────────────────────────────────────────────────────


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
            row += f" {fmt_ms(vals)} |"
        rows.append(row)
    row = "| **Lean/C++** |"
    for inp in inputs:
        lean = bench_data.get(inp, {}).get("Lean", [])
        cpp = bench_data.get(inp, {}).get("C++", [])
        row += f" **{ratio(lean, cpp)}** |"
    rows.append(row)
    return "\n".join(rows)


def cmd_readme(_args):
    """Regenerate results tables in README.md from benchmark JSON."""
    results_dir = ROOT / "results"
    results_files = sorted(results_dir.glob("z3-*.json"))
    if not results_files:
        print("No results/z3-*.json found. Run benchmarks first.")
        return

    results_file = results_files[-1]
    print(f"Using {results_file.name}")

    with open(results_file) as f:
        results = json.load(f)

    tables = ""
    for bench_key, cfg in BENCHMARKS.items():
        if bench_key not in results:
            continue
        tables += f"### {cfg['label']}\n\n"
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


# ── CLI ────────────────────────────────────────────────────────────────────


def main():
    parser = argparse.ArgumentParser(description="Benchmark tool")
    sub = parser.add_subparsers(dest="command", required=True)

    sub.add_parser("gen-inputs", help="Generate all input files")
    sub.add_parser("build", help="Build all languages")

    run_parser = sub.add_parser("run", help="Run benchmarks")
    run_parser.add_argument(
        "--runs", type=int, default=5, help="Number of runs (default: 5)"
    )
    run_parser.add_argument("--bench", default=None, help="Single benchmark to run")
    run_parser.add_argument(
        "--build", action="store_true", help="Build all languages before running"
    )

    sub.add_parser("readme", help="Regenerate README tables")

    args = parser.parse_args()

    dispatch = {
        "gen-inputs": cmd_gen_inputs,
        "build": cmd_build,
        "run": cmd_run,
        "readme": cmd_readme,
    }
    dispatch[args.command](args)


if __name__ == "__main__":
    main()
