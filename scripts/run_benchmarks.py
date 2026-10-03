#!/usr/bin/env python3
"""Run J and R production benches and record only the numbers they print.

Python does not time the matmul or the hash. J prints 6!:2. R prints
system.time. Sequential, so the two processes do not share a core.
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
NUM = re.compile(r"-?\d+(?:\.\d+)?")
LABELS = {
    "BENCH_V1",
    "LANGUAGE",
    "VERSION",
    "GMP_VERSION",
    "TIMER",
    "RECORD",
    "SIZE",
    "OP",
    "TRIALS",
    "SECONDS",
    "USER_SECONDS",
    "SYS_SECONDS",
    "CHECKSUM",
    "RESULT_TYPE",
    "NODE_BYTES",
    "SKIP_LINE",
    "BENCH_DONE",
    "FLOAT_REFUSED",
}


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
    cands = list(Path.home().glob("j/j*/bin/jconsole"))
    cands += list(Path("/opt").glob("j/j*/bin/jconsole"))
    cands += list(Path("/usr/local").glob("j*/bin/jconsole"))
    cands = sorted(cands)
    return str(cands[-1]) if cands else None


def parse_records(stdout: str) -> tuple[dict[str, str], list[dict], list[str]]:
    lines = [ln.strip() for ln in stdout.splitlines() if ln.strip()]
    try:
        start = lines.index("BENCH_V1")
    except ValueError:
        return {}, [], []
    lines = lines[start:]
    header: dict[str, str] = {}
    records: list[dict] = []
    skips: list[str] = []
    i = 0
    cur: dict | None = None

    def close() -> None:
        nonlocal cur
        if cur is not None:
            records.append(cur)
            cur = None

    while i < len(lines):
        lab = lines[i]
        i += 1
        if lab not in LABELS:
            continue
        body: list[str] = []
        while i < len(lines) and lines[i] not in LABELS:
            body.append(lines[i])
            i += 1
        if lab in {"BENCH_V1", "BENCH_DONE", "RECORD"}:
            if lab == "RECORD":
                close()
                cur = {}
            continue
        if lab == "SKIP_LINE":
            skips.extend(body)
            continue
        if lab in {"LANGUAGE", "VERSION", "GMP_VERSION", "TIMER"} and cur is None:
            header[lab] = " ".join(body)
            continue
        if cur is None:
            header[lab] = " ".join(body)
            continue
        cur[lab] = body
    close()
    return header, records, skips


def require_nums(body: list[str] | None, n: int) -> list[str]:
    if body is None or len(body) != n:
        raise SystemExit(f"expected {n} numbers, got {body}")
    for token in body:
        if not NUM.fullmatch(token):
            raise SystemExit(f"not a printed number: {token}")
    return body


def main() -> int:
    print("=== benches (J then R; timings are theirs) ===")
    print("time:", now_pt())
    jbin = find_jconsole()
    rbin = os.environ.get("RSCRIPT") or shutil.which("Rscript")
    if not jbin or not rbin:
        print("missing jconsole or Rscript", jbin, rbin)
        return 127
    env = os.environ.copy()
    user_lib = str(Path.home() / "R" / "library")
    if Path(user_lib).is_dir():
        prev = env.get("R_LIBS_USER", "")
        env["R_LIBS_USER"] = user_lib + ((":" + prev) if prev else "")

    def run(cmd: list[str]) -> tuple[int, str, str]:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            stdin=subprocess.DEVNULL,
            env=env,
        )
        return proc.returncode, proc.stdout, proc.stderr

    # Sequential on purpose: a parallel run would contaminate latency.
    j_code, j_out, j_err = run([jbin, str(ROOT / "j" / "bench.ijs")])
    print("--- J exit", j_code)
    if j_err.strip():
        print(j_err[-500:])
    r_code, r_out, r_err = run([rbin, str(ROOT / "r" / "bench.R")])
    print("--- R exit", r_code)
    if r_err.strip():
        print(r_err[-500:])

    sides = []
    all_runs = []
    not_run = []
    problems = []
    if j_code != 0 or "BENCH_DONE" not in j_out or "FLOAT_REFUSED" in j_out + j_err:
        problems.append("J bench failed")
    if r_code != 0 or "BENCH_DONE" not in r_out or "FLOAT_REFUSED" in r_out + r_err:
        problems.append("R bench failed")

    parsed = {}
    for lang, out in (("J", j_out), ("R", r_out)):
        header, records, skips = parse_records(out)
        parsed[lang] = (header, records, skips)
        for rec in records:
            trials = int(rec["TRIALS"][0])
            seconds = require_nums(rec.get("SECONDS"), trials)
            run = {
                "language": header.get("LANGUAGE", lang),
                "version": header.get("VERSION"),
                "operation": rec["OP"][0],
                "shape": {"m": int(rec["SIZE"][0]), "k": int(rec["SIZE"][0]), "n": int(rec["SIZE"][0])},
                "timer": header.get("TIMER"),
                "trials": trials,
                "seconds": seconds,
            }
            if header.get("GMP_VERSION"):
                run["gmp_version"] = header["GMP_VERSION"]
            if "USER_SECONDS" in rec:
                run["user_seconds"] = require_nums(rec["USER_SECONDS"], trials)
            if "SYS_SECONDS" in rec:
                run["sys_seconds"] = require_nums(rec["SYS_SECONDS"], trials)
            if "CHECKSUM" in rec:
                run["checksum"] = rec["CHECKSUM"][0]
            if "NODE_BYTES" in rec:
                run["node_bytes"] = int(rec["NODE_BYTES"][0])
            if "RESULT_TYPE" in rec:
                run["result_type"] = rec["RESULT_TYPE"][0]
            all_runs.append(run)
        for line in skips:
            not_run.append({"language": header.get("LANGUAGE", lang), "line": line})

    # Agreement checks on shared shapes. Mismatch is a failure, not a filled-in time.
    def key_of(run: dict) -> tuple:
        return (run["operation"], run["shape"]["n"], run["language"])

    by = {key_of(r): r for r in all_runs}
    for op in ("unmasked_integer_matmul", "sha512_dag_seal"):
        for n in (128, 1024):
            j = by.get((op, n, "J"))
            r = by.get((op, n, "R"))
            if j and r:
                if j["checksum"] != r["checksum"]:
                    problems.append(f"checksum mismatch {op} N={n}")
                else:
                    print(f"checksum agree {op} N={n}")
            elif j and not r:
                print(f"only J measured {op} N={n}")
            elif r and not j:
                print(f"only R measured {op} N={n}")

    for run in all_runs:
        print(
            f"{run['language']} {run['operation']} N={run['shape']['n']} "
            f"trials={run['trials']} seconds={run['seconds']}"
        )

    result = {
        "schema_version": "1.0.0",
        "timestamp_pt": now_pt(),
        "note": (
            "Every seconds value is a decimal string printed by J 6!:2 "
            "(format 0j6, rounded to 1e-6 second) or by R system.time "
            "(elapsed, plus user.self and sys.self, formatC digits 6). "
            "Python did not time these operations and did not fill gaps. "
            "Inputs are extended integers: A[i;j]=(i*N+j) mod 5 and "
            "B[i;j]=(N*N+i*N+j) mod 5, row-major. sha512_dag_seal times "
            "dag_seal_hex of exact=product, predicted=product, the 4x4 "
            "permutation, and Goldilocks p. The routed head is not in "
            "this timing. N=1024 seal is omitted for R; see not_run."
        ),
        "runs": all_runs,
        "not_run": not_run,
        "problems": problems,
        "stdout": {"J": j_out, "R": r_out},
        "stderr": {"J": j_err, "R": r_err},
    }
    out_path = ROOT / "results" / "benchmarks.json"
    # Emit seconds tokens verbatim so JSON does not re-round the timer text.
    def dump_run(run: dict) -> str:
        lines = ["{"]
        order = [
            "language",
            "version",
            "gmp_version",
            "operation",
            "shape",
            "timer",
            "trials",
            "seconds",
            "user_seconds",
            "sys_seconds",
            "checksum",
            "node_bytes",
            "result_type",
        ]
        parts = []
        for k in order:
            if k not in run:
                continue
            v = run[k]
            if k in {"seconds", "user_seconds", "sys_seconds"}:
                parts.append(f'    "{k}": [{", ".join(v)}]')
            elif k in {"trials", "node_bytes"}:
                parts.append(f'    "{k}": {v}')
            elif k == "shape":
                parts.append(
                    '    "shape": {"m": %d, "k": %d, "n": %d}'
                    % (v["m"], v["k"], v["n"])
                )
            else:
                parts.append(f'    "{k}": {json.dumps(v)}')
        lines.append(",\n".join(parts))
        lines.append("  }")
        return "\n".join(lines)

    body = {
        "schema_version": result["schema_version"],
        "timestamp_pt": result["timestamp_pt"],
        "note": result["note"],
        "problems": problems,
        "not_run": not_run,
    }
    text = "{\n"
    text += f'  "schema_version": {json.dumps(body["schema_version"])},\n'
    text += f'  "timestamp_pt": {json.dumps(body["timestamp_pt"])},\n'
    text += f'  "note": {json.dumps(body["note"])},\n'
    text += '  "runs": [\n'
    text += ",\n".join(dump_run(r) for r in all_runs)
    text += "\n  ],\n"
    text += f'  "not_run": {json.dumps(not_run, indent=2)},\n'
    text += f'  "problems": {json.dumps(problems)}\n'
    text += "}\n"
    out_path.write_text(text, encoding="utf-8")
    print("wrote", out_path)
    if problems:
        print("PROBLEMS", problems)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
