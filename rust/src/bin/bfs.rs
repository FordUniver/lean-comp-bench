// BFS benchmark
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

    let mut visited = vec![false; n];
    let mut queue = Vec::with_capacity(n);
    let mut dist = vec![0i64; n];

    visited[0] = true;
    queue.push(0u32);
    let mut qhead = 0usize;
    let mut dist_sum: i64 = 0;

    while qhead < queue.len() {
        let v = queue[qhead] as usize;
        qhead += 1;
        let lo = offset[v] as usize;
        let hi = offset[v + 1] as usize;
        for &w_raw in &adj[lo..hi] {
            let w = w_raw as usize;
            if !visited[w] {
                visited[w] = true;
                let d = dist[v] + 1;
                dist[w] = d;
                dist_sum += d;
                queue.push(w as u32);
            }
        }
    }

    let compute_ms = t1.elapsed().as_secs_f64() * 1000.0;

    println!(
        "read={:.1}ms compute={:.1}ms checksum={} visited={}",
        read_ms,
        compute_ms,
        dist_sum,
        queue.len()
    );
}
