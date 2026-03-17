# How Fast Is Verified Lean?

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

Each implementation is intended to be idiomatic and responsible for its language. C++, Rust, and Haskell use bounds-checked array access; Lean uses unchecked access made safe by (sorry) proofs, matching what a fully verified implementation would compile to. All four implementations of each algorithm are structurally identical (same CSR construction, same loop structure, same hash function). Checksums are verified across languages on every run.

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
| **C++** | 4.4 ± 0.2 | 5.9 ± 0.1 | 30.1 ± 1.1 |
| **Rust** | 5.3 ± 0.6 | 6.2 ± 0.1 | 30.4 ± 1.5 |
| **Haskell** | 4.2 ± 0.2 | 6.7 ± 0.1 | 32.8 ± 1.6 |
| **Lean** | 24.5 ± 5.7 | 35.6 ± 0.6 | 209.5 ± 3.1 |
| **Lean/C++** | **5.5x** | **6.1x** | **7.0x** |

### Color Refinement (1-WL)

| | sparse 100K | medium 100K | dense 100K |
|---|---:|---:|---:|
| **C++** | 73.2 ± 0.9 | 61.1 ± 4.8 | 423.9 ± 2.0 |
| **Rust** | 34.4 ± 0.4 | 38.5 ± 1.0 | 204.8 ± 0.9 |
| **Haskell** | 256.7 ± 5.7 | 180.1 ± 7.8 | 837.1 ± 4.7 |
| **Lean** | 214.6 ± 1.7 | 257.6 ± 7.7 | 2327.6 ± 12.5 |
| **Lean/C++** | **2.9x** | **4.2x** | **5.5x** |

### Point-in-Convex-Hull (2D)

| | 100-gon | 1000-gon | 10000-gon |
|---|---:|---:|---:|
| **C++** | 10.5 ± 0.2 | 91.1 ± 1.5 | 893.0 ± 4.0 |
| **Rust** | 8.4 ± 0.8 | 58.7 ± 1.1 | 549.3 ± 5.9 |
| **Haskell** | 16.3 ± 0.2 | 142.3 ± 2.5 | 1386.0 ± 3.1 |
| **Lean** | 49.5 ± 1.1 | 428.0 ± 11.2 | 4199.0 ± 71.9 |
| **Lean/C++** | **4.7x** | **4.7x** | **4.7x** |

### Face Enumeration

| | 5d | 6-cube | 7-cube |
|---|---:|---:|---:|
| **C++** | 1.7 ± 0.1 | 6.5 ± 2.4 | 31.0 ± 5.2 |
| **Rust** | 0.8 ± 0.1 | 5.8 ± 0.2 | 21.3 ± 2.5 |
| **Haskell** | 2.3 ± 0.1 | 12.3 ± 0.7 | 50.3 ± 5.4 |
| **Lean** | 3.5 ± 0.6 | 12.8 ± 0.9 | 70.4 ± 2.2 |
| **Lean/C++** | **2.1x** | **2.0x** | **2.3x** |

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
