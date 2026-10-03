#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
exec "$ROOT/vendor/tinyapl" "$ROOT/tinyapl/demo_run.apl"
