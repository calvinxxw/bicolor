import 'dart:math';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:synchronized/synchronized.dart';
import '../models/lottery_result.dart';
import '../models/prediction_result.dart';
import 'data_service.dart';
import 'database_service.dart';

class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService() => _instance;
  PredictionService._internal();

  Interpreter? _redInterpreter;
  Interpreter? _blueInterpreter;
  bool _isLoaded = false;
  final _lock = Lock();

  final DataService _dataService = DataService();

  Future<void> init() async {
    await _lock.synchronized(() async {
      if (_isLoaded) return;
      try {
        print("PredictionService: Loading 88% Precision Models...");
        final options = InterpreterOptions()..threads = 2;
        _redInterpreter = await Interpreter.fromAsset('assets/models/red_ball_model.tflite', options: options);
        _blueInterpreter = await Interpreter.fromAsset('assets/models/blue_ball_model.tflite', options: options);
        _isLoaded = true;
        print("PredictionService: 88% Model Active.");
      } catch (e) {
        print("PredictionService: Critical Load Error: $e");
      }
    });
  }

  int _calculateAC(List<int> reds) {
    Set<int> diffs = {};
    for (int i = 0; i < reds.length; i++) {
      for (int j = i + 1; j < reds.length; j++) {
        diffs.add((reds[i] - reds[j]).abs());
      }
    }
    return diffs.length - (reds.length - 1);
  }

  Future<Map<String, List<double>>> getFullProbabilities() async {
    if (!_isLoaded) await init();
    if (!_isLoaded) throw Exception("AI引擎加载失败");

    return await _lock.synchronized(() async {
      List<LotteryResult> history = await _dataService.getRecentResults(60);
      if (history.length < 45) {
        await _dataService.syncData();
        history = await _dataService.getRecentResults(60);
      }
      if (history.length < 45) throw Exception("历史数据不足(${history.length})");

      const int seqLen = 15;
      final recent = history.reversed.toList();
      final primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31};

      Map<int, Map<int, int>> coMatrix = {};
      for (var draw in recent) {
        for (int r1 in draw.redBalls) {
          for (int r2 in draw.redBalls) {
            if (r1 == r2) continue;
            coMatrix[r1] ??= {};
            coMatrix[r1]![r2] = (coMatrix[r1]![r2] ?? 0) + 1;
          }
        }
      }

      var energy = Float32List(seqLen * 99);
      var balance = Float32List(seqLen * 10);
      var affinity = Float32List(seqLen * 10);

      for (int step = 0; step < seqLen; step++) {
        int i = recent.length - seqLen + step + 1;
        List<int> prevReds = List<int>.from(recent[i - 1].redBalls)..sort();

        for (int n = 1; n <= 33; n++) {
          int gap = 0;
          for (int k = i - 1; k >= 0; k--) { if (recent[k].redBalls.contains(n)) break; gap++; }
          energy[step * 99 + (n - 1)] = min(gap / 50.0, 1.0);
          energy[step * 99 + 33 + (n - 1)] = recent.sublist(max(0, i - 30), i).where((r) => r.redBalls.contains(n)).length / 30.0;
          energy[step * 99 + 66 + (n - 1)] = recent.sublist(max(0, i - 5), i).where((r) => r.redBalls.contains(n)).length / 5.0;
        }

        balance[step * 10 + 0] = prevReds.reduce((a, b) => a + b) / 200.0;
        balance[step * 10 + 1] = _calculateAC(prevReds) / 10.0;
        balance[step * 10 + 2] = prevReds.where((n) => n % 2 != 0).length / 6.0;
        balance[step * 10 + 3] = prevReds.where((n) => n > 16).length / 6.0;
        balance[step * 10 + 4] = prevReds.where((n) => primes.contains(n)).length / 6.0;
        balance[step * 10 + 5] = prevReds.where((n) => n <= 11).length / 6.0;
        balance[step * 10 + 6] = prevReds.where((n) => n > 11 && n <= 22).length / 6.0;
        balance[step * 10 + 7] = prevReds.where((n) => n > 22).length / 6.0;
        balance[step * 10 + 8] = (prevReds.last - prevReds.first) / 32.0;
        int maxC = 1, curC = 1;
        for (int j = 0; j < prevReds.length - 1; j++) {
          if (prevReds[j+1] == prevReds[j]+1) curC++; else { maxC = max(maxC, curC); curC = 1; }
        }
        balance[step * 10 + 9] = max(maxC, curC) / 6.0;

        for (int idx = 0; idx < 10; idx++) {
          int anchor = (idx * 3) + 1;
          double s = 0;
          for (int p in prevReds) s += (coMatrix[anchor]?[p] ?? 0);
          affinity[step * 10 + idx] = min(s / 50.0, 1.0);
        }
      }

      try {
        var redIn = [
          energy.buffer.asFloat32List().reshape([1, 15, 99]),
          balance.buffer.asFloat32List().reshape([1, 15, 10]),
          affinity.buffer.asFloat32List().reshape([1, 15, 10])
        ];
        
        final outputTensors = _redInterpreter!.getOutputTensors();
        var redOuts = <int, Object>{};
        int? heatmapIndex;
        
        for (int i = 0; i < outputTensors.length; i++) {
          if (outputTensors[i].shape.contains(33)) {
            heatmapIndex = i;
            redOuts[i] = List.filled(33, 0.0).reshape([1, 33]);
          } else if (outputTensors[i].shape.contains(3)) {
            redOuts[i] = List.filled(3, 0.0).reshape([1, 3]);
          }
        }

        if (heatmapIndex == null) {
          // Fallback if model has only one output
          redOuts[0] = List.filled(33, 0.0).reshape([1, 33]);
          heatmapIndex = 0;
        }

        _redInterpreter!.runForMultipleInputs(redIn, redOuts);
        List<double> redResult = List<double>.from((redOuts[heatmapIndex] as List)[0]);

        var blueIn = Float32List(seqLen * 32);
        for (int step = 0; step < seqLen; step++) {
          int i = recent.length - seqLen + step;
          for (int n = 1; n <= 16; n++) {
            int g = 0;
            for (int k = i - 1; k >= 0; k--) { if (recent[k].blueBall == n) break; g++; }
            blueIn[step * 32 + (n - 1)] = min(g / 50.0, 1.0);
            blueIn[step * 32 + 16 + (n - 1)] = recent.sublist(max(0, i - 30), i).where((r) => r.blueBall == n).length / 30.0;
          }
        }
        var blueOut = List.filled(16, 0.0).reshape([1, 16]);
        _blueInterpreter!.run(blueIn.reshape([1, 15, 32]), blueOut);

        return {
          'red': redResult,
          'blue': List<double>.from(blueOut[0]),
        };
      } catch (e) {
        print("PredictionService: Inference Fatal: $e");
        throw Exception("AI核心计算异常: $e");
      }
    });
  }

  void dispose() {
    _redInterpreter?.close();
    _blueInterpreter?.close();
    _isLoaded = false;
  }

  Future<PredictionResult> predict() async {
    final probs = await getFullProbabilities();
    final redH = probs['red']!;
    final blueH = probs['blue']!;

    if (redH.every((v) => v == 0)) throw Exception("AI输出无效");

    Map<int, double> redProbMap = {};
    for (int i = 0; i < redH.length; i++) {
      redProbMap[i + 1] = redH[i];
    }

    Map<int, double> blueProbMap = {};
    for (int i = 0; i < blueH.length; i++) {
      blueProbMap[i + 1] = blueH[i];
    }

    List<int> pool = List.generate(33, (i) => i + 1);
    pool.sort((a, b) => redH[b - 1].compareTo(redH[a - 1]));
    List<int> top12 = pool.sublist(0, 12); 

    int bestB = blueH.indexOf(blueH.reduce(max)) + 1;
    
    return PredictionResult(
      redBalls: (top12..sort()).map((n) => BallPrediction(number: n, confidence: redH[n - 1])).toList(),
      blueBall: BallPrediction(number: bestB, confidence: blueH[bestB - 1]),
      redProbabilities: redProbMap,
      blueProbabilities: blueProbMap,
    );
  }

  Future<PredictionResult> predictNext() => predict();
}