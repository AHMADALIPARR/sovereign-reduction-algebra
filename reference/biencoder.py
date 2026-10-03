"""Retired. Not a numeric authority.

The SUBLEQ bi-encoder runs in J (j/biencoder.ijs) and R (r/biencoder.R).
Both use extended integers. Python must not multiply, mask, or reduce mod p
for this pipeline. scripts/run_biencoder.py only launches those programs and
compares the integers they print.

TinyAPL under tinyapl/ is the earlier experiment. Its Complex Double type
cannot hold Goldilocks p = 18446744069414584321.
"""

raise RuntimeError(
    "reference/biencoder.py is retired. Run scripts/run_biencoder.py "
    "(J and R extended integers). Python is not the bi-encoder."
)
