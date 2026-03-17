# How Fast Is Verified Lean?

Baseline performance comparison of Lean 4 against C++, Rust, and Haskell on combinatorial algorithms from graph and polyhedral computation. Lean 4 is both a theorem prover and a compiled programming language. Formally verified implementations of mathematical algorithms have long been possible using interactive theorem provers, but typically with ad-hoc definitions maintained by the implementers themselves. Lean's mathlib library changes this: verified implementations can be tied to a large, actively maintained framework of definitions accepted by both pure and applied mathematicians. This benchmark suite measures how compiled Lean compares to established languages on representative algorithms.

## Benchmarks

Four algorithms from two domains (graph algorithms, polyhedral computation):

**BFS.** Graph traversal from vertex 0 on random graphs in CSR representation. Parameters: 100K vertices at sparse (avg degree 3), medium (avg degree 10), and dense (avg degree 100) densities.

**Color Refinement (1-WL).** Iterative partition refinement: hash each vertex's color together with its sorted neighbor colors, assign new colors, repeat until stable. First step of graph canonization. Same graphs as BFS.

**Point-in-Convex-Hull (2D).** Test 100K query points for membership in a convex polygon via cross-product sign test. `int64` arithmetic. Polygon sizes: 100, 1000, 10000 vertices.

**Face Enumeration.** Enumerate all faces of a hypercube by closing vertex-facet incidences under pairwise intersection. Faces as 512-bit bitsets. Dimensions: 6 (728 faces), 7 (2186 faces), 8 (6560 faces).

## Languages

| Language | Compilation | Notes |
|---|---|---|
| **C++** | clang/g++ `-O2 -std=c++17` | `std::vector`, `.at()` bounds checking |
| **Rust** | `--release`, LTO | Safe indexing, no `unsafe` |
| **Haskell** | GHC `-O2` via cabal | Bounds-checked mutable vectors |
| **Lean 4** | v4.28, `lake build` | `sorry` proofs for array bounds (erased at compile time) |

## Principles

Each implementation is intended to be idiomatic and responsible for its language (see [Caveats](#caveats) for known compromises). C++, Rust, and Haskell use bounds-checked array access; Lean uses unchecked access made safe by (sorry) proofs, matching what a fully verified implementation would compile to. All four implementations of each algorithm are structurally identical (same CSR construction, same loop structure, same hash function). Checksums are verified across languages on every run.

All implementations read the same input files. Timing separates I/O from computation; only compute time is reported.

## Caveats

- Lean implementations use `sorry` as a stand-in for real bound proofs. Since proofs are erased at compile time, the resulting binaries are identical to what fully verified code would produce.
- Lean's `for i in [:n]` compiles to heap-allocated `Nat` arithmetic (a known compiler limitation). Pre-allocated arrays with indexed writes are used where this was identified as a bottleneck.
- Color refinement uses insertion sort for neighbor colors in all languages. Lean and Haskell lack stdlib slice-sort; C++ and Rust use insertion sort to match, keeping the algorithm identical. This is O(d²) per vertex and affects dense graph performance.
- Point-in-hull iterates all polygon edges without early exit. Lean's `for` range loop cannot break; all other languages match this behavior for consistency. A real implementation would exit on the first negative cross product.
- Lean's generated C code does not auto-vectorize. C++ and Rust inner loops may benefit from SIMD.
- All benchmarks are single-threaded.
- Results vary between platforms (Apple Silicon vs x86_64 Linux) though ratios are broadly consistent.

## Results

Compute time in milliseconds (mean ± stddev, 7 runs). Linux x86_64, single core. All languages produce identical checksums.

<!-- RESULTS_START -->
### BFS

| | sparse 100K | medium 100K | dense 100K |
|---|---:|---:|---:|
| **C++** | 4.5 ± 0.2 | 5.7 ± 0.2 | 30.4 ± 3.5 |
| **Rust** | 5.0 ± 0.7 | 5.9 ± 0.2 | 30.2 ± 3.1 |
| **Haskell** | 4.2 ± 0.3 | 6.5 ± 0.2 | 33.6 ± 3.5 |
| **Lean** | 21.4 ± 0.8 | 34.7 ± 0.9 | 209.4 ± 12.4 |
| **Lean/C++** | **4.7x** | **6.1x** | **6.9x** |

### Color Refinement (1-WL)

| | sparse 100K | medium 100K | dense 100K |
|---|---:|---:|---:|
| **C++** | 70.9 ± 0.7 | 58.2 ± 1.3 | 419.5 ± 1.8 |
| **Rust** | 34.8 ± 0.7 | 36.7 ± 0.3 | 205.1 ± 5.0 |
| **Haskell** | 247.7 ± 1.6 | 165.2 ± 1.6 | 829.0 ± 3.8 |
| **Lean** | 215.0 ± 3.9 | 242.2 ± 2.6 | 2327.8 ± 45.7 |
| **Lean/C++** | **3.0x** | **4.2x** | **5.5x** |

### Point-in-Convex-Hull (2D)

| | 100-gon | 1000-gon | 10000-gon |
|---|---:|---:|---:|
| **C++** | 10.0 ± 0.1 | 90.6 ± 0.9 | 895.7 ± 15.5 |
| **Rust** | 8.7 ± 0.7 | 57.7 ± 0.8 | 548.9 ± 5.6 |
| **Haskell** | 16.1 ± 0.3 | 139.8 ± 0.8 | 1395.5 ± 29.7 |
| **Lean** | 47.6 ± 0.7 | 421.7 ± 2.4 | 4190.4 ± 33.0 |
| **Lean/C++** | **4.7x** | **4.7x** | **4.7x** |

### Face Enumeration

| | 6-cube | 7-cube | 8-cube |
|---|---:|---:|---:|
| **C++** | 8.3 ± 0.6 | 28.8 ± 0.6 | 19.1 ± 0.9 |
| **Rust** | 5.9 ± 0.1 | 22.5 ± 0.9 | 15.7 ± 0.5 |
| **Haskell** | 12.4 ± 0.9 | 51.3 ± 1.0 | 51.1 ± 0.7 |
| **Lean** | 12.4 ± 1.2 | 70.4 ± 0.6 | 35.5 ± 1.6 |
| **Lean/C++** | **1.5x** | **2.4x** | **1.9x** |

<!-- RESULTS_END -->

## Usage

```bash
./bench.py gen-inputs              # generate all input files
./bench.py build                   # build all languages
./bench.py run --runs 7            # run benchmarks (default 5 runs)
./bench.py run --build --runs 7    # build then run
./bench.py run --bench bfs         # single benchmark
./bench.py readme                  # regenerate README tables from results JSON
```

Prerequisites: C++17 compiler, Rust, GHC + cabal, Lean 4 (elan), Python 3.11+.
