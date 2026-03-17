#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# ///
"""Generate input files for benchmarks.

Graph 3x3 grid: {sparse, medium, dense} × {small, medium, large}
Polygon 3x3 grid: {polygon size} × {query count}
Cube: dimensions 5, 6, 7
"""

import random
import math
from pathlib import Path


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


def main():
    out = Path(__file__).parent
    seed = 42

    # ── Graphs: 3×3 grid (density × size) ────────────────────────────────
    print("Graphs:")
    graph_grid = {
        #            medium (100K)              large (1M)
        "sparse": [(100_000, 150_000), (1_000_000, 1_500_000)],
        "medium": [(100_000, 500_000), (1_000_000, 5_000_000)],
        "dense": [(100_000, 5_000_000)],
    }
    for density, sizes in graph_grid.items():
        for n, m in sizes:
            name = f"graph_{density}_{n // 1000}k.txt"
            gen_graph(n, m, seed, out / name)

    # ── Polygons: 3×3 grid (polygon size × query count) ──────────────────
    print("\nPolygons:")
    poly_sizes = [100, 1_000, 10_000]
    query_counts = [100_000, 1_000_000]
    for np in poly_sizes:
        for nq in query_counts:
            name = f"polygon_{np}_{nq // 1000}k.txt"
            gen_polygon_queries(np, nq, seed, out / name)

    # ── Cubes: dimensions 6, 7, 8 ────────────────────────────────────────
    print("\nCubes:")
    for d in [6, 7, 8]:
        gen_cube_incidence(d, out / f"cube_{d}d.txt")


if __name__ == "__main__":
    main()
