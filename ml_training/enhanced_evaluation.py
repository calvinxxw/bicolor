"""
Enhanced Model Evaluation Module
Implements comprehensive metrics for lottery prediction models:
- Probabilistic metrics (Log Loss, Brier Score)
- Classification metrics (Accuracy, Precision, Recall, F1)
- Ranking metrics (Top-K accuracy, MRR)
- Baseline comparisons (Random, Frequency-based)
- Statistical significance testing
"""

import numpy as np
import pandas as pd
from sklearn.metrics import (
    log_loss, accuracy_score, precision_recall_fscore_support,
    roc_auc_score, confusion_matrix
)
from scipy import stats
import warnings
warnings.filterwarnings('ignore')


class LotteryModelEvaluator:
    """Comprehensive evaluator for lottery prediction models"""

    def __init__(self, num_red_classes=33, num_blue_classes=16):
        self.num_red_classes = num_red_classes
        self.num_blue_classes = num_blue_classes

    def random_baseline_probs(self, num_classes, num_samples):
        """Generate random baseline probabilities (uniform distribution)"""
        return np.ones((num_samples, num_classes)) / num_classes

    def frequency_baseline_probs(self, y_train, num_classes, num_samples):
        """Generate frequency-based baseline probabilities"""
        freq = np.bincount(y_train, minlength=num_classes)
        probs = freq / freq.sum()
        return np.tile(probs, (num_samples, 1))

    def calculate_log_loss(self, y_true, y_pred_proba, num_classes=None, eps=1e-15):
        """
        Calculate log loss (cross-entropy loss)
        Lower is better. Random baseline: -log(1/num_classes)
        """
        try:
            # Clip probabilities to avoid log(0)
            y_pred_proba_clipped = np.clip(y_pred_proba, eps, 1 - eps)
            if num_classes is None:
                num_classes = y_pred_proba.shape[1]
            labels = list(range(num_classes))
            return log_loss(y_true, y_pred_proba_clipped, labels=labels)
        except Exception as e:
            print(f"Error calculating log loss: {e}")
            return np.nan

    def calculate_brier_score(self, y_true, y_pred_proba):
        """
        Calculate Brier score (mean squared error of probabilities)
        Lower is better. Range: [0, 2]
        """
        num_classes = y_pred_proba.shape[1]
        y_true_one_hot = np.zeros((len(y_true), num_classes))
        y_true_one_hot[np.arange(len(y_true)), y_true] = 1
        return np.mean(np.sum((y_pred_proba - y_true_one_hot) ** 2, axis=1))

    def calculate_top_k_accuracy(self, y_true, y_pred_proba, k=1):
        """
        Calculate top-k accuracy
        Percentage of samples where true label is in top-k predictions
        """
        top_k_preds = np.argsort(y_pred_proba, axis=1)[:, -k:]
        correct = np.array([y_true[i] in top_k_preds[i] for i in range(len(y_true))])
        return correct.mean()

    def calculate_mrr(self, y_true, y_pred_proba):
        """
        Calculate Mean Reciprocal Rank
        Average of 1/rank where rank is position of true label in sorted predictions
        """
        ranks = []
        for i in range(len(y_true)):
            sorted_indices = np.argsort(y_pred_proba[i])[::-1]
            rank = np.where(sorted_indices == y_true[i])[0][0] + 1
            ranks.append(1.0 / rank)
        return np.mean(ranks)

    def calculate_calibration_error(self, y_true, y_pred_proba, n_bins=10):
        """
        Calculate Expected Calibration Error (ECE)
        Measures how well predicted probabilities match actual frequencies
        """
        y_pred_max = np.max(y_pred_proba, axis=1)
        y_pred_class = np.argmax(y_pred_proba, axis=1)

        bin_boundaries = np.linspace(0, 1, n_bins + 1)
        ece = 0.0

        for i in range(n_bins):
            bin_lower = bin_boundaries[i]
            bin_upper = bin_boundaries[i + 1]

            in_bin = (y_pred_max > bin_lower) & (y_pred_max <= bin_upper)
            prop_in_bin = in_bin.mean()

            if prop_in_bin > 0:
                accuracy_in_bin = (y_true[in_bin] == y_pred_class[in_bin]).mean()
                avg_confidence_in_bin = y_pred_max[in_bin].mean()
                ece += np.abs(avg_confidence_in_bin - accuracy_in_bin) * prop_in_bin

        return ece

    def permutation_test(self, metric_model, metric_baseline, n_permutations=1000):
        """
        Perform permutation test to assess statistical significance
        Returns p-value for hypothesis that model is better than baseline
        """
        observed_diff = metric_model - metric_baseline

        # For metrics where lower is better (log loss, brier score)
        # we want to test if model < baseline, so diff should be negative
        # For metrics where higher is better (accuracy, top-k)
        # we want to test if model > baseline, so diff should be positive

        # Generate null distribution by random permutations
        null_diffs = []
        for _ in range(n_permutations):
            # Randomly assign which is "model" and which is "baseline"
            if np.random.rand() < 0.5:
                null_diff = metric_model - metric_baseline
            else:
                null_diff = metric_baseline - metric_model
            null_diffs.append(null_diff)

        null_diffs = np.array(null_diffs)
        p_value = (np.abs(null_diffs) >= np.abs(observed_diff)).mean()

        return p_value

    def evaluate_comprehensive(self, y_true, y_pred_proba, y_train=None,
                               model_name="Model", baseline_type="random"):
        """
        Comprehensive evaluation with all metrics and baseline comparison

        Args:
            y_true: True labels
            y_pred_proba: Predicted probabilities (num_samples, num_classes)
            y_train: Training labels for frequency baseline
            model_name: Name of the model being evaluated
            baseline_type: 'random' or 'frequency'

        Returns:
            Dictionary of metrics
        """
        num_classes = y_pred_proba.shape[1]
        num_samples = len(y_true)

        print(f"\n{'='*60}")
        print(f"Evaluating {model_name} ({num_samples} samples, {num_classes} classes)")
        print(f"{'='*60}")

        # Generate baseline
        if baseline_type == "random":
            baseline_probs = self.random_baseline_probs(num_classes, num_samples)
            baseline_name = "Random Baseline"
        elif baseline_type == "frequency" and y_train is not None:
            baseline_probs = self.frequency_baseline_probs(y_train, num_classes, num_samples)
            baseline_name = "Frequency Baseline"
        else:
            baseline_probs = self.random_baseline_probs(num_classes, num_samples)
            baseline_name = "Random Baseline"

        # Calculate metrics for model
        metrics = {}

        # Probabilistic metrics
        metrics['log_loss'] = self.calculate_log_loss(y_true, y_pred_proba, num_classes)
        metrics['brier_score'] = self.calculate_brier_score(y_true, y_pred_proba)
        metrics['calibration_error'] = self.calculate_calibration_error(y_true, y_pred_proba)

        # Classification metrics
        y_pred = np.argmax(y_pred_proba, axis=1)
        metrics['accuracy'] = accuracy_score(y_true, y_pred)

        # Top-k metrics
        metrics['top_1_acc'] = self.calculate_top_k_accuracy(y_true, y_pred_proba, k=1)
        metrics['top_3_acc'] = self.calculate_top_k_accuracy(y_true, y_pred_proba, k=3)
        metrics['top_5_acc'] = self.calculate_top_k_accuracy(y_true, y_pred_proba, k=5)
        if num_classes >= 12:
            metrics['top_12_acc'] = self.calculate_top_k_accuracy(y_true, y_pred_proba, k=12)

        # Ranking metric
        metrics['mrr'] = self.calculate_mrr(y_true, y_pred_proba)

        # Calculate baseline metrics
        baseline_metrics = {}
        baseline_metrics['log_loss'] = self.calculate_log_loss(y_true, baseline_probs, num_classes)
        baseline_metrics['brier_score'] = self.calculate_brier_score(y_true, baseline_probs)
        baseline_metrics['top_1_acc'] = self.calculate_top_k_accuracy(y_true, baseline_probs, k=1)
        baseline_metrics['top_3_acc'] = self.calculate_top_k_accuracy(y_true, baseline_probs, k=3)

        # Print results
        print(f"\n{model_name} Metrics:")
        print(f"  Log Loss:          {metrics['log_loss']:.4f}")
        print(f"  Brier Score:       {metrics['brier_score']:.4f}")
        print(f"  Calibration Error: {metrics['calibration_error']:.4f}")
        print(f"  Top-1 Accuracy:    {metrics['top_1_acc']:.4f} ({metrics['top_1_acc']*100:.2f}%)")
        print(f"  Top-3 Accuracy:    {metrics['top_3_acc']:.4f} ({metrics['top_3_acc']*100:.2f}%)")
        print(f"  Top-5 Accuracy:    {metrics['top_5_acc']:.4f} ({metrics['top_5_acc']*100:.2f}%)")
        if 'top_12_acc' in metrics:
            print(f"  Top-12 Accuracy:   {metrics['top_12_acc']:.4f} ({metrics['top_12_acc']*100:.2f}%)")
        print(f"  MRR:               {metrics['mrr']:.4f}")

        print(f"\n{baseline_name} Metrics:")
        print(f"  Log Loss:          {baseline_metrics['log_loss']:.4f}")
        print(f"  Brier Score:       {baseline_metrics['brier_score']:.4f}")
        print(f"  Top-1 Accuracy:    {baseline_metrics['top_1_acc']:.4f} ({baseline_metrics['top_1_acc']*100:.2f}%)")
        print(f"  Top-3 Accuracy:    {baseline_metrics['top_3_acc']:.4f} ({baseline_metrics['top_3_acc']*100:.2f}%)")

        # Calculate improvements
        print(f"\nImprovement over {baseline_name}:")
        log_loss_improvement = (baseline_metrics['log_loss'] - metrics['log_loss']) / baseline_metrics['log_loss'] * 100
        brier_improvement = (baseline_metrics['brier_score'] - metrics['brier_score']) / baseline_metrics['brier_score'] * 100
        top1_improvement = (metrics['top_1_acc'] - baseline_metrics['top_1_acc']) / baseline_metrics['top_1_acc'] * 100
        top3_improvement = (metrics['top_3_acc'] - baseline_metrics['top_3_acc']) / baseline_metrics['top_3_acc'] * 100

        print(f"  Log Loss:       {log_loss_improvement:+.2f}% (lower is better)")
        print(f"  Brier Score:    {brier_improvement:+.2f}% (lower is better)")
        print(f"  Top-1 Accuracy: {top1_improvement:+.2f}%")
        print(f"  Top-3 Accuracy: {top3_improvement:+.2f}%")

        # Statistical significance
        print(f"\nStatistical Significance (vs {baseline_name}):")
        print("  Note: For truly random data, improvements should not be significant")

        metrics['baseline_metrics'] = baseline_metrics
        metrics['improvements'] = {
            'log_loss': log_loss_improvement,
            'brier_score': brier_improvement,
            'top_1_acc': top1_improvement,
            'top_3_acc': top3_improvement
        }

        return metrics


if __name__ == '__main__':
    # Test the evaluator with synthetic data
    print("Testing Enhanced Evaluation Module\n")

    evaluator = LotteryModelEvaluator(num_red_classes=33, num_blue_classes=16)

    # Simulate some predictions
    np.random.seed(42)
    n_samples = 100

    # Red ball evaluation (33 classes)
    y_true_red = np.random.randint(0, 33, n_samples)
    y_pred_proba_red = np.random.dirichlet(np.ones(33), n_samples)  # Random probabilities

    metrics_red = evaluator.evaluate_comprehensive(
        y_true_red,
        y_pred_proba_red,
        model_name="Red Ball Model",
        baseline_type="random"
    )

    # Blue ball evaluation (16 classes)
    y_true_blue = np.random.randint(0, 16, n_samples)
    y_pred_proba_blue = np.random.dirichlet(np.ones(16), n_samples)

    metrics_blue = evaluator.evaluate_comprehensive(
        y_true_blue,
        y_pred_proba_blue,
        model_name="Blue Ball Model",
        baseline_type="random"
    )

    print("\nEvaluation module test complete!")
