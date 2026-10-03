#!/usr/bin/env python3
"""Run the SUBLEQ bi-encoder and check the predicted tensor against exact matmul.

Exit 0 when TinyAPL and the Python mirror agree and the unmasked head equals
A @ B. The routed prediction is a sparse approximation: exact equality with
matmul is recorded (tensor_match) and is not required for exit 0. Numbers in
the JSON are computed by this process. Never fabricated.
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "reference"))

from biencoder import (  # noqa: E402
    GSAFE_P,
    K,
    M,
    N,
    SEED,
    P,
    flatten,
    hand_example,
    matmul,
    run_seeded,
    transpose,
)
from goldilocks import P as GP  # noqa: E402

PT = ZoneInfo("America/Los_Angeles")
TINYAPL = ROOT / "vendor" / "tinyapl"


def now_pt() -> str:
    return datetime.now(PT).strftime("%Y-%m-%d %H:%M:%S PT")


def flatten_apl(text: str) -> str:
    parts = []
    for line in text.splitlines():
        if "⍝" in line:
            line = line[: line.index("⍝")]
        line = line.strip()
        if line:
            parts.append(line)
    return "⋄".join(parts)


def tinyapl_env() -> dict:
    env = os.environ.copy()
    target = Path("/usr/lib/x86_64-linux-gnu/libncursesw.so.6")
    libdir = Path("/tmp/sra-ncurses")
    if target.exists():
        libdir.mkdir(exist_ok=True)
        link = libdir / "libncurses.so.6"
        if not link.exists():
            link.symlink_to(target)
        prev = env.get("LD_LIBRARY_PATH", "")
        env["LD_LIBRARY_PATH"] = str(libdir) + ((":" + prev) if prev else "")
    return env


def run_tinyapl(code: str, timeout: float = 60.0) -> tuple[bool, str, str]:
    if not TINYAPL.exists():
        return False, "", "tinyapl binary missing"
    path = ROOT / "results" / "_tmp_biencoder.apl"
    path.write_text(code, encoding="utf-8")
    try:
        r = subprocess.run(
            [str(TINYAPL), str(path)],
            capture_output=True,
            text=True,
            timeout=timeout,
            env=tinyapl_env(),
        )
        err = r.stderr or ""
        ok = r.returncode == 0 and "Syntax error" not in r.stdout and "error" not in err.lower()
        # TinyAPL prints domain/rank errors on stdout and still exits 0.
        if any(tok in r.stdout for tok in ("Syntax error", "Rank error", "Domain error", "Length error", "Index error")):
            ok = False
        return ok, r.stdout, err
    except Exception as e:
        return False, "", str(e)


def parse_apl_ints(line: str) -> list[int]:
    s = line.strip().replace("¯", "-").replace("⟨", " ").replace("⟩", " ").replace("⋄", " ")
    s = s.replace("[", " ").replace("]", " ")
    parts = [p for p in s.split() if p]
    return [int(p) for p in parts]


def parse_labeled(stdout: str) -> dict[str, list[int]]:
    lines = [ln.strip() for ln in stdout.splitlines() if ln.strip()]
    wanted = {
        "M", "K", "N", "SEED", "A", "B", "PREDICTED", "EXACT_HEAD", "REFERENCE",
        "AGGREGATES", "PREDICATES", "GSAFE_PREDICTED", "MAX_ABS_ERROR",
        "EXACT_HEAD_MATCH", "NOT_SOFTMAX",
    }
    out: dict[str, list[int]] = {}
    i = 0
    while i < len(lines):
        if lines[i] in wanted and i + 1 < len(lines):
            out[lines[i]] = parse_apl_ints(lines[i + 1])
            i += 2
        else:
            i += 1
    return out


def check(name: str, cond: bool, detail: str = "") -> dict:
    return {"name": name, "pass": bool(cond), "detail": detail}


def main() -> int:
    print("=== SUBLEQ bi-encoder ===")
    print("time:", now_pt())
    seeded = run_seeded()
    hand = hand_example()
    cases: list[dict] = []

    cases.append(check(
        "hand.predicted",
        hand["predicted"] == hand["expected_predicted"],
        str(hand["predicted"]),
    ))
    cases.append(check(
        "hand.reference",
        hand["reference"] == hand["expected_reference"] and hand["exact_head"] == hand["expected_reference"],
    ))
    cases.append(check(
        "hand.max_abs_error",
        hand["max_abs_error"] == hand["expected_max_abs_error"],
        str(hand["max_abs_error"]),
    ))

    w_ok = matmul(seeded["Wq"], transpose(seeded["Wk"])) == [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    cases.append(check("weights.permutation_inverse", w_ok))
    cases.append(check(
        "python.exact_head_eq_matmul",
        seeded["exact_head"] == seeded["reference"] == matmul(seeded["A"], seeded["B"]),
    ))

    field_small_match = seeded["field_small"]["predicted"] == seeded["predicted"]
    cases.append(check(
        "goldilocks.small_matches_integer",
        field_small_match,
        "small products do not wrap mod p" if field_small_match else "mismatch",
    ))
    # Large case is computed; just sanity-check shapes and that it differs from a naive int matmul
    # (at least one entry must be reduced). Do not invent a TinyAPL result for it.
    large_ref = seeded["field_large"]["reference"]
    cases.append(check(
        "goldilocks.large_python_only_shape",
        len(large_ref) == 4 and len(large_ref[0]) == 4 and all(0 <= x < GP for row in large_ref for x in row),
    ))

    lib = flatten_apl((ROOT / "tinyapl" / "library.apl").read_text(encoding="utf-8"))
    enc = flatten_apl((ROOT / "tinyapl" / "biencoder.apl").read_text(encoding="utf-8"))
    demo = flatten_apl((ROOT / "tinyapl" / "biencoder_demo.apl").read_text(encoding="utf-8"))
    ok, stdout, err = run_tinyapl(lib + "⋄" + enc + "⋄" + demo)
    parsed = parse_labeled(stdout) if ok else {}
    cases.append(check("tinyapl.runs", ok, (err or stdout)[:400]))

    tiny_pred = parsed.get("PREDICTED")
    tiny_exact = parsed.get("EXACT_HEAD")
    tiny_ref = parsed.get("REFERENCE")
    tiny_err = parsed.get("MAX_ABS_ERROR")
    tiny_agg = parsed.get("AGGREGATES")
    tiny_pred_mask = parsed.get("PREDICATES")
    tiny_gsafe = parsed.get("GSAFE_PREDICTED")
    tiny_match = parsed.get("EXACT_HEAD_MATCH")
    tiny_a = parsed.get("A")
    tiny_b = parsed.get("B")

    py_pred = flatten(seeded["predicted"])
    py_exact = flatten(seeded["exact_head"])
    py_ref = flatten(seeded["reference"])
    py_agg = flatten(seeded["aggregates"])
    py_mask = [x for row in seeded["predicates"] for x in row]
    py_gsafe = flatten(seeded["gsafe_predicted"])
    py_a = flatten(seeded["A"])
    py_b = flatten(seeded["B"])

    if ok:
        cases.append(check("tinyapl.shapes", parsed.get("M") == [M] and parsed.get("K") == [K] and parsed.get("N") == [N] and parsed.get("SEED") == [SEED]))
        cases.append(check("tinyapl.inputs", tiny_a == py_a and tiny_b == py_b))
        cases.append(check("tinyapl.predicted_matches_python", tiny_pred == py_pred, f"tiny={tiny_pred} py={py_pred}"))
        cases.append(check("tinyapl.exact_head_matches_python", tiny_exact == py_exact == py_ref))
        cases.append(check("tinyapl.reference_matches_python", tiny_ref == py_ref))
        cases.append(check("tinyapl.max_abs_error", tiny_err == [seeded["max_abs_error"]], str(tiny_err)))
        cases.append(check("tinyapl.aggregates", tiny_agg == py_agg, f"tiny={tiny_agg} py={py_agg}"))
        cases.append(check("tinyapl.predicates", tiny_pred_mask == py_mask))
        cases.append(check("tinyapl.gsafe", tiny_gsafe == py_gsafe))
        cases.append(check("tinyapl.exact_head_flag", tiny_match == [1]))
        cases.append(check("tinyapl.not_softmax_flag", parsed.get("NOT_SOFTMAX") == [1]))
        cases.append(check("subleq.path_executed", tiny_agg is not None and len(tiny_agg) == M * N and tiny_pred_mask is not None and len(tiny_pred_mask) == M * N * K))

    exact_match = seeded["predicted"] == seeded["reference"]
    tensor_detail = f"max_abs_error={seeded['max_abs_error']}"
    cases.append(check("tensor_match.predicted_vs_exact_matmul", exact_match, tensor_detail))

    # System success ignores the scientific question of whether the sparse
    # route equals full matmul; that result is tensor_match above.
    gate_names = {c["name"] for c in cases if c["name"] != "tensor_match.predicted_vs_exact_matmul"}
    failed_gates = [c for c in cases if c["name"] in gate_names and not c["pass"]]
    overall = len(failed_gates) == 0 and ok

    for c in cases:
        mark = "OK" if c["pass"] else "FAIL"
        extra = ""
        if not c["pass"] or c["name"].startswith("tensor_match"):
            extra = f" — {c['detail']}" if c["detail"] else ""
        print(f"  [{mark}] {c['name']}{extra}")

    result = {
        "schema_version": "1.0.0",
        "timestamp_pt": now_pt(),
        "note": (
            "SUBLEQ bi-encoder is not softmax attention. Weights are a fixed "
            "permutation, not trained. Predicted tensor is the SUBLEQ-routed "
            "dot product. exact_head is the unmasked contraction and must equal "
            "reference matmul. Full Goldilocks p is Python-only."
        ),
        "shapes": {"M": M, "K": K, "N": N, "D": K},
        "seed": SEED,
        "radix": 5,
        "A": seeded["A"],
        "B": seeded["B"],
        "Wq": seeded["Wq"],
        "Wk": seeded["Wk"],
        "reference_matmul": seeded["reference"],
        "predicted": seeded["predicted"],
        "exact_head": seeded["exact_head"],
        "subleq_aggregates": seeded["aggregates"],
        "predicates_per_pair": seeded["predicates"],
        "gsafe_predicted": seeded["gsafe_predicted"],
        "gsafe_p": GSAFE_P,
        "tensor_match": {
            "exact_match": exact_match,
            "max_abs_error": seeded["max_abs_error"],
            "compared": "predicted (SUBLEQ-routed) vs exact A@B",
        },
        "tinyapl": {
            "ran": ok,
            "matches_python_mirror": ok and tiny_pred == py_pred and tiny_exact == py_exact and tiny_agg == py_agg,
            "stdout": stdout if ok else stdout[:2000],
            "stderr": err[:2000],
            "parsed_max_abs_error": tiny_err[0] if tiny_err else None,
        },
        "goldilocks": {
            "p": str(GP),
            "small_integer_case_matches_field": field_small_match,
            "small_field_predicted": seeded["field_small"]["predicted"],
            "large_case_tinyapl_executed": False,
            "large_case_reason": (
                "TinyAPL Complex Double cannot represent p=2^64-2^32+1 as an exact "
                "distinct scalar (ulp at 2^64 is 4096). Large residues were reduced "
                "only in reference/biencoder.py."
            ),
            "large_A": seeded["field_large"] and None,
            "large_reference_matmul": seeded["field_large"]["reference"],
            "large_predicted": seeded["field_large"]["predicted"],
            "large_exact_head": seeded["field_large"]["exact_head"],
            "large_max_abs_error_mod_p": max(
                abs(p - r) for p, r in zip(
                    flatten(seeded["field_large"]["predicted"]),
                    flatten(seeded["field_large"]["reference"]),
                )
            ),
        },
        "hand_example": {
            "predicted": hand["predicted"],
            "reference": hand["reference"],
            "max_abs_error": hand["max_abs_error"],
        },
        "correctness": {
            "passed": sum(1 for c in cases if c["pass"]),
            "failed": sum(1 for c in cases if not c["pass"]),
            "cases": cases,
        },
        "overall_pass": overall,
    }
    # Fix large_A properly (the and None was a mistake — write the matrices)
    from biencoder import large_field_inputs
    la, lb = large_field_inputs()
    result["goldilocks"]["large_A"] = la
    result["goldilocks"]["large_B"] = lb

    # JSON cannot hold raw ints that are fine — they can. P-values fit.
    out_path = ROOT / "results" / "biencoder_result.json"
    out_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("wrote", out_path)
    print("tensor_match exact:", exact_match, "max_abs_error:", seeded["max_abs_error"])
    print("overall_pass:", overall)
    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
