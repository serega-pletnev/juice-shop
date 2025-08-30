set -euo pipefail
REPO="${REPO:-devsecops-diploma}"
WORKDIR="${PWD}/${REPO}"
mkdir -p "$WORKDIR"/{.github/workflows,ci}
cd "$WORKDIR"

cat > .gitignore <<'EOF'
node_modules
npm-debug.log*
dist
coverage
*.sarif
*.cdx.json
sbom*.json
zap*.json
zap*.html
EOF

cat > .dockerignore <<'EOF'
.git
.github
node_modules
npm-debug.log
Dockerfile
.dockerignore
ci
coverage
EOF

cat > package.json <<'EOF'
{
  "name": "devsecops-diploma-app",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node app.js",
    "build": "echo \"no build step\""
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
EOF

cat > app.js <<'EOF'
const express = require('express');
const app = express();
app.get('/', (req,res)=>res.send('OK'));
app.get('/assets/public/favicon_js.ico', (req,res)=>res.sendStatus(200));
app.listen(3000, ()=>console.log('listening on 3000'));
EOF

cat > Dockerfile <<'EOF'
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --omit=dev || npm install --omit=dev
COPY . .
ENV NODE_ENV=production
EXPOSE 3000
CMD ["npm","start"]
EOF

cat > ci/gate.sh <<'EOF'
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
EOF
chmod +x ci/gate.sh

cat > .github/workflows/devsecops.yml <<'YAML'
name: DevSecOps CI (SAST/SCA/Secrets/Image + DAST gates)

on:
  push:
    branches: [ master, main ]
  pull_request:
    branches: [ master, main ]

permissions:
  contents: read
  security-events: write
  actions: read

env:
  IMAGE_NAME: app
  IMAGE_TAG: ${{ github.sha }}

jobs:
  build_test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - name: Install
        run: |
          if [ -f package-lock.json ]; then npm ci; else npm i; fi
      - name: Build
        run: npm run build || true

  semgrep:
    runs-on: ubuntu-latest
    needs: build_test
    steps:
      - uses: actions/checkout@v4
      - name: Semgrep scan -> semgrep.sarif
        run: |
          docker run --rm \
            -v "$PWD:/src" -w /src returntocorp/semgrep:latest \
            semgrep --config=auto --sarif --output semgrep.sarif
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: semgrep.sarif
      - uses: actions/upload-artifact@v4
        with:
          name: semgrep
          path: semgrep.sarif

  trivy_fs:
    runs-on: ubuntu-latest
    needs: build_test
    steps:
      - uses: actions/checkout@v4
      - name: Trivy FS -> trivy-fs.sarif
        run: |
          docker run --rm \
            -v "$PWD:/src" \
            -v "$HOME/.cache/trivy:/root/.cache/" \
            aquasec/trivy:latest \
            fs --security-checks vuln,misconfig,secret \
            --format sarif --output /src/trivy-fs.sarif /src
      - name: SBOM -> sbom.cdx.json
        run: |
          docker run --rm -v "$PWD:/src" aquasec/trivy:latest \
            fs --format cyclonedx --output /src/sbom.cdx.json /src
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-fs.sarif
      - uses: actions/upload-artifact@v4
        with:
          name: trivy-fs
          path: |
            trivy-fs.sarif
            sbom.cdx.json

  image_scan:
    runs-on: ubuntu-latest
    needs: build_test
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t $IMAGE_NAME:$IMAGE_TAG .
      - name: Trivy image -> trivy-image.sarif
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v "$HOME/.cache/trivy:/root/.cache/" \
            -v "$PWD:/src" aquasec/trivy:latest \
            image --security-checks vuln \
            --format sarif --output /src/trivy-image.sarif $IMAGE_NAME:$IMAGE_TAG
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-image.sarif
      - uses: actions/upload-artifact@v4
        with:
          name: trivy-image
          path: trivy-image.sarif

  gitleaks:
    runs-on: ubuntu-latest
    needs: build_test
    steps:
      - uses: actions/checkout@v4
      - name: Gitleaks -> gitleaks.sarif
        run: |
          docker run --rm -v "$PWD:/repo" zricethezav/gitleaks:latest \
            detect --source=/repo --redact \
            --report-format sarif --report-path /repo/gitleaks.sarif
      - uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: gitleaks.sarif
      - uses: actions/upload-artifact@v4
        with:
          name: gitleaks
          path: gitleaks.sarif

  gate_pre_dast:
    runs-on: ubuntu-latest
    needs: [semgrep, trivy_fs, image_scan, gitleaks]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          pattern: '*'
          merge-multiple: true
      - name: Ensure jq
        run: sudo apt-get update -y && sudo apt-get install -y jq
      - name: Pre-gate
        run: ci/gate.sh pre

  dast_local:
    runs-on: ubuntu-latest
    needs: [gate_pre_dast]
    timeout-minutes: 25
    steps:
      - uses: actions/checkout@v4
      - name: Build image if absent
        run: |
          if ! docker image inspect $IMAGE_NAME:$IMAGE_TAG >/dev/null 2>&1; then
            docker build -t $IMAGE_NAME:$IMAGE_TAG .
          fi
      - name: Create network
        run: docker network create scan || true
      - name: Run app
        run: |
          docker rm -f app || true
          docker run -d --name app --network scan $IMAGE_NAME:$IMAGE_TAG
      - name: Wait readiness
        run: |
          for i in $(seq 1 60); do
            if docker run --rm --network scan curlimages/curl:8.8.0 -fsS http://app:3000 >/dev/null; then
              exit 0
            fi
            sleep 2
          done
          exit 1
      - name: ZAP Baseline -> zap.json & zap.html
        run: |
          docker run --rm --network scan \
            -v "$PWD:/zap/wrk" owasp/zap2docker-stable \
            zap-baseline.py -t http://app:3000 \
            -J zap.json -r zap.html -m 1 -d -I
      - uses: actions/upload-artifact@v4
        with:
          name: dast
          path: |
            zap.json
            zap.html
      - name: Stop app and net
        if: always()
        run: |
          docker rm -f app || true
          docker network rm scan || true

  gate_on_dast:
    runs-on: ubuntu-latest
    needs: dast_local
    steps:
      - uses: actions/checkout@v4
      - uses: actions/download-artifact@v4
        with:
          name: dast
          path: .
      - name: Ensure jq
        run: sudo apt-get update -y && sudo apt-get install -y jq
      - name: DAST gate
        run: ci/gate.sh dast
YAML

git init -q
git config user.name "devsecops-bot"
git config user.email "devsecops-bot@example.local"
git add .
git commit -m "init: app + Dockerfile + CI + gates"

if ! command -v gh >/dev/null 2>&1; then
  echo "Install GitHub CLI (gh) and run: gh auth login"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  gh auth login
fi

OWNER="$(gh api user -q .login)"
gh repo create "${OWNER}/${REPO}" --public --source=. --remote=origin --push >/dev/null

gh workflow run devsecops.yml >/dev/null || true
sleep 5
run_id="$(gh run list --workflow=devsecops.yml --limit 1 --json databaseId -q '.[0].databaseId')"
gh run watch "$run_id"
gh run view "$run_id" --json status,conclusion,url -q '{status:.status,conclusion:.conclusion,url:.url}'
