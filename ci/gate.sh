#!/usr/bin/env bash
set -euo pipefail
cmd="${1:-}"
shift || true
exist() { [ -s "$1" ]; }
findf() {
  local f="$1"
  if exist "$f"; then echo "$f"; return 0; fi
  if exist "artifacts/$f"; then echo "artifacts/$f"; return 0; fi
  if exist "semgrep/$f"; then echo "semgrep/$f"; return 0; fi
  if exist "trivy_fs/$f"; then echo "trivy_fs/$f"; return 0; fi
  if exist "gitleaks/$f"; then echo "gitleaks/$f"; return 0; fi
  if exist "image_scan/$f"; then echo "image_scan/$f"; return 0; fi
  return 1
}
if [[ "$cmd" == "pre" ]]; then
  dir="${1:-.}"
  cd "$dir"
  need=( "semgrep.sarif" "trivy-fs.sarif" "sbom.spdx.json" "gitleaks.sarif" "gitleaks.json" "trivy-image.sarif" )
  miss=0
  for n in "${need[@]}"; do
    if f=$(findf "$n"); then
      echo "ok: $f"
    else
      echo "missing: $n"
      miss=$((miss+1))
    fi
  done
  [[ $miss -eq 0 ]] || exit 1
  exit 0
fi
if [[ "$cmd" == "dast" ]]; then
  zap_json="${1:-dast/zap.json}"
  max_high="${2:-0}"
  max_med="${3:-5}"
  jq -e . >/dev/null 2>&1 <<<"{}" || { echo "jq required"; exit 2; }
  [[ -s "$zap_json" ]] || { echo "no $zap_json"; exit 1; }
  highs=$(jq '[.site[].alerts[]?|select(.riskcode=="3")]|length' "$zap_json")
  meds=$(jq  '[.site[].alerts[]?|select(.riskcode=="2")]|length' "$zap_json")
  echo "high=$highs med=$meds"
  (( highs <= max_high )) || exit 1
  (( meds  <= max_med ))  || exit 1
  exit 0
fi
echo "usage: gate.sh pre <dir> | gate.sh dast <zap.json> <max_high> <max_med>"
exit 2
