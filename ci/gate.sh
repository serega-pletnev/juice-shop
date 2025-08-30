#!/usr/bin/env bash
set -euo pipefail
root="${1:-.}"
max_high="${2:-0}"
max_medium="${3:-5}"

count_sarif() {
  file="$1"
  high=$(jq '[.runs[]?.results[]?|select(.level=="error")] | length' "$file" 2>/dev/null || echo 0)
  med=$(jq  '[.runs[]?.results[]?|select(.level=="warning")] | length' "$file" 2>/dev/null || echo 0)
  echo "$high $med"
}

sum_high=0
sum_med=0

for f in "$root/semgrep.sarif" "$root/trivy-fs.sarif" "$root/trivy-image.sarif" "$root/gitleaks.sarif"; do
  if [ -f "$f" ]; then
    read -r h m < <(count_sarif "$f")
    sum_high=$((sum_high + h))
    sum_med=$((sum_med + m))
  fi
done

if [ -f "$root/zap.json" ]; then
  zap_h=$(jq '[.site[]?.alerts[]?|select(.riskcode=="3")] | length' "$root/zap.json" 2>/dev/null || echo 0)
  zap_m=$(jq '[.site[]?.alerts[]?|select(.riskcode=="2")] | length' "$root/zap.json" 2>/dev/null || echo 0)
  sum_high=$((sum_high + zap_h))
  sum_med=$((sum_med + zap_m))
fi

echo "HIGH=$sum_high MEDIUM=$sum_med MAX_HIGH=$max_high MAX_MEDIUM=$max_medium"

if [ "$sum_high" -gt "$max_high" ] || [ "$sum_med" -gt "$max_medium" ]; then
  echo "gate: fail"
  exit 1
fi

echo "gate: pass"
