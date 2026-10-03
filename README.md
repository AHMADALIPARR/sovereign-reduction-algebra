# Sovereign Reduction Algebra (TinyAPL)

Experimental **reduction algebra** `R = (D, OP, E, A, C, S)` realized in
[TinyAPL](https://github.com/RubenVerg/TinyAPL) with a Python Goldilocks reference.

This is **not** ordinary aggregation, DB hashing, WORM storage, or softmax attention.
The SUBLEQ attention pipeline is subtract → compare → predicate → select → route → reduce.

## Layout

```
sovereign-reduction-algebra/
  README.md
  docs/SPEC.md              # algebra spec, including the SHA-512 DAG byte layout
  docs/result_schema.json
  j/biencoder.ijs           # production J arithmetic and SHA-512 DAG seal
  j/sha512.ijs
  j/bench.ijs               # measured 6!:2 benches
  r/biencoder.R             # production R/gmp arithmetic and SHA-512 DAG seal
  r/sha512.R
  r/bench.R                 # measured system.time benches
  tinyapl/                  # legacy TinyAPL sources (not production)
  reference/                # legacy Python Goldilocks + reduction algebra
  scripts/run_biencoder.py  # launch J and R, compare printed integers and seals
  scripts/run_benchmarks.py # record J/R timer output only
  results/                  # measured JSON only (never fabricated)
  vendor/tinyapl            # TinyAPL 0.12.0.0 Linux binary
```

## TinyAPL install / run (this box)

1. Binary from GitHub release `0.12.0.0` asset `tinyapl` (Linux).
2. Needs `libncurses.so.6` (`apt install libncurses6`).
3. CLI:
   - `vendor/tinyapl` — REPL (empty line exits)
   - `vendor/tinyapl path/to/file.apl` — run a file

**File-mode quirks we hit and encoded around:**

- Prefer `⋄`-separated statements (or the flattened `demo_run.apl`).
- Array locals must be **lowercase** (Capitals are function names).
- Replicate is `⌿` (`/` is reduce).
- Scan: use prefix folds `ScanSum←{(+/)¨(1+⍳≢⍵)↑¨⊂⍵}` (`+\` is not a classic scan here).
- `∇` recursion hung in this build — tree reduce uses `PairSum⍣{1=≢⍵}`.
- Numbers are **Complex Double** — Goldilocks `p` is not an exact distinct scalar.

### Run TinyAPL demo

```bash
./vendor/tinyapl tinyapl/demo_run.apl
```

### Run full pipeline (correctness + optional benches)

```bash
python3 scripts/run_pipeline.py
```

Results land in `results/pipeline_result.json`. Benchmarks run **only** if correctness passes.
Latency fields are real `⎕_Measure` samples or explicitly `not_measured`.

## Goldilocks

- Older reduction-algebra checks: `reference/goldilocks.py` with `p = 2^64 - 2^32 + 1`.
- Bi-encoder field arithmetic does **not** use that module. J and R hold `p` as an extended integer.
- TinyAPL demos: `GSafeP = 65537 (Fermat prime)` for exact Double-safe ops.
- Verification rule: `reference(X) = candidate(X) (mod p)` for full-field cases.

## Topologies

R0 scalar-reference · R1 sequential (D=N−1) · R2 balanced-tree (⌈log2 N⌉) ·
R3 chunked · R4 segmented · R5 tacit-fused · R6 goldilocks-field · R7 subleq-routed-field.

## License / status

Experimental research code. The production seal is SHA-512 in J and R, described below. The older Python JSON HMAC and TinyAPL `VerifyStub` are legacy and are not that seal.

## SUBLEQ bi-encoder (production: J and R)

Not softmax attention and not a trained model. No timings are published here.

Production arithmetic is **only** extended integers in:

- `j/biencoder.ijs` — J (`jconsole` / `ijconsole`, j9). Matmul is `+/ .*`.
- `r/biencoder.R` — R with **gmp** `bigz` (never double, never base `%*%` on numeric). `p` does not fit in signed 64-bit, so bit64 is not used.

Python `scripts/run_biencoder.py` is a process launcher. It does not multiply or reduce mod `p`. It exits **non-zero** if the unmasked head disagrees with the printed reference product, shapes disagree, or J and R disagree on the seeded 4×4 case. The SUBLEQ-routed tensor is a separate metric (`routed.max_abs_error`); it is **not** required to be zero and is not treated as a pass of exact matmul.

Two towers apply one fixed permutation (`Wq +/ .* |: Wk = I` in J, the same product in R). Weights are not trained. The late interaction is subtract → compare → predicate → select → route → reduce, and that predicate masks factors of the dot product. The unmasked head must equal exact `A +/ .* B`.

Goldilocks `p = 18446744069414584321` is an extended integer in both J and R. The seeded small products agree with the field product because they do not wrap. A fixed large residue case is reduced in both languages and must agree. `reference/biencoder.py` is retired and raises if imported.

TinyAPL (`tinyapl/biencoder.apl`) is the earlier experiment only. Its scalars are Complex Double and cannot hold `p` (ulp at 2^64 is 4096). It is not the production runtime.

```bash
# JCONSOLE and RSCRIPT override discovery. gmp is loaded from ~/R/library when present.
python3 scripts/run_biencoder.py
python3 -m unittest tests.test_biencoder
python3 scripts/run_benchmarks.py
```

`scripts/run_biencoder.py` writes `results/biencoder_result.json` from the integers and hex digests J and R actually printed. It exits non-zero if those digests differ. `scripts/run_benchmarks.py` writes `results/benchmarks.json` from J `6!:2` and R `system.time` only.

### SHA-512 DAG seal

Not the SHA-256 canonical-JSON stub in `reference/reduction_algebra.py`, and not TinyAPL `VerifyStub`. Both of those remain only so the older reduction-algebra demo still runs. They are not production cryptography. Python does not hash the bi-encoder.

J (`j/sha512.ijs`) and R (`r/sha512.R`) each implement SHA-512 (FIPS 180-4). J keeps each 64-bit word as two uint32 halves because `b.` is not exact at or above `2^63`. R keeps each word as four uint16 limbs because a uint32 with the high bit set is R's `NA_integer_` and cannot go through `bitw*`. The seeded run prints the same lowercase hex seal from both.

Canonical bytes are big-endian and contain no JSON and no floats. Decimal integers are ASCII, with an optional leading `-`, no `+`, and no leading zeros (`0` is `0`).

Node preimage:

- 8 bytes `SRANOD01`
- uint32 length and ASCII role (`exact_head`, `predicted`, `weights`, or `prime`)
- uint32 rank, then that many uint32 dimensions
- uint32 count (rank 0 has count 1; that node is the Goldilocks prime)
- each integer, row-major (last axis fastest): uint32 byte length, then the decimal ASCII

The node digest is SHA-512 of that preimage. The DAG preimage is 8 bytes `SRADAG01`, a uint32 child count, then the raw 64-byte digests in the order exact head, routed prediction, weights, prime. The seal is SHA-512 of that preimage. `verify` recomputes the seal and compares. A tensor with `predicted[0,0]` increased by 1 must fail verify. The unmasked head is still required to match exact matmul. The routed error is still reported and is not forced to 0.

### Benchmarks

`j/bench.ijs` and `r/bench.R` time square extended-integer products `A +/ .* B` (R: `%*%` on `bigz`) and the production `dag_seal_hex` of that product (used both as the exact head and as the predicted tensor), the 4×4 permutation, and `p`. Entries are `(i*N+j) mod 5` and `(N*N+i*N+j) mod 5`. Shapes that finished are recorded in `results/benchmarks.json`. N=1024 sealing under the R interpreter was not started; the file says why. No timing in that file was typed in by hand.
