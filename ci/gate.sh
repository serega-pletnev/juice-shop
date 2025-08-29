#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-pre}"
WS="${GITHUB_WORKSPACE:-$PWD}"

case "$MODE" in
  pre)
    echo "[gate] PRE: checking that security artifacts exist (SAST/SCA/Secrets/Image)"
    found=0
    # Ищем любые релевантные артефакты, созданные предыдущими шагами
    for f in \
      "$WS"/semgrep*.sarif \
      "$WS"/codeql*.sarif \
      "$WS"/trivy*.sarif \
      "$WS"/gitleaks*.json \
      "$WS"/sbom*.json "$WS"/*.spdx.json "$WS"/*sbom*.json
    do
      if [ -f "$f" ]; then
        echo "  + found: $(basename "$f")"
        found=1
      fi
    done

    if [ "$found" -ne 1 ]; then
      echo "ERROR: no security artifacts found in $WS"
      ls -la "$WS" || true
      exit 2
    fi

    echo "[gate] PRE passed"
    ;;

  dast)
    echo "[gate] DAST: evaluating ZAP/Nuclei results"
    ZAP_JSON="$WS/zap.json"
    NUCLEI_TXT="$WS/nuclei.txt"

    sudo apt-get update -y >/dev/null
    sudo apt-get install -y jq >/dev/null

    if [[ ! -f "$ZAP_JSON" ]]; then
      echo "ERROR: ZAP report not found at: $ZAP_JSON"
      ls -la "$WS" || true
      exit 2
    fi

    highs=$(jq '[.site[].alerts[] | select(.riskcode=="3")] | length' "$ZAP_JSON")
    meds=$(jq  '[.site[].alerts[] | select(.riskcode=="2")] | length' "$ZAP_JSON")
    echo "ZAP High=$highs Medium=$meds"

    # Порог «по красоте»: High > 0 — блок, Medium > 5 — блок
    if [[ "$highs" -gt 0 || "$meds" -gt 5 ]]; then
      echo "ZAP gate FAIL (High=$highs, Medium=$meds)"
      exit 1
    fi

    if [[ -s "$NUCLEI_TXT" ]]; then
      echo "Nuclei findings present:"
      cat "$NUCLEI_TXT"
      exit 1
    fi

    echo "[gate] DAST passed"
    ;;

  *)
    echo "Usage: $0 {pre|dast}"
    exit 64
    ;;
esac
