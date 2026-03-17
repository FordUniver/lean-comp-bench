// Face enumeration from vertex-facet incidence benchmark
// Input: incidence file (n_vertices n_facets, then one line per facet with vertex indices)
// Output: read=Xms compute=Yms faces=N checksum=K
//
// Enumerates all faces of a polytope by closing facets under intersection.
// Faces represented as bitsets (up to 128 vertices via two uint64_t).
#include <cstdio>
#include <cstdint>
#include <chrono>
#include <vector>
#include <unordered_set>

using Clock = std::chrono::steady_clock;

static double ms_since(Clock::time_point t0) {
    return std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
}

// Face as pair of uint64_t (supports up to 128 vertices)
struct Face {
    uint64_t lo, hi;
    bool operator<(const Face &o) const {
        return hi < o.hi || (hi == o.hi && lo < o.lo);
    }
    bool operator==(const Face &o) const { return lo == o.lo && hi == o.hi; }
};

struct FaceHash {
    size_t operator()(const Face &f) const {
        return std::hash<uint64_t>{}(f.lo) ^ (std::hash<uint64_t>{}(f.hi) * 0x9e3779b97f4a7c15ULL);
    }
};

Face face_intersect(const Face &a, const Face &b) {
    return {a.lo & b.lo, a.hi & b.hi};
}

int face_popcount(const Face &f) {
    return __builtin_popcountll(f.lo) + __builtin_popcountll(f.hi);
}

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "Usage: %s <incidence_file>\n", argv[0]); return 1; }

    // ── Read ─────────────────────────────────────────────────────────────────
    auto t0 = Clock::now();

    FILE *f = fopen(argv[1], "r");
    if (!f) { perror("fopen"); return 1; }

    int nv, nf;
    fscanf(f, "%d %d", &nv, &nf);

    std::vector<Face> facets(nf);
    for (int i = 0; i < nf; i++) {
        facets.at(i) = {0, 0};
        // Read vertices until end of line
        int v;
        char c;
        while (fscanf(f, "%d%c", &v, &c) >= 1) {
            if (v < 64) facets.at(i).lo |= (1ULL << v);
            else        facets.at(i).hi |= (1ULL << (v - 64));
            if (c == '\n' || c == '\r') break;
        }
    }
    fclose(f);

    double read_ms = ms_since(t0);

    // ── Compute ──────────────────────────────────────────────────────────────
    auto t1 = Clock::now();

    // Start with facets, close under intersection
    std::unordered_set<Face, FaceHash> all_faces;
    std::vector<Face> worklist;

    // Add facets
    for (int i = 0; i < nf; i++) {
        if (all_faces.insert(facets.at(i)).second) {
            worklist.push_back(facets.at(i));
        }
    }

    // BFS-style closure: intersect every new face with every known face
    size_t processed = 0;
    while (processed < worklist.size()) {
        Face current = worklist.at(processed);
        processed++;
        for (size_t j = 0; j < processed; j++) {
            Face inter = face_intersect(current, worklist.at(j));
            if (face_popcount(inter) > 0) {
                if (all_faces.insert(inter).second) {
                    worklist.push_back(inter);
                }
            }
        }
    }

    // Checksum: sum of popcount of all faces
    int64_t checksum = 0;
    for (auto &face : all_faces) {
        checksum += face_popcount(face);
    }

    double compute_ms = ms_since(t1);

    printf("read=%.1fms compute=%.1fms faces=%zu checksum=%lld\n",
           read_ms, compute_ms, all_faces.size(), (long long)checksum);
    return 0;
}
