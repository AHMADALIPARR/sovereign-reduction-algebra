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

- Full field: `reference/goldilocks.py` with `p = 2^64 - 2^32 + 1`.
- TinyAPL demos: `GSafeP = 65537 (Fermat prime)` for exact Double-safe ops.
- Verification rule: `reference(X) = candidate(X) (mod p)` for full-field cases.

## Topologies

R0 scalar-reference · R1 sequential (D=N−1) · R2 balanced-tree (⌈log2 N⌉) ·
R3 chunked · R4 segmented · R5 tacit-fused · R6 goldilocks-field · R7 subleq-routed-field.

## License / status

Experimental research code. Crypto helpers are **deterministic stubs**, not production cryptography.

## SUBLEQ bi-encoder (matmul tensor)

Not softmax attention and not a trained model. Sources:

- `tinyapl/biencoder.apl` — towers, library `SubleqPipeline` route, predicted tensor
- `tinyapl/biencoder_demo.apl` — seeded demo (flattened with `library.apl` by the runner)
- `reference/biencoder.py` — exact matmul plus the same SUBLEQ bi-encoder over integers and Goldilocks

Two towers apply one fixed permutation (`Wq @ Wkᵀ = I`, not fit by a training loop). A late interaction calls the library SUBLEQ pipeline on each query/key pair and masks factors of the dot product. The unmasked head equals exact `A +/∙× B`. The routed head is a sparse approximation; its max absolute error versus that matmul is measured.

```bash
python3 scripts/run_biencoder.py
python3 tests/test_biencoder.py
```

`scripts/run_biencoder.py` writes `results/biencoder_result.json`. Exit 0 means TinyAPL and the Python mirror agree and the unmasked head matches exact matmul. `tensor_match.exact_match` is the routed-versus-exact comparison and may be false; `max_abs_error` is the measured integer gap. Full Goldilocks `p` stays in Python (TinyAPL Complex Double cannot hold `p`). If `libncurses.so.6` is missing, the script points `LD_LIBRARY_PATH` at `libncursesw.so.6`.
