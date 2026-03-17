// Point-in-convex-hull (2D) benchmark
use std::env;
use std::fs;
use std::time::Instant;

#[inline(always)]
fn parse_i64(bytes: &[u8]) -> i64 {
    if bytes.first() == Some(&b'-') {
        let mut n: i64 = 0;
        for &b in &bytes[1..] {
            n = n * 10 + (b - b'0') as i64;
        }
        -n
    } else {
        let mut n: i64 = 0;
        for &b in bytes {
            n = n * 10 + (b - b'0') as i64;
        }
        n
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <polygon_file>", args[0]);
        std::process::exit(1);
    }

    // ── Read ─────────────────────────────────────────────────────────────────
    let t0 = Instant::now();

    let bytes = fs::read(&args[1]).unwrap();
    let mut iter = bytes
        .split(|&b| b == b' ' || b == b'\n' || b == b'\r' || b == b'\t')
        .filter(|s| !s.is_empty());

    let np: usize = parse_i64(iter.next().unwrap()) as usize;
    let nq: usize = parse_i64(iter.next().unwrap()) as usize;

    let mut px = vec![0i64; np];
    let mut py = vec![0i64; np];
    for i in 0..np {
        px[i] = parse_i64(iter.next().unwrap());
        py[i] = parse_i64(iter.next().unwrap());
    }

    let mut qx = vec![0i64; nq];
    let mut qy = vec![0i64; nq];
    for i in 0..nq {
        qx[i] = parse_i64(iter.next().unwrap());
        qy[i] = parse_i64(iter.next().unwrap());
    }

    let read_ms = t0.elapsed().as_secs_f64() * 1000.0;

    // ── Compute ──────────────────────────────────────────────────────────────
    let t1 = Instant::now();

    let mut inside = 0u32;
    for q in 0..nq {
        let x = qx[q];
        let y = qy[q];
        let mut is_in = true;
        for i in 0..np {
            let j = if i + 1 < np { i + 1 } else { 0 };
            let cross = (px[j] - px[i]) * (y - py[i]) - (py[j] - py[i]) * (x - px[i]);
            if cross < 0 {
                is_in = false;
            }
        }
        if is_in {
            inside += 1;
        }
    }

    let compute_ms = t1.elapsed().as_secs_f64() * 1000.0;

    println!(
        "read={:.1}ms compute={:.1}ms inside={} total={}",
        read_ms, compute_ms, inside, nq
    );
}
