# SHA-512 DAG seal

Production sealing for the bi-encoder is a SHA-512 directed acyclic digest
computed independently in J (`j/sha512.ijs`) and R (`r/sha512.R`). Python does
not hash the bi-encoder. This is not the legacy SHA-256 canonical-JSON stub in
`reference/reduction_algebra.py`, and not TinyAPL `VerifyStub`.

## Child nodes

Four nodes, in fixed order:

| Role | Contents |
|------|----------|
| `exact_head` | Unmasked exact product tensor |
| `predicted` | Routed (or, in benches, the same product) tensor |
| `weights` | Fixed 4×4 permutation |
| `prime` | Goldilocks `p` (rank 0, count 1) |

## Node preimage

Canonical bytes are big-endian. No JSON. No floats. Decimal integers are ASCII
with an optional leading `-`, no `+`, and no leading zeros (`0` is `0`).

1. 8 bytes magic `SRANOD01`
2. uint32 length, then ASCII role string
3. uint32 rank, then that many uint32 dimensions
4. uint32 count (rank 0 ⇒ count 1)
5. each integer, row-major (last axis fastest): uint32 byte length, then decimal ASCII

Node digest = SHA-512(preimage).

## Parent (DAG) preimage

1. 8 bytes magic `SRADAG01`
2. uint32 child count
3. raw 64-byte child digests in order: exact_head, predicted, weights, prime

Seal = SHA-512(parent preimage).

```
  [exact_head] [predicted] [weights] [prime]
        \           |          |         /
         \          |          |        /
          └─── parent hash of child digests ───► seal
```

## Word representation

- **J:** each 64-bit SHA-512 word is two uint32 halves because `b.` is not exact
  at or above `2^63`.
- **R:** each word is four uint16 limbs because a uint32 with the high bit set is
  R's `NA_integer_` and cannot go through `bitw*`.

## Verification

`verify` recomputes the seal and compares. A tensor with `predicted[0,0]`
increased by 1 must change the seal and fail verify. NIST FIPS 180-4 empty /
`abc` / long vectors are printed by both engines and checked by the launcher.

## Measured seals

| Case | Digest |
|------|--------|
| Seeded 4×4 bi-encoder (J = R) | `e6b4a8fda2cde450bd3d9c2b14932136b2894e2b78a1d6c91c52681ec06f3bd7f13e660a655ca84171ccb77584cc0729792c2123ab5b4b758e74576323756f6e` |
| Bench product seal N=128 (J = R) | `ccafddfba100f51a3856500b009f0644f15d6956e7ecd9667d4e84c4a6a74f7cc60cfe83381f559ff7d28979ebcbc44758f07a7ba86e9a6b682adaee2555a6fc` |
| Bench product seal N=1024 (J) | `681ec299e447f7c07defe7a09ee8641c6a66fa60d041a1a8dccc5196e7c9fb2aa4238618fc0d098cc8913cf9a878aa29f27d4102cffa2ff2cfa405a3533b89af` |
