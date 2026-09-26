#!/usr/bin/env bash
# Ekransız test paketi: içe aktarma + tests/run.gd + country_check (kısa). Her adımın sonucunu ve toplamı yazar.
#   GODOT=~/godot/godot tools/run_tests.sh [--days=60] [--skip-import]
# Çıkış kodu: 0 = hepsi geçti, 1 = en az bir adım kaldı. Günlükler: build/test-logs/ (LOG_DIR ile değişir).
set -u
cd "$(dirname "$0")/.."

GODOT="${GODOT:-godot}"
DAYS=60
IMPORT=1
for a in "$@"; do
  case "$a" in
    --days=*) DAYS="${a#--days=}" ;;
    --skip-import) IMPORT=0 ;;
    *) echo "bilinmeyen argüman: $a" >&2; exit 2 ;;
  esac
done
LOG_DIR="${LOG_DIR:-build/test-logs}"
mkdir -p "$LOG_DIR"

declare -a NAMES=() RESULTS=() TIMES=()
FAILED=0

# step <ad> <komut...>: çıktı hem ekrana hem günlüğe; çıkış kodu kaydedilir
step() {
  local name="$1"; shift
  echo ""
  echo "=== $name ==="
  local t0=$SECONDS
  "$@" 2>&1 | tee "$LOG_DIR/$name.log"
  local code=${PIPESTATUS[0]}
  NAMES+=("$name")
  TIMES+=("$((SECONDS - t0))")
  if [ "$code" -eq 0 ]; then
    RESULTS+=("geçti")
  else
    RESULTS+=("KALDI (çıkış $code)")
    FAILED=1
  fi
}

if [ "$IMPORT" -eq 1 ]; then
  step import "$GODOT" --headless --path . --import
fi
step tests "$GODOT" --headless --path . -s tests/run.gd
step country_check "$GODOT" --headless --path . -s game/dev/country_check.gd -- --days="$DAYS"

echo ""
echo "=== toplam ==="
for i in "${!NAMES[@]}"; do
  printf '  %-14s %-20s %4d sn\n' "${NAMES[$i]}" "${RESULTS[$i]}" "${TIMES[$i]}"
done
if [ "$FAILED" -eq 0 ]; then
  echo "SONUÇ: tüm adımlar geçti"
else
  echo "SONUÇ: en az bir adım kaldı (günlükler: $LOG_DIR)"
fi
exit "$FAILED"
