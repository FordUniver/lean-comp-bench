// BFS benchmark — barebones (unsafe indexing)
use std::env;
use std::fs;
use std::time::Instant;

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 2 { eprintln!("Usage: {} <graph_file>", args[0]); std::process::exit(1); }

    // ── Read ─────────────────────────────────────────────────────────────────
    let t0 = Instant::now();

    let contents = fs::read_to_string(&args[1]).unwrap();
    let mut iter = contents.split_ascii_whitespace();
    let n: usize = iter.next().unwrap().parse().unwrap();
    let m: usize = iter.next().unwrap().parse().unwrap();

    // Build CSR adjacency
    let mut deg = vec![0u32; n];
    let mut eu = Vec::with_capacity(m);
    let mut ev = Vec::with_capacity(m);
    for _ in 0..m {
        let u: usize = iter.next().unwrap().parse().unwrap();
        let v: usize = iter.next().unwrap().parse().unwrap();
        deg[u] += 1;
        deg[v] += 1;
        eu.push(u);
        ev.push(v);
    }

    let mut offset = vec![0u32; n + 1];
    for i in 0..n { offset[i + 1] = offset[i] + deg[i]; }
    let total = offset[n] as usize;
    let mut adj = vec![0u32; total];
    let mut pos = vec![0u32; n];
    for i in 0..m {
        let u = eu[i]; let v = ev[i];
        unsafe {
            let pu = *offset.get_unchecked(u) + *pos.get_unchecked(u);
            *adj.get_unchecked_mut(pu as usize) = v as u32;
            *pos.get_unchecked_mut(u) += 1;
            let pv = *offset.get_unchecked(v) + *pos.get_unchecked(v);
            *adj.get_unchecked_mut(pv as usize) = u as u32;
            *pos.get_unchecked_mut(v) += 1;
        }
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

    unsafe {
        while qhead < queue.len() {
            let v = *queue.get_unchecked(qhead) as usize;
            qhead += 1;
            let lo = *offset.get_unchecked(v) as usize;
            let hi = *offset.get_unchecked(v + 1) as usize;
            for i in lo..hi {
                let w = *adj.get_unchecked(i) as usize;
                if !*visited.get_unchecked(w) {
                    *visited.get_unchecked_mut(w) = true;
                    let d = *dist.get_unchecked(v) + 1;
                    *dist.get_unchecked_mut(w) = d;
                    dist_sum += d;
                    queue.push(w as u32);
                }
            }
        }
    }

    let compute_ms = t1.elapsed().as_secs_f64() * 1000.0;

    println!("read={:.1}ms compute={:.1}ms checksum={} visited={}",
             read_ms, compute_ms, dist_sum, queue.len());
}
