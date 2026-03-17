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

    int n, m;
    fscanf(f, "%d %d", &n, &m);

    // CSR-style adjacency: offsets + flat neighbor array
    // First pass: count degrees
    int *deg = (int *)calloc(n, sizeof(int));
    int *eu = (int *)malloc(m * sizeof(int));
    int *ev = (int *)malloc(m * sizeof(int));
    for (int i = 0; i < m; i++) {
        fscanf(f, "%d %d", &eu[i], &ev[i]);
        deg[eu[i]]++;
        deg[ev[i]]++;
    }
    fclose(f);

    // Build adjacency arrays
    int *offset = (int *)malloc((n + 1) * sizeof(int));
    offset[0] = 0;
    for (int i = 0; i < n; i++) offset[i + 1] = offset[i] + deg[i];
    int total_edges = offset[n];
    int *adj = (int *)malloc(total_edges * sizeof(int));
    int *pos = (int *)calloc(n, sizeof(int));
    for (int i = 0; i < m; i++) {
        int u = eu[i], v = ev[i];
        adj[offset[u] + pos[u]++] = v;
        adj[offset[v] + pos[v]++] = u;
    }
    free(eu); free(ev); free(deg); free(pos);

    double read_ms = ms_since(t0);

    // ── Compute ──────────────────────────────────────────────────────────────
    auto t1 = Clock::now();

    // BFS from vertex 0
    int *visited = (int *)calloc(n, sizeof(int));
    int *queue = (int *)malloc(n * sizeof(int));
    int qhead = 0, qtail = 0;

    visited[0] = 1;
    queue[qtail++] = 0;

    int64_t dist_sum = 0;
    int *dist = (int *)calloc(n, sizeof(int));

    while (qhead < qtail) {
        int v = queue[qhead++];
        for (int i = offset[v]; i < offset[v + 1]; i++) {
            int w = adj[i];
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
    printf("read=%.1fms compute=%.1fms checksum=%lld visited=%d\n",
           read_ms, compute_ms, (long long)dist_sum, qtail);

    free(visited); free(queue); free(dist); free(adj); free(offset);
    return 0;
}
