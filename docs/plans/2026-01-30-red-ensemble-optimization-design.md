# Red Ball Ensemble Optimization Design

Date: 2026-01-30
Owner: Codex + user

## Goal
Maximize red 4+ hit rate in top-12 predictions using an honest walk-forward backtest over the last 20 draws. Runtime target: <= 5 minutes per evaluation run.

## Constraints
- Walk-forward only (no leakage).
- Feature/window changes allowed; feature shape can change (Flutter updates OK).
- Ensemble with LightGBM + XGBoost.
- Blending happens on-device in Flutter.
- Keep fast evaluation (small grid, caching).

## Success Metrics
Primary:
- Red 4+ hit rate (top-12) over the last 20 draws.

Secondary:
- Average red hits per draw (top-12).
- Red 3+ hit rate (top-12) for context.

## Architecture Overview
1) Feature generator: precompute per-draw features once, cache for reuse.
2) Base models: XGBoost + LightGBM classifiers producing 33-class probabilities.
3) Ensemble blending: weighted average of probability vectors.
4) Walk-forward evaluator: train on data before each draw, predict next, score hits.

## Feature/Window Search (Fast Mode)
- Candidate seq_len: {10, 12, 15}
- Frequency window: {20, 30, 40}
- Momentum window: {3, 5, 7}
- Feature packs: gaps only; gaps+freq; gaps+freq+momentum; add stats; add co-occurrence
- Keep search small (4-6 configs) and reuse cached tensors.

## Ensemble Strategy
- Two models share a unified feature shape (same input vector).
- Blend probabilities: P = w * P_xgb + (1 - w) * P_lgbm.
- Choose weight w on a tuning segment (all draws before the last 20). Sweep w in {0.3, 0.4, 0.5, 0.6, 0.7}.
- Evaluate final metric on last 20 draws only.

## Training / Export
- Train XGBoost and LightGBM on historical data (per draw in walk-forward).
- Convert both to ONNX with consistent input shape.
- Store model artifacts:
  - red_ball_xgb.onnx
  - red_ball_lgbm.onnx
- Blue model unchanged for now (optional future ensemble).

## Flutter Changes
- Model sync downloads both red ONNX files.
- PredictionService loads two red sessions and blends outputs.
- Single feature build feeds both sessions.
- Fallback: if one model fails to load or infer, use the other.

## Error Handling
- Validate ONNX files after sync (file size + dummy inference).
- If validation fails, keep last-good models.
- Guard probability length == 33 before ranking.

## Testing
- Add a fast walk-forward script (last 20 draws) that prints:
  - Red 4+ hit rate
  - Avg red hits
  - Red 3+ hit rate
- Flutter unit test for blending two probability arrays.
- Optional inference smoke test on a fixed input to verify output shapes.

## Rollout
1) Implement ensemble in training + export.
2) Update Flutter for dual-model load + blending.
3) Run walk-forward evaluation (last 20 draws).
4) If target metric improves, release new models and app update.

## Open Questions
- Final feature pack and window choices from fast grid search.
- Whether to ensemble blue model later (out of scope for now).
