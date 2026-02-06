# Lottery Predictor v8 - Debug Tools Edition

## APK Information

**File**: `lottery_predictor_v8_debug_tools.apk`
**Size**: 89.9 MB (90 MB on disk)
**Build Date**: February 6, 2026
**Flutter Version**: 3.38.5
**Build Type**: Release (optimized)

## What's Included

This APK contains the lottery prediction app with the following ML models:

### Models (ONNX format for on-device inference)
- `red_ball_xgb.onnx` (6.4 MB) - XGBoost model for red balls
- `red_ball_lgbm.onnx` (6.5 MB) - LightGBM model for red balls
- `blue_ball_xgb.onnx` (1.7 MB) - XGBoost model for blue balls
- `blue_ball_lgbm.onnx` (2.1 MB) - LightGBM model for blue balls

### Data
- `history.csv` - Historical lottery draw data

### Features
- **Ensemble Predictions**: Combines XGBoost and LightGBM predictions
- **On-Device Inference**: All predictions run locally using ONNX Runtime
- **Historical Data**: Includes complete draw history
- **Visualization**: Charts and statistics using fl_chart
- **Auto-Update**: Can fetch latest draw results

## Model Performance

Based on the enhanced ML optimization:

### Red Ball Model (LightGBM - Best Performer)
- Top-1 Accuracy: 3.21% (vs 3.16% random baseline)
- Top-12 Accuracy: 36.64%
- Calibration Error: 0.0115 (well-calibrated)
- Statistical Significance: p=0.52 (not significant)

### Blue Ball Model (LightGBM)
- Top-1 Accuracy: 4.00% (vs 8.50% random baseline)
- Top-3 Accuracy: 22.00%
- Calibration Error: 0.0606
- Statistical Significance: p=0.49 (not significant)

## Important Disclaimer

⚠️ **This app is for educational and entertainment purposes only.**

Lottery draws are independent random events. Despite the sophisticated ML models:
- **No significant edge over random guessing** (p > 0.05)
- Models cannot predict truly random events
- Improvements over baseline are minimal and not statistically significant
- The app demonstrates ML techniques but cannot provide reliable predictions

## Installation

1. Enable "Install from Unknown Sources" in Android settings
2. Transfer the APK to your Android device
3. Tap the APK file to install
4. Grant necessary permissions (storage for data access)

## Technical Details

### Dependencies
- Flutter SDK 3.38.5
- ONNX Runtime 1.4.1 (for model inference)
- SQLite (for data storage)
- Dio (for network requests)
- FL Chart (for visualizations)

### Minimum Requirements
- Android 5.0 (API level 21) or higher
- ~100 MB free storage
- Internet connection (for fetching latest results)

### Build Command
```bash
flutter build apk --release
```

### Build Optimizations
- Tree-shaking enabled (reduced MaterialIcons from 1.6MB to 3.8KB)
- Release mode optimizations
- Code obfuscation
- Asset compression

## Version History

- **v8 (Debug Tools)**: Added in-app debug screen and feature diagnostics
- **v7 (Sorting Fix)**: Corrected draw sorting and latest-data ordering
- **v6 (Enhanced ML)**: Improved preprocessing, evaluation, and training pipeline
- **v5 (Ensemble)**: XGBoost + LightGBM ensemble with dual-window training
- **v4 (Auto)**: Automatic model retraining
- **v3 (Manual)**: Manual prediction interface
- **v2 (XGBoost)**: Initial XGBoost implementation

## Source Code

The enhanced ML training pipeline is available in:
- `ml_training/enhanced_preprocessing.py`
- `ml_training/enhanced_evaluation.py`
- `ml_training/enhanced_training.py`
- `ml_training/model_analysis.py`

See `ml_training/OPTIMIZATION_SUMMARY.md` for complete documentation.

---

**Built**: February 6, 2026
**Framework**: Flutter 3.38.5
**Models**: XGBoost + LightGBM Ensemble
