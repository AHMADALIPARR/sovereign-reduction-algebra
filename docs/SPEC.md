# Reduction Algebra Specification

## Object

```
R = (D, OP, E, A, C, S)
```

| Symbol | Meaning |
|--------|---------|
| **D** | Domain (booleans, reals/exact ints, Goldilocks F_p, attention tensors) |
| **OP** | Operator (boolean/arithmetic/structural/field/SUBLEQ/crypto stubs) |
| **E** | Identity elements for each OP |
| **A** | Algebraic laws (associativity only where established on D) |
| **C** | Canonicalization (mod p residues; JSON canonical form) |
| **S** | Sealing semantics (deterministic hash commit/chain/seal/verify stubs) |

This studies **reduction algebra** for an experimental SUBLEQ Attention Engine.
It is **not** ordinary DB aggregation, WORM storage, or softmax transformer attention.

## Goldilocks

`p = 18446744069414584321 = 2^64 - 2^32 + 1`.

Authoritative ops: `reference/goldilocks.py` (Python arbitrary precision).

TinyAPL uses `Complex Double` and **cannot** represent `p` as a distinct exact scalar
(ulp at 2^64 is 4096). TinyAPL-native demos use `GSafeP = 65537 (Fermat prime)` for exact local
arithmetic. Full-field equality is always checked against the Python reference.

## Bi-encoder arithmetic

The SUBLEQ bi-encoder (two towers, fixed permutation, routed dot product) is
**not** softmax attention and is not trained. Its products and Goldilocks
residues are extended integers in J (`j/biencoder.ijs`) and R gmp `bigz`
(`r/biencoder.R`). Python is not a numeric authority for that pipeline.
TinyAPL cannot represent `p` exactly and is only the earlier experiment.
The unmasked head must equal `A` times `B`. The routed tensor is reported
separately and is not required to match that product.

## SUBLEQ attention pipeline

```
ARRAY → SUBTRACT (B←B−A) → COMPARE → PREDICATE → SELECT → ROUTE → REDUCE → STATE
```

**Not** equivalent to softmax attention.

## Topologies R0–R7

| Id | Name | Depth |
|----|------|-------|
| R0 | scalar-reference | 0 |
| R1 | sequential | N−1 |
| R2 | balanced-tree | ⌈log2 N⌉ |
| R3 | chunked | (chunk−1)+(⌈N/chunk⌉−1) |
| R4 | segmented | per segment |
| R5 | tacit-fused | N−1 |
| R6 | goldilocks-field | N−1 |
| R7 | subleq-routed-field | N−1 |

## Verification

1. No performance claim without correctness pass.
2. Deterministic identical inputs.
3. `reference(X) = candidate(X) (mod p)` for Goldilocks.
4. Never fabricate metrics; use `not_measured` when untimed.
