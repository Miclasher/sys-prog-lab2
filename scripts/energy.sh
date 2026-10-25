#!/usr/bin/env bash
# П. 3 і 4.4: енерговитрати через Intel/AMD RAPL.
# Використання: sudo ./scripts/energy.sh ./matmul_O0 1024 ijk
BIN=${1:-./matmul_O0}; N=${2:-1024}; VAR=${3:-ijk}
NAME=$(basename "$BIN")_${VAR}
mkdir -p results
OUT=results/$NAME.energy.txt
: > "$OUT"

echo "=== 3.1 Енергія всієї системи (пакет CPU + RAM) під час виконання ===" | tee -a "$OUT"
perf stat -a -e power/energy-pkg/,power/energy-ram/ "$BIN" "$N" "$VAR" 2>&1 | tee -a "$OUT"

echo "=== Базовий рівень: система в простої стільки ж часу ===" | tee -a "$OUT"
T=$(/usr/bin/time -f "%e" "$BIN" "$N" "$VAR" 2>&1 >/dev/null | tail -1)
perf stat -a -e power/energy-pkg/,power/energy-ram/ sleep "$T" 2>&1 | tee -a "$OUT"

echo "Енергія програми ≈ E(з програмою) − E(простій) за той самий час." | tee -a "$OUT"
echo "Додатково: середня потужність P = E / t." | tee -a "$OUT"
