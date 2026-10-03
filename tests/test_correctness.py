#!/usr/bin/env python3
"""pytest-friendly / direct correctness runner."""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
# Reuse pipeline correctness by importing carefully
sys.path.insert(0, str(ROOT / "reference"))

def main():
    # Execute pipeline module's correctness section via subprocess for isolation
    import subprocess
    r = subprocess.run([sys.executable, str(ROOT / "scripts" / "run_pipeline.py")], cwd=str(ROOT))
    return r.returncode

if __name__ == "__main__":
    raise SystemExit(main())
