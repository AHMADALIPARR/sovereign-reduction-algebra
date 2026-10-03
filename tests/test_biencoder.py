#!/usr/bin/env python3
"""Direct checks for the Python bi-encoder mirror. TinyAPL is run by scripts/run_biencoder.py."""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "reference"))

from biencoder import hand_example, matmul, run_seeded, transpose  # noqa: E402


def main() -> int:
    hand = hand_example()
    assert hand["predicted"] == [[7, 5], [4, 9]], hand["predicted"]
    assert hand["reference"] == [[7, 7], [6, 9]]
    assert hand["exact_head"] == hand["reference"]
    assert hand["max_abs_error"] == 2
    seeded = run_seeded()
    assert matmul(seeded["Wq"], transpose(seeded["Wk"])) == [
        [1, 0, 0, 0],
        [0, 1, 0, 0],
        [0, 0, 1, 0],
        [0, 0, 0, 1],
    ]
    assert seeded["exact_head"] == seeded["reference"] == matmul(seeded["A"], seeded["B"])
    assert seeded["field_small"]["predicted"] == seeded["predicted"]
    assert seeded["field_large"]["exact_head"] == seeded["field_large"]["reference"]
    assert seeded["max_abs_error"] == max(
        abs(p - r)
        for prow, rrow in zip(seeded["predicted"], seeded["reference"])
        for p, r in zip(prow, rrow)
    )
    print("test_biencoder: ok")
    print("seeded max_abs_error", seeded["max_abs_error"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
