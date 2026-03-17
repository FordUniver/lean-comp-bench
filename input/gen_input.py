#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# ///
"""Generate input files for benchmarks."""

import random
import sys
from pathlib import Path

def gen_graph(n: int, m: int, seed: int, path: Path):
    """Random simple graph with n vertices, m edges."""
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
    print(f"  {path}: {n} vertices, {m} edges")

def gen_polygon_queries(n_poly: int, n_queries: int, seed: int, path: Path):
    """Convex polygon (regular n-gon scaled to integers) + random query points."""
    import math
    rng = random.Random(seed)
    scale = 1_000_000
    # Regular polygon vertices (integer coords)
    poly = []
    for i in range(n_poly):
        angle = 2 * math.pi * i / n_poly
        x = int(scale * math.cos(angle))
        y = int(scale * math.sin(angle))
        poly.append((x, y))
    # Random query points in bounding box
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
    print(f"  {path}: {n_poly}-gon, {n_queries} queries")

def gen_cube_incidence(d: int, path: Path):
    """Vertex-facet incidence of d-dimensional hypercube."""
    n_vertices = 2 ** d
    n_facets = 2 * d
    # Vertices are binary strings of length d
    # Facet 2*i: vertices with bit i = 0
    # Facet 2*i+1: vertices with bit i = 1
    with open(path, "w") as f:
        f.write(f"{n_vertices} {n_facets}\n")
        for facet in range(n_facets):
            coord = facet // 2
            value = facet % 2
            verts = [v for v in range(n_vertices) if ((v >> coord) & 1) == value]
            f.write(" ".join(str(v) for v in verts) + "\n")
    print(f"  {path}: {d}-cube, {n_vertices} vertices, {n_facets} facets")

def main():
    out = Path(__file__).parent
    print("Generating inputs:")
    gen_graph(100_000, 500_000, seed=42, path=out / "graph_100k.txt")
    gen_polygon_queries(1_000, 1_000_000, seed=42, path=out / "polygon_1k_1M.txt")
    gen_cube_incidence(7, path=out / "cube_7d.txt")

if __name__ == "__main__":
    main()
