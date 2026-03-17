// Sorting benchmark: quicksort and mergesort on uint64 arrays
// LCG PRNG (Knuth) — identical across all languages
#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <cstdio>
#include <vector>
#include <chrono>

static uint64_t lcg_state;
static void lcg_seed(uint64_t s) { lcg_state = s; }
static uint64_t lcg_next() {
    lcg_state = lcg_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return lcg_state;
}

static void quicksort(std::vector<uint64_t> &a, int64_t lo, int64_t hi) {
    if (lo >= hi) return;
    uint64_t pivot = a[hi];
    int64_t i = lo;
    for (int64_t j = lo; j < hi; j++) {
        if (a[j] <= pivot) {
            std::swap(a[i], a[j]);
            i++;
        }
    }
    std::swap(a[i], a[hi]);
    quicksort(a, lo, i - 1);
    quicksort(a, i + 1, hi);
}

static void merge(std::vector<uint64_t> &a, std::vector<uint64_t> &buf,
                  int64_t lo, int64_t mid, int64_t hi) {
    std::copy(a.begin() + lo, a.begin() + hi + 1, buf.begin() + lo);
    int64_t i = lo, j = mid + 1, k = lo;
    while (i <= mid && j <= hi) {
        if (buf[i] <= buf[j]) a[k++] = buf[i++];
        else                   a[k++] = buf[j++];
    }
    while (i <= mid) a[k++] = buf[i++];
    while (j <= hi)  a[k++] = buf[j++];
}

static void mergesort_rec(std::vector<uint64_t> &a, std::vector<uint64_t> &buf,
                          int64_t lo, int64_t hi) {
    if (lo >= hi) return;
    int64_t mid = lo + (hi - lo) / 2;
    mergesort_rec(a, buf, lo, mid);
    mergesort_rec(a, buf, mid + 1, hi);
    merge(a, buf, lo, mid, hi);
}

static uint64_t checksum(const std::vector<uint64_t> &a) {
    uint64_t h = 0;
    for (auto x : a) h = h * 131 + x;
    return h;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <algo: quick|merge> <n>\n", argv[0]);
        return 1;
    }
    const char *algo = argv[1];
    int64_t n = atoll(argv[2]);

    std::vector<uint64_t> a(n);
    lcg_seed(42);
    for (int64_t i = 0; i < n; i++) a[i] = lcg_next();

    auto t0 = std::chrono::steady_clock::now();

    if (strcmp(algo, "quick") == 0) {
        quicksort(a, 0, n - 1);
    } else if (strcmp(algo, "merge") == 0) {
        std::vector<uint64_t> buf(n);
        mergesort_rec(a, buf, 0, n - 1);
    } else {
        fprintf(stderr, "Unknown algo: %s\n", algo);
        return 1;
    }

    auto t1 = std::chrono::steady_clock::now();
    double ms = std::chrono::duration<double, std::milli>(t1 - t0).count();

    printf("%s n=%lld %.1fms checksum=%llu\n", algo, (long long)n, ms,
           (unsigned long long)checksum(a));
    return 0;
}
