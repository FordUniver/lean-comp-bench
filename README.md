# lean-comp-bench

Baseline performance comparison of Lean 4 against C++, Rust, and Haskell on combinatorial algorithms from graph and polyhedral computation. Lean 4 is both a theorem prover and a compiled programming language. Formally verified implementations of mathematical algorithms have long been possible using interactive theorem provers, but typically with ad-hoc definitions maintained by the implementers themselves. Lean's mathlib library changes this: verified implementations can be tied to a large, actively maintained framework of definitions accepted by both pure and applied mathematicians. This benchmark suite measures how compiled Lean compares to established languages on representative algorithms.

## Benchmarks

Four algorithms from two domains (graph algorithms, polyhedral computation):

**BFS.** Graph traversal from vertex 0 on random graphs in CSR representation. Parameters: 100K vertices at sparse (avg degree 3), medium (avg degree 10), and dense (avg degree 100) densities.

**Color Refinement (1-WL).** Iterative partition refinement: hash each vertex's color together with its sorted neighbor colors, assign new colors, repeat until stable. First step of graph canonization. Same graphs as BFS.

**Point-in-Convex-Hull (2D).** Test 100K query points for membership in a convex polygon via cross-product sign test. `int64` arithmetic. Polygon sizes: 100, 1000, 10000 vertices.

**Face Enumeration.** Enumerate all faces of a hypercube by closing vertex-facet incidences under pairwise intersection. Faces as 128-bit bitsets. Dimensions: 5 (242 faces), 6 (728 faces), 7 (2186 faces).

## Languages

| Language | Compilation | Notes |
|---|---|---|
| **C++** | clang/g++ `-O2 -std=c++17` | `std::vector`, `.at()` bounds checking |
| **Rust** | `--release`, LTO | Safe indexing, no `unsafe` |
| **Haskell** | GHC `-O2` via cabal | Bounds-checked mutable vectors |
| **Lean 4** | v4.28, `lake build` | `sorry` proofs for array bounds (erased at compile time) |

## Principles

Each language uses its idiomatic, responsible style. C++, Rust, and Haskell use bounds-checked array access; Lean uses unchecked access backed by (sorry) proofs, matching what a fully verified implementation would compile to. All four implementations of each algorithm are structurally identical (same CSR construction, same loop structure, same hash function). Checksums are verified across languages on every run.

All implementations read the same input files. Timing separates I/O from computation; only compute time is reported.

## Caveats

- Lean implementations use `sorry` as a stand-in for real bound proofs. Since proofs are erased at compile time, the resulting binaries are identical to what fully verified code would produce.
- Lean's `for i in [:n]` compiles to heap-allocated `Nat` arithmetic (a known compiler limitation). Pre-allocated arrays with indexed writes are used where this was identified as a bottleneck.
- Lean's generated C code does not auto-vectorize. C++ and Rust inner loops may benefit from SIMD.
- All benchmarks are single-threaded.
- Results vary between platforms (Apple Silicon vs x86_64 Linux) though ratios are broadly consistent.

## Results

Compute time in milliseconds (mean ± stddev, 7 runs). Linux x86_64, single core. All languages produce identical checksums.

<!-- RESULTS_START -->
### BFS

| | sparse 100K | medium 100K | dense 100K |
|---|---:|---:|---:|
| **C++** | 4.5 ± 0.3 | 5.8 ± 0.2 | 29.2 ± 4.3 |
| **Rust** | 5.2 ± 0.6 | 6.4 ± 0.2 | 30.6 ± 4.1 |
| **Haskell** | 4.4 ± 0.3 | 6.4 ± 0.1 | 34.0 ± 4.0 |
| **Lean** | 22.2 ± 1.2 | 35.4 ± 2.0 | 209.4 ± 8.4 |
| **Lean/C++** | **5.0x** | **6.2x** | **7.2x** |

### Color Refinement (1-WL)

| | sparse 100K | medium 100K | dense 100K |
|---|---:|---:|---:|
| **C++** | 72.2 ± 1.2 | 58.4 ± 1.4 | 421.8 ± 7.2 |
| **Rust** | 36.5 ± 0.7 | 40.6 ± 0.8 | 203.5 ± 4.6 |
| **Haskell** | 249.0 ± 5.3 | 169.2 ± 4.7 | 835.8 ± 15.5 |
| **Lean** | 214.8 ± 1.4 | 250.6 ± 7.2 | 2312.8 ± 14.0 |
| **Lean/C++** | **3.0x** | **4.3x** | **5.5x** |

### Point-in-Convex-Hull (2D)

| | 100-gon | 1000-gon | 10000-gon |
|---|---:|---:|---:|
| **C++** | 10.3 ± 0.2 | 90.8 ± 0.8 | 888.4 ± 1.6 |
| **Rust** | 8.9 ± 0.7 | 59.9 ± 2.9 | 548.7 ± 4.1 |
| **Haskell** | 16.3 ± 0.4 | 141.2 ± 1.0 | 1397.3 ± 23.8 |
| **Lean** | 47.7 ± 0.6 | 425.9 ± 9.2 | 4187.6 ± 56.3 |
| **Lean/C++** | **4.6x** | **4.7x** | **4.7x** |

### Face Enumeration

| | 5-cube | 6-cube | 7-cube |
|---|---:|---:|---:|
| **C++** | 1.7 ± 0.2 | 8.2 ± 0.8 | 29.4 ± 0.9 |
| **Rust** | 0.9 ± 0.1 | 5.6 ± 1.8 | 21.6 ± 3.8 |
| **Haskell** | 2.0 ± 0.4 | 11.9 ± 1.0 | 50.9 ± 0.5 |
| **Lean** | 2.8 ± 0.6 | 12.2 ± 0.8 | 72.0 ± 0.9 |
| **Lean/C++** | **1.7x** | **1.5x** | **2.5x** |

<!-- RESULTS_END -->

## Usage

```bash
./run_bench.py --build --runs 7          # build all + run all benchmarks
./run_bench.py --build --bench bfs       # single benchmark
./run_bench.py --build --runs 0          # build only
./gen_readme.py                          # regenerate tables from results JSON
```

Prerequisites: C++17 compiler, Rust, GHC + cabal, Lean 4 (elan), Python 3.11+.
