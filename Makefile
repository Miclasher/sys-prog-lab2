CC = gcc
SRC = matmul.c

# -g і -fno-omit-frame-pointer потрібні, щоб perf/FlameGraph бачили імена функцій і стек
DBG = -g -fno-omit-frame-pointer

all: matmul_O0 matmul_O3 asm

matmul_O0: $(SRC)
	$(CC) -O0 $(DBG) $< -o $@

matmul_O3: $(SRC)
	$(CC) -O3 -march=native $(DBG) $< -o $@

# Асемблер для порівняння (п. 4.1)
asm: $(SRC)
	$(CC) -O0 -S -fverbose-asm $< -o matmul_O0.s
	$(CC) -O3 -march=native -S -fverbose-asm $< -o matmul_O3.s
	$(CC) -O3 -march=native -fopt-info-vec-optimized -c $< -o /dev/null 2> vec_report.txt || true

clean:
	rm -f matmul_O0 matmul_O3 *.s vec_report.txt perf.data* *.folded
	rm -rf results

.PHONY: all asm clean
