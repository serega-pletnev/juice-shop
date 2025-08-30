#!/usr/bin/env bash
set -euo pipefail
mode="${1:-pre}"
find_sarif(){ local p="$1"; local out="$2"; if [[ -f "$p" ]]; then cp "$p" "$out"; return 0; fi; local f; f=$(ls -1 ${p} 2>/dev/null | head -n1 || true); if [[ -n "${f:-}" && -f "$f" ]]; then cp "$f" "$out"; return 0; fi; f=$(find . -maxdepth 4 -type f -name "$p" 2>/dev/null | head -n1 || true); if [[ -n "${f:-}" && -f "$f" ]]; then cp "$f" "$out"; return 0; fi; return 1; }
if [[ "$mode" == "pre" ]]; then
  for t in semgrep gitleaks trivy-fs trivy-image; do
    case "$t" in
      semgrep) pat1="semgrep.sarif"; alt="semgrep*.sarif";;
      gitleaks) pat1="gitleaks.sarif"; alt="gitleaks*.sarif";;
      trivy-fs) pat1="trivy-fs.sarif"; alt="trivy*fs*.sarif";;
      trivy-image) pat1="trivy-image.sarif"; alt="trivy*image*.sarif";;
    esac
    if ! find_sarif "$pat1" "$pat1"; then
      if ! find_sarif "$alt" "$pat1"; then echo "missing:$pat1"; exit 1; fi
    fi
    jq '.runs|length' "$pat1" >/dev/null
  done
  echo OK
  exit 0
fi
if [[ "$mode" == "dast" ]]; then
  file="zap.json"
  if [[ ! -f "$file" ]]; then cand=$(ls -1 zap*.json 2>/dev/null | head -n1 || true); if [[ -n "${cand:-}" ]]; then cp "$cand" "$file"; fi; fi
  if [[ ! -f "$file" ]]; then echo "missing:zap.json"; exit 1; fi
  high=$(jq '[.site[]?.alerts[]? | select(.riskcode=="3")] | length' "$file")
  med=$(jq '[.site[]?.alerts[]? | select(.riskcode=="2")] | length' "$file")
  echo "ZAP_HIGH=$high"
  echo "ZAP_MEDIUM=$med"
  if (( high > 0 )) || (( med > 5 )); then exit 1; fi
  echo OK
  exit 0
fi
echo "usage: $0 {pre|dast}"
exit 2
