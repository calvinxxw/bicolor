# Red-Blue Ball Ensemble Update Plan

Date: 2026-01-30
Owner: Codex + user

## Goal
Maximize hit rates for both Red and Blue balls using an ensemble of XGBoost and LightGBM classifiers. Target: Red 4+ hit rate (top-12) and Blue hit rate (top-3).

## Constraints
- Walk-forward backtest over the last 20 draws to validate.
- Ensemble blending (XGB + LGBM) for both Red and Blue.
- Blending happens on-device in Flutter.
- Consistent input feature shapes for both models in the ensemble.

## Success Metrics
- Red: 4+ hit rate (top-12).
- Blue: hit rate (top-3).

## Architecture Overview
1) Unified Feature Generator: Same features for XGBoost and LightGBM.
2) Red Ensemble: XGBoost (33-class) + LightGBM (33-class).
3) Blue Ensemble: XGBoost (16-class) + LightGBM (16-class).
4) Blending: Weighted average of probability vectors.
   - P = w * P_xgb + (1 - w) * P_lgbm.
   - Initial weight: 0.5 (equal weighting) or tuned via backtest.

## Implementation Details

### 1. Training (ml_training/train_ensemble.py)
- Load `ssq_data.csv`.
- Calculate features for Red (seq_len=15, 1785 features) and Blue (seq_len=15, 480 features).
- Train XGBoost and LightGBM for Red ball.
- Train XGBoost and LightGBM for Blue ball.
- Save all 4 models.

### 2. Export (ml_training/export_ensemble_onnx.py)
- Convert all 4 models to ONNX format.
- Red models: `red_ball_xgb.onnx`, `red_ball_lgbm.onnx`.
- Blue models: `blue_ball_xgb.onnx`, `blue_ball_lgbm.onnx`.
- Verify input/output shapes.

### 3. Flutter Integration
- Update `PredictionService` to load both sets of models.
- Implement `blendProbabilities(List<double> p1, List<double> p2, double weight)`.
- Use the blended probabilities for ranking and selection.
- Update sync service to download all 4 ONNX files.

## Backtest Validation
- Run `fair_backtest_ensemble.py` on the last 20 draws.
- Compare metrics against the single XGBoost model.

## Rollout
1. Implement training and export scripts.
2. Run backtest.
3. If results are positive, update Flutter app and release.
