#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-pre}"

fail(){ echo "::error::${*}"; exit 1; }
note(){ echo "::notice::${*}"; }

find_once(){ find . -maxdepth 4 -type f -name "$1" -print -quit; }

if [[ "$MODE" == "pre" ]]; then
  note "Gate PRE: проверяем, что все артефакты SAST/SCA/Secrets есть на диске"
  need=( "semgrep.sarif" "trivy-fs.sarif" "sbom.spdx.json" "gitleaks.json" )
  for f in "${need[@]}"; do
    p="$(find_once "$f" || true)"
    [[ -n "${p:-}" && -s "$p" ]] || fail "Не найден артефакт: $f (скачать перед gate через actions/download-artifact)"
    note "ok: $f -> $p"
  done
  note "Gate PRE: OK"
  exit 0
fi

if [[ "$MODE" == "dast" ]]; then
  note "Gate DAST: анализ zap.json / nuclei.txt"
  # jq для разбора zap.json
  if ! command -v jq >/dev/null 2>&1; then
    sudo apt-get update -y >/dev/null 2>&1 || true
    sudo apt-get install -y jq >/dev/null 2>&1 || true
  fi

  zp="$(find_once 'zap.json' || true)"
  [[ -n "${zp:-}" && -s "$zp" ]] || fail "zap.json не найден — проверь шаг ZAP baseline и монтирование -v \${{ github.workspace }}:/zap/wrk"
  nu="$(find_once 'nuclei.txt' || true)"
  [[ -n "${nu:-}" && -f "$nu" ]] || fail "nuclei.txt не найден — проверь шаг Nuclei"

  highs=$(jq '[.site[]?.alerts[]? | select(.riskcode=="3")] | length' "$zp" 2>/dev/null || echo 0)
  meds=$(jq  '[.site[]?.alerts[]? | select(.riskcode=="2")] | length' "$zp" 2>/dev/null || echo 0)

  note "ZAP: High=$highs Medium=$meds"
  # Порог: любое High => fail, Medium > 5 => fail
  if (( highs > 0 )); then fail "ZAP Gate: обнаружены High ($highs)"; fi
  if (( meds  > 5 )); then fail "ZAP Gate: слишком много Medium ($meds > 5)"; fi

  # Nuclei: если файл непустой — фейлим
  if [[ -s "$nu" ]]; then
    echo "----- nuclei findings -----"
    sed -n '1,200p' "$nu" || true
    fail "Nuclei: найдены уязвимости"
  fi

  note "Gate DAST: OK"
  exit 0
fi

fail "неизвестный режим: $MODE (используй: pre | dast)"
