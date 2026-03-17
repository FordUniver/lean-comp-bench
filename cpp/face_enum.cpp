// Face enumeration from vertex-facet incidence benchmark
// Input: incidence file (n_vertices n_facets, then one line per facet with
// vertex indices) Output: read=Xms compute=Yms faces=N checksum=K
//
// Enumerates all faces of a polytope by closing facets under intersection.
// Faces represented as bitsets (up to 512 vertices via eight uint64_t).
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <unordered_set>
#include <vector>

using Clock = std::chrono::steady_clock;

static double ms_since(Clock::time_point t0) {
  return std::chrono::duration<double, std::milli>(Clock::now() - t0).count();
}

// Face as 8 × uint64_t (supports up to 512 vertices)
struct Face {
  uint64_t w[8];
  bool operator<(const Face &o) const {
    for (int i = 7; i > 0; i--) {
      if (w[i] != o.w[i])
        return w[i] < o.w[i];
    }
    return w[0] < o.w[0];
  }
  bool operator==(const Face &o) const {
    for (int i = 0; i < 8; i++) {
      if (w[i] != o.w[i])
        return false;
    }
    return true;
  }
};

struct FaceHash {
  size_t operator()(const Face &f) const {
    size_t h = std::hash<uint64_t>{}(f.w[0]);
    for (int i = 1; i < 8; i++)
      h ^= std::hash<uint64_t>{}(f.w[i]) * (0x9e3779b97f4a7c15ULL + i);
    return h;
  }
};

Face face_intersect(const Face &a, const Face &b) {
  Face r;
  for (int i = 0; i < 8; i++)
    r.w[i] = a.w[i] & b.w[i];
  return r;
}

int face_popcount(const Face &f) {
  int c = 0;
  for (int i = 0; i < 8; i++)
    c += __builtin_popcountll(f.w[i]);
  return c;
}

int main(int argc, char **argv) {
  if (argc < 2) {
    fprintf(stderr, "Usage: %s <incidence_file>\n", argv[0]);
    return 1;
  }

  // ── Read ─────────────────────────────────────────────────────────────────
  auto t0 = Clock::now();

  FILE *f = fopen(argv[1], "r");
  if (!f) {
    perror("fopen");
    return 1;
  }

  int nv, nf;
  fscanf(f, "%d %d", &nv, &nf);

  std::vector<Face> facets(nf);
  for (int i = 0; i < nf; i++) {
    facets.at(i) = {};
    for (int k = 0; k < 8; k++)
      facets.at(i).w[k] = 0;
    // Read vertices until end of line
    int v;
    char c;
    while (fscanf(f, "%d%c", &v, &c) >= 1) {
      facets.at(i).w[v / 64] |= (1ULL << (v % 64));
      if (c == '\n' || c == '\r')
        break;
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

  printf("read=%.1fms compute=%.1fms faces=%zu checksum=%lld\n", read_ms,
         compute_ms, all_faces.size(), (long long)checksum);
  return 0;
}
