#!/usr/bin/env bash
set -euo pipefail
ART="$1"
fail(){ echo "GATE FAIL: $*"; exit 1; }

# Gitleaks
if [ -f "$ART/gitleaks.json/gitleaks.json" ]; then
  cnt=$(jq '.findings | length' "$ART/gitleaks.json/gitleaks.json" 2>/dev/null || echo 0)
  [ "$cnt" -gt 0 ] && fail "Secrets found: $cnt"
fi

# Semgrep
if [ -f "$ART/semgrep.json/semgrep.json" ]; then
  high=$(jq '[.results[] | select(.extra.severity=="ERROR" or .extra.severity=="HIGH")] | length' "$ART/semgrep.json/semgrep.json")
  [ "$high" -gt 0 ] && fail "Semgrep high/error: $high"
fi

# Trivy SARIF (fs + image)
check_sarif(){
  f="$1"; [ -f "$f" ] || return 0
  crit=$(jq '[.. | objects | select(.rule.severity=="critical" or .level=="error")] | length' "$f")
  high=$(jq '[.. | objects | select(.rule.severity=="high")] | length' "$f")
  [ "$crit" -gt 0 ] && fail "Trivy critical: $crit"
  [ "$high" -gt 5 ] && fail "Trivy high: $high"
}
check_sarif "$ART/trivy-fs.sarif/trivy-fs.sarif"
check_sarif "$ART/trivy-image.sarif/trivy-image.sarif"

echo "GATE PASSED"
