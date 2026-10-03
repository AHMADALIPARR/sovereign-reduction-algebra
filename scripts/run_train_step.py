#!/usr/bin/env python3
"""Launch one J and one R integer training step and compare printed integers.

Python does not multiply, mask, reduce, or hash. A float in either print fails.
Wq and Wk stay the permutation. The unmasked head must equal A times B after
the step or this process exits nonzero. Routed error is not required to be zero.
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
PERM = [
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
    [1, 0, 0, 0],
]
KNOWN_HEAD = [
    [18, 18, 12, 16],
    [23, 22, 12, 19],
    [19, 29, 18, 29],
    [6, 15, 10, 15],
]
KNOWN_PRE_SEAL = (
    "e6b4a8fda2cde450bd3d9c2b14932136b2894e2b78a1d6c91c52681ec06f3bd7"
    "f13e660a655ca84171ccb77584cc0729792c2123ab5b4b758e74576323756f6e"
)
AGREE = (
    "M",
    "K",
    "N",
    "D",
    "SEED",
    "A",
    "B",
    "WQ",
    "WK",
    "PROJ_BEFORE",
    "PROJ_AFTER",
    "PRE_EXACT_HEAD",
    "PRE_PREDICTED",
    "PRE_REFERENCE",
    "RESIDUAL",
    "LOSS",
    "POST_EXACT_HEAD",
    "POST_PREDICTED",
    "POST_REFERENCE",
    "PRE_MAX_ABS_ERROR",
    "POST_MAX_ABS_ERROR",
    "PRE_EXACT_HEAD_MATCH",
    "POST_EXACT_HEAD_MATCH",
    "NOT_SOFTMAX",
    "VERIFY",
)
HEX_KEYS = ("PRE_SEAL", "SEAL")
LABELS = set(AGREE) | set(HEX_KEYS) | {"TRAIN_STEP_V1", "ENGINE"}
MATRIX_KEYS = (
    "A",
    "B",
    "WQ",
    "WK",
    "PROJ_BEFORE",
    "PROJ_AFTER",
    "PRE_EXACT_HEAD",
    "PRE_PREDICTED",
    "PRE_REFERENCE",
    "RESIDUAL",
    "POST_EXACT_HEAD",
    "POST_PREDICTED",
    "POST_REFERENCE",
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
        start = lines.index("TRAIN_STEP_V1")
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
    if block is None:
        return None
    rows: list[list[int]] = []
    for ln in block:
        if "." in ln or any(c in ln.lower() for c in "e"):
            # Reject scientific notation and decimal points. Hex is not parsed here.
            if any(ch in ln for ch in "."):
                return None
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


def hex_line(block: list[str] | None) -> str | None:
    if block is None or len(block) != 1:
        return None
    s = block[0].strip().lower()
    if len(s) != 128 or any(c not in "0123456789abcdef" for c in s):
        return None
    return s


def main() -> int:
    print("=== one integer training step (J and R) ===")
    print("time:", now_pt())
    jbin = find_jconsole()
    rbin = find_rscript()
    cases: list[dict] = []
    j_code, j_out, j_err = (127, "", "jconsole not found") if not jbin else run_cmd(
        [jbin, str(ROOT / "j" / "train_step.ijs")]
    )
    r_env = os.environ.copy()
    user_lib = str(Path.home() / "R" / "library")
    if Path(user_lib).is_dir():
        prev = r_env.get("R_LIBS_USER", "")
        r_env["R_LIBS_USER"] = user_lib + ((":" + prev) if prev else "")
    r_code, r_out, r_err = (127, "", "Rscript not found") if not rbin else run_cmd(
        [rbin, str(ROOT / "r" / "train_step.R")],
        env=r_env,
    )
    blob_j = j_out + j_err
    blob_r = r_out + r_err
    cases.append(check(
        "j.runs",
        j_code == 0 and "TRAIN_STEP_V1" in j_out and "FLOAT_REFUSED" not in blob_j,
        (j_err or j_out)[:400],
    ))
    cases.append(check(
        "r.runs",
        r_code == 0 and "TRAIN_STEP_V1" in r_out and "FLOAT_REFUSED" not in blob_r,
        (r_err or r_out)[:400],
    ))
    jb = parse_blocks(j_out)
    rb = parse_blocks(r_out)
    jhex = {key: hex_line(jb.get(key)) for key in HEX_KEYS}
    rhex = {key: hex_line(rb.get(key)) for key in HEX_KEYS}
    for key in HEX_KEYS:
        cases.append(check(
            f"agree.{key}",
            jhex[key] is not None and jhex[key] == rhex[key],
            "missing" if jhex[key] is None or rhex[key] is None else "",
        ))
    cases.append(check("seal.pre_untrained", jhex["PRE_SEAL"] == KNOWN_PRE_SEAL == rhex["PRE_SEAL"]))
    cases.append(check(
        "seal.post_differs_from_untrained",
        jhex["SEAL"] is not None and jhex["SEAL"] != KNOWN_PRE_SEAL,
    ))

    parsed: dict[str, dict[str, list[list[int]] | None]] = {"J": {}, "R": {}}
    for key in AGREE:
        gj, gr = grid(jb.get(key)), grid(rb.get(key))
        parsed["J"][key] = gj
        parsed["R"][key] = gr
        cases.append(check(
            f"agree.{key}",
            gj is not None and gj == gr,
            "missing or non-integer" if gj is None or gr is None else "",
        ))

    jg, rg = parsed["J"], parsed["R"]
    cases.append(check(
        "exact_head.pre_equals_product",
        jg.get("PRE_EXACT_HEAD") == KNOWN_HEAD
        and jg.get("PRE_EXACT_HEAD") == jg.get("PRE_REFERENCE") == rg.get("PRE_REFERENCE")
        and jg.get("PRE_EXACT_HEAD_MATCH") == [[1]]
        and rg.get("PRE_EXACT_HEAD_MATCH") == [[1]],
    ))
    cases.append(check(
        "exact_head.post_equals_product",
        jg.get("POST_EXACT_HEAD") == KNOWN_HEAD
        and jg.get("POST_EXACT_HEAD") == jg.get("POST_REFERENCE") == rg.get("POST_EXACT_HEAD")
        and jg.get("POST_EXACT_HEAD_MATCH") == [[1]]
        and rg.get("POST_EXACT_HEAD_MATCH") == [[1]],
    ))
    cases.append(check(
        "weights.frozen_permutation",
        jg.get("WQ") == PERM == jg.get("WK") == rg.get("WQ") == rg.get("WK"),
    ))
    zeros = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
    cases.append(check(
        "projection.before_is_zero",
        jg.get("PROJ_BEFORE") == zeros == rg.get("PROJ_BEFORE"),
    ))
    cases.append(check(
        "projection.after_is_residual",
        jg.get("PROJ_AFTER") == jg.get("RESIDUAL") == rg.get("PROJ_AFTER") == rg.get("RESIDUAL")
        and jg.get("PROJ_AFTER") != jg.get("PROJ_BEFORE"),
    ))
    cases.append(check("shapes", scalar(jb.get("M")) == 4 and scalar(jb.get("K")) == 4 and scalar(jb.get("N")) == 4 and scalar(jb.get("D")) == 4 and scalar(jb.get("SEED")) == 20261002))
    cases.append(check("routed.pre_error_is_15", scalar(jb.get("PRE_MAX_ABS_ERROR")) == 15 and scalar(rb.get("PRE_MAX_ABS_ERROR")) == 15))
    cases.append(check("not_softmax", jg.get("NOT_SOFTMAX") == [[1]] and rg.get("NOT_SOFTMAX") == [[1]]))
    cases.append(check("seal.verify", jg.get("VERIFY") == [[1]] and rg.get("VERIFY") == [[1]]))
    post_match = (
        jg.get("POST_EXACT_HEAD") == KNOWN_HEAD
        and jg.get("POST_EXACT_HEAD_MATCH") == [[1]]
        and rg.get("POST_EXACT_HEAD_MATCH") == [[1]]
    )
    pre_err = scalar(jb.get("PRE_MAX_ABS_ERROR"))
    post_err = scalar(jb.get("POST_MAX_ABS_ERROR"))
    reduced = (
        pre_err is not None and post_err is not None and post_err < pre_err
    )

    failed = [c for c in cases if not c["pass"]]
    overall = len(failed) == 0
    for c in cases:
        mark = "OK" if c["pass"] else "FAIL"
        extra = f" — {c['detail']}" if (not c["pass"] and c["detail"]) else ""
        print(f"  [{mark}] {c['name']}{extra}")
    print("loss:", scalar(jb.get("LOSS")))
    print("routed max_abs_error pre:", pre_err, "post:", post_err, "(not required to be 0)")
    print("routed error reduced:", reduced)
    print("post exact head matches A times B:", post_match)

    def side(blocks: dict, grids: dict, engine_hex: dict) -> dict:
        return {
            "engine_line": blocks.get("ENGINE"),
            "matrices": {key: grids.get(key) for key in MATRIX_KEYS},
            "loss": scalar(blocks.get("LOSS")),
            "pre_max_abs_error": scalar(blocks.get("PRE_MAX_ABS_ERROR")),
            "post_max_abs_error": scalar(blocks.get("POST_MAX_ABS_ERROR")),
            "pre_exact_head_match": scalar(blocks.get("PRE_EXACT_HEAD_MATCH")) == 1,
            "post_exact_head_match": scalar(blocks.get("POST_EXACT_HEAD_MATCH")) == 1,
            "pre_seal": engine_hex.get("PRE_SEAL"),
            "seal": engine_hex.get("SEAL"),
        }

    result = {
        "schema_version": "1.0.0",
        "timestamp_pt": now_pt(),
        "note": (
            "One integer training step, not softmax and not a training framework. "
            "Wq and Wk stay the permutation, so the unmasked head stays A times B. "
            "The loss is the sum of absolute residuals between the exact product and "
            "the routed prediction. That residual is added once to an integer projection "
            "that starts at zero. Python only launched J and R and compared prints. "
            "A post-step exact-head mismatch fails the run. Routed error is not required "
            "to be zero. No timing was measured. The seal is the current SHA-512 DAG over "
            "the post-step unmasked head, post-step routed prediction, Wq stacked over Wk "
            "stacked over the projection, and p."
        ),
        "update_rule": (
            "Wq and Wk are not updated. The integer projection between the unmasked head "
            "and the routed prediction starts at 0 and becomes that matrix plus the routed "
            "residual (exact product minus routed prediction), extended integers only."
        ),
        "jconsole": jbin,
        "rscript": rbin,
        "seed": scalar(jb.get("SEED")),
        "shapes": {"M": 4, "K": 4, "N": 4, "D": 4},
        "loss": scalar(jb.get("LOSS")),
        "routed": {
            "pre_max_abs_error": pre_err,
            "post_max_abs_error": post_err,
            "reduced": reduced,
            "required_zero": False,
            "gates_exit": False,
        },
        "exact_head": {
            "pre_match": jg.get("PRE_EXACT_HEAD") == KNOWN_HEAD and jg.get("PRE_EXACT_HEAD_MATCH") == [[1]],
            "post_match": post_match,
            "pre_gates_exit": True,
            "post_gates_exit": True,
        },
        "seal": {
            "algorithm": "SHA-512",
            "dag_order": ["exact_head", "predicted", "weights", "prime"],
            "weights_layout": "Wq stacked over Wk stacked over the projection, 12x4, row-major",
            "pre_untrained": jhex.get("PRE_SEAL"),
            "J": jhex.get("SEAL"),
            "R": rhex.get("SEAL"),
            "agree": jhex.get("SEAL") is not None and jhex.get("SEAL") == rhex.get("SEAL"),
            "verify": scalar(jb.get("VERIFY")) == 1 and scalar(rb.get("VERIFY")) == 1,
        },
        "J": side(jb, jg, jhex),
        "R": side(rb, rg, rhex),
        "stdout": {"J": j_out, "R": r_out},
        "stderr": {"J": j_err, "R": r_err},
        "correctness": {
            "passed": sum(1 for c in cases if c["pass"]),
            "failed": len(failed),
            "cases": cases,
        },
        "overall_pass": overall,
    }
    out_path = ROOT / "results" / "train_step_result.json"
    out_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("wrote", out_path)
    print("overall_pass:", overall)
    return 0 if overall else 1


if __name__ == "__main__":
    raise SystemExit(main())
