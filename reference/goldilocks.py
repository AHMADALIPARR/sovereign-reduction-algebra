"""Goldilocks prime field F_p with p = 2^64 - 2^32 + 1.

Exact Python reference for verification. TinyAPL uses Complex Double and cannot
represent arbitrary field elements; candidates must match this module mod p.
"""
from __future__ import annotations

P = (1 << 64) - (1 << 32) + 1  # 18446744069414584321
assert P == 18446744069414584321


def canonical(x: int) -> int:
    """C: map any integer into the canonical residue [0, p)."""
    return x % P


def add(a: int, b: int) -> int:
    return (canonical(a) + canonical(b)) % P


def sub(a: int, b: int) -> int:
    return (canonical(a) - canonical(b)) % P


def mul(a: int, b: int) -> int:
    return (canonical(a) * canonical(b)) % P


def exp(a: int, e: int) -> int:
    """Modular exponentiation; e may be any non-negative int."""
    if e < 0:
        raise ValueError("exponent must be non-negative")
    return pow(canonical(a), e, P)


def inverse(a: int) -> int:
    a = canonical(a)
    if a == 0:
        raise ZeroDivisionError("inverse of 0 in Goldilocks")
    # p is prime => a^(p-2) ≡ a^{-1}
    return pow(a, P - 2, P)


def negate(a: int) -> int:
    return (-canonical(a)) % P


def dot(xs: list[int], ys: list[int]) -> int:
    if len(xs) != len(ys):
        raise ValueError("dot length mismatch")
    acc = 0
    for x, y in zip(xs, ys):
        acc = (acc + mul(x, y)) % P
    return acc


def reduce_sum(xs: list[int]) -> int:
    acc = 0
    for x in xs:
        acc = add(acc, x)
    return acc


def reduce_product(xs: list[int]) -> int:
    if not xs:
        return 1
    acc = 1
    for x in xs:
        acc = mul(acc, x)
    return acc


def scan_sum(xs: list[int]) -> list[int]:
    out = []
    acc = 0
    for x in xs:
        acc = add(acc, x)
        out.append(acc)
    return out


def scan_product(xs: list[int]) -> list[int]:
    out = []
    acc = 1
    for x in xs:
        acc = mul(acc, x)
        out.append(acc)
    return out


def polynomial_eval(coeffs: list[int], x: int) -> int:
    """Horner evaluation: coeffs[0] + coeffs[1]*x + ... (low degree first)."""
    acc = 0
    for c in reversed(coeffs):
        acc = add(mul(acc, x), c)
    return acc


def tree_reduce_sum(xs: list[int]) -> tuple[int, int]:
    """Balanced pairwise tree reduce. Returns (value, dependency_depth)."""
    if not xs:
        return 0, 0
    layer = [canonical(x) for x in xs]
    depth = 0
    while len(layer) > 1:
        nxt = []
        for i in range(0, len(layer) - 1, 2):
            nxt.append(add(layer[i], layer[i + 1]))
        if len(layer) % 2 == 1:
            nxt.append(layer[-1])
        layer = nxt
        depth += 1
    return layer[0], depth


def sequential_reduce_sum(xs: list[int]) -> tuple[int, int]:
    """Left fold. Depth = max(N-1, 0)."""
    n = len(xs)
    return reduce_sum(xs), max(n - 1, 0)


def chunked_reduce_sum(xs: list[int], chunk: int = 4) -> tuple[int, int]:
    if chunk < 1:
        raise ValueError("chunk must be >= 1")
    if not xs:
        return 0, 0
    partials = []
    for i in range(0, len(xs), chunk):
        partials.append(reduce_sum(xs[i : i + chunk]))
    # depth ≈ (chunk-1) + (num_chunks-1) in sequential combine of partials
    val, d2 = sequential_reduce_sum(partials)
    d1 = min(chunk - 1, max(len(xs) - 1, 0)) if xs else 0
    return val, d1 + d2


__all__ = [
    "P",
    "canonical",
    "add",
    "sub",
    "mul",
    "exp",
    "inverse",
    "negate",
    "dot",
    "reduce_sum",
    "reduce_product",
    "scan_sum",
    "scan_product",
    "polynomial_eval",
    "tree_reduce_sum",
    "sequential_reduce_sum",
    "chunked_reduce_sum",
]
