// Reproducing lacker/lean4perf benchmark
// 10M string->int insertions into a hash map
use std::collections::HashMap;
use std::time::Instant;

fn main() {
    let start = Instant::now();

    let mut map = HashMap::new();
    for i in 0..10_000_000u64 {
        map.insert(i.to_string(), i);
    }

    let ms = start.elapsed().as_secs_f64() * 1000.0;
    println!("ran {} map inserts in {:.1}ms", map.len(), ms);
}
