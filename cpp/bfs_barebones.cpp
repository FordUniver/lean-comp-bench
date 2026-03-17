// BFS benchmark — barebones (raw arrays, manual queue)
// Input: graph file (n m, then m edges u v)
// Output: read=Xms compute=Yms checksum=C
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <chrono>

using Clock = std::chrono::steady_clock;

static double ms_since(Clock::time_point t0) {
    return std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <graph_file>\n", argv[0]); return 1; }

    // ── Read ─────────────────────────────────────────────────────────────────
    auto t0 = Clock::now();

    FILE *f = fopen(argv[1], "r");
    if (!f) { perror("fopen"); return 1; }

    uint32_t n, m;
    fscanf(f, "%u %u", &n, &m);

    // CSR-style adjacency: offsets + flat neighbor array
    // First pass: count degrees
    uint32_t *deg = (uint32_t *)calloc(n, sizeof(uint32_t));
    uint32_t *eu = (uint32_t *)malloc(m * sizeof(uint32_t));
    uint32_t *ev = (uint32_t *)malloc(m * sizeof(uint32_t));
    for (uint32_t i = 0; i < m; i++) {
        fscanf(f, "%u %u", &eu[i], &ev[i]);
        deg[eu[i]]++;
        deg[ev[i]]++;
    }
    fclose(f);

    // Build adjacency arrays
    uint32_t *offset = (uint32_t *)malloc((n + 1) * sizeof(uint32_t));
    offset[0] = 0;
    for (uint32_t i = 0; i < n; i++) offset[i + 1] = offset[i] + deg[i];
    uint32_t total_edges = offset[n];
    uint32_t *adj = (uint32_t *)malloc(total_edges * sizeof(uint32_t));
    uint32_t *pos = (uint32_t *)calloc(n, sizeof(uint32_t));
    for (uint32_t i = 0; i < m; i++) {
        uint32_t u = eu[i], v = ev[i];
        adj[offset[u] + pos[u]++] = v;
        adj[offset[v] + pos[v]++] = u;
    }
    free(eu); free(ev); free(deg); free(pos);

    double read_ms = ms_since(t0);

    // ── Compute ──────────────────────────────────────────────────────────────
    auto t1 = Clock::now();

    // BFS from vertex 0
    uint32_t *visited = (uint32_t *)calloc(n, sizeof(uint32_t));
    uint32_t *queue = (uint32_t *)malloc(n * sizeof(uint32_t));
    uint32_t qhead = 0, qtail = 0;

    visited[0] = 1;
    queue[qtail++] = 0;

    int64_t dist_sum = 0;
    int64_t *dist = (int64_t *)calloc(n, sizeof(int64_t));

    while (qhead < qtail) {
        uint32_t v = queue[qhead++];
        for (uint32_t i = offset[v]; i < offset[v + 1]; i++) {
            uint32_t w = adj[i];
            if (!visited[w]) {
                visited[w] = 1;
                dist[w] = dist[v] + 1;
                dist_sum += dist[w];
                queue[qtail++] = w;
            }
        }
    }

    double compute_ms = ms_since(t1);

    // ── Output ───────────────────────────────────────────────────────────────
    printf("read=%.1fms compute=%.1fms checksum=%lld visited=%u\n",
           read_ms, compute_ms, (long long)dist_sum, qtail);

    free(visited); free(queue); free(dist); free(adj); free(offset);
    return 0;
}
