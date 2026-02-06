import os
import sys
import unittest

import pandas as pd

ROOT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if ROOT_DIR not in sys.path:
    sys.path.insert(0, ROOT_DIR)

import predict_next
import training_config


class PredictNextFeatureTests(unittest.TestCase):
    def _sample_df(self):
        return pd.DataFrame({
            "issue": [1, 2],
            "red1": [1, 1],
            "red2": [2, 7],
            "red3": [3, 8],
            "red4": [4, 9],
            "red5": [5, 10],
            "red6": [6, 11],
            "blue": [1, 2],
        })

    def test_red_frequency_uses_bayesian_smoothing(self):
        df = self._sample_df()
        _, red_freqs, momentum, _, _ = predict_next.calculate_features_single(df)
        alpha_r = 1.0
        beta_r = 5.5

        expected_freq = (1 + alpha_r) / (30.0 + alpha_r + beta_r)
        expected_momentum = (1 + alpha_r) / (5.0 + alpha_r + beta_r)

        self.assertAlmostEqual(red_freqs[1, 0], expected_freq, places=6)
        self.assertAlmostEqual(momentum[1, 0], expected_momentum, places=6)

    def test_blue_frequency_uses_bayesian_smoothing(self):
        df = self._sample_df()
        _, blue_freqs = predict_next.prepare_blue_features_single(df)
        alpha_b = 1.0
        beta_b = 15.0

        expected_freq = (1 + alpha_b) / (30.0 + alpha_b + beta_b)
        self.assertAlmostEqual(blue_freqs[1, 0], expected_freq, places=6)

    def test_training_config_defaults_full_history(self):
        self.assertIsNone(training_config.RED_WINDOW)
        self.assertIsNone(training_config.BLUE_WINDOW)
        self.assertEqual(training_config.SEQ_LEN, 15)

    def test_predict_next_uses_training_config(self):
        self.assertEqual(predict_next.RED_WINDOW, training_config.RED_WINDOW)
        self.assertEqual(predict_next.BLUE_WINDOW, training_config.BLUE_WINDOW)
        self.assertEqual(predict_next.SEQ_LEN, training_config.SEQ_LEN)

    def test_select_context_full_history(self):
        df = pd.DataFrame({"issue": list(range(1, 11))})
        context = training_config.select_context(df, None, 3)
        self.assertEqual(len(context), len(df))


if __name__ == "__main__":
    unittest.main()
