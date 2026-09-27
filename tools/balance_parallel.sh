#!/usr/bin/env bash
# Denge testini paralel koşturur: her süreç tek koşu (farklı tohum). Kullanım: tools/balance_parallel.sh [koşu=6]
# Her kontrol en az MIN koşuda geçmeli (varsayılan: koşu − 1, ör. 5/6); değilse çıkış kodu 1.
# Koşu çıktıları OUT_DIR'e yazılır (verilmezse geçici klasör).
N=${1:-6}
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
MIN=${MIN:-$(( N > 1 ? N - 1 : N ))}
OUT=${OUT_DIR:-$(mktemp -d)}
mkdir -p "$OUT"
for i in $(seq 1 $N); do
  $G --headless --path . -s game/dev/balance.gd -- --runs=1 --until=${UNTIL:-19420601} --seed=$((1000 + i * 7919)) > $OUT/run_$i.txt 2>&1 &
done
wait
grep -h "^koşu" $OUT/run_*.txt
grep -h "^CAPDBG" $OUT/run_*.txt | cut -c1-600
printf '\n== KONTROLLER (geçen koşu / toplam, en az %s) ==\n' "$MIN"
FAILED=0
for c in poland france uk_holds germany_holds germany_1942 soviet_holds italy_holds barbarossa poland_war japan_china pacific_war china_holds; do
  ok=$(grep -h "OK   \[$c\]" $OUT/run_*.txt | wc -l | tr -d ' ')
  desc=$(grep -h "\[$c\]" $OUT/run_1.txt | sed -E 's/.*\] ([^0-9]*[^ ]).*/\1/' | head -1)
  mark="  "
  if [ "$ok" -lt "$MIN" ]; then
    mark="✗ "
    FAILED=1
  fi
  printf "%s%-14s %s/%s  %s\n" "$mark" "$c" "$ok" "$N" "$desc"
done
if [ "$FAILED" -eq 0 ]; then
  echo "SONUÇ: tüm kontroller en az $MIN/$N"
else
  echo "SONUÇ: en az bir kontrol $MIN/$N altında"
fi
exit $FAILED
