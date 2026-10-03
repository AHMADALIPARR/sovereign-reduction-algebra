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
