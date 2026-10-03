#!/usr/bin/env python3
"""Launch the J and R SUBLEQ bi-encoders and compare the integers they print.

Python does not multiply, reduce, or reduce mod p. It only starts the two
processes, checks that the printed decimal integers agree, and writes that
record. A nonzero routed error is stored and does not fail the run.
Exit status is nonzero when the unmasked head disagrees with the printed
reference matmul, shapes disagree, J and R disagree on the seeded case, or the SHA-512 DAG seals differ.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo

ROOT = Path(__file__).resolve().parents[1]
PT = ZoneInfo("America/Los_Angeles")
INT_RE = re.compile(r"-?\d+")

# Labels whose integer grids must be identical on both sides.
AGREE = (
    "M",
    "K",
    "N",
    "SEED",
    "RADIX",
    "A",
    "B",
    "WQ",
    "WK",
    "Q",
    "KTOWER",
    "PREDICTED",
    "EXACT_HEAD",
    "REFERENCE",
    "AGGREGATES",
    "PREDICATES",
    "GSAFE_PREDICTED",
    "MAX_ABS_ERROR",
    "EXACT_HEAD_MATCH",
    "PERMUTATION_INVERSE",
    "SHAPES_OK",
    "NOT_SOFTMAX",
    "GOLDILOCKS_P",
    "FIELD_SMALL_PREDICTED",
    "FIELD_SMALL_EXACT_HEAD",
    "FIELD_SMALL_REFERENCE",
    "FIELD_SMALL_AGREES",
    "FIELD_LARGE_PREDICTED",
    "FIELD_LARGE_EXACT_HEAD",
    "FIELD_LARGE_REFERENCE",
    "FIELD_LARGE_EXACT_MATCH",
    "HAND_PREDICTED",
    "HAND_EXACT_HEAD",
    "HAND_REFERENCE",
    "HAND_MAX_ABS_ERROR",
    "HAND_EXACT_HEAD_MATCH",
    "VERIFY",
    "VERIFY_MUTATED",
)
LABELS = set(AGREE) | {
    "BIENCODER_V1",
    "ENGINE",
    "J_VERSION",
    "R_VERSION",
    "GMP_VERSION",
    "SHA512_EMPTY",
    "SHA512_ABC",
    "SHA512_LONG",
    "SEAL",
    "MUTATED_SEAL",
    "NEG_SEAL",
}
HEX_KEYS = (
    "SHA512_EMPTY",
    "SHA512_ABC",
    "SHA512_LONG",
    "SEAL",
    "MUTATED_SEAL",
    "NEG_SEAL",
)
# Published FIPS 180-4 vectors. Python does not compute SHA-512.
NIST_EMPTY = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
NIST_ABC = "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
NIST_LONG = "8e959b75dae313da8cf4f72814fc143f8f7779c6eb9f7fa17299aeadb6889018501d289e4900f7e4331b99dec4b5433ac7d329eeb6dd26545e96e55b874be909"
MATRIX_KEYS = (
    "A",
    "B",
    "WQ",
    "WK",
    "Q",
    "KTOWER",
    "PREDICTED",
    "EXACT_HEAD",
    "REFERENCE",
    "AGGREGATES",
    "PREDICATES",
    "GSAFE_PREDICTED",
    "FIELD_SMALL_PREDICTED",
    "FIELD_SMALL_EXACT_HEAD",
    "FIELD_SMALL_REFERENCE",
    "FIELD_LARGE_PREDICTED",
    "FIELD_LARGE_EXACT_HEAD",
    "FIELD_LARGE_REFERENCE",
    "HAND_PREDICTED",
    "HAND_EXACT_HEAD",
    "HAND_REFERENCE",
)


def now_pt() -> str:
    return datetime.now(PT).strftime("%Y-%m-%d %H:%M:%S PT")


def find_jconsole() -> str | None:
    env = os.environ.get("JCONSOLE")
    if env:
        return env
    for name in ("ijconsole", "jconsole"):
        found = shutil.which(name)
        if found:
            return found
    cands: list[Path] = []
    cands += sorted(Path.home().glob("j/j*/bin/jconsole"))
    cands += sorted(Path("/opt").glob("j/j*/bin/jconsole"))
    cands += sorted(Path("/usr/local").glob("j*/bin/jconsole"))
    return str(cands[-1]) if cands else None


def find_rscript() -> str | None:
    env = os.environ.get("RSCRIPT")
    if env:
        return env
    return shutil.which("Rscript")


def run_cmd(cmd: list[str], env: dict | None = None, timeout: float = 120.0) -> tuple[int, str, str]:
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
            stdin=subprocess.DEVNULL,
        )
        return proc.returncode, proc.stdout, proc.stderr
    except subprocess.TimeoutExpired as exc:
        out = exc.stdout or ""
        err = (exc.stderr or "") + "\nTIMEOUT"
        if isinstance(out, bytes):
            out = out.decode()
        if isinstance(err, bytes):
            err = err.decode()
        return 124, out, err
    except OSError as exc:
        return 127, "", str(exc)


def parse_blocks(stdout: str) -> dict[str, list[str]]:
    lines = [ln.rstrip() for ln in stdout.splitlines()]
    try:
        start = lines.index("BIENCODER_V1")
    except ValueError:
        return {}
    lines = lines[start:]
    out: dict[str, list[str]] = {}
    i = 0
    while i < len(lines):
        if lines[i] in LABELS:
            lab = lines[i]
            i += 1
            block: list[str] = []
            while i < len(lines) and lines[i] not in LABELS:
                if lines[i].strip():
                    block.append(lines[i].strip())
                i += 1
            out[lab] = block
        else:
            i += 1
    return out


def grid(block: list[str] | None) -> list[list[int]] | None:
    """Parse printed decimals. This does not perform the bi-encoder arithmetic."""
    if block is None:
        return None
    rows: list[list[int]] = []
    for ln in block:
        parts = ln.replace("¯", "-").split()
        nums: list[int] = []
        for part in parts:
            if part.startswith("_"):
                part = "-" + part[1:]
            if not INT_RE.fullmatch(part):
                return None
            nums.append(int(part))
        rows.append(nums)
    if rows and any(len(r) != len(rows[0]) for r in rows):
        return None
    return rows


def scalar(block: list[str] | None) -> int | None:
    g = grid(block)
    if g is None or len(g) != 1 or len(g[0]) != 1:
        return None
    return g[0][0]


def check(name: str, cond: bool, detail: str = "") -> dict:
    return {"name": name, "pass": bool(cond), "detail": detail, "gates_exit": True}


def shape_of(g: list[list[int]] | None) -> tuple[int, int] | None:
    if not g or not g[0]:
        return None
    return (len(g), len(g[0]))


def main() -> int:
    print("=== SUBLEQ bi-encoder (J and R) ===")
    print("time:", now_pt())
    jbin = find_jconsole()
    rbin = find_rscript()
    cases: list[dict] = []
    j_code, j_out, j_err = (127, "", "jconsole not found") if not jbin else run_cmd(
        [jbin, str(ROOT / "j" / "biencoder.ijs")]
    )
    r_env = os.environ.copy()
    user_lib = str(Path.home() / "R" / "library")
    if Path(user_lib).is_dir():
        prev = r_env.get("R_LIBS_USER", "")
        r_env["R_LIBS_USER"] = user_lib + ((":" + prev) if prev else "")
    r_code, r_out, r_err = (127, "", "Rscript not found") if not rbin else run_cmd(
        [rbin, str(ROOT / "r" / "biencoder.R")],
        env=r_env,
    )
    cases.append(check("j.runs", j_code == 0 and "BIENCODER_V1" in j_out and "FLOAT_REFUSED" not in j_out + j_err, (j_err or j_out)[:400]))
    cases.append(check("r.runs", r_code == 0 and "BIENCODER_V1" in r_out and "FLOAT_REFUSED" not in r_out + r_err, (r_err or r_out)[:400]))

    jb = parse_blocks(j_out)
    rb = parse_blocks(r_out)

    def hex_line(block: list[str] | None) -> str | None:
        if block is None or len(block) != 1:
            return None
        s = block[0].strip().lower()
        if len(s) != 128 or any(c not in "0123456789abcdef" for c in s):
            return None
        return s

    jhex = {key: hex_line(jb.get(key)) for key in HEX_KEYS}
    rhex = {key: hex_line(rb.get(key)) for key in HEX_KEYS}
    for key in HEX_KEYS:
        cases.append(check(
            f"agree.{key}",
            jhex[key] is not None and jhex[key] == rhex[key],
            "missing" if jhex[key] is None or rhex[key] is None else "",
        ))
    cases.append(check("sha512.empty", jhex["SHA512_EMPTY"] == NIST_EMPTY == rhex["SHA512_EMPTY"]))
    cases.append(check("sha512.abc", jhex["SHA512_ABC"] == NIST_ABC == rhex["SHA512_ABC"]))
    cases.append(check("sha512.long", jhex["SHA512_LONG"] == NIST_LONG == rhex["SHA512_LONG"]))
    cases.append(check(
        "seal.differs_when_tensor_mutated",
        jhex["SEAL"] is not None and jhex["SEAL"] != jhex["MUTATED_SEAL"] and rhex["SEAL"] != rhex["MUTATED_SEAL"],
    ))

    parsed: dict[str, dict[str, list[list[int]] | None]] = {"J": {}, "R": {}}
    for key in AGREE:
        gj, gr = grid(jb.get(key)), grid(rb.get(key))
        parsed["J"][key] = gj
        parsed["R"][key] = gr
        cases.append(check(
            f"agree.{key}",
            gj is not None and gj == gr,
            "missing" if gj is None or gr is None else "",
        ))

    def flag_ok(side: dict) -> bool:
        g = side.get("EXACT_HEAD_MATCH")
        return g == [[1]]

    jg, rg = parsed["J"], parsed["R"]
    cases.append(check("exact_head.J_equals_reference", jg.get("EXACT_HEAD") is not None and jg.get("EXACT_HEAD") == jg.get("REFERENCE") and flag_ok(jg)))
    cases.append(check("exact_head.R_equals_reference", rg.get("EXACT_HEAD") is not None and rg.get("EXACT_HEAD") == rg.get("REFERENCE") and flag_ok(rg)))
    cases.append(check("exact_head.engines_agree", jg.get("EXACT_HEAD") is not None and jg.get("EXACT_HEAD") == rg.get("EXACT_HEAD")))

    m, k, n = scalar(jb.get("M")), scalar(jb.get("K")), scalar(jb.get("N"))
    shapes_ok = (
        m == 4 and k == 4 and n == 4
        and shape_of(jg.get("A")) == (m, k)
        and shape_of(jg.get("B")) == (k, n)
        and shape_of(jg.get("EXACT_HEAD")) == (m, n)
        and shape_of(jg.get("PREDICTED")) == (m, n)
        and shape_of(jg.get("REFERENCE")) == (m, n)
        and shape_of(jg.get("PREDICATES")) == (m * n, k)
        and jg.get("SHAPES_OK") == [[1]]
        and rg.get("SHAPES_OK") == [[1]]
    )
    cases.append(check("shapes", shapes_ok, f"M={m} K={k} N={n}"))
    cases.append(check("permutation_inverse", jg.get("PERMUTATION_INVERSE") == [[1]] and rg.get("PERMUTATION_INVERSE") == [[1]]))
    cases.append(check("goldilocks.small_integer_agreement", jg.get("FIELD_SMALL_AGREES") == [[1]] and rg.get("FIELD_SMALL_AGREES") == [[1]] and jg.get("FIELD_SMALL_PREDICTED") == jg.get("PREDICTED")))
    cases.append(check("goldilocks.large_exact_head", jg.get("FIELD_LARGE_EXACT_MATCH") == [[1]] and rg.get("FIELD_LARGE_EXACT_MATCH") == [[1]] and jg.get("FIELD_LARGE_EXACT_HEAD") == jg.get("FIELD_LARGE_REFERENCE")))
    cases.append(check("goldilocks.p", scalar(jb.get("GOLDILOCKS_P")) == 18446744069414584321 and jg.get("GOLDILOCKS_P") == rg.get("GOLDILOCKS_P")))
    cases.append(check("hand.exact_head", jg.get("HAND_EXACT_HEAD_MATCH") == [[1]] and jg.get("HAND_EXACT_HEAD") == jg.get("HAND_REFERENCE") == rg.get("HAND_REFERENCE")))
    cases.append(check("not_softmax", jg.get("NOT_SOFTMAX") == [[1]] and rg.get("NOT_SOFTMAX") == [[1]]))
    cases.append(check("seal.verify", jg.get("VERIFY") == [[1]] and rg.get("VERIFY") == [[1]]))
    cases.append(check("seal.verify_mutated_fails", jg.get("VERIFY_MUTATED") == [[0]] and rg.get("VERIFY_MUTATED") == [[0]]))

    routed_err = scalar(jb.get("MAX_ABS_ERROR"))
    hand_err = scalar(jb.get("HAND_MAX_ABS_ERROR"))
    # Routed gap is a metric. It is not a pass/fail of exact matmul.
    routed = {
        "max_abs_error": routed_err,
        "hand_max_abs_error": hand_err,
        "equals_exact_matmul": routed_err == 0,
        "required_zero": False,
        "gates_exit": False,
        "note": "SUBLEQ-routed prediction is a sparse approximation. Nonzero error does not fail the run.",
    }

    exact_head_match = (
        jg.get("EXACT_HEAD") is not None
        and jg.get("EXACT_HEAD") == jg.get("REFERENCE") == rg.get("EXACT_HEAD")
        and flag_ok(jg)
        and flag_ok(rg)
    )
    failed = [c for c in cases if not c["pass"]]
    overall = len(failed) == 0
    for c in cases:
        mark = "OK" if c["pass"] else "FAIL"
        extra = f" — {c['detail']}" if (not c["pass"] and c["detail"]) else ""
        print(f"  [{mark}] {c['name']}{extra}")
    print("routed max_abs_error:", routed_err, "(not required to be 0)")
    print("hand routed max_abs_error:", hand_err)

    def side_record(blocks: dict, grids: dict) -> dict:
        return {
            "engine_line": blocks.get("ENGINE"),
            "version": (blocks.get("J_VERSION") or blocks.get("R_VERSION") or [None])[0],
            "gmp_version": (blocks.get("GMP_VERSION") or [None])[0],
            "matrices": {key: grids.get(key) for key in MATRIX_KEYS},
            "max_abs_error": scalar(blocks.get("MAX_ABS_ERROR")),
            "exact_head_match": scalar(blocks.get("EXACT_HEAD_MATCH")) == 1,
            "permutation_inverse": scalar(blocks.get("PERMUTATION_INVERSE")) == 1,
            "field_small_agrees": scalar(blocks.get("FIELD_SMALL_AGREES")) == 1,
            "field_large_exact_match": scalar(blocks.get("FIELD_LARGE_EXACT_MATCH")) == 1,
        }

    result = {
        "schema_version": "2.0.0",
        "timestamp_pt": now_pt(),
        "note": (
            "SUBLEQ bi-encoder is not softmax attention and not a trained model. "
            "Arithmetic ran in J and R extended integers. Python only launched the "
            "processes and compared the printed decimals. The routed tensor is a "
            "separate metric; a nonzero max abs error is not a failure of the "
            "unmasked head. The production seal is a SHA-512 DAG computed in J and "
            "in R over canonical integer tensors (exact head, routed prediction, "
            "weights, prime). Python does not hash. TinyAPL is legacy because "
            "Complex Double cannot hold p."
        ),
        "jconsole": jbin,
        "rscript": rbin,
        "j_version": (jb.get("J_VERSION") or [None])[0],
        "r_version": (rb.get("R_VERSION") or [None])[0],
        "gmp_version": (rb.get("GMP_VERSION") or [None])[0],
        "seed": scalar(jb.get("SEED")),
        "shapes": {"M": m, "K": k, "N": n},
        "exact_head_match": exact_head_match,
        "permutation_inverse": jg.get("PERMUTATION_INVERSE") == [[1]] and rg.get("PERMUTATION_INVERSE") == [[1]],
        "goldilocks_p": str(scalar(jb.get("GOLDILOCKS_P"))) if scalar(jb.get("GOLDILOCKS_P")) is not None else None,
        "goldilocks_small_agrees": jg.get("FIELD_SMALL_AGREES") == [[1]] and rg.get("FIELD_SMALL_AGREES") == [[1]],
        "routed": routed,
        "seal": {
            "algorithm": "SHA-512",
            "dag_order": ["exact_head", "predicted", "weights", "prime"],
            "J": jhex.get("SEAL"),
            "R": rhex.get("SEAL"),
            "agree": jhex.get("SEAL") is not None and jhex.get("SEAL") == rhex.get("SEAL"),
            "verify": scalar(jb.get("VERIFY")) == 1 and scalar(rb.get("VERIFY")) == 1,
            "mutated_seal": {"J": jhex.get("MUTATED_SEAL"), "R": rhex.get("MUTATED_SEAL")},
            "verify_mutated": scalar(jb.get("VERIFY_MUTATED")),
            "neg_seal": {"J": jhex.get("NEG_SEAL"), "R": rhex.get("NEG_SEAL")},
        },
        "sha512_kat": {
            "empty": jhex.get("SHA512_EMPTY"),
            "abc": jhex.get("SHA512_ABC"),
            "long": jhex.get("SHA512_LONG"),
        },
        "J": side_record(jb, jg),
        "R": side_record(rb, rg),
        "stdout": {"J": j_out, "R": r_out},
        "stderr": {"J": j_err, "R": r_err},
        "correctness": {
            "passed": sum(1 for c in cases if c["pass"]),
            "failed": len(failed),
            "cases": cases,
        },
        "overall_pass": overall,
    }
    out_path = ROOT / "results" / "biencoder_result.json"
    out_path.write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("wrote", out_path)
    print("overall_pass:", overall)
    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
