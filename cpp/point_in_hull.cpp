// Point-in-convex-hull (2D) benchmark
// Input: polygon+queries file (n_poly n_queries, then vertices, then queries)
// Output: read=Xms compute=Yms inside=N total=M
#include <cstdio>
#include <cstdint>
#include <chrono>
#include <vector>

using Clock = std::chrono::steady_clock;

static double ms_since(Clock::time_point t0) {
    return std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <polygon_file>\n", argv[0]); return 1; }

    // ── Read ─────────────────────────────────────────────────────────────────
    auto t0 = Clock::now();

    FILE *f = fopen(argv[1], "r");
    if (!f) { perror("fopen"); return 1; }

    int np, nq;
    fscanf(f, "%d %d", &np, &nq);

    std::vector<int64_t> px(np), py(np);
    for (int i = 0; i < np; i++)
        fscanf(f, "%lld %lld", &px.at(i), &py.at(i));

    std::vector<int64_t> qx(nq), qy(nq);
    for (int i = 0; i < nq; i++)
        fscanf(f, "%lld %lld", &qx.at(i), &qy.at(i));

    fclose(f);
    double read_ms = ms_since(t0);

    // ── Compute ──────────────────────────────────────────────────────────────
    auto t1 = Clock::now();

    int inside = 0;
    for (int q = 0; q < nq; q++) {
        int64_t x = qx.at(q), y = qy.at(q);
        bool in = true;
        for (int i = 0; i < np; i++) {
            int j = (i + 1 < np) ? i + 1 : 0;
            int64_t cross = (px.at(j) - px.at(i)) * (y - py.at(i))
                          - (py.at(j) - py.at(i)) * (x - px.at(i));
            if (cross < 0) { in = false; break; }
        }
        if (in) inside++;
    }

    double compute_ms = ms_since(t1);

    printf("read=%.1fms compute=%.1fms inside=%d total=%d\n",
           read_ms, compute_ms, inside, nq);
    return 0;
}
