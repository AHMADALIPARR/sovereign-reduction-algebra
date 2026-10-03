"""Mini SUBLEQ bi-encoder mirror.

Two towers apply a fixed linear map, then a late-interaction head uses the
library SUBLEQ pipeline (subtract → compare → predicate → select → route →
reduce) to mask factors of a dot product.

This is NOT softmax attention and NOT a trained transformer. Weights are a
fixed permutation matrix P with P @ P.T = I, so the unmasked head equals
ordinary matmul. The routed head is a sparse approximation; its error versus
A @ B is measured, not assumed.

TinyAPL runs the same algorithm on small integers (exact in Complex Double).
Full Goldilocks p is authoritative here in Python only.
"""
from __future__ import annotations

from goldilocks import P, add, mul, sub, reduce_sum, canonical
from reduction_algebra import subleq_attention_pipeline

# Park–Miller minimal standard generator. Products stay below 2^53, so the
# same recurrence is exact in TinyAPL Complex Double.
LCG_A = 48271
LCG_M = 2147483647
SEED = 20261002
RADIX = 5
M = 4
K = 4
N = 4
GSAFE_P = 65537

# Fixed permutation: coordinates rotate so column t moves to t-1 (last → front).
# Wq @ Wk.T = I when Wk = Wq = PERM. Not learned.
PERM = [
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
    [1, 0, 0, 0],
]


def lcg_step(seed: int) -> int:
    return (LCG_A * seed) % LCG_M


def lcg_draw(n: int, seed: int, mod: int) -> tuple[list[int], int]:
    out: list[int] = []
    for _ in range(n):
        seed = lcg_step(seed)
        out.append(seed % mod)
    return out, seed


def matmul(a: list[list[int]], b: list[list[int]]) -> list[list[int]]:
    if not a or not b:
        raise ValueError("empty matmul")
    k = len(a[0])
    if any(len(row) != k for row in a) or any(len(row) != len(b[0]) for row in b):
        raise ValueError("matmul shape")
    if len(b) != k:
        raise ValueError("matmul inner dim")
    n = len(b[0])
    return [
        [sum(a[i][t] * b[t][j] for t in range(k)) for j in range(n)]
        for i in range(len(a))
    ]


def transpose(a: list[list[int]]) -> list[list[int]]:
    return [list(col) for col in zip(*a)]


def reshape(vals: list[int], rows: int, cols: int) -> list[list[int]]:
    if len(vals) != rows * cols:
        raise ValueError("reshape length")
    return [vals[i * cols : (i + 1) * cols] for i in range(rows)]


def flatten(mat: list[list[int]]) -> list[int]:
    return [x for row in mat for x in row]


def demo_matrices(seed: int = SEED, m: int = M, k: int = K, n: int = N, radix: int = RADIX):
    """Deterministic A [m,k], B [k,n] from the shared LCG."""
    av, seed2 = lcg_draw(m * k, seed, radix)
    bv, seed3 = lcg_draw(k * n, seed2, radix)
    return reshape(av, m, k), reshape(bv, k, n), seed3


def weights():
    return [row[:] for row in PERM], [row[:] for row in PERM]


def _subleq_pair(q: list[int], k: list[int]) -> tuple[list[int], int, int]:
    """Library pipeline. Returns predicate, aggregate of routed diffs, routed dot."""
    st = subleq_attention_pipeline(q, k)
    pred = [int(p) for p in st.predicate]
    terms = [qi * ki for qi, ki in zip(q, k)]
    routed = sum(t if m else 0 for t, m in zip(terms, pred))
    # aggregate_sum returns float; integer diffs stay exact.
    agg = int(st.aggregate)
    return pred, agg, routed


