# TFLite Integration Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement core TFLite prediction functionality with minimal UI to display predicted lottery numbers and confidence scores.

**Architecture:** Create PredictionService to load TFLite models and run inference, data models for predictions, reusable BallWidget for display, and replace demo counter with prediction UI.

**Tech Stack:** Flutter, tflite_flutter 0.12.1, Dart

---

## Task 1: Create Data Model Classes

**Files:**
- Create: `flutter_app/lib/models/prediction_result.dart`

**Step 1: Create prediction data models**

Create file with complete data classes:

```dart
class PredictionResult {
  final List<BallPrediction> redBalls;
  final BallPrediction blueBall;

  PredictionResult({
    required this.redBalls,
    required this.blueBall,
  });
}

class BallPrediction {
  final int number;
  final double confidence;

  BallPrediction({
    required this.number,
    required this.confidence,
  });
}
```

**Step 2: Verify file compiles**

Run: `cd flutter_app && flutter analyze lib/models/prediction_result.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/models/prediction_result.dart
git commit -m "feat: add prediction data models"
```

---

## Task 2: Create Ball Display Widget

**Files:**
- Create: `flutter_app/lib/widgets/ball_widget.dart`

**Step 1: Create BallWidget**

Create reusable widget for displaying lottery balls:

```dart
import 'package:flutter/material.dart';

class BallWidget extends StatelessWidget {
  final int number;
  final bool isBlue;

  const BallWidget({
    super.key,
    required this.number,
    this.isBlue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isBlue ? Colors.blue : Colors.red,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          number.toString().padLeft(2, '0'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
```

**Step 2: Verify file compiles**

Run: `cd flutter_app && flutter analyze lib/widgets/ball_widget.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/widgets/ball_widget.dart
git commit -m "feat: add ball display widget"
```

---

## Task 3: Create PredictionService (Part 1: Structure)

**Files:**
- Create: `flutter_app/lib/services/prediction_service.dart`

**Step 1: Create service class structure**

Create file with imports and class skeleton:

```dart
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/prediction_result.dart';

class PredictionService {
  Interpreter? _redBallInterpreter;
  Interpreter? _blueBallInterpreter;

  // Hardcoded input data: 5 recent lottery draws
  static const List<List<int>> _redBallHistory = [
    [3, 7, 12, 18, 25, 31],
    [5, 9, 15, 22, 28, 33],
    [2, 8, 14, 19, 26, 30],
    [4, 11, 16, 23, 27, 32],
    [1, 6, 13, 20, 24, 29],
  ];

  static const List<int> _blueBallHistory = [8, 12, 5, 10, 3];

  Future<void> loadModels() async {
    // TODO: Implement in next step
  }

  Future<PredictionResult> predict() async {
    // TODO: Implement in next step
    throw UnimplementedError();
  }

  void dispose() {
    _redBallInterpreter?.close();
    _blueBallInterpreter?.close();
  }
}
```

**Step 2: Verify file compiles**

Run: `cd flutter_app && flutter analyze lib/services/prediction_service.dart`
Expected: No issues found (UnimplementedError is intentional)

**Step 3: Commit**

```bash
git add flutter_app/lib/services/prediction_service.dart
git commit -m "feat: add prediction service structure"
```

---

## Task 4: Implement Model Loading

**Files:**
- Modify: `flutter_app/lib/services/prediction_service.dart`

**Step 1: Implement loadModels method**

Replace the `loadModels` method:

```dart
Future<void> loadModels() async {
  if (_redBallInterpreter != null && _blueBallInterpreter != null) {
    return; // Already loaded
  }

  try {
    _redBallInterpreter = await Interpreter.fromAsset('assets/models/red_ball_model.tflite');
    _blueBallInterpreter = await Interpreter.fromAsset('assets/models/blue_ball_model.tflite');
    print('Models loaded successfully');
  } catch (e) {
    print('Error loading models: $e');
    rethrow;
  }
}
```

**Step 2: Verify file compiles**

