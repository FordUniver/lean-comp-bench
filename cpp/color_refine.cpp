// Color refinement (1-WL) benchmark
// Input: graph file (n m, then m edges u v)
// Output: read=Xms compute=Yms rounds=R colors=C checksum=K
#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <cstring>
#include <chrono>
#include <algorithm>
#include <unordered_map>
#include <vector>

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
    for (uint32_t i = 0; i < n; i++) offset.at(i + 1) = offset.at(i) + deg.at(i);
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

    std::vector<uint32_t> color(n, 0);
    std::vector<uint32_t> new_color(n);
    std::vector<uint64_t> sig_hash(n);
    // Reusable buffer for neighbor colors
    uint32_t max_deg = 0;
    for (uint32_t v = 0; v < n; v++) {
        uint32_t d = offset.at(v + 1) - offset.at(v);
        if (d > max_deg) max_deg = d;
    }
    std::vector<uint32_t> nbuf(max_deg);
    std::unordered_map<uint64_t, uint32_t> mapping;
    mapping.reserve(n);

    uint32_t rounds = 0;
    uint32_t num_colors = 0;

    for (uint32_t round = 0; round < n; round++) {
        // Build signature hash for each vertex
        for (uint32_t v = 0; v < n; v++) {
            uint32_t lo = offset.at(v), hi = offset.at(v + 1);
            uint32_t deg_v = hi - lo;
            for (uint32_t i = 0; i < deg_v; i++)
                nbuf.at(i) = color.at(adj.at(lo + i));
            std::sort(nbuf.begin(), nbuf.begin() + deg_v);

            uint64_t h = (uint64_t)color.at(v) * 1000003ULL;
            h = h ^ ((uint64_t)deg_v * 2654435761ULL);
            h = h * 1000003ULL;
            for (uint32_t i = 0; i < deg_v; i++) {
                h = h ^ ((uint64_t)nbuf.at(i) * 2654435761ULL);
                h = h * 1000003ULL;
            }
            sig_hash.at(v) = h;
        }

        // Map hashes to consecutive colors, track stability
        mapping.clear();
        uint32_t next_id = 0;
        bool stable = true;
        for (uint32_t v = 0; v < n; v++) {
            auto it = mapping.find(sig_hash.at(v));
            uint32_t cid;
            if (it == mapping.end()) {
                cid = next_id;
                mapping[sig_hash.at(v)] = next_id++;
            } else {
                cid = it->second;
            }
            new_color.at(v) = cid;
            if (cid != color.at(v)) stable = false;
        }

        rounds = round + 1;
        num_colors = next_id;

        if (stable) break;

        std::swap(color, new_color);
    }

    // Compute checksum
    int64_t checksum = 0;
    for (uint32_t v = 0; v < n; v++) checksum += color.at(v);

    double compute_ms = ms_since(t1);

    // ── Output ───────────────────────────────────────────────────────────────
    printf("read=%.1fms compute=%.1fms rounds=%u colors=%u checksum=%lld\n",
           read_ms, compute_ms, rounds, num_colors, (long long)checksum);

    return 0;
}
