// Color refinement (1-WL) benchmark — barebones (raw arrays, manual hashing)
// Input: graph file (n m, then m edges u v)
// Output: read=Xms compute=Yms rounds=R colors=C checksum=K
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <chrono>
#include <algorithm>
#include <unordered_map>

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

    uint32_t *color = (uint32_t *)calloc(n, sizeof(uint32_t));
    uint32_t *new_color = (uint32_t *)malloc(n * sizeof(uint32_t));
    uint64_t *sig_hash = (uint64_t *)malloc(n * sizeof(uint64_t));
    // Reusable buffer for neighbor colors
    uint32_t max_deg = 0;
    for (uint32_t v = 0; v < n; v++) {
        uint32_t d = offset[v + 1] - offset[v];
        if (d > max_deg) max_deg = d;
    }
    uint32_t *nbuf = (uint32_t *)malloc(max_deg * sizeof(uint32_t));

    uint32_t rounds = 0;
    uint32_t num_colors = 0;

    for (uint32_t round = 0; round < n; round++) {
        // Build signature hash for each vertex
        for (uint32_t v = 0; v < n; v++) {
            uint32_t lo = offset[v], hi = offset[v + 1];
            uint32_t deg_v = hi - lo;
            for (uint32_t i = 0; i < deg_v; i++)
                nbuf[i] = color[adj[lo + i]];
            std::sort(nbuf, nbuf + deg_v);

            uint64_t h = (uint64_t)color[v] * 1000003ULL;
            h = h ^ ((uint64_t)deg_v * 2654435761ULL);
            h = h * 1000003ULL;
            for (uint32_t i = 0; i < deg_v; i++) {
                h = h ^ ((uint64_t)nbuf[i] * 2654435761ULL);
                h = h * 1000003ULL;
            }
            sig_hash[v] = h;
        }

        // Map hashes to consecutive colors
        std::unordered_map<uint64_t, uint32_t> mapping;
        uint32_t next_id = 0;
        for (uint32_t v = 0; v < n; v++) {
            auto it = mapping.find(sig_hash[v]);
            if (it == mapping.end()) {
                mapping[sig_hash[v]] = next_id;
                new_color[v] = next_id;
                next_id++;
            } else {
                new_color[v] = it->second;
            }
        }

        rounds = round + 1;
        num_colors = next_id;

        // Check stability
        bool stable = true;
        for (uint32_t v = 0; v < n; v++) {
            if (new_color[v] != color[v]) { stable = false; break; }
        }
        if (stable) break;

        memcpy(color, new_color, n * sizeof(uint32_t));
    }

    // Compute checksum
    int64_t checksum = 0;
    for (uint32_t v = 0; v < n; v++) checksum += color[v];

    double compute_ms = ms_since(t1);

    // ── Output ───────────────────────────────────────────────────────────────
    printf("read=%.1fms compute=%.1fms rounds=%u colors=%u checksum=%lld\n",
           read_ms, compute_ms, rounds, num_colors, (long long)checksum);

    free(color); free(new_color); free(sig_hash); free(nbuf);
    free(adj); free(offset);
    return 0;
}
