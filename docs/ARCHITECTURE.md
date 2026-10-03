# Architecture

Sovereign Reduction Algebra is an array reduction algebra for an experimental
SUBLEQ attention / bi-encoder. Production numeric work runs in J 9.7 and R 4.5
with gmp `bigz`. Python launches those processes and compares the integers they
print. It does not multiply, reduce modulo the Goldilocks prime, or hash.

This is not a trained softmax transformer. Tower weights are a fixed
permutation. The late interaction is subtract → compare → predicate → select →
route → reduce. The unmasked head must equal exact matrix multiplication. The
routed tensor is a separate sparse approximation and is not required to match
that product.

## Components

| Layer | Path | Role |
|-------|------|------|
| J arithmetic | `j/biencoder.ijs` | Extended-integer matmul (`+/ .*`), SUBLEQ routing, field residues |
| J seal | `j/sha512.ijs` | FIPS 180-4 SHA-512; 64-bit words as two uint32 halves |
| J benches | `j/bench.ijs` | `6!:2` timings written through the Python recorder |
| R arithmetic | `r/biencoder.R` | gmp `bigz` matmul; never double, never base `%*%` on numeric |
| R seal | `r/sha512.R` | SHA-512 with uint16 limbs (high-bit uint32 is `NA_integer_` in R) |
| R benches | `r/bench.R` | `system.time` timings |
| Launcher | `scripts/run_biencoder.py` | Starts J and R; compares printed decimals and hex seals |
| Bench recorder | `scripts/run_benchmarks.py` | Records timer output only; does not invent seconds |
| Results | `results/*.json` | Measured artifacts |
| TinyAPL | `tinyapl/`, `vendor/tinyapl` | Legacy demo. Complex Double cannot hold Goldilocks `p`. |
| Astra | `astra/*.apl` | GNU-APL style agent registry, routing, and mixture sources (included, not claimed executed here) |

```
                    ┌──────────────────────────┐
                    │  Python process launcher │
                    │  compare printed ints    │
                    └────────────┬─────────────┘
                                 │
              ┌──────────────────┼──────────────────┐
              ▼                                     ▼
     ┌────────────────┐                    ┌────────────────┐
     │  J 9.7         │                    │  R 4.5 + gmp   │
     │  +/ .*         │                    │  bigz %*%      │
     │  SHA-512 DAG   │                    │  SHA-512 DAG   │
     └───────┬────────┘                    └───────┬────────┘
             │                                     │
             └──────────────┬──────────────────────┘
                            ▼
              exact_head · predicted · weights · prime
                            │
                            ▼
                   parent SHA-512 seal
```

See also `docs/images/architecture.svg`.

## Field

Goldilocks prime `p = 18446744069414584321 = 2^64 − 2^32 + 1` is held as an
extended integer in both engines. Seeded small products agree with the field
product when they do not wrap. A fixed large residue case is reduced in both
languages and must agree.

## Pipeline

```
ARRAY → SUBTRACT → COMPARE → PREDICATE → SELECT → ROUTE → REDUCE → STATE
```

Two towers apply one fixed permutation (`Wq +/ .* |: Wk = I` in J; the same
product in R). One integer training step does not move `Wq` or `Wk`. It adds
the routed residual to an integer projection, then adds that projection
elementwise to the routed prediction. The unmasked head must still
equal `A` times `B`.

## Verification rules

1. Unmasked head equals exact `A × B` in both engines.
2. J and R agree on the seeded 4×4 case (shapes, tensors, seals).
3. SHA-512 DAG seals agree; `verify` passes; a one-entry mutation fails verify.
4. Routed max absolute error is reported and does not gate exit status.
5. Benchmark seconds come only from J `6!:2` or R `system.time`.

## Legacy

TinyAPL remains for the earlier reduction-algebra demos. Its scalars are
Complex Double; ulp at `2^64` is 4096, so `p` is not an exact distinct scalar.
The older Python Goldilocks reference and SHA-256 JSON stub are not the
production bi-encoder seal.
