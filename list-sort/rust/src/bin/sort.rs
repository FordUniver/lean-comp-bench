use std::env;
use std::time::Instant;

/* LCG PRNG (Knuth) — identical across all languages */
struct Lcg(u64);

impl Lcg {
    fn new(seed: u64) -> Self { Lcg(seed) }
    fn next(&mut self) -> u64 {
        self.0 = self.0.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        self.0
    }
}

/* Quicksort (Lomuto partition) */
fn quicksort(a: &mut [u64]) {
    if a.len() <= 1 { return; }
    let hi = a.len() - 1;
    let pivot = a[hi];
    let mut i = 0;
    for j in 0..hi {
        if a[j] <= pivot {
            a.swap(i, j);
            i += 1;
        }
    }
    a.swap(i, hi);
    let (left, right) = a.split_at_mut(i);
    quicksort(left);
    quicksort(&mut right[1..]);
}

/* Mergesort */
fn mergesort(a: &mut [u64], buf: &mut [u64]) {
    let n = a.len();
    if n <= 1 { return; }
    let mid = n / 2;
    mergesort(&mut a[..mid], &mut buf[..mid]);
    mergesort(&mut a[mid..], &mut buf[mid..]);
    // merge
    buf[..n].copy_from_slice(&a[..n]);
    let (mut i, mut j, mut k) = (0, mid, 0);
    while i < mid && j < n {
        if buf[i] <= buf[j] { a[k] = buf[i]; i += 1; }
        else                 { a[k] = buf[j]; j += 1; }
        k += 1;
    }
    while i < mid { a[k] = buf[i]; i += 1; k += 1; }
    while j < n   { a[k] = buf[j]; j += 1; k += 1; }
}

fn checksum(a: &[u64]) -> u64 {
    a.iter().fold(0u64, |h, &x| h.wrapping_mul(131).wrapping_add(x))
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: {} <algo: quick|merge> <n>", args[0]);
        std::process::exit(1);
    }
    let algo = &args[1];
    let n: usize = args[2].parse().unwrap();

    let mut rng = Lcg::new(42);
    let mut a: Vec<u64> = (0..n).map(|_| rng.next()).collect();

    let start = Instant::now();

    match algo.as_str() {
        "quick" => quicksort(&mut a),
        "merge" => {
            let mut buf = vec![0u64; n];
            mergesort(&mut a, &mut buf);
        }
        _ => { eprintln!("Unknown algo: {}", algo); std::process::exit(1); }
    }

    let ms = start.elapsed().as_secs_f64() * 1000.0;
    println!("{} n={} {:.1}ms checksum={}", algo, n, ms, checksum(&a));
}
