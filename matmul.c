// Множення квадратних матриць C = A * B (double).
// Використання: ./matmul [N] [variant]
//   N       - розмір матриці (за замовчуванням 1024)
//   variant - ijk (наївний, за замовчуванням) або ikj (кеш-дружній)
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static void init_matrix(double *m, int n, unsigned seed) {
    srand(seed);
    for (int i = 0; i < n * n; i++)
        m[i] = (double)rand() / RAND_MAX;
}

__attribute__((noinline))
static void matmul_ijk(const double *A, const double *B, double *C, int n) {
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            double sum = 0.0;
            for (int k = 0; k < n; k++)
                sum += A[i * n + k] * B[k * n + j];
            C[i * n + j] = sum;
        }
}

__attribute__((noinline))
static void matmul_ikj(const double *restrict A, const double *restrict B,
                       double *restrict C, int n) {
    memset(C, 0, sizeof(double) * n * n);
    for (int i = 0; i < n; i++)
        for (int k = 0; k < n; k++) {
            double a = A[i * n + k];
            for (int j = 0; j < n; j++)
                C[i * n + j] += a * B[k * n + j];
        }
}

static double checksum(const double *m, int n) {
    double s = 0.0;
    for (int i = 0; i < n * n; i++) s += m[i];
    return s;
}

int main(int argc, char **argv) {
    int n = argc > 1 ? atoi(argv[1]) : 1024;
    const char *variant = argc > 2 ? argv[2] : "ijk";

    double *A = malloc(sizeof(double) * n * n);
    double *B = malloc(sizeof(double) * n * n);
    double *C = malloc(sizeof(double) * n * n);
    if (!A || !B || !C) { fprintf(stderr, "out of memory\n"); return 1; }

    init_matrix(A, n, 1);
    init_matrix(B, n, 2);

    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    if (strcmp(variant, "ikj") == 0) matmul_ikj(A, B, C, n);
    else                             matmul_ijk(A, B, C, n);
    clock_gettime(CLOCK_MONOTONIC, &t1);

    double sec = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    double gflops = 2.0 * n * n * (double)n / sec / 1e9;
    printf("N=%d variant=%s time=%.3f s  %.2f GFLOP/s  checksum=%.6e\n",
           n, variant, sec, gflops, checksum(C, n));

    free(A); free(B); free(C);
    return 0;
}
