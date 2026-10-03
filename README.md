# Sovereign Reduction Algebra (TinyAPL)

Experimental **reduction algebra** `R = (D, OP, E, A, C, S)` realized in
[TinyAPL](https://github.com/RubenVerg/TinyAPL) with a Python Goldilocks reference.

This is **not** ordinary aggregation, DB hashing, WORM storage, or softmax attention.
The SUBLEQ attention pipeline is subtract → compare → predicate → select → route → reduce.

## Layout

```
sovereign-reduction-algebra/
  README.md
  docs/SPEC.md              # algebra spec
  docs/result_schema.json
  tinyapl/                  # TinyAPL sources + flattened demo_run.apl
  reference/                # Python Goldilocks + reduction algebra (verification)
  tests/vectors/            # deterministic expected outputs
  scripts/run_pipeline.py   # generate→reference→candidate→verify→bench
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

Experimental research code. Crypto helpers are **deterministic stubs**, not production cryptography.

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
```

The script writes `results/biencoder_result.json` from the integers J and R actually printed.

Sealing for the older reduction-algebra pipeline is a deterministic SHA-256 of canonical JSON bytes in `reference/reduction_algebra.py` (`commit` / `seal` / `verify`). That is not the bi-encoder and not production cryptography. TinyAPL `VerifyStub` is a legacy stub that does not recompute a digest.
