"""Reduction algebra R = (D, OP, E, A, C, S) — Python reference.

Implements boolean/arithmetic/structural primitives, SUBLEQ attention pipeline,
topologies R0–R7, and cryptographic stubs. Goldilocks field ops live in
goldilocks.py and are re-exported here for a single import surface.
"""
from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass, asdict
from typing import Any, Callable, Iterable, Sequence

from goldilocks import (
    P,
    add as g_add,
    sub as g_sub,
    mul as g_mul,
    exp as g_exp,
    inverse as g_inverse,
    canonical as g_canonical,
    dot as g_dot,
    reduce_sum as g_reduce_sum,
    scan_sum as g_scan_sum,
    polynomial_eval as g_poly,
    tree_reduce_sum,
    sequential_reduce_sum,
    chunked_reduce_sum,
)

# ---------------------------------------------------------------------------
# Boolean reductions
# ---------------------------------------------------------------------------

def all_(xs: Sequence[bool | int]) -> bool:
    return all(bool(x) for x in xs)


def any_(xs: Sequence[bool | int]) -> bool:
    return any(bool(x) for x in xs)


def xor_(xs: Sequence[bool | int]) -> bool:
    acc = False
    for x in xs:
        acc = acc ^ bool(x)
    return acc


def threshold(xs: Sequence[bool | int], k: int) -> bool:
    return sum(bool(x) for x in xs) >= k


# ---------------------------------------------------------------------------
# Arithmetic reductions (ordinary — not Goldilocks)
# ---------------------------------------------------------------------------

def sum_(xs: Sequence[float | int]) -> float | int:
    return sum(xs)


def product_(xs: Sequence[float | int]) -> float | int:
    acc = 1
    for x in xs:
        acc *= x
    return acc


def min_(xs: Sequence[float | int]):
    return min(xs)


def max_(xs: Sequence[float | int]):
    return max(xs)


def scan_sum_ordinary(xs: Sequence[float | int]) -> list:
    out, acc = [], 0
    for x in xs:
        acc = acc + x
        out.append(acc)
    return out


# ---------------------------------------------------------------------------
# Structural
# ---------------------------------------------------------------------------

def reduce_op(xs: Sequence[Any], op: Callable[[Any, Any], Any], identity=None):
    it = iter(xs)
    try:
        acc = next(it) if identity is None else identity
    except StopIteration:
        if identity is None:
            raise ValueError("empty reduce without identity")
        return identity
    if identity is not None:
        # restart with identity
        acc = identity
        it = iter(xs)
    for x in it:
        acc = op(acc, x)
    return acc


def tree_reduce(xs: Sequence[Any], op: Callable[[Any, Any], Any]) -> tuple[Any, int]:
    if not xs:
        raise ValueError("empty tree reduce")
    layer = list(xs)
    depth = 0
    while len(layer) > 1:
        nxt = []
        for i in range(0, len(layer) - 1, 2):
            nxt.append(op(layer[i], layer[i + 1]))
        if len(layer) % 2:
            nxt.append(layer[-1])
        layer = nxt
        depth += 1
    return layer[0], depth


def segmented_reduce(xs: Sequence[Any], flags: Sequence[int], op: Callable, identity=0):
    """Match TinyAPL Partition ⊆ : nonzero runs form segments; zeros are gaps."""
    if len(xs) != len(flags):
        raise ValueError("segmented_reduce length mismatch")
    parts: list[list] = []
    cur = None
    for x, f in zip(xs, flags):
        if f:
            if cur is None:
                cur = []
                parts.append(cur)
            cur.append(x)
        else:
            cur = None
    out = []
    for part in parts:
        if not part:
            continue
        acc = part[0]
        for y in part[1:]:
            acc = op(acc, y)
        out.append(acc)
    return out


def segmented_reduce_keep(xs: Sequence[Any], flags: Sequence[int], op: Callable, identity=0):
    """flags[i]==1 starts a new segment; every element belongs to some segment."""
    if len(xs) != len(flags):
        raise ValueError("segmented_reduce_keep length mismatch")
    out = []
    acc = identity
    started = False
    for x, f in zip(xs, flags):
        if f and started:
            out.append(acc)
            acc = identity
        acc = op(acc, x)
        started = True
    if started:
        out.append(acc)
    return out

