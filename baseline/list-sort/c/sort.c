#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

/* LCG PRNG (Knuth) — identical across all languages */
static uint64_t lcg_state;

static void lcg_seed(uint64_t s) { lcg_state = s; }

static uint64_t lcg_next(void) {
    lcg_state = lcg_state * 6364136223846793005ULL + 1442695040888963407ULL;
    return lcg_state;
}

/* Quicksort (Lomuto partition) */
static void quicksort(uint64_t *a, int64_t lo, int64_t hi) {
    if (lo >= hi) return;
    uint64_t pivot = a[hi];
    int64_t i = lo;
    for (int64_t j = lo; j < hi; j++) {
        if (a[j] <= pivot) {
            uint64_t tmp = a[i]; a[i] = a[j]; a[j] = tmp;
            i++;
        }
    }
    uint64_t tmp = a[i]; a[i] = a[hi]; a[hi] = tmp;
    quicksort(a, lo, i - 1);
    quicksort(a, i + 1, hi);
}

/* Mergesort */
static void merge(uint64_t *a, uint64_t *buf, int64_t lo, int64_t mid, int64_t hi) {
    memcpy(buf + lo, a + lo, (hi - lo + 1) * sizeof(uint64_t));
    int64_t i = lo, j = mid + 1, k = lo;
    while (i <= mid && j <= hi) {
        if (buf[i] <= buf[j]) a[k++] = buf[i++];
        else                   a[k++] = buf[j++];
    }
    while (i <= mid) a[k++] = buf[i++];
    while (j <= hi)  a[k++] = buf[j++];
}

static void mergesort_rec(uint64_t *a, uint64_t *buf, int64_t lo, int64_t hi) {
    if (lo >= hi) return;
    int64_t mid = lo + (hi - lo) / 2;
    mergesort_rec(a, buf, lo, mid);
    mergesort_rec(a, buf, mid + 1, hi);
    merge(a, buf, lo, mid, hi);
}

static uint64_t checksum(uint64_t *a, int64_t n) {
    uint64_t h = 0;
    for (int64_t i = 0; i < n; i++)
        h = h * 131 + a[i];
    return h;
}

int main(int argc, char **argv) {
    if (argc < 3) {
        fprintf(stderr, "Usage: %s <algo: quick|merge> <n>\n", argv[0]);
        return 1;
    }
    const char *algo = argv[1];
    int64_t n = atoll(argv[2]);

    uint64_t *a = malloc(n * sizeof(uint64_t));
    if (!a) { perror("malloc"); return 1; }

    lcg_seed(42);
    for (int64_t i = 0; i < n; i++)
        a[i] = lcg_next();

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);

    if (strcmp(algo, "quick") == 0) {
        quicksort(a, 0, n - 1);
    } else if (strcmp(algo, "merge") == 0) {
        uint64_t *buf = malloc(n * sizeof(uint64_t));
        mergesort_rec(a, buf, 0, n - 1);
        free(buf);
    } else {
        fprintf(stderr, "Unknown algo: %s\n", algo);
        return 1;
    }

    clock_gettime(CLOCK_MONOTONIC, &t1);
    double ms = (t1.tv_sec - t0.tv_sec) * 1000.0 + (t1.tv_nsec - t0.tv_nsec) / 1e6;

    printf("%s n=%lld %.1fms checksum=%llu\n", algo, (long long)n, ms, (unsigned long long)checksum(a, n));
    free(a);
    return 0;
}