Run: `cd flutter_app && flutter analyze lib/services/prediction_service.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/services/prediction_service.dart
git commit -m "feat: implement model loading"
```

---

## Task 5: Implement Prediction Logic

**Files:**
- Modify: `flutter_app/lib/services/prediction_service.dart`

**Step 1: Implement predict method**

Replace the `predict` method with complete implementation:

```dart
Future<PredictionResult> predict() async {
  await loadModels();

  // Prepare red ball input (5x6 matrix)
  final redInput = List.generate(
    5,
    (i) => _redBallHistory[i].map((n) => n.toDouble()).toList(),
  );

  // Prepare blue ball input (5x1 matrix)
  final blueInput = _blueBallHistory.map((n) => [n.toDouble()]).toList();

  // Run red ball inference
  final redOutput = List.filled(33, 0.0).reshape([1, 33]);
  _redBallInterpreter!.run(redInput, redOutput);

  // Run blue ball inference
  final blueOutput = List.filled(16, 0.0).reshape([1, 16]);
  _blueBallInterpreter!.run(blueInput, blueOutput);

  // Parse red ball predictions (top 6)
  final redProbabilities = redOutput[0] as List<double>;
  final redBallsWithProbs = List.generate(
    33,
    (i) => {'number': i + 1, 'prob': redProbabilities[i]},
  );
  redBallsWithProbs.sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

  final redBalls = redBallsWithProbs
      .take(6)
      .map((item) => BallPrediction(
            number: item['number'] as int,
            confidence: item['prob'] as double,
          ))
      .toList();

  // Parse blue ball prediction (top 1)
  final blueProbabilities = blueOutput[0] as List<double>;
  final blueBallsWithProbs = List.generate(
    16,
    (i) => {'number': i + 1, 'prob': blueProbabilities[i]},
  );
  blueBallsWithProbs.sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

  final blueBall = BallPrediction(
    number: blueBallsWithProbs[0]['number'] as int,
    confidence: blueBallsWithProbs[0]['prob'] as double,
  );

  return PredictionResult(redBalls: redBalls, blueBall: blueBall);
}
```

**Step 2: Verify file compiles**

Run: `cd flutter_app && flutter analyze lib/services/prediction_service.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/services/prediction_service.dart
git commit -m "feat: implement prediction logic"
```

---

## Task 6: Update Main UI (Part 1: Replace Demo)

**Files:**
- Modify: `flutter_app/lib/main.dart`

**Step 1: Replace entire main.dart**

Replace the entire file with new prediction UI:

```dart
import 'package:flutter/material.dart';
import 'services/prediction_service.dart';
import 'models/prediction_result.dart';
import 'widgets/ball_widget.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lottery Prediction',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const PredictionScreen(),
    );
  }
}

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});

  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen> {
  final PredictionService _service = PredictionService();
  PredictionResult? _result;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _runPrediction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.predict();
      setState(() {
        _result = result;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Prediction failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Lottery Prediction'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_result == null)
                const Text(
                  'Tap "Predict" to generate lottery numbers',
                  style: TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                )
              else
                _buildPredictionDisplay(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isLoading ? null : _runPrediction,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  child: Text('Predict', style: TextStyle(fontSize: 18)),
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredictionDisplay() {
    return Column(
      children: [
        const Text(
          'Red Balls',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _result!.redBalls
              .map((ball) => BallWidget(number: ball.number))
              .toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _result!.redBalls
              .map((ball) => Text(
                    '${(ball.confidence * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 12),
                  ))
              .toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          'Blue Ball',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        BallWidget(number: _result!.blueBall.number, isBlue: true),
        const SizedBox(height: 8),
        Text(
          '${(_result!.blueBall.confidence * 100).toStringAsFixed(1)}%',
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
```

**Step 2: Verify file compiles**

Run: `cd flutter_app && flutter analyze lib/main.dart`
Expected: No issues found

**Step 3: Commit**

```bash
git add flutter_app/lib/main.dart
git commit -m "feat: replace demo UI with prediction screen"
```

