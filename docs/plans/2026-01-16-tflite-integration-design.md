# TFLite Integration Design: Core Prediction Functionality

**Date:** 2026-01-16
**Status:** Approved
**Scope:** Phase 1 - Core prediction functionality only

## 1. Overview

Implement the core TensorFlow Lite prediction functionality for the lottery prediction app. This is the minimal implementation to get ML inference working with a simple UI.

**Goals:**
- Load and run TFLite models for red and blue ball predictions
- Display predicted numbers with confidence scores
- Use hardcoded sample data for testing
- Validate TFLite integration works correctly

**Non-Goals (Future Work):**
- Data fetching from web sources
- SQLite storage
- Historical data analysis
- Multiple prediction modes (single/multiple bets)
- Full app navigation structure

## 2. Architecture Overview

### Core Components

1. **PredictionService** (`lib/services/prediction_service.dart`)
   - Loads TFLite models from assets
   - Runs inference with hardcoded input data
   - Returns predictions with confidence scores

2. **Simple UI** (`lib/main.dart` - replace demo counter)
   - Title: "Lottery Prediction"
   - Display area: 6 red balls + 1 blue ball (visual circles)
   - Confidence scores below each number
   - "Predict" button to trigger inference

### Data Flow

```
User taps "Predict"
  → PredictionService.predict()
  → Load models (if not loaded)
  → Prepare hardcoded input (5 recent draws)
  → Run TFLite inference
  → Parse output (probabilities)
  → Select top predictions
  → Return to UI with confidence scores
  → UI updates to show results
```

### Hardcoded Input Data

We'll use 5 recent real lottery results (from late 2024) as input:
- Red balls: 5 draws × 6 numbers each
- Blue balls: 5 draws × 1 number each

## 3. PredictionService Implementation

### Class Structure

```dart
class PredictionService {
  Interpreter? _redBallInterpreter;
  Interpreter? _blueBallInterpreter;

  Future<void> loadModels();
  Future<PredictionResult> predict();
  void dispose();
}
```

### Model Loading

- Load models from `assets/models/` on first prediction
- Use `tflite_flutter` package's `Interpreter.fromAsset()`
- Cache interpreters for reuse
- Handle loading errors gracefully

### Input Preparation

Hardcoded 5 recent draws (example from late 2024):

```dart
// Red balls: 5 draws × 6 numbers
final redInput = [
  [3, 7, 12, 18, 25, 31],
  [5, 9, 15, 22, 28, 33],
  [2, 8, 14, 19, 26, 30],
  [4, 11, 16, 23, 27, 32],
  [1, 6, 13, 20, 24, 29],
];

// Blue balls: 5 draws × 1 number
final blueInput = [8, 12, 5, 10, 3];
```

### Inference Process

1. Reshape input to match model expectations (5×6 for red, 5×1 for blue)
2. Run `interpreter.run(input, output)`
3. Parse output arrays (33 probabilities for red, 16 for blue)
4. Select top 6 red balls and top 1 blue ball by probability
5. Return predictions with confidence scores

### Output Format

```dart
class PredictionResult {
  List<BallPrediction> redBalls;  // 6 predictions
  BallPrediction blueBall;         // 1 prediction
}

class BallPrediction {
  int number;
  double confidence;  // 0.0 to 1.0
}
```

## 4. UI Implementation

### Widget Structure

```
main.dart:
  MaterialApp
    └── PredictionScreen (StatefulWidget)
        ├── AppBar: "Lottery Prediction"
        ├── Body: Column
        │   ├── Predicted Numbers Display
        │   │   ├── Row: 6 red ball widgets
        │   │   └── Row: 1 blue ball widget
        │   ├── Confidence Scores Display
        │   │   ├── Red balls: 6 Text widgets with percentages
        │   │   └── Blue ball: 1 Text widget with percentage
        │   └── Predict Button
        └── Loading indicator (during inference)
```

### Ball Widget

- Circular container with number inside
- Red balls: red background (#FF0000), white text
- Blue ball: blue background (#0000FF), white text
- Size: 50×50 pixels
- Font: bold, size 20

### State Management

```dart
class _PredictionScreenState {
  PredictionService _service = PredictionService();
  PredictionResult? _result;
  bool _isLoading = false;

  Future<void> _runPrediction() async {
    setState(() => _isLoading = true);
    _result = await _service.predict();
    setState(() => _isLoading = false);
  }
}
```

### Initial State

- Show placeholder text: "Tap 'Predict' to generate lottery numbers"
- After prediction: Display balls and confidence scores
- During loading: Show CircularProgressIndicator

### Error Handling

- Wrap prediction in try-catch
- Show SnackBar with error message if model loading fails
- Log errors to console for debugging

## 5. File Structure & Changes

### Files to Create

1. **`lib/services/prediction_service.dart`** (~150 lines)
   - PredictionService class
   - Model loading logic
   - Inference logic
   - Hardcoded input data

2. **`lib/models/prediction_result.dart`** (~30 lines)
   - PredictionResult class
   - BallPrediction class
   - Simple data classes

3. **`lib/widgets/ball_widget.dart`** (~40 lines)
   - Reusable ball display widget
   - Red and blue variants

### Files to Modify

1. **`lib/main.dart`** (replace entirely)
   - Remove demo counter code
   - Add PredictionScreen
   - Wire up prediction service

2. **`pubspec.yaml`** (no changes needed)
   - Already has tflite_flutter: ^0.12.1

### Total Code

~220 lines of new Dart code

### Asset Configuration

Models already exist in `assets/models/` and are configured in pubspec.yaml:
- `red_ball_model.tflite` (94KB)
- `blue_ball_model.tflite` (22KB)

## 6. Implementation Notes

### Model Input/Output Specifications

Based on the design document (`2026-01-14-lottery-design.md`):

**Red Ball Model:**
- Input shape: (5, 6) - last 5 draws of 6 red balls each
- Output shape: (33,) - probability for each number 1-33
- Select top 6 numbers by probability

**Blue Ball Model:**
- Input shape: (5, 1) - last 5 draws of 1 blue ball each
- Output shape: (16,) - probability for each number 1-16
- Select top 1 number by probability

### TFLite Integration

Using `tflite_flutter` package (v0.12.1):
- Windows binary already installed: `flutter_app/windows/blobs/libtensorflowlite_c-win.dll`
- Models loaded from assets using `Interpreter.fromAsset()`
- Inference runs on CPU (no GPU acceleration needed for this model size)

### Testing Strategy

1. Verify models load successfully
2. Run prediction and check output format
3. Validate confidence scores are between 0-1
4. Ensure predicted numbers are in valid ranges (1-33 for red, 1-16 for blue)
5. Test error handling (missing models, invalid input)

## 7. Future Enhancements

After this core functionality is working:

1. **Data Fetching** - Replace hardcoded data with web scraping
2. **SQLite Storage** - Store historical lottery results
3. **Multiple Prediction Modes** - Single bet vs. multiple bet recommendations
4. **Historical Analysis** - Show number frequency and trends
5. **Full App Navigation** - Home, Prediction, History, Analysis screens

## 8. Success Criteria

This implementation is successful when:

- ✅ TFLite models load without errors
- ✅ Prediction returns 6 red balls + 1 blue ball
- ✅ Confidence scores display correctly
- ✅ UI updates smoothly without crashes
- ✅ Windows build runs successfully
- ✅ Predictions are deterministic (same input → same output)

## 9. References

- Original design: `docs/plans/2026-01-14-lottery-design.md`
- TFLite setup: `docs/notes/2026-01-15-session-summary.md`
- Package: tflite_flutter v0.12.1 (LiteRT 1.4.0)
