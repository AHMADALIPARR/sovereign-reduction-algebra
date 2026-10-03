#!/usr/bin/env bash
# Time Astra zint matmul and the SHA-512 DAG seal. N=128, three trials.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APL="${APL:-/home/box/gnu-apl/bin/apl}"
exec "$APL" --script \
  -f "$ROOT/astra/zint.apl" \
  -f "$ROOT/astra/dagseal.apl" \
  -f "$ROOT/astra/bench.apl"
