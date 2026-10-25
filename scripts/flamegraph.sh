#!/usr/bin/env bash
# П. 1 і 4.3: побудова FlameGraph для програми.
# Використання: ./scripts/flamegraph.sh ./matmul_O0 1024 ijk
set -e
BIN=${1:-./matmul_O0}; N=${2:-1024}; VAR=${3:-ijk}
NAME=$(basename "$BIN")_${VAR}
mkdir -p results

# Скрипти Брендана Грегга
[ -d FlameGraph ] || git clone --depth 1 https://github.com/brendangregg/FlameGraph.git

# 1) запис стеків з частотою 99 Гц (-g = call graph)
sudo perf record -F 99 -g -o results/$NAME.perf.data -- "$BIN" "$N" "$VAR"
# 2) перетворення бінарного perf.data у текстові стеки
sudo perf script -i results/$NAME.perf.data > results/$NAME.perf
# 3) "згортання" однакових стеків у рядки "a;b;c count"
./FlameGraph/stackcollapse-perf.pl results/$NAME.perf > results/$NAME.folded
# 4) малювання SVG
./FlameGraph/flamegraph.pl --title "$NAME N=$N" results/$NAME.folded > results/$NAME.svg

echo "Готово: results/$NAME.svg (відкрийте у браузері)"

# Для всієї системи (опційно):
# sudo perf record -F 99 -a -g -- sleep 10   (поки в іншому терміналі працює програма)
