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

  void dispose() {
    _redBallInterpreter?.close();
    _blueBallInterpreter?.close();
  }
}
