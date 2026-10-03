# Astra APL

The `astra/` directory holds GNU-APL style source for an agent registry, budget
routing, and bounded-round mixture orchestration. These files are included as
architecture and reference source. This release does not claim that they were
executed on this box unless a future run is recorded under `results/`.

## Files

| File | Purpose |
|------|---------|
| `astra/agents.apl` | Agent registry (`Register`, `ResetAgents`) and numerical specialists (mean, median, trimmed, midrange, Winsor, consensus) |
| `astra/routing.apl` | Deterministic capability and budget routing over profiles `(name, capabilities, keywords, cost, enabled)` |
| `astra/orchestrate.apl` | Synchronous bounded-round mixture with budget accounting; no concurrency or preemption claim |

## Calling convention

An agent receives a nested request: numeric-data, prior-proposals, round. A
proposal is a numeric vector. `Register` takes a profile and a function name,
rejects duplicates and missing names, and returns a one-origin index.

Routing request shape: prompt, required capabilities, preferred capabilities,
top-k, budget, excluded indices. Result: selected indices, weights, raw scores,
total cost.

Mixture config: prompt, data, required, preferred, top-k, total budget, round
count. Result: answer, history, routes, failures, spent, success flag.

## Relationship to the bi-encoder

Astra is orthogonal to the J/R SUBLEQ bi-encoder. It does not replace production
arithmetic or the SHA-512 DAG seal. It is a separate APL-shaped orchestration
sketch kept alongside the reduction algebra for future GNU APL experiments.
