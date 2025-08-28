#!/usr/bin/env bash
set -euo pipefail
ART_DIR="${1:-artifacts}"

# Пороги (можно переопределять через переменные окружения)
CRIT_MAX="${CRIT_MAX:-0}"
HIGH_MAX="${HIGH_MAX:-10}"
MED_MAX="${MED_MAX:-50}"
SECRETS_MAX="${SECRETS_MAX:-0}"

crit=0; high=0; med=0; secrets=0

# Trivy IMAGE SARIF
if [ -f "$ART_DIR/trivy-image.sarif" ]; then
  c=$(jq '[.runs[].results[]? | select(.properties.severity=="CRITICAL")] | length' "$ART_DIR/trivy-image.sarif")
  h=$(jq '[.runs[].results[]? | select(.properties.severity=="HIGH")]     | length' "$ART_DIR/trivy-image.sarif")
  crit=$((crit+c)); high=$((high+h))
fi

# Trivy FS SARIF
if [ -f "$ART_DIR/trivy-fs.sarif" ]; then
  c=$(jq '[.runs[].results[]? | select(.properties.severity=="CRITICAL")] | length' "$ART_DIR/trivy-fs.sarif")
  h=$(jq '[.runs[].results[]? | select(.properties.severity=="HIGH")]     | length' "$ART_DIR/trivy-fs.sarif")
  m=$(jq '[.runs[].results[]? | select(.properties.severity=="MEDIUM")]   | length' "$ART_DIR/trivy-fs.sarif")
  crit=$((crit+c)); high=$((high+h)); med=$((med+m))
fi

# Semgrep SARIF → (error -> HIGH, warning -> MEDIUM)
if [ -f "$ART_DIR/semgrep.sarif" ]; then
  shigh=$(jq '[.runs[].results[]? | select(.level=="error")]   | length' "$ART_DIR/semgrep.sarif")
  smed=$(jq  '[.runs[].results[]? | select(.level=="warning")] | length' "$ART_DIR/semgrep.sarif")
  high=$((high+shigh)); med=$((med+smed))
fi

# Gitleaks JSON
if [ -f "$ART_DIR/gitleaks.json" ]; then
  s=$(jq '[.findings[]] | length' "$ART_DIR/gitleaks.json" 2>/dev/null || echo 0)
  secrets=$((secrets+s))
fi

echo "Totals: CRITICAL=$crit HIGH=$high MEDIUM=$med SECRETS=$secrets"

fail=0
if [ "$crit"    -gt "$CRIT_MAX"    ]; then echo "GATE FAIL: CRITICAL>$CRIT_MAX ($crit)"; fail=1; fi
if [ "$high"    -gt "$HIGH_MAX"    ]; then echo "GATE FAIL: HIGH>$HIGH_MAX ($high)";   fail=1; fi
if [ "$secrets" -gt "$SECRETS_MAX" ]; then echo "GATE FAIL: SECRETS>$SECRETS_MAX ($secrets)"; fail=1; fi
# MEDIUM обычно не фейлим релиз (только предупреждаем), но можно включить при желании:
if [ "$med" -gt "$MED_MAX" ]; then echo "GATE WARN: MEDIUM>$MED_MAX ($med)"; fi

if [ "$fail" -eq 1 ]; then exit 1; fi
echo "GATE PASS"
