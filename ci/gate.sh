#!/usr/bin/env bash
set -euo pipefail

# Абсолютные пути — никаких относительных
WS="${GITHUB_WORKSPACE:-$PWD}"
ZAP_JSON="${WS}/zap.json"
NUCLEI_TXT="${WS}/nuclei.txt"

# jq для парсинга отчёта
sudo apt-get update -y >/dev/null
sudo apt-get install -y jq >/dev/null

if [[ ! -f "$ZAP_JSON" ]]; then
  echo "ERROR: ZAP report not found at: $ZAP_JSON"
  echo "Workspace listing:"
  ls -la "$WS"
  exit 2
fi

# Считаем High (riskcode=3) и Medium (riskcode=2)
highs=$(jq '[.site[].alerts[] | select(.riskcode=="3")] | length' "$ZAP_JSON")
meds=$(jq  '[.site[].alerts[] | select(.riskcode=="2")] | length' "$ZAP_JSON")

echo "ZAP High=$highs Medium=$meds"

# Порог: High > 0 — валим; Medium > 5 — валим (пример)
if [[ "$highs" -gt 0 || "$meds" -gt 5 ]]; then
  echo "ZAP gate FAIL (High=$highs, Medium=$meds)"
  exit 1
fi

# Если nuclei что-то нашёл — валим
if [[ -s "$NUCLEI_TXT" ]]; then
  echo "Nuclei findings present:"
  cat "$NUCLEI_TXT"
  exit 1
fi

echo "Security gate PASSED"
