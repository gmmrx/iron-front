#!/bin/zsh
# Denge testini paralel koşturur: her süreç tek koşu (farklı tohum). Kullanım: tools/balance_parallel.sh [koşu=6]
N=${1:-6}
G=${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}
OUT=$(mktemp -d)
for i in $(seq 1 $N); do
  $G --headless --path . -s game/dev/balance.gd -- --runs=1 --until=${UNTIL:-19420601} --seed=$((1000 + i * 7919)) > $OUT/run_$i.txt 2>&1 &
done
wait
grep -h "^koşu" $OUT/run_*.txt
grep -h "^CAPDBG" $OUT/run_*.txt | cut -c1-600
echo "\n== KONTROLLER (geçen koşu / toplam) =="
for c in poland france uk_holds germany_holds germany_1942 soviet_holds italy_holds barbarossa poland_war japan_china pacific_war china_holds; do
  ok=$(grep -h "OK   \[$c\]" $OUT/run_*.txt | wc -l | tr -d ' ')
  desc=$(grep -h "\[$c\]" $OUT/run_1.txt | sed -E 's/.*\] ([^0-9]*[^ ]).*/\1/' | head -1)
  printf "  %-14s %s/%s  %s\n" "$c" "$ok" "$N" "$desc"
done
