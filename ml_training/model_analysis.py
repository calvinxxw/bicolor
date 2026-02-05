"""
Model Performance Analysis Script
Comprehensive analysis of lottery prediction models:
- Feature importance analysis
- Performance comparison vs baselines
- Statistical significance testing
"""

import pandas as pd
import numpy as np
import joblib
from scipy import stats
import warnings
warnings.filterwarnings('ignore')

from enhanced_preprocessing import LotteryDataPreprocessor
from enhanced_evaluation import LotteryModelEvaluator


class ModelAnalyzer:
    """Analyze trained lottery prediction models"""

    def __init__(self):
        self.preprocessor = LotteryDataPreprocessor(random_state=42)
        self.evaluator = LotteryModelEvaluator()

    def analyze_feature_importance(self, model, feature_names=None, top_n=20):
        """
        Analyze and visualize feature importance

        Args:
            model: Trained model (XGBoost or LightGBM)
            feature_names: List of feature names
            top_n: Number of top features to display

        Returns:
            DataFrame with feature importances
        """
        try:
            # Get feature importances
            if hasattr(model, 'feature_importances_'):
                importances = model.feature_importances_
            else:
                print("Model does not have feature_importances_ attribute")
                return None

            # Create DataFrame
            if feature_names is None:
                feature_names = [f"feature_{i}" for i in range(len(importances))]

            importance_df = pd.DataFrame({
                'feature': feature_names,
                'importance': importances
            }).sort_values('importance', ascending=False)

            print(f"\nTop {top_n} Most Important Features:")
            print(importance_df.head(top_n).to_string(index=False))

            return importance_df

        except Exception as e:
            print(f"Error analyzing feature importance: {e}")
            return None

    def compare_models(self, models_dict, X_test, y_test, num_classes):
        """
        Compare multiple models on the same test set

        Args:
            models_dict: Dictionary of {model_name: model}
            X_test, y_test: Test data
            num_classes: Number of classes

        Returns:
            DataFrame with comparison results
        """
        print("\n" + "="*60)
        print("MODEL COMPARISON")
        print("="*60)

        results = []

        for model_name, model in models_dict.items():
            print(f"\nEvaluating {model_name}...")

            y_pred_proba = model.predict_proba(X_test)

            metrics = {
                'Model': model_name,
                'Log Loss': self.evaluator.calculate_log_loss(y_test, y_pred_proba, num_classes),
                'Brier Score': self.evaluator.calculate_brier_score(y_test, y_pred_proba),
                'Top-1 Acc': self.evaluator.calculate_top_k_accuracy(y_test, y_pred_proba, k=1),
                'Top-3 Acc': self.evaluator.calculate_top_k_accuracy(y_test, y_pred_proba, k=3),
                'Top-5 Acc': self.evaluator.calculate_top_k_accuracy(y_test, y_pred_proba, k=5),
                'MRR': self.evaluator.calculate_mrr(y_test, y_pred_proba)
            }

            if num_classes >= 12:
                metrics['Top-12 Acc'] = self.evaluator.calculate_top_k_accuracy(y_test, y_pred_proba, k=12)

            results.append(metrics)

        # Create comparison DataFrame
        comparison_df = pd.DataFrame(results)

        print("\n" + "="*60)
        print("COMPARISON RESULTS")
        print("="*60)
        print(comparison_df.to_string(index=False))

        return comparison_df

    def analyze_prediction_distribution(self, model, X_test, num_classes):
        """
        Analyze the distribution of predicted probabilities

        Args:
            model: Trained model
            X_test: Test features
            num_classes: Number of classes

        Returns:
            Statistics about prediction distribution
        """
        y_pred_proba = model.predict_proba(X_test)

        # Calculate statistics
        max_probs = np.max(y_pred_proba, axis=1)
        entropy = -np.sum(y_pred_proba * np.log(y_pred_proba + 1e-10), axis=1)

        stats_dict = {
            'Mean Max Probability': np.mean(max_probs),
            'Std Max Probability': np.std(max_probs),
            'Mean Entropy': np.mean(entropy),
            'Std Entropy': np.std(entropy),
            'Min Max Probability': np.min(max_probs),
            'Max Max Probability': np.max(max_probs)
        }

        print("\nPrediction Distribution Statistics:")
        for key, value in stats_dict.items():
            print(f"  {key}: {value:.4f}")

        # Compare to uniform distribution
        uniform_entropy = -np.log(1.0 / num_classes)
        print(f"\n  Uniform Distribution Entropy: {uniform_entropy:.4f}")
        print(f"  Model Entropy vs Uniform: {np.mean(entropy) / uniform_entropy:.2%}")

        return stats_dict

    def statistical_significance_test(self, model_probs, baseline_probs, y_true,
                                     metric='log_loss', n_bootstrap=1000):
        """
        Perform bootstrap test for statistical significance

        Args:
            model_probs: Model predicted probabilities
            baseline_probs: Baseline predicted probabilities
            y_true: True labels
            metric: Metric to compare ('log_loss', 'accuracy', 'top_k')
            n_bootstrap: Number of bootstrap samples

        Returns:
            p-value and confidence interval
        """
        print(f"\nPerforming bootstrap significance test ({n_bootstrap} samples)...")

        # Calculate observed difference
        if metric == 'log_loss':
            model_score = self.evaluator.calculate_log_loss(y_true, model_probs, model_probs.shape[1])
            baseline_score = self.evaluator.calculate_log_loss(y_true, baseline_probs, baseline_probs.shape[1])
            observed_diff = baseline_score - model_score  # Positive = model is better
        elif metric == 'top_1_acc':
            model_score = self.evaluator.calculate_top_k_accuracy(y_true, model_probs, k=1)
            baseline_score = self.evaluator.calculate_top_k_accuracy(y_true, baseline_probs, k=1)
            observed_diff = model_score - baseline_score  # Positive = model is better
        else:
            raise ValueError(f"Unknown metric: {metric}")

        # Bootstrap
        n_samples = len(y_true)
        bootstrap_diffs = []

        for _ in range(n_bootstrap):
            # Resample with replacement
            indices = np.random.choice(n_samples, n_samples, replace=True)
            y_boot = y_true[indices]
            model_probs_boot = model_probs[indices]
            baseline_probs_boot = baseline_probs[indices]

            if metric == 'log_loss':
                model_boot = self.evaluator.calculate_log_loss(y_boot, model_probs_boot, model_probs.shape[1])
                baseline_boot = self.evaluator.calculate_log_loss(y_boot, baseline_probs_boot, baseline_probs.shape[1])
                diff = baseline_boot - model_boot
            elif metric == 'top_1_acc':
                model_boot = self.evaluator.calculate_top_k_accuracy(y_boot, model_probs_boot, k=1)
                baseline_boot = self.evaluator.calculate_top_k_accuracy(y_boot, baseline_probs_boot, k=1)
                diff = model_boot - baseline_boot

            bootstrap_diffs.append(diff)

        bootstrap_diffs = np.array(bootstrap_diffs)

        # Calculate p-value (two-tailed)
        p_value = np.mean(np.abs(bootstrap_diffs) <= np.abs(observed_diff))

        # Calculate 95% confidence interval
        ci_lower = np.percentile(bootstrap_diffs, 2.5)
        ci_upper = np.percentile(bootstrap_diffs, 97.5)

        print(f"  Observed Difference: {observed_diff:.6f}")
        print(f"  95% CI: [{ci_lower:.6f}, {ci_upper:.6f}]")
        print(f"  P-value: {p_value:.4f}")

        if p_value < 0.05:
            print(f"  Result: Statistically significant (p < 0.05)")
        else:
            print(f"  Result: Not statistically significant (p >= 0.05)")

        return {
            'observed_diff': observed_diff,
            'p_value': p_value,
            'ci_lower': ci_lower,
            'ci_upper': ci_upper
        }

    def comprehensive_analysis(self, model_path, data_path='ssq_data.csv',
                              model_type='red', seq_len=15):
        """
        Perform comprehensive analysis of a trained model

        Args:
            model_path: Path to saved model
            data_path: Path to data CSV
            model_type: 'red' or 'blue'
            seq_len: Sequence length used in training

        Returns:
            Dictionary with all analysis results
        """
        print("="*60)
        print(f"COMPREHENSIVE MODEL ANALYSIS: {model_type.upper()} BALL")
        print("="*60)

        # Load model
        print(f"\nLoading model from {model_path}...")
        model = joblib.load(model_path)

        # Load and prepare data
        print(f"Loading data from {data_path}...")
        df = pd.read_csv(data_path).sort_values('issue').reset_index(drop=True)

        # Prepare test data (last 20% of data)
        if model_type == 'red':
            data = self.preprocessor.prepare_training_data(
                df, seq_len=seq_len, window_size=None, use_bayesian=True
            )
            X, y = data['X_red'], data['y_red']
            num_classes = 33
        else:
            data = self.preprocessor.prepare_training_data(
                df, seq_len=seq_len, window_size=1000, use_bayesian=True
            )
            X, y = data['X_blue'], data['y_blue']
            num_classes = 16

        # Use last 20% as test set
        split_idx = int(len(X) * 0.8)
        X_test, y_test = X[split_idx:], y[split_idx:]
        X_train, y_train = X[:split_idx], y[:split_idx]

        print(f"Test set: {X_test.shape}")

        # 1. Feature importance
        print("\n" + "="*60)
        print("FEATURE IMPORTANCE ANALYSIS")
        print("="*60)
        importance_df = self.analyze_feature_importance(model, top_n=20)

        # 2. Prediction distribution
        print("\n" + "="*60)
        print("PREDICTION DISTRIBUTION ANALYSIS")
        print("="*60)
        dist_stats = self.analyze_prediction_distribution(model, X_test, num_classes)

        # 3. Performance evaluation
        print("\n" + "="*60)
        print("PERFORMANCE EVALUATION")
        print("="*60)
        y_pred_proba = model.predict_proba(X_test)
        metrics = self.evaluator.evaluate_comprehensive(
            y_test, y_pred_proba, y_train,
            model_name=f"{model_type.upper()} Ball Model",
            baseline_type="random"
        )

        # 4. Statistical significance
        print("\n" + "="*60)
        print("STATISTICAL SIGNIFICANCE TESTING")
        print("="*60)
        baseline_probs = self.evaluator.random_baseline_probs(num_classes, len(y_test))
        sig_test = self.statistical_significance_test(
            y_pred_proba, baseline_probs, y_test,
            metric='log_loss', n_bootstrap=1000
        )

        print("\n" + "="*60)
        print("ANALYSIS COMPLETE")
        print("="*60)

        return {
            'importance': importance_df,
            'distribution': dist_stats,
            'metrics': metrics,
            'significance': sig_test
        }


if __name__ == '__main__':
    analyzer = ModelAnalyzer()

    # Analyze red ball model
    print("\n\n")
    red_results = analyzer.comprehensive_analysis(
        model_path='red_ball_lgbm_enhanced.joblib',
        data_path='ssq_data.csv',
        model_type='red',
        seq_len=15
    )

    # Analyze blue ball model
    print("\n\n")
    blue_results = analyzer.comprehensive_analysis(
        model_path='blue_ball_lgbm_enhanced.joblib',
        data_path='ssq_data.csv',
        model_type='blue',
        seq_len=15
    )
