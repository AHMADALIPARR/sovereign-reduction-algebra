#!/usr/bin/env bash
# Launch the GNU APL Astra sources. Does not hash display text.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APL="${APL:-/home/box/gnu-apl/bin/apl}"
exec "$APL" --script \
  -f "$ROOT/astra/agents.apl" \
  -f "$ROOT/astra/routing.apl" \
  -f "$ROOT/astra/orchestrate.apl" \
  -f "$ROOT/astra/zint.apl" \
  -f "$ROOT/astra/dagseal.apl" \
  -f "$ROOT/astra/run.apl"
