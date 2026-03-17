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
| **C++** | 4.4 ± 0.1 | 5.6 ± 0.1 | 31.8 ± 3.2 |
| **Rust** | 4.9 ± 0.6 | 6.0 ± 0.2 | 33.0 ± 2.9 |
| **Haskell** | 4.1 ± 0.1 | 6.5 ± 0.2 | 32.1 ± 3.4 |
| **Lean** | 20.9 ± 0.5 | 36.2 ± 1.4 | 211.1 ± 3.5 |
| **Lean/C++** | **4.7x** | **6.4x** | **6.6x** |

### Color Refinement (1-WL)

| | sparse 100K | medium 100K | dense 100K |
|---|---:|---:|---:|
| **C++** | 71.0 ± 0.8 | 62.9 ± 1.6 | 548.5 ± 2.0 |
| **Rust** | 34.8 ± 0.7 | 37.1 ± 1.5 | 323.7 ± 1.1 |
| **Haskell** | 249.0 ± 4.2 | 172.1 ± 3.5 | 830.6 ± 6.9 |
| **Lean** | 213.1 ± 2.7 | 250.4 ± 4.8 | 2314.8 ± 19.9 |
| **Lean/C++** | **3.0x** | **4.0x** | **4.2x** |

### Point-in-Convex-Hull (2D)

| | 100-gon | 1000-gon | 10000-gon |
|---|---:|---:|---:|
| **C++** | 23.8 ± 0.5 | 224.7 ± 1.7 | 2236.5 ± 9.3 |
| **Rust** | 18.4 ± 0.2 | 152.6 ± 1.0 | 1498.7 ± 7.5 |
| **Haskell** | 24.0 ± 0.3 | 215.3 ± 1.0 | 2135.4 ± 18.1 |
| **Lean** | 48.0 ± 0.8 | 421.0 ± 2.0 | 4182.2 ± 53.0 |
| **Lean/C++** | **2.0x** | **1.9x** | **1.9x** |

### Face Enumeration

| | 6-cube | 7-cube | 8-cube |
|---|---:|---:|---:|
| **C++** | 13.2 ± 3.2 | 64.5 ± 4.8 | 516.7 ± 12.0 |
| **Rust** | 10.4 ± 3.1 | 39.9 ± 4.7 | 279.3 ± 6.2 |
| **Haskell** | 18.4 ± 3.2 | 107.0 ± 4.5 | 819.6 ± 17.4 |
| **Lean** | 15.2 ± 1.3 | 85.9 ± 2.3 | 722.9 ± 10.5 |
| **Lean/C++** | **1.2x** | **1.3x** | **1.4x** |

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
