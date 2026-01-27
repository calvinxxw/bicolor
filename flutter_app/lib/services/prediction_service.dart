import 'dart:math';
import 'dart:typed_data';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter/services.dart';
import '../models/lottery_result.dart';
import '../models/prediction_result.dart';
import 'data_service.dart';

class PredictionService {
  static final PredictionService _instance = PredictionService._internal();
  factory PredictionService() => _instance;
  PredictionService._internal();

  OrtSession? _redSession;
  OrtSession? _blueSession;
  bool _isLoaded = false;
  final _lock = Lock();

  final DataService _dataService = DataService();

  Future<void> init() async {
    await _lock.synchronized(() async {
      if (_isLoaded) return;
      try {
        print("PredictionService: Loading XGBoost-ONNX Models...");
        
        // Initialize ONNX Runtime Environment
        OrtEnv.instance.init();
        
        final redModelData = await rootBundle.load('assets/models/red_ball_xgb.onnx');
        final blueModelData = await rootBundle.load('assets/models/blue_ball_xgb.onnx');

        final sessionOptions = OrtSessionOptions();
        
        _redSession = OrtSession.fromBuffer(redModelData.buffer.asUint8List(), sessionOptions);
        _blueSession = OrtSession.fromBuffer(blueModelData.buffer.asUint8List(), sessionOptions);
        
        _isLoaded = true;
        print("PredictionService: XGBoost-ONNX Model Active.");
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

      // Flattened features for XGBoost
      var redFeatures = Float32List(seqLen * 119);
      var blueFeatures = Float32List(seqLen * 32);

      for (int step = 0; step < seqLen; step++) {
        int i = recent.length - seqLen + step + 1;
        List<int> prevReds = List<int>.from(recent[i - 1].redBalls)..sort();

        // Red Features (119 per step)
        int redBase = step * 119;
        for (int n = 1; n <= 33; n++) {
          int gap = 0;
          for (int k = i - 1; k >= 0; k--) { if (recent[k].redBalls.contains(n)) break; gap++; }
          redFeatures[redBase + (n - 1)] = min(gap / 50.0, 1.0);
          redFeatures[redBase + 33 + (n - 1)] = recent.sublist(max(0, i - 30), i).where((r) => r.redBalls.contains(n)).length / 30.0;
          redFeatures[redBase + 66 + (n - 1)] = recent.sublist(max(0, i - 5), i).where((r) => r.redBalls.contains(n)).length / 5.0;
        }

        redFeatures[redBase + 99 + 0] = prevReds.reduce((a, b) => a + b) / 200.0;
        redFeatures[redBase + 99 + 1] = _calculateAC(prevReds) / 10.0;
        redFeatures[redBase + 99 + 2] = prevReds.where((n) => n % 2 != 0).length / 6.0;
        redFeatures[redBase + 99 + 3] = prevReds.where((n) => n > 16).length / 6.0;
        redFeatures[redBase + 99 + 4] = prevReds.where((n) => primes.contains(n)).length / 6.0;
        redFeatures[redBase + 99 + 5] = prevReds.where((n) => n <= 11).length / 6.0;
        redFeatures[redBase + 99 + 6] = prevReds.where((n) => n > 11 && n <= 22).length / 6.0;
        redFeatures[redBase + 99 + 7] = prevReds.where((n) => n > 22).length / 6.0;
        redFeatures[redBase + 99 + 8] = (prevReds.last - prevReds.first) / 32.0;
        int maxC = 1, curC = 1;
        for (int j = 0; j < prevReds.length - 1; j++) {
          if (prevReds[j+1] == prevReds[j]+1) curC++; else { maxC = max(maxC, curC); curC = 1; }
        }
        redFeatures[redBase + 99 + 9] = max(maxC, curC) / 6.0;

        for (int idx = 0; idx < 10; idx++) {
          int anchor = (idx * 3) + 1;
          double s = 0;
          for (int p in prevReds) s += (coMatrix[anchor]?[p] ?? 0);
          redFeatures[redBase + 109 + idx] = min(s / 50.0, 1.0);
        }

        // Blue Features (32 per step)
        int blueBase = step * 32;
        int i_blue = recent.length - seqLen + step;
        for (int n = 1; n <= 16; n++) {
          int g = 0;
          for (int k = i_blue - 1; k >= 0; k--) { if (recent[k].blueBall == n) break; g++; }
          blueFeatures[blueBase + (n - 1)] = min(g / 50.0, 1.0);
          blueFeatures[blueBase + 16 + (n - 1)] = recent.sublist(max(0, i_blue - 30), i_blue).where((r) => r.blueBall == n).length / 30.0;
        }
      }

      try {
        final runOptions = OrtRunOptions();
        
        // Red Inference
        final redInputOrt = OrtValueTensor.createTensorWithDataList(redFeatures, [1, 1785]);
        final redInputs = {'input': redInputOrt};
        final redOutputs = _redSession!.run(runOptions, redInputs);
        
        // XGBoost with zipmap=False returns output 0 as labels and output 1 as probabilities
        final redProbabilities = (redOutputs[1]?.value as List<List<double>>)[0];
        
        // Blue Inference
        final blueInputOrt = OrtValueTensor.createTensorWithDataList(blueFeatures, [1, 480]);
        final blueInputs = {'input': blueInputOrt};
        final blueOutputs = _blueSession!.run(runOptions, blueInputs);
        final blueProbabilities = (blueOutputs[1]?.value as List<List<double>>)[0];

        // Clean up
        redInputOrt.release();
        blueInputOrt.release();
        for (var element in redOutputs) { element?.release(); }
        for (var element in blueOutputs) { element?.release(); }

        return {
          'red': List<double>.from(redProbabilities),
          'blue': List<double>.from(blueProbabilities),
        };
      } catch (e) {
        print("PredictionService: Inference Fatal: $e");
        throw Exception("AI核心计算异常: $e");
      }
    });
  }

  void dispose() {
    _redSession?.release();
    _blueSession?.release();
    OrtEnv.instance.release();
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
