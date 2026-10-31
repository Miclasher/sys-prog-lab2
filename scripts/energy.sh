#!/usr/bin/env bash
# П. 3 і 4.4: енерговитрати через RAPL (AMD Zen 3: подія power/energy-pkg/).
# Використання: sudo ./scripts/energy.sh ./matmul_O0 1024 ijk
#
# Змінні середовища (необов'язково):
#   REPS=5     кількість повторів (береться середнє ± σ)
#   PIN=2      ядро для taskset (PIN= вимикає прив'язку; потрібно для OpenMP)
#   SETTLE=2   пауза (с) між запуском і виміром простою, щоб частоти/струм «заспокоїлись»
#   WARMUP=1   один прогрівальний запуск без виміру (0 — вимкнути)
#
# Метод: пара «запуск програми» → «простій такої самої тривалості» повторюється REPS разів.
#   E_програми = E(з програмою) − E(простій за той самий час)
# На Zen 3 є тільки power/energy-pkg/ (energy-ram відсутній).
set -u
export LC_ALL=C

BIN=${1:-./matmul_O0}; N=${2:-1024}; VAR=${3:-ijk}
REPS=${REPS:-5}; PIN=${PIN-2}; SETTLE=${SETTLE:-2}; WARMUP=${WARMUP:-1}

NAME=$(basename "$BIN")_${VAR}
OUT=results/$NAME.energy.txt

# ---------- перевірки ----------
[ "$(id -u)" -eq 0 ] || { echo "Потрібні права root: sudo $0 $*" >&2; exit 1; }
command -v perf >/dev/null || { echo "Не знайдено perf (sudo pacman -S perf)" >&2; exit 1; }
[ -x "$BIN" ] || { echo "Не знайдено виконуваний файл: $BIN (спершу make)" >&2; exit 1; }

mkdir -p results
: > "$OUT"
TSV=$(mktemp); trap 'rm -f "$TSV"' EXIT

log() { echo "$@" | tee -a "$OUT"; }

# measure CMD...  →  виставляє E_J (Дж, energy-pkg) і T_S (с, тривалість); вивід команди йде в лог
measure() {
    local tmp rc
    tmp=$(mktemp)
    perf stat -a -x, -o "$tmp" -e power/energy-pkg/,duration_time -- "$@" 2>&1 | tee -a "$OUT"
    rc=${PIPESTATUS[0]}
    E_J=$(awk -F, '/energy-pkg/ && $1+0==$1 {s+=$1; f=1} END{if(f) printf "%.6f", s}' "$tmp")
    T_S=$(awk -F, '/duration_time/ && $1+0==$1 {printf "%.6f", $1/1e9; exit}' "$tmp")
    rm -f "$tmp"
    if [ -z "$E_J" ] || [ -z "$T_S" ]; then
        echo "Помилка: perf не повернув power/energy-pkg/ (перевірте: perf list | grep -i power; потрібні root і ядро >= 5.8)." >&2
        return 1
    fi
    return "$rc"
}

# швидка перевірка, що лічильник RAPL взагалі працює
measure sleep 0.1 >/dev/null 2>&1 || { echo "RAPL недоступний: нативний Linux, root, ядро >= 5.8, не VM/WSL." >&2; exit 1; }
: > "$OUT"   # прибираємо службові рядки перевірки

RUN=("$BIN" "$N" "$VAR")
if [ -n "$PIN" ] && command -v taskset >/dev/null && [ "$PIN" -lt "$(nproc)" ]; then
    RUN=(taskset -c "$PIN" "${RUN[@]}")
fi

# ---------- заголовок ----------
log "=== Енергія (RAPL, power/energy-pkg/) ==="
log "Дата:      $(date '+%F %T')"
log "Ядро:      $(uname -r)"
log "CPU:       $(lscpu | awk -F: '/Model name/ {gsub(/^ +/,"",$2); print $2; exit}')"
log "Governor:  $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo н/д)"
log "Boost:     $(cat /sys/devices/system/cpu/cpufreq/boost 2>/dev/null || echo н/д)"
log "Команда:   ${RUN[*]}"
log "Повторів:  $REPS (пауза перед простоєм: ${SETTLE} с)"
log ""

if [ "$WARMUP" = "1" ]; then
    log "--- прогрів (не враховується) ---"
    "${RUN[@]}" 2>&1 | tee -a "$OUT"
    log ""
fi

# ---------- вимірювання ----------
for r in $(seq 1 "$REPS"); do
    log "--- повтор $r/$REPS: програма ---"
    measure "${RUN[@]}" || exit 1
    Er=$E_J; Tr=$T_S

    sleep "$SETTLE"

    log "--- повтор $r/$REPS: простій $Tr с ---"
    measure sleep "$Tr" || exit 1
    Ei=$E_J; Ti=$T_S

    # E_простою масштабуємо до тривалості запуску (sleep трохи довший за Tr)
    awk -v r="$r" -v tr="$Tr" -v er="$Er" -v ei="$Ei" -v ti="$Ti" 'BEGIN{
        eis = ei*tr/ti;
        printf "%d\t%.6f\t%.6f\t%.6f\t%.6f\t%.4f\t%.4f\n", r, tr, er, eis, er-eis, er/tr, ei/ti
    }' >> "$TSV"
    log "    t=${Tr} с  E(програма)=${Er} Дж  E(простій)=${Ei} Дж за ${Ti} с"
done

# ---------- підсумок ----------
stats() {   # $1 = номер стовпця в TSV
    awk -F'\t' -v c="$1" '{x=$c; n++; s+=x; q+=x*x}
        END{m=s/n; v=(n>1)?(q-s*s/n)/(n-1):0; if(v<0)v=0; printf "%.4f ± %.4f", m, sqrt(v)}' "$TSV"
}
mean() { awk -F'\t' -v c="$1" '{s+=$c; n++} END{printf "%.4f", s/n}' "$TSV"; }

log ""
log "=== Підсумок: $NAME, N=$N, $REPS повторів (середнє ± σ) ==="
log "Час виконання t, с:              $(stats 2)"
log "E_pkg з програмою, Дж:           $(stats 3)"
log "E_pkg простій (за той же t), Дж: $(stats 4)"
log "E програми (різниця), Дж:        $(stats 5)"
log "P з програмою, Вт:               $(stats 6)"
log "P простою, Вт:                   $(stats 7)"
log ""
log "SUMMARY name=$NAME N=$N reps=$REPS t_s=$(mean 2) E_run_J=$(mean 3) E_prog_J=$(mean 5) P_run_W=$(mean 6) P_idle_W=$(mean 7)"
log ""
log "Енергія програми ≈ E(з програмою) − E(простій) за той самий час; P = E / t."
log "Примітка: на AMD RAPL — модельна оцінка пакета; для порівняння варіантів достатньо, як абсолютна точність — гірше за ватметр."
awk -F'\t' '$5 < 0 {bad=1} END{exit bad}' "$TSV" || log "УВАГА: різниця від'ємна в частині повторів — шум більший за сигнал; збільште N або REPS."

# файли створено від root — повертаємо власника
[ -n "${SUDO_USER:-}" ] && chown -R "$SUDO_USER": results 2>/dev/null
exit 0
