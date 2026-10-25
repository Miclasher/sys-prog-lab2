#!/usr/bin/env bash
# П. 2 і 4.2: статистика виконання.
# Використання: ./scripts/stats.sh ./matmul_O0 1024 ijk
BIN=${1:-./matmul_O0}; N=${2:-1024}; VAR=${3:-ijk}
NAME=$(basename "$BIN")_${VAR}
mkdir -p results

echo "=== 2.1 /usr/bin/time --verbose ==="
/usr/bin/time --verbose "$BIN" "$N" "$VAR" 2>&1 | tee results/$NAME.time.txt

echo "=== 2.2 perf stat -d ==="
perf stat -d "$BIN" "$N" "$VAR" 2>&1 | tee results/$NAME.stat.txt

echo "=== 2.3 perf record + perf report ==="
perf record -g -o results/$NAME.rec.data -- "$BIN" "$N" "$VAR"
perf report -i results/$NAME.rec.data --stdio --sort symbol | head -40 | tee results/$NAME.report.txt
echo "Інтерактивно: perf report -i results/$NAME.rec.data"
echo "Анотація асемблера гарячої функції: perf annotate -i results/$NAME.rec.data matmul_ijk"
