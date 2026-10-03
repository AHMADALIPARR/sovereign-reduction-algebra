#!/usr/bin/env python3
"""J and R one-step integer training agreement. Does not recompute the projection."""
from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RESULT = ROOT / "results" / "train_step_result.json"
KNOWN_PRE_SEAL = (
    "e6b4a8fda2cde450bd3d9c2b14932136b2894e2b78a1d6c91c52681ec06f3bd7"
    "f13e660a655ca84171ccb77584cc0729792c2123ab5b4b758e74576323756f6e"
)
PERM = [
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1],
    [1, 0, 0, 0],
]
ZEROS = [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]


class TestTrainStep(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        proc = subprocess.run(
            [sys.executable, str(ROOT / "scripts" / "run_train_step.py")],
            cwd=str(ROOT),
            capture_output=True,
            text=True,
        )
        cls.proc = proc
        cls.data = json.loads(RESULT.read_text(encoding="utf-8"))

    def test_runner_exits_zero_and_integers_agree(self):
        self.assertEqual(self.proc.returncode, 0, self.proc.stdout + self.proc.stderr)
        self.assertTrue(self.data["overall_pass"])
        self.assertEqual(self.data["correctness"]["failed"], 0)
        self.assertEqual(self.data["J"]["loss"], self.data["R"]["loss"])
        self.assertEqual(self.data["J"]["matrices"]["WQ"], self.data["R"]["matrices"]["WQ"])
        self.assertEqual(self.data["J"]["matrices"]["WK"], self.data["R"]["matrices"]["WK"])
        self.assertEqual(self.data["J"]["matrices"]["PROJ_BEFORE"], self.data["R"]["matrices"]["PROJ_BEFORE"])
        self.assertEqual(self.data["J"]["matrices"]["PROJ_AFTER"], self.data["R"]["matrices"]["PROJ_AFTER"])
        self.assertEqual(self.data["seal"]["J"], self.data["seal"]["R"])
        self.assertEqual(len(self.data["seal"]["J"]), 128)

    def test_weights_frozen_and_exact_head_matches_after_step(self):
        known = [
            [18, 18, 12, 16],
            [23, 22, 12, 19],
            [19, 29, 18, 29],
            [6, 15, 10, 15],
        ]
        j = self.data["J"]["matrices"]
        r = self.data["R"]["matrices"]
        self.assertEqual(j["WQ"], PERM)
        self.assertEqual(j["WK"], PERM)
        self.assertEqual(r["WQ"], PERM)
        self.assertEqual(r["WK"], PERM)
        self.assertEqual(j["PRE_EXACT_HEAD"], known)
        self.assertEqual(j["POST_EXACT_HEAD"], known)
        self.assertEqual(j["POST_EXACT_HEAD"], j["POST_REFERENCE"])
        self.assertEqual(r["POST_EXACT_HEAD"], r["POST_REFERENCE"])
        self.assertTrue(self.data["exact_head"]["pre_match"])
        self.assertTrue(self.data["exact_head"]["post_match"])
        self.assertTrue(self.data["exact_head"]["post_gates_exit"])
        self.assertEqual(j["PROJ_BEFORE"], ZEROS)
        self.assertEqual(j["PROJ_AFTER"], j["RESIDUAL"])
        self.assertNotEqual(j["PROJ_AFTER"], ZEROS)

    def test_routed_error_is_measured_and_not_required_zero(self):
        routed = self.data["routed"]
        j = self.data["J"]["matrices"]
        r = self.data["R"]["matrices"]
        self.assertEqual(routed["pre_max_abs_error"], 15)
        self.assertEqual(j["POST_PREDICTED"], j["POST_EXACT_HEAD"])
        self.assertEqual(r["POST_PREDICTED"], r["POST_EXACT_HEAD"])
        self.assertEqual(j["POST_PREDICTED"], r["POST_PREDICTED"])
        self.assertIsInstance(routed["post_max_abs_error"], int)
        self.assertFalse(routed["required_zero"])
        self.assertFalse(routed["gates_exit"])
        # Measured: adding the residual makes the post prediction the exact product.
        self.assertEqual(routed["post_max_abs_error"], 0)
        self.assertTrue(routed["reduced"])

    def test_seal_uses_current_dag_and_untrained_seal_unchanged(self):
        seal = self.data["seal"]
        self.assertEqual(seal["pre_untrained"], KNOWN_PRE_SEAL)
        self.assertTrue(seal["agree"])
        self.assertTrue(seal["verify"])
        self.assertNotEqual(seal["J"], seal["pre_untrained"])
        self.assertEqual(seal["dag_order"], ["exact_head", "predicted", "weights", "prime"])
        self.assertNotIn("softmax", self.data["update_rule"].lower())
        self.assertNotIn("wq +=", self.data["update_rule"].lower())


if __name__ == "__main__":
    unittest.main()
