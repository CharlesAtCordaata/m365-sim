#!/usr/bin/env bash
# Hit every read endpoint on a running m365-sim and print status + item count.
# Usage: scripts/smoke.sh [base_url]   (default http://localhost:8888)
set -u
BASE="${1:-http://localhost:8888}"
AUTH=(-H "Authorization: Bearer test-token")

curl -s "$BASE/health"; echo
paths=$(curl -s "${AUTH[@]}" "$BASE/openapi.json" | python3 -c '
import sys, json
for p, ops in json.load(sys.stdin)["paths"].items():
    if "get" in ops and "{" not in p and p != "/health":
        print(p)')

for p in $paths; do
  out=$(curl -s -o /tmp/m365sim.body -w "%{http_code}" "${AUTH[@]}" "$BASE$p")
  n=$(python3 -c 'import json;d=json.load(open("/tmp/m365sim.body"));print(len(d["value"]) if isinstance(d.get("value"),list) else "-")' 2>/dev/null || echo "?")
  printf "%s  items=%-3s %s\n" "$out" "$n" "$p"
done
