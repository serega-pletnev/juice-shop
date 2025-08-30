#!/usr/bin/env bash
set -euo pipefail
url="$1"
timeout="${2:-60}"
for i in $(seq 1 "$timeout"); do
  if curl -sfL "$url" >/dev/null 2>&1; then exit 0; fi
  sleep 1
done
echo "timeout"
exit 1
