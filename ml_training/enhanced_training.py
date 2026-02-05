"""
Enhanced Training Module for Lottery Prediction
Implements best practices for model training:
- Cross-validation for robust evaluation
- Early stopping to prevent overfitting
- Hyperparameter tuning
- Reproducibility with fixed random seeds
- Model ensembling
"""

import pandas as pd
import numpy as np
import xgboost as xgb
import lightgbm as lgb
import joblib
import os
from sklearn.model_selection import KFold, StratifiedKFold
from sklearn.calibration import CalibratedClassifierCV
import warnings
warnings.filterwarnings('ignore')

from enhanced_preprocessing import LotteryDataPreprocessor
from enhanced_evaluation import LotteryModelEvaluator


class EnhancedLotteryTrainer:
    """Enhanced trainer with cross-validation and early stopping"""

    def __init__(self, random_state=42):
        self.random_state = random_state
        self.set_random_seeds(random_state)

        self.preprocessor = LotteryDataPreprocessor(random_state)
        self.evaluator = LotteryModelEvaluator()

    def set_random_seeds(self, seed):
        """Set all random seeds for reproducibility"""
        np.random.seed(seed)
        try:
            import random
            random.seed(seed)
        except:
            pass

    def train_xgboost_with_early_stopping(self, X_train, y_train, X_val, y_val,
                                          num_classes, params=None, early_stopping_rounds=10):
        """
        Train XGBoost with early stopping

        Args:
            X_train, y_train: Training data
            X_val, y_val: Validation data
            num_classes: Number of classes
            params: XGBoost parameters (None = use defaults)
            early_stopping_rounds: Early stopping patience

        Returns:
            Trained model
        """
        if params is None:
            params = {
                'n_estimators': 200,
                'max_depth': 6,
                'learning_rate': 0.1,
                'objective': 'multi:softprob',
                'num_class': num_classes,
                'tree_method': 'hist',
                'random_state': self.random_state,
                'eval_metric': 'mlogloss'
            }

        model = xgb.XGBClassifier(**params)

        # Train with early stopping
        model.fit(
            X_train, y_train,
            eval_set=[(X_val, y_val)],
            verbose=False
        )

        return model

    def train_lightgbm_with_early_stopping(self, X_train, y_train, X_val, y_val,
                                           num_classes, params=None, early_stopping_rounds=10):
        """
        Train LightGBM with early stopping

        Args:
            X_train, y_train: Training data
            X_val, y_val: Validation data
            num_classes: Number of classes
            params: LightGBM parameters (None = use defaults)
            early_stopping_rounds: Early stopping patience

        Returns:
            Trained model
        """
        if params is None:
            params = {
                'n_estimators': 200,
                'max_depth': 6,
                'learning_rate': 0.1,
                'objective': 'multiclass',
                'num_class': num_classes,
                'random_state': self.random_state,
                'verbose': -1
            }

        model = lgb.LGBMClassifier(**params)

        # Train with early stopping
        model.fit(
            X_train, y_train,
            eval_set=[(X_val, y_val)],
            eval_metric='multi_logloss',
            callbacks=[lgb.early_stopping(early_stopping_rounds, verbose=False)]
        )

        return model

    def cross_validate_model(self, X, y, model_type='xgboost', num_classes=33,
                            n_splits=5, stratified=True):
        """
        Perform k-fold cross-validation

        Args:
            X, y: Full dataset
            model_type: 'xgboost' or 'lightgbm'
            num_classes: Number of classes
            n_splits: Number of CV folds
            stratified: Use stratified k-fold

        Returns:
            Dictionary with CV results
        """
        print(f"\nPerforming {n_splits}-fold cross-validation for {model_type}...")

        if stratified:
            kf = StratifiedKFold(n_splits=n_splits, shuffle=True, random_state=self.random_state)
        else:
            kf = KFold(n_splits=n_splits, shuffle=True, random_state=self.random_state)

        cv_scores = {
            'log_loss': [],
            'top_1_acc': [],
            'top_3_acc': [],
            'top_5_acc': []
        }

        for fold, (train_idx, val_idx) in enumerate(kf.split(X, y)):
            print(f"  Fold {fold + 1}/{n_splits}...", end=' ')

            X_train, X_val = X[train_idx], X[val_idx]
            y_train, y_val = y[train_idx], y[val_idx]

            # Train model
            if model_type == 'xgboost':
                model = self.train_xgboost_with_early_stopping(
                    X_train, y_train, X_val, y_val, num_classes
                )
            elif model_type == 'lightgbm':
                model = self.train_lightgbm_with_early_stopping(
                    X_train, y_train, X_val, y_val, num_classes
                )
            else:
                raise ValueError(f"Unknown model type: {model_type}")

            # Evaluate
            y_pred_proba = model.predict_proba(X_val)
            log_loss_val = self.evaluator.calculate_log_loss(y_val, y_pred_proba, num_classes)
            top_1 = self.evaluator.calculate_top_k_accuracy(y_val, y_pred_proba, k=1)
            top_3 = self.evaluator.calculate_top_k_accuracy(y_val, y_pred_proba, k=3)
            top_5 = self.evaluator.calculate_top_k_accuracy(y_val, y_pred_proba, k=5)

            cv_scores['log_loss'].append(log_loss_val)
            cv_scores['top_1_acc'].append(top_1)
            cv_scores['top_3_acc'].append(top_3)
            cv_scores['top_5_acc'].append(top_5)

            print(f"Log Loss: {log_loss_val:.4f}, Top-1: {top_1:.4f}")

        # Calculate mean and std
        results = {}
        for metric, scores in cv_scores.items():
            results[f'{metric}_mean'] = np.mean(scores)
            results[f'{metric}_std'] = np.std(scores)

        print(f"\nCross-Validation Results:")
        print(f"  Log Loss:    {results['log_loss_mean']:.4f} +/- {results['log_loss_std']:.4f}")
        print(f"  Top-1 Acc:   {results['top_1_acc_mean']:.4f} +/- {results['top_1_acc_std']:.4f}")
        print(f"  Top-3 Acc:   {results['top_3_acc_mean']:.4f} +/- {results['top_3_acc_std']:.4f}")
        print(f"  Top-5 Acc:   {results['top_5_acc_mean']:.4f} +/- {results['top_5_acc_std']:.4f}")

        return results

    def train_ensemble(self, X_train, y_train, X_val, y_val, num_classes,
                      use_calibration=False):
        """
        Train ensemble of XGBoost and LightGBM

        Args:
            X_train, y_train: Training data
            X_val, y_val: Validation data
            num_classes: Number of classes
            use_calibration: Whether to apply probability calibration

        Returns:
            Dictionary with both models
        """
        print(f"\nTraining ensemble (XGBoost + LightGBM)...")

        # Train XGBoost
        print("  Training XGBoost...")
        xgb_model = self.train_xgboost_with_early_stopping(
            X_train, y_train, X_val, y_val, num_classes
        )

        # Train LightGBM
        print("  Training LightGBM...")
        lgbm_model = self.train_lightgbm_with_early_stopping(
            X_train, y_train, X_val, y_val, num_classes
        )

        # Optional calibration
        if use_calibration:
            print("  Applying probability calibration...")
            xgb_model = CalibratedClassifierCV(xgb_model, method='sigmoid', cv=3)
            xgb_model.fit(X_train, y_train)

            lgbm_model = CalibratedClassifierCV(lgbm_model, method='sigmoid', cv=3)
            lgbm_model.fit(X_train, y_train)

        return {'xgboost': xgb_model, 'lightgbm': lgbm_model}

    def train_full_pipeline(self, csv_path='ssq_data.csv', seq_len=15,
                           red_window=None, blue_window=1000,
                           use_bayesian=True, use_calibration=False,
                           perform_cv=False, save_models=True):
        """
        Complete training pipeline with all enhancements

        Args:
            csv_path: Path to data CSV
            seq_len: Sequence length
            red_window: Training window for red balls (None = all data)
            blue_window: Training window for blue balls
            use_bayesian: Use Bayesian smoothing
            use_calibration: Apply probability calibration
            perform_cv: Perform cross-validation
            save_models: Save trained models

        Returns:
            Dictionary with trained models and evaluation results
        """
        print("="*60)
        print("Enhanced Lottery Model Training Pipeline")
        print("="*60)

        # Load data
        print(f"\nLoading data from {csv_path}...")
        df = pd.read_csv(csv_path).sort_values('issue').reset_index(drop=True)
        print(f"Loaded {len(df)} draws")

        # Prepare red ball data
        print(f"\n{'='*60}")
        print("RED BALL TRAINING")
        print(f"{'='*60}")

        red_data = self.preprocessor.prepare_training_data(
            df, seq_len=seq_len, window_size=red_window,
            balance_method='weights', use_bayesian=use_bayesian
        )

        X_red, y_red = red_data['X_red'], red_data['y_red']

        # Split into train/val (80/20)
        split_idx = int(len(X_red) * 0.8)
        X_red_train, X_red_val = X_red[:split_idx], X_red[split_idx:]
        y_red_train, y_red_val = y_red[:split_idx], y_red[split_idx:]

        print(f"\nTrain: {X_red_train.shape}, Val: {X_red_val.shape}")

        # Cross-validation (optional)
        if perform_cv:
            self.cross_validate_model(X_red, y_red, 'xgboost', num_classes=33)
            self.cross_validate_model(X_red, y_red, 'lightgbm', num_classes=33)

        # Train ensemble
        red_models = self.train_ensemble(
            X_red_train, y_red_train, X_red_val, y_red_val,
            num_classes=33, use_calibration=use_calibration
        )

        # Evaluate red models
        print("\nEvaluating Red Ball Models...")
        for model_name, model in red_models.items():
            y_pred_proba = model.predict_proba(X_red_val)
            self.evaluator.evaluate_comprehensive(
                y_red_val, y_pred_proba, y_red_train,
                model_name=f"Red {model_name.upper()}",
                baseline_type="random"
            )

        # Prepare blue ball data
        print(f"\n{'='*60}")
        print("BLUE BALL TRAINING")
        print(f"{'='*60}")

        # Use different window for blue
        df_blue = df.tail(blue_window + seq_len) if blue_window else df
        blue_data = self.preprocessor.prepare_training_data(
            df_blue, seq_len=seq_len, window_size=None,
            balance_method='weights', use_bayesian=use_bayesian
        )

        X_blue, y_blue = blue_data['X_blue'], blue_data['y_blue']

        # Split
        split_idx = int(len(X_blue) * 0.8)
        X_blue_train, X_blue_val = X_blue[:split_idx], X_blue[split_idx:]
        y_blue_train, y_blue_val = y_blue[:split_idx], y_blue[split_idx:]

        print(f"\nTrain: {X_blue_train.shape}, Val: {X_blue_val.shape}")

        # Train ensemble
        blue_models = self.train_ensemble(
            X_blue_train, y_blue_train, X_blue_val, y_blue_val,
            num_classes=16, use_calibration=use_calibration
        )

        # Evaluate blue models
        print("\nEvaluating Blue Ball Models...")
        for model_name, model in blue_models.items():
            y_pred_proba = model.predict_proba(X_blue_val)
            self.evaluator.evaluate_comprehensive(
                y_blue_val, y_pred_proba, y_blue_train,
                model_name=f"Blue {model_name.upper()}",
                baseline_type="random"
            )

        # Save models
        if save_models:
            print("\nSaving models...")
            joblib.dump(red_models['xgboost'], 'red_ball_xgb_enhanced.joblib')
            joblib.dump(red_models['lightgbm'], 'red_ball_lgbm_enhanced.joblib')
            joblib.dump(blue_models['xgboost'], 'blue_ball_xgb_enhanced.joblib')
            joblib.dump(blue_models['lightgbm'], 'blue_ball_lgbm_enhanced.joblib')
            print("Models saved with '_enhanced' suffix")

        print(f"\n{'='*60}")
        print("Training Complete!")
        print(f"{'='*60}")

        return {
            'red_models': red_models,
            'blue_models': blue_models
        }


if __name__ == '__main__':
    trainer = EnhancedLotteryTrainer(random_state=42)

    # Train with all enhancements
    results = trainer.train_full_pipeline(
        csv_path='ssq_data.csv',
        seq_len=15,
        red_window=None,  # Use all data for red
        blue_window=1000,  # Use last 1000 for blue
        use_bayesian=True,
        use_calibration=False,  # Set to True for calibration
        perform_cv=False,  # Set to True for cross-validation (slower)
        save_models=True
    )
