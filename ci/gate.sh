set -e
root="${1:-artifacts}"
f() { jq -r '[.runs[].results]|flatten|length' "$1" 2>/dev/null || echo 0; }
e() { jq -r '[.runs[].results[]|select(.level=="error")]|length' "$1" 2>/dev/null || echo 0; }
find_file() { p="$(ls -1 "$root"/**/"$1" 2>/dev/null | head -n1)"; echo "${p:-}"; }

srf_semgrep="$(find_file semgrep.sarif)"
srf_trivy_fs="$(find_file trivy-fs.sarif)"
srf_trivy_img="$(find_file trivy-image.sarif)"
srf_gitleaks="$(find_file gitleaks.sarif)"
zap_json="$(find_file zap.json)"

cnt_semgrep="$(f "$srf_semgrep")"
cnt_gitleaks="$(f "$srf_gitleaks")"
cnt_trivy_fs_err="$(e "$srf_trivy_fs")"
cnt_trivy_img_err="$(e "$srf_trivy_img")"
cnt_zap="$(jq -r '.site.alerts|length' "$zap_json" 2>/dev/null || echo 0)"

echo "semgrep=$cnt_semgrep gitleaks=$cnt_gitleaks trivy_fs_err=$cnt_trivy_fs_err trivy_img_err=$cnt_trivy_img_err zap=$cnt_zap"

if [ "$cnt_semgrep" -eq 0 ] && [ "$cnt_gitleaks" -eq 0 ] && [ "$cnt_trivy_fs_err" -eq 0 ] && [ "$cnt_trivy_img_err" -eq 0 ] && [ "$cnt_zap" -eq 0 ]; then
  exit 0
else
  exit 1
fi
