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
    // TODO: Implement in next step
    throw UnimplementedError();
  }

  void dispose() {
    _redBallInterpreter?.close();
    _blueBallInterpreter?.close();
  }
}
