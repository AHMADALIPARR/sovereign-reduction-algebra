#!/usr/bin/env python3
"""J and R bi-encoder agreement. Does not recompute matmul or Goldilocks."""
from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULT = ROOT / "results" / "biencoder_result.json"


class TestJAndRBiencoder(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        proc = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "run_biencoder.py")],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
        )
        cls.proc = proc
        cls.data = json.loads(RESULT.read_text(encoding="utf-8"))

    def test_runner_exits_zero(self):
        self.assertEqual(self.proc.returncode, 0, self.proc.stdout + self.proc.stderr)
        self.assertTrue(self.data["overall_pass"])
        self.assertEqual(self.data["correctness"]["failed"], 0)

    def test_exact_head_matches_reference(self):
        j = self.data["J"]["matrices"]
        r = self.data["R"]["matrices"]
        self.assertEqual(j["EXACT_HEAD"], j["REFERENCE"])
        self.assertEqual(r["EXACT_HEAD"], r["REFERENCE"])
        self.assertEqual(j["EXACT_HEAD"], r["EXACT_HEAD"])
        self.assertTrue(self.data["exact_head_match"])
        self.assertEqual(j["HAND_EXACT_HEAD"], j["HAND_REFERENCE"])
        self.assertEqual(j["HAND_EXACT_HEAD"], [[7, 7], [6, 9]])
        self.assertEqual(r["HAND_EXACT_HEAD"], [[7, 7], [6, 9]])

    def test_routed_error_is_recorded_not_required_zero(self):
        routed = self.data["routed"]
        self.assertIn("max_abs_error", routed)
        self.assertIsInstance(routed["max_abs_error"], int)
        self.assertFalse(routed["required_zero"])
        self.assertFalse(routed["gates_exit"])
        self.assertEqual(self.data["J"]["max_abs_error"], self.data["R"]["max_abs_error"])
        self.assertEqual(routed["max_abs_error"], self.data["J"]["max_abs_error"])
        self.assertEqual(self.data["J"]["matrices"]["PREDICTED"], self.data["R"]["matrices"]["PREDICTED"])
        self.assertNotEqual(self.data["J"]["matrices"]["PREDICTED"], self.data["J"]["matrices"]["EXACT_HEAD"])
        self.assertEqual(routed["hand_max_abs_error"], 2)
        self.assertEqual(self.data["J"]["matrices"]["HAND_PREDICTED"], [[7, 5], [4, 9]])
        self.assertEqual(self.data["R"]["matrices"]["HAND_PREDICTED"], [[7, 5], [4, 9]])

    def test_permutation_inverse(self):
        self.assertTrue(self.data["permutation_inverse"])
        self.assertTrue(self.data["J"]["permutation_inverse"])
        self.assertTrue(self.data["R"]["permutation_inverse"])
        self.assertEqual(self.data["J"]["matrices"]["WQ"], self.data["R"]["matrices"]["WK"])

    def test_goldilocks_small_integer_agreement(self):
        self.assertTrue(self.data["goldilocks_small_agrees"])
        self.assertEqual(self.data["goldilocks_p"], "18446744069414584321")
        j = self.data["J"]["matrices"]
        r = self.data["R"]["matrices"]
        self.assertEqual(j["FIELD_SMALL_PREDICTED"], j["PREDICTED"])
        self.assertEqual(j["FIELD_SMALL_EXACT_HEAD"], j["EXACT_HEAD"])
        self.assertEqual(r["FIELD_SMALL_PREDICTED"], r["PREDICTED"])
        self.assertEqual(r["FIELD_LARGE_EXACT_HEAD"], r["FIELD_LARGE_REFERENCE"])
        self.assertEqual(j["FIELD_LARGE_EXACT_HEAD"], r["FIELD_LARGE_EXACT_HEAD"])
        self.assertEqual(j["FIELD_LARGE_PREDICTED"], r["FIELD_LARGE_PREDICTED"])
        self.assertTrue(self.data["J"]["field_large_exact_match"])
        self.assertTrue(self.data["R"]["field_small_agrees"])

    def test_not_softmax_and_shapes(self):
        self.assertEqual(self.data["shapes"], {"M": 4, "K": 4, "N": 4})
        self.assertIn("not softmax", self.data["note"])
        self.assertNotIn("trained softmax", self.data["note"])

    def test_sha512_dag_seal_agrees_and_mutation_fails(self):
        seal = self.data["seal"]
        self.assertTrue(seal["agree"])
        self.assertEqual(seal["J"], seal["R"])
        self.assertEqual(len(seal["J"]), 128)
        self.assertEqual(seal["dag_order"], ["exact_head", "predicted", "weights", "prime"])
        self.assertTrue(seal["verify"])
        self.assertEqual(seal["verify_mutated"], 0)
        self.assertEqual(seal["mutated_seal"]["J"], seal["mutated_seal"]["R"])
        self.assertNotEqual(seal["J"], seal["mutated_seal"]["J"])
        self.assertEqual(seal["neg_seal"]["J"], seal["neg_seal"]["R"])
        kat = self.data["sha512_kat"]
        self.assertEqual(
            kat["empty"],
            "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e",
        )
        self.assertEqual(
            kat["abc"],
            "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f",
        )
        self.assertNotIn("sha256", self.data["note"].lower())


if __name__ == "__main__":
    unittest.main()
