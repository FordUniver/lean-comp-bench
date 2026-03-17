// Color refinement (1-WL) benchmark
use std::collections::HashMap;
use std::env;
use std::fs;
use std::time::Instant;

#[inline(always)]
fn parse_usize(bytes: &[u8]) -> usize {
    let mut n: usize = 0;
    for &b in bytes {
        n = n * 10 + (b - b'0') as usize;
    }
    n
}

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 {
        eprintln!("Usage: {} <graph_file>", args[0]);
        std::process::exit(1);
    }

    // ── Read ─────────────────────────────────────────────────────────────────
    let t0 = Instant::now();

    let bytes = fs::read(&args[1]).unwrap();
    let mut iter = bytes
        .split(|&b| b == b' ' || b == b'\n' || b == b'\r' || b == b'\t')
        .filter(|s| !s.is_empty());
    let n: usize = parse_usize(iter.next().unwrap());
    let m: usize = parse_usize(iter.next().unwrap());

    // Build CSR adjacency
    let mut deg = vec![0u32; n];
    let mut eu = Vec::with_capacity(m);
    let mut ev = Vec::with_capacity(m);
    for _ in 0..m {
        let u: usize = parse_usize(iter.next().unwrap());
        let v: usize = parse_usize(iter.next().unwrap());
        deg[u] += 1;
        deg[v] += 1;
        eu.push(u);
        ev.push(v);
    }

    let mut offset = vec![0u32; n + 1];
    for i in 0..n {
        offset[i + 1] = offset[i] + deg[i];
    }
    let total = offset[n] as usize;
    let mut adj = vec![0u32; total];
    let mut pos = vec![0u32; n];
    for i in 0..m {
        let u = eu[i];
        let v = ev[i];
        let pu = offset[u] + pos[u];
        adj[pu as usize] = v as u32;
        pos[u] += 1;
        let pv = offset[v] + pos[v];
        adj[pv as usize] = u as u32;
        pos[v] += 1;
    }

    let read_ms = t0.elapsed().as_secs_f64() * 1000.0;

    // ── Compute ──────────────────────────────────────────────────────────────
    let t1 = Instant::now();

    let mut color = vec![0u32; n];
    let mut new_color = vec![0u32; n];
    let mut sig_hash = vec![0u64; n];

    // Find max degree for reusable buffer
    let mut max_deg: usize = 0;
    for v in 0..n {
        let d = (offset[v + 1] - offset[v]) as usize;
        if d > max_deg {
            max_deg = d;
        }
    }
    let mut nbuf = vec![0u32; max_deg];
    let mut mapping: HashMap<u64, u32> = HashMap::with_capacity(n);

    let mut rounds: u32 = 0;
    let mut num_colors: u32 = 0;

    for round in 0..n {
        // Build signature hash for each vertex
        for v in 0..n {
            let lo = offset[v] as usize;
            let hi = offset[v + 1] as usize;
            let deg_v = hi - lo;
            for i in 0..deg_v {
                let w = adj[lo + i] as usize;
                nbuf[i] = color[w];
            }
            nbuf[..deg_v].sort_unstable();

            let mut h: u64 = (color[v] as u64).wrapping_mul(1000003);
            h ^= (deg_v as u64).wrapping_mul(2654435761);
            h = h.wrapping_mul(1000003);
            for &nc in &nbuf[..deg_v] {
                h ^= (nc as u64).wrapping_mul(2654435761);
                h = h.wrapping_mul(1000003);
            }
            sig_hash[v] = h;
        }

        // Map hashes to consecutive colors, track stability
        mapping.clear();
        let mut next_id: u32 = 0;
        let mut stable = true;
        for v in 0..n {
            let h = sig_hash[v];
            let id = mapping.entry(h).or_insert_with(|| {
                let id = next_id;
                next_id += 1;
                id
            });
            new_color[v] = *id;
            if *id != color[v] {
                stable = false;
            }
        }

        rounds = (round + 1) as u32;
        num_colors = next_id;

        if stable {
            break;
        }

        std::mem::swap(&mut color, &mut new_color);
    }

    // Compute checksum
    let checksum: i64 = color.iter().map(|&c| c as i64).sum();

    let compute_ms = t1.elapsed().as_secs_f64() * 1000.0;

    println!(
        "read={:.1}ms compute={:.1}ms rounds={} colors={} checksum={}",
        read_ms, compute_ms, rounds, num_colors, checksum
    );
}