---

## Task 7: Build and Test

**Files:**
- Test: `flutter_app/` (entire app)

**Step 1: Clean build artifacts**

Run: `cd flutter_app && flutter clean`
Expected: Removes build/ directory

**Step 2: Build Windows app**

Run: `cd flutter_app && flutter build windows`
Expected: Build succeeds without errors

**Step 3: Run app and test prediction**

Run: `cd flutter_app && flutter run -d windows`
Expected:
- App launches successfully
- Shows "Tap 'Predict' to generate lottery numbers"
- Tap "Predict" button
- Loading indicator appears
- Predicted numbers display (6 red balls + 1 blue ball)
- Confidence scores show below each ball

**Step 4: Verify predictions**

Check:
- Red balls: 6 numbers between 1-33
- Blue ball: 1 number between 1-16
- Confidence scores: percentages between 0-100%
- Numbers are formatted with leading zeros (e.g., 05, 12)

**Step 5: Test error handling**

Temporarily rename model file to test error handling:
Run: `mv flutter_app/assets/models/red_ball_model.tflite flutter_app/assets/models/red_ball_model.tflite.bak`
Run app and tap "Predict"
Expected: Error message displayed in SnackBar
Restore file: `mv flutter_app/assets/models/red_ball_model.tflite.bak flutter_app/assets/models/red_ball_model.tflite`

**Step 6: Commit (no changes, just verification)**

No commit needed - this is a verification step

---

## Task 8: Update Session Documentation

**Files:**
- Create: `docs/notes/2026-01-16-tflite-integration-session.md`

**Step 1: Create session summary**

Document what was implemented:

```markdown
# Session Summary: TFLite Integration Implementation

**Date:** 2026-01-16
**Status:** ✅ Complete

## What Was Accomplished

Implemented core TFLite prediction functionality for lottery prediction app.

### Components Created

1. **Data Models** (`lib/models/prediction_result.dart`)
   - PredictionResult class
   - BallPrediction class

2. **Ball Widget** (`lib/widgets/ball_widget.dart`)
   - Reusable circular ball display
   - Red and blue variants

3. **Prediction Service** (`lib/services/prediction_service.dart`)
   - TFLite model loading
   - Inference logic
   - Hardcoded sample data (5 recent draws)

4. **Prediction UI** (`lib/main.dart`)
   - Replaced demo counter
   - Display predicted numbers with confidence scores
   - Loading states and error handling

### Testing Results

- ✅ Models load successfully
- ✅ Predictions return 6 red balls + 1 blue ball
- ✅ Confidence scores display correctly
- ✅ UI updates smoothly
- ✅ Error handling works

### Next Steps

Future enhancements:
- Data fetching from web sources
- SQLite storage for historical data
- Multiple prediction modes
- Historical analysis features
```

**Step 2: Commit**

```bash
git add docs/notes/2026-01-16-tflite-integration-session.md
git commit -m "docs: add TFLite integration session summary"
```

---

## Notes

### Model Input/Output Format

**Red Ball Model:**
- Input: `List<List<double>>` shape (5, 6) - 5 draws × 6 numbers
- Output: `List<double>` shape (33,) - probabilities for numbers 1-33
- Select top 6 by probability

**Blue Ball Model:**
- Input: `List<List<double>>` shape (5, 1) - 5 draws × 1 number
- Output: `List<double>` shape (16,) - probabilities for numbers 1-16
- Select top 1 by probability

### Troubleshooting

**If models fail to load:**
- Check `pubspec.yaml` has assets configured
- Verify model files exist in `assets/models/`
- Check TFLite binary is in `windows/blobs/`

**If inference fails:**
- Check input shape matches model expectations
- Verify output buffer size is correct
- Check model compatibility with TFLite version

### References

- Design: `docs/plans/2026-01-16-tflite-integration-design.md`
- TFLite setup: `docs/notes/2026-01-15-session-summary.md`
- Package: tflite_flutter v0.12.1