def biencoder(a, b, wq, wk):
    """Towers + SUBLEQ-routed matmul prediction.

    Q = A @ Wq, Krows = B.T @ Wk, C_exact = Q @ Krows.T,
    C_pred[i,j] = sum_t pred_ij[t] * Q[i,t] * Krows[j,t]
    where pred comes from SubleqPipeline(Q[i], Krows[j]).
    """
    q = matmul(a, wq)
    krows = matmul(transpose(b), wk)
    exact = matmul(q, transpose(krows))
    reference = matmul(a, b)
    pred_rows = []
    agg_rows = []
    predicates = []
    for qi in q:
        pr, ag, pd = [], [], []
        for kj in krows:
            pmask, agg, routed = _subleq_pair(qi, kj)
            pr.append(routed)
            ag.append(agg)
            pd.extend(pmask)
        pred_rows.append(pr)
        agg_rows.append(ag)
        predicates.append(pd)
    # predicates stored row-major over pairs, each mask length D=K
    gsafe = [[x % GSAFE_P for x in row] for row in pred_rows]
    return {
        "Q": q,
        "K": krows,
        "predicted": pred_rows,
        "exact_head": exact,
        "reference": reference,
        "aggregates": agg_rows,
        "predicates": predicates,
        "gsafe_predicted": gsafe,
        "max_abs_error": max(abs(p - r) for p, r in zip(flatten(pred_rows), flatten(reference))),
    }


def field_biencoder(a, b, wq, wk):
    """Same towers and SUBLEQ route in Goldilocks. Python-only for full p.

    Predicate uses the balanced representative in (-p/2, p/2], matching R7,
    which agrees with ordinary ≤0 on small non-wrapping integers.
    Products and the routed sum are reduced mod p.
    """
    def fmatmul(x, y):
        kk = len(x[0])
        nn = len(y[0])
        out = []
        for i in range(len(x)):
            row = []
            for j in range(nn):
                acc = 0
                for t in range(kk):
                    acc = add(acc, mul(x[i][t], y[t][j]))
                row.append(acc)
            out.append(row)
        return out

    q = fmatmul(a, wq)
    krows = fmatmul(transpose(b), wk)
    exact = fmatmul(q, transpose(krows))
    reference = fmatmul(a, b)
    predicted = []
    aggs = []
    preds = []
    for qi in q:
        prow, arow, masks = [], [], []
        for kj in krows:
            diff = [sub(kj[t], qi[t]) for t in range(len(qi))]
            mask = []
            routed_diffs = []
            routed_terms = []
            for t, d in enumerate(diff):
                signed = d if d <= P // 2 else d - P
                bit = 1 if signed <= 0 else 0
                mask.append(bit)
                routed_diffs.append(d if bit else 0)
                routed_terms.append(mul(qi[t], kj[t]) if bit else 0)
            prow.append(reduce_sum(routed_terms))
            arow.append(reduce_sum(routed_diffs))
            masks.extend(mask)
        predicted.append(prow)
        aggs.append(arow)
        preds.append(masks)
    return {
        "predicted": predicted,
        "exact_head": exact,
        "reference": reference,
        "aggregates": aggs,
        "predicates": preds,
        "modulus": str(P),
    }


def hand_example():
    """Identity-weight case checked by hand and by an early TinyAPL probe.

    A = [[1,2,3],[4,0,1]], B = [[1,2],[0,1],[2,1]]
    C = [[7,7],[6,9]]
    SUBLEQ masks on (rowA, colB) yield routed [[7,5],[4,9]], max abs error 2.
    """
    a = [[1, 2, 3], [4, 0, 1]]
    b = [[1, 2], [0, 1], [2, 1]]
    w = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    out = biencoder(a, b, w, w)
    return {
        "A": a,
        "B": b,
        "predicted": out["predicted"],
        "reference": out["reference"],
        "exact_head": out["exact_head"],
        "max_abs_error": out["max_abs_error"],
        "expected_predicted": [[7, 5], [4, 9]],
        "expected_reference": [[7, 7], [6, 9]],
        "expected_max_abs_error": 2,
    }


def large_field_inputs():
    """Fixed residues near p. Not representable as exact TinyAPL scalars."""
    a = [
        [P - 2, 4, 1, 7],
        [3, P - 5, 2, 9],
        [8, 1, P - 1, 6],
        [0, 5, 4, P - 3],
    ]
    b = [
        [P - 4, 2, 3, 1],
        [6, P - 1, 0, 5],
        [1, 8, P - 6, 2],
        [7, 3, 4, P - 2],
    ]
    return a, b


def run_seeded():
    a, b, seed_after = demo_matrices()
    wq, wk = weights()
    out = biencoder(a, b, wq, wk)
    field_small = field_biencoder(a, b, wq, wk)
    la, lb = large_field_inputs()
    field_large = field_biencoder(la, lb, wq, wk)
    return {
        "A": a,
        "B": b,
        "seed_after": seed_after,
        "Wq": wq,
        "Wk": wk,
        **out,
        "field_small": field_small,
        "field_large": field_large,
    }
