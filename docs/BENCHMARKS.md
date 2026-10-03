# Benchmarks

Source of truth: `results/benchmarks.json` (recorded 2026-10-02 23:10:14 PT).

Every seconds value was printed by J `6!:2` (format `0j6`) or R `system.time`
(elapsed). Python did not time these operations. Inputs are extended integers
`A[i;j] = (i·N+j) mod 5` and `B[i;j] = (N·N+i·N+j) mod 5`, row-major.
`sha512_dag_seal` times `dag_seal_hex` of exact=product, predicted=product, the
4×4 permutation, and Goldilocks `p`. The routed head is not in these timings.

## Unmasked integer matmul

| Engine | N | Trials (s) | Mean (s) |
|--------|---|------------|----------|
| J 9.7 | 128 | 0.112684, 0.092637, 0.095784 | 0.100368 |
| R 4.5 / gmp | 128 | 0.089, 0.089, 0.090 | 0.089333 |
| J 9.7 | 1024 | 59.500851, 61.984229, 59.716807 | 60.400629 |
| R 4.5 / gmp | 1024 | 66.719, 68.561, 64.266 | 66.515333 |

## SHA-512 DAG seal

| Engine | N | Trials (s) | Digest |
|--------|---|------------|--------|
| J 9.7 | 128 | 6.514977, 6.452345, 6.419265 | `ccafddfba100f51a3856500b009f0644f15d6956e7ecd9667d4e84c4a6a74f7cc60cfe83381f559ff7d28979ebcbc44758f07a7ba86e9a6b682adaee2555a6fc` |
| R 4.5 / gmp | 128 | 38.453, 36.978, 38.912 | same as J N=128 |
| J 9.7 | 1024 | 512.146054 (1 trial) | `681ec299e447f7c07defe7a09ee8641c6a66fa60d041a1a8dccc5196e7c9fb2aa4238618fc0d098cc8913cf9a878aa29f27d4102cffa2ff2cfa405a3533b89af` |
| R 4.5 / gmp | 1024 | not run | — |

R N=1024 seal was not started: the N=128 seal was measured in-process; the node
preimage holds `N·N` integers and the seal hashes two of them, so N=1024 is 64×
the integers. The R SHA-512 path is an interpreter loop over 16-bit limbs.

## Seeded 4×4 bi-encoder (correctness, not a throughput bench)

From `results/biencoder_result.json`:

- Unmasked exact head: `18 18 12 16 / 23 22 12 19 / 19 29 18 29 / 6 15 10 15`
- Routed max abs error: 15
- `p = 18446744069414584321`
- Shared SHA-512 DAG seal (J and R agreed):
  `e6b4a8fda2cde450bd3d9c2b14932136b2894e2b78a1d6c91c52681ec06f3bd7f13e660a655ca84171ccb77584cc0729792c2123ab5b4b758e74576323756f6e`

## Environment (as recorded)

- J: `j9.7.1/j64/linux/commercial/www.jsoftware.com/2026-04-06T04:00:54/clang-14-0-0/SLEEF=0`
- R: `R version 4.5.0 (2025-04-11)`, gmp package `0.7.5.1`

Re-run:

```bash
JCONSOLE=/path/to/jconsole python3 scripts/run_benchmarks.py
```