def rank_reduce(matrix: Sequence[Sequence[Any]], op: Callable, axis: int = 0):
    """Reduce 2D along axis 0 (rows→col reduce) or 1 (per-row reduce)."""
    if not matrix:
        return []
    if axis == 1:
        return [reduce_op(row, op) for row in matrix]
    cols = len(matrix[0])
    out = []
    for j in range(cols):
        col = [matrix[i][j] for i in range(len(matrix))]
        out.append(reduce_op(col, op))
    return out


def contract(tensor: Sequence[Sequence[float]], axis: int = 0):
    """Sum-contract along axis (matrices only)."""
    return rank_reduce(tensor, lambda a, b: a + b, axis=axis)


def partition(xs: Sequence[Any], flags: Sequence[int]) -> list[list[Any]]:
    """TinyAPL ⊆ semantics: contiguous nonzero flags form partitions; zeros are gaps."""
    parts: list[list[Any]] = []
    cur: list[Any] | None = None
    for x, f in zip(xs, flags):
        if f:
            if cur is None:
                cur = []
                parts.append(cur)
            cur.append(x)
        else:
            cur = None
    return parts


def inner_product(xs: Sequence[float], ys: Sequence[float]) -> float:
    return sum(a * b for a, b in zip(xs, ys))


def outer_product(xs: Sequence[float], ys: Sequence[float], op=lambda a, b: a * b):
    return [[op(a, b) for b in ys] for a in xs]


def fused_map_reduce(xs: Sequence[Any], map_fn: Callable, red_op: Callable, identity=0):
    acc = identity
    for x in xs:
        acc = red_op(acc, map_fn(x))
    return acc


# ---------------------------------------------------------------------------
# Attention (SUBLEQ-style — NOT softmax)
# ---------------------------------------------------------------------------

@dataclass
class AttentionState:
    selected: list[float]
    routed: list[float]
    aggregate: float
    predicate: list[int]
    meta: dict


def subleq_subtract(a: Sequence[float], b: Sequence[float]) -> list[float]:
    """B[i] ← B[i] - A[i]  (returns new B')."""
    if len(a) != len(b):
        raise ValueError("subtract length mismatch")
    return [bi - ai for ai, bi in zip(a, b)]


def compare_le_zero(xs: Sequence[float]) -> list[int]:
    """COMPARE → PREDICATE: 1 iff x ≤ 0 (SUBLEQ branch sense)."""
    return [1 if x <= 0 else 0 for x in xs]


def select(xs: Sequence[float], mask: Sequence[int]) -> list[float]:
    return [x for x, m in zip(xs, mask) if m]


def route(xs: Sequence[float], mask: Sequence[int], fill: float = 0.0) -> list[float]:
    """Keep values where mask=1, else fill (positional route)."""
    return [x if m else fill for x, m in zip(xs, mask)]


def aggregate_sum(xs: Sequence[float]) -> float:
    return float(sum(xs))


def attention_contract(routed: Sequence[float]) -> float:
    return aggregate_sum(routed)


def subleq_attention_pipeline(
    a: Sequence[float],
    b: Sequence[float],
) -> AttentionState:
    """ARRAY → SUBTRACT → COMPARE → PREDICATE → SELECT → ROUTE → REDUCE → STATE.

    Does NOT claim equivalence to softmax attention.
    """
    diff = subleq_subtract(a, b)
    pred = compare_le_zero(diff)
    selected = select(diff, pred)
    routed = route(diff, pred, fill=0.0)
    agg = attention_contract(routed)
    return AttentionState(
        selected=selected,
        routed=routed,
        aggregate=agg,
        predicate=pred,
        meta={
            "pipeline": "SUBLEQ",
            "note": "Not softmax attention; subtract-compare-route-reduce.",
            "diff": diff,
        },
    )


# ---------------------------------------------------------------------------
# Crypto stubs (deterministic hashes — not production crypto)
# ---------------------------------------------------------------------------

