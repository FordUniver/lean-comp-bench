// BFS benchmark
// Input: graph file (n m, then m edges u v)
// Output: read=Xms compute=Yms checksum=C
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <vector>

using Clock = std::chrono::steady_clock;

static double ms_since(Clock::time_point t0) {
  return std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <graph_file>\n", argv[0]);
    return 1;
  }

  // ── Read ─────────────────────────────────────────────────────────────────
  auto t0 = Clock::now();

  FILE *f = fopen(argv[1], "r");
  if (!f) {
    perror("fopen");
    return 1;
  }

  uint32_t n, m;
  fscanf(f, "%u %u", &n, &m);

  // CSR-style adjacency: offsets + flat neighbor array
  // First pass: count degrees
  std::vector<uint32_t> deg(n, 0);
  std::vector<uint32_t> eu(m);
  std::vector<uint32_t> ev(m);
  for (uint32_t i = 0; i < m; i++) {
    fscanf(f, "%u %u", &eu.at(i), &ev.at(i));
    deg.at(eu.at(i))++;
    deg.at(ev.at(i))++;
  }
  fclose(f);

  // Build adjacency arrays
  std::vector<uint32_t> offset(n + 1);
  offset.at(0) = 0;
  for (uint32_t i = 0; i < n; i++)
    offset.at(i + 1) = offset.at(i) + deg.at(i);
  uint32_t total_edges = offset.at(n);
  std::vector<uint32_t> adj(total_edges);
  std::vector<uint32_t> pos(n, 0);
  for (uint32_t i = 0; i < m; i++) {
    uint32_t u = eu.at(i), v = ev.at(i);
    adj.at(offset.at(u) + pos.at(u)++) = v;
    adj.at(offset.at(v) + pos.at(v)++) = u;
  }

  double read_ms = ms_since(t0);

  // ── Compute ──────────────────────────────────────────────────────────────
  auto t1 = Clock::now();

  // BFS from vertex 0
  std::vector<uint32_t> visited(n, 0);
  std::vector<uint32_t> queue(n);
  uint32_t qhead = 0, qtail = 0;

  visited.at(0) = 1;
  queue.at(qtail++) = 0;

  int64_t dist_sum = 0;
  std::vector<int64_t> dist(n, 0);

  while (qhead < qtail) {
    uint32_t v = queue.at(qhead++);
    for (uint32_t i = offset.at(v); i < offset.at(v + 1); i++) {
      uint32_t w = adj.at(i);
      if (!visited.at(w)) {
        visited.at(w) = 1;
        dist.at(w) = dist.at(v) + 1;
        dist_sum += dist.at(w);
        queue.at(qtail++) = w;
      }
    }
  }

  double compute_ms = ms_since(t1);

  // ── Output ───────────────────────────────────────────────────────────────
  printf("read=%.1fms compute=%.1fms checksum=%lld visited=%u\n", read_ms,
         compute_ms, (long long)dist_sum, qtail);

  return 0;
}
