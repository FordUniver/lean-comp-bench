// Face enumeration from vertex-facet incidence benchmark
use std::collections::HashSet;
use std::env;
use std::fs;
use std::hash::{Hash, Hasher};
use std::time::Instant;

#[inline(always)]
fn parse_usize(bytes: &[u8]) -> usize {
    let mut n: usize = 0;
    for &b in bytes {
        n = n * 10 + (b - b'0') as usize;
    }
    n
}

#[derive(Clone, Copy, PartialEq, Eq)]
struct Face {
    w: [u64; 8],
}

impl Hash for Face {
    fn hash<H: Hasher>(&self, state: &mut H) {
        self.w.hash(state);
    }
}

impl Face {
    fn empty() -> Self {
        Face { w: [0; 8] }
    }
    fn set_bit(&mut self, v: usize) {
        self.w[v / 64] |= 1u64 << (v % 64);
    }
    fn intersect(&self, other: &Face) -> Face {
        let mut r = [0u64; 8];
        for i in 0..8 {
            r[i] = self.w[i] & other.w[i];
        }
        Face { w: r }
    }
    fn popcount(&self) -> u32 {
        let mut c = 0u32;
        for i in 0..8 {
            c += self.w[i].count_ones();
        }
        c
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <incidence_file>", args[0]);
        std::process::exit(1);
    }

    // ── Read ─────────────────────────────────────────────────────────────────
    let t0 = Instant::now();

    let bytes = fs::read(&args[1]).unwrap();
    let mut lines = bytes.split(|&b| b == b'\n');

    let header = lines.next().unwrap();
    let mut hiter = header.split(|&b| b == b' ').filter(|s| !s.is_empty());
    let _nv: usize = parse_usize(hiter.next().unwrap());
    let nf: usize = parse_usize(hiter.next().unwrap());

    let mut facets = Vec::with_capacity(nf);
    for _ in 0..nf {
        let line = lines.next().unwrap_or(&[]);
        let mut face = Face::empty();
        for tok in line.split(|&b| b == b' ').filter(|s| !s.is_empty()) {
            face.set_bit(parse_usize(tok));
        }
        facets.push(face);
    }

    let read_ms = t0.elapsed().as_secs_f64() * 1000.0;

    // ── Compute ──────────────────────────────────────────────────────────────
    let t1 = Instant::now();

    let mut all_faces = HashSet::new();
    let mut worklist = Vec::new();

    for &f in &facets {
        if all_faces.insert(f) {
            worklist.push(f);
        }
    }

    let mut processed = 0;
    while processed < worklist.len() {
        let current = worklist[processed];
        processed += 1;
        for j in 0..processed {
            let inter = current.intersect(&worklist[j]);
            if inter.popcount() > 0
                && all_faces.insert(inter) {
                    worklist.push(inter);
                }
        }
    }

    let checksum: i64 = all_faces.iter().map(|f| f.popcount() as i64).sum();

    let compute_ms = t1.elapsed().as_secs_f64() * 1000.0;

    println!(
        "read={:.1}ms compute={:.1}ms faces={} checksum={}",
        read_ms,
        compute_ms,
        all_faces.len(),
        checksum
    );
}