def canonicalize(obj: Any) -> str:
    """C: canonical JSON (sorted keys, no spaces)."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), default=str)


def commit(data: Any) -> str:
    return hashlib.sha256(canonicalize(data).encode()).hexdigest()


def chain(prev_hash: str, data: Any) -> str:
    return hashlib.sha256((prev_hash + canonicalize(data)).encode()).hexdigest()


def seal(data: Any, key: str = "sovereign-reduction-algebra") -> dict:
    body = canonicalize(data)
    mac = hashlib.sha256((key + body).encode()).hexdigest()
    return {"body": body, "seal": mac, "alg": "HMAC-SHA256-stub", "key_id": "stub"}


def verify(sealed: dict, key: str = "sovereign-reduction-algebra") -> bool:
    mac = hashlib.sha256((key + sealed["body"]).encode()).hexdigest()
    return mac == sealed.get("seal")


# ---------------------------------------------------------------------------
# Topologies R0–R7
# ---------------------------------------------------------------------------

@dataclass
class TopologyResult:
    topology: str
    value: Any
    dependency_depth: int | None
    notes: str


def R0_scalar_reference(xs: Sequence[float]) -> TopologyResult:
    """R0: scalar Python sum reference."""
    return TopologyResult("R0_scalar_reference", float(sum(xs)), 0, "reference scalar fold")


def R1_sequential(xs: Sequence[float]) -> TopologyResult:
    n = len(xs)
    acc = 0.0
    for x in xs:
        acc += x
    return TopologyResult("R1_sequential", acc, max(n - 1, 0), "sequential D=N-1")


def R2_balanced_tree(xs: Sequence[float]) -> TopologyResult:
    val, depth = tree_reduce(list(xs), lambda a, b: a + b) if xs else (0.0, 0)
    expected = math.ceil(math.log2(len(xs))) if len(xs) > 1 else 0
    return TopologyResult(
        "R2_balanced_tree",
        float(val),
        depth,
        f"tree depth={depth}, ceil(log2 N)={expected}",
    )


def R3_chunked(xs: Sequence[float], chunk: int = 4) -> TopologyResult:
    if not xs:
        return TopologyResult("R3_chunked", 0.0, 0, "empty")
    partials = [sum(xs[i : i + chunk]) for i in range(0, len(xs), chunk)]
    val = sum(partials)
    depth = (min(chunk, len(xs)) - 1) + (len(partials) - 1)
    return TopologyResult("R3_chunked", float(val), depth, f"chunk={chunk}")


def R4_segmented(xs: Sequence[float], flags: Sequence[int] | None = None) -> TopologyResult:
    if flags is None:
        flags = [1] + [0] * (len(xs) - 1)
    segs = segmented_reduce(xs, flags, lambda a, b: a + b, identity=0)
    return TopologyResult("R4_segmented", segs, None, "per-segment sums")


def R5_tacit_fused(xs: Sequence[float]) -> TopologyResult:
    """Map (x→x) fused into sum — semantic identity with sum."""
    val = fused_map_reduce(xs, lambda x: x, lambda a, b: a + b, identity=0.0)
    return TopologyResult("R5_tacit_fused", float(val), max(len(xs) - 1, 0), "fused map-reduce")


def R6_goldilocks_field(xs: Sequence[int]) -> TopologyResult:
    val, depth = sequential_reduce_sum(xs)
    return TopologyResult("R6_goldilocks_field", val, depth, f"sum mod p, p={P}")


def R7_subleq_routed_field(a: Sequence[int], b: Sequence[int]) -> TopologyResult:
    """SUBLEQ pipeline over Goldilocks: subtract, predicate ≤0 (as signed lift),
    route, then field-sum the routed values (negatives canonicalized).
    """
    # Work in signed ints then canonicalise for field aggregate
    diff = [g_sub(bi, ai) for ai, bi in zip(a, b)]
    # Predicate on balanced representatives in (-p/2, p/2]
    pred = []
    for d in diff:
        signed = d if d <= P // 2 else d - P
        pred.append(1 if signed <= 0 else 0)
    routed = [d if m else 0 for d, m in zip(diff, pred)]
    agg = g_reduce_sum(routed)
    return TopologyResult(
        "R7_subleq_routed_field",
        {"predicate": pred, "routed": routed, "aggregate": agg},
        max(len(a) - 1, 0),
        "SUBLEQ-routed Goldilocks reduce; not softmax",
    )


def run_all_topologies(xs: Sequence[float], a=None, b=None, gxs=None) -> list[TopologyResult]:
    gxs = gxs if gxs is not None else [int(x) % P for x in xs]
    a = a if a is not None else gxs
    b = b if b is not None else [(2 * x) % P for x in gxs]
    return [
        R0_scalar_reference(xs),
        R1_sequential(xs),
        R2_balanced_tree(xs),
        R3_chunked(xs),
        R4_segmented(xs),
        R5_tacit_fused(xs),
        R6_goldilocks_field(gxs),
        R7_subleq_routed_field(a, b),
    ]


def result_to_dict(r: TopologyResult) -> dict:
    return asdict(r)
