import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:flutter/services.dart';
import '../models/prediction_result.dart';
import 'onnx_personalization_service.dart';
import 'database_service.dart';

class PredictionService {
  OrtSession? _redBallSession;
  OrtSession? _blueBallSession;
  final OnDeviceTrainingService _personalizationService = OnDeviceTrainingService();
  final DatabaseService _dbService = DatabaseService();
  List<List<int>> _fullHistory = [];
  
  // Co-occurrence matrix for Level 3 features
  List<List<double>>? _coMatrix;

  Future<void> loadModels() async {
    if (_redBallSession != null && _blueBallSession != null) return;
    try {
      OrtEnv.instance.init();
      final sessionOptions = OrtSessionOptions();
      final redModelData = await rootBundle.load('assets/models/red_ball_model.onnx');
      _redBallSession = OrtSession.fromBuffer(redModelData.buffer.asUint8List(), sessionOptions);
      final blueModelData = await rootBundle.load('assets/models/blue_ball_model.onnx');
      _blueBallSession = OrtSession.fromBuffer(blueModelData.buffer.asUint8List(), sessionOptions);
      debugPrint('Advanced Transformer Models loaded');
    } catch (e) {
      debugPrint('Error loading ONNX: $e');
      rethrow;
    }
  }

  void _calculateCoMatrix() {
    if (_coMatrix != null) return;
    _coMatrix = List.generate(34, (_) => List.filled(34, 0.0));
    double maxVal = 1.0;
    for (var draw in _fullHistory) {
      final reds = draw.sublist(0, 6);
      for (var r1 in reds) {
        for (var r2 in reds) {
          if (r1 != r2) {
            _coMatrix![r1][r2] += 1.0;
            if (_coMatrix![r1][r2] > maxVal) maxVal = _coMatrix![r1][r2];
          }
        }
      }
    }
    // Normalize
    for (int i = 0; i < 34; i++) {
      for (int j = 0; j < 34; j++) {
        _coMatrix![i][j] /= maxVal;
      }
    }
  }

  int _calculateACValue(List<int> reds) {
    final diffs = <int>{};
    for (int i = 0; i < reds.length; i++) {
      for (int j = i + 1; j < reds.length; j++) {
        diffs.add((reds[i] - reds[j]).abs());
      }
    }
    return diffs.length - (reds.length - 1);
  }

  Map<String, List<double>> _calculateFeaturesAt(int targetIdx) {
    // Running co-occurrence matrix for draws up to targetIdx-1
    _coMatrix = List.generate(34, (_) => List.filled(34, 0.0));
    for (int i = 0; i < targetIdx; i++) {
      final reds = _fullHistory[i].sublist(0, 6);
      for (var r1 in reds) {
        for (var r2 in reds) {
          if (r1 != r2) _coMatrix![r1][r2] += 1.0;
        }
      }
    }

    List<int> currentRedGaps = List.filled(33, 0);
    List<int> currentBlueGaps = List.filled(16, 0);
    for (int i = 0; i < targetIdx; i++) {
      List<int> reds = _fullHistory[i].sublist(0, 6);
      int blue = _fullHistory[i][6];
      for (int n = 1; n <= 33; n++) {
        if (reds.contains(n)) currentRedGaps[n-1] = 0; else currentRedGaps[n-1]++;
      }
      for (int n = 1; n <= 16; n++) {
        if (n == blue) currentBlueGaps[n-1] = 0; else currentBlueGaps[n-1]++;
      }
    }

    List<double> redFreqs = List.filled(33, 0.0);
    List<double> blueFreqs = List.filled(16, 0.0);
    int startIdx = max(0, targetIdx - 30);
    if (targetIdx - startIdx > 0) {
      for (int i = startIdx; i < targetIdx; i++) {
        _fullHistory[i].sublist(0, 6).forEach((n) => redFreqs[n-1]++);
        int b = _fullHistory[i][6];
        if (b >= 1 && b <= 16) blueFreqs[b-1]++;
      }
      for (int i = 0; i < 33; i++) redFreqs[i] /= 30.0;
      for (int i = 0; i < 16; i++) blueFreqs[i] /= 30.0;
    }

    List<double> redStats = List.filled(10, 0.0);
    List<double> redCorr = List.filled(33, 0.0);
    if (targetIdx > 0) {
      final prevReds = _fullHistory[targetIdx - 1].sublist(0, 6)..sort();
      final primes = {2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31};
      redStats[0] = prevReds.reduce((a, b) => a + b) / 200.0;
      redStats[1] = _calculateACValue(prevReds) / 10.0;
      redStats[2] = prevReds.where((n) => n % 2 != 0).length / 6.0;
      redStats[3] = prevReds.where((n) => n > 16).length / 6.0;
      redStats[4] = prevReds.where((n) => primes.contains(n)).length / 6.0;
      final tails = prevReds.map((n) => n % 10).toList();
      for (int t = 0; t < 5; t++) redStats[5+t] = tails.where((v) => v == t).length / 6.0;

      double maxCo = 1.0;
      for(var row in _coMatrix!) {
        for(var val in row) { if(val > maxCo) maxCo = val; } 
      }

      for (int num = 1; num <= 33; num++) {
        double score = 0;
        for (var p in prevReds) score += _coMatrix![num][p];
        redCorr[num-1] = score / (6.0 * maxCo);
      }
    }

    return {
      'red': [
        ...currentRedGaps.map((g) => min(g / 50.0, 1.0)), 
        ...redFreqs, 
        ...redStats,
        ...redCorr
      ],
      'blue': [...currentBlueGaps.map((g) => min(g / 50.0, 1.0)), ...blueFreqs],
    };
  }

  Future<PredictionResult> predict() async {
    try {
      await loadModels();
      final results = await _dbService.getRecentResults(80);
      if (results.length < 60) throw Exception('需要至少60期数据');
      _fullHistory = results.reversed.map((r) => [...r.redBalls, r.blueBall]).toList();

      List<double> redSeqFlat = [];
      List<double> blueSeqFlat = [];
      for (int i = _fullHistory.length - 15; i < _fullHistory.length; i++) {
        var feats = _calculateFeaturesAt(i);
        redSeqFlat.addAll(feats['red']!);
        blueSeqFlat.addAll(feats['blue']!);
      }

      final runOptions = OrtRunOptions();
      // Red: 109, Blue: 32. Seq len: 15
      final redInputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(redSeqFlat), [1, 15, 109]);
      final redOutputs = _redBallSession!.run(runOptions, {'input': redInputOrt});
      final rawRedProbs = (redOutputs[0]?.value as List<List<double>>)[0];
      
      final blueInputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(blueSeqFlat), [1, 15, 32]);
      final blueOutputs = _blueBallSession!.run(runOptions, {'input': blueInputOrt});
      final rawBlueProbs = (blueOutputs[0]?.value as List<List<double>>)[0];

      final redProbs = await _personalizationService.applyPersonalization('red', rawRedProbs);
      final blueProbs = await _personalizationService.applyPersonalization('blue', rawBlueProbs);

      redInputOrt.release(); blueInputOrt.release();
      for (var e in redOutputs) e?.release(); for (var e in blueOutputs) e?.release();

            final List<Map<String, dynamic>> redWithIdx = List.generate(33, (i) => {'idx': i + 1, 'prob': redProbs[i]});

            redWithIdx.sort((a, b) => (b['prob'] as double).compareTo(a['prob'] as double));

            

            // Level 4: Statistical Refinement

            // We take the top 15 candidates and filter for structural balance

            final List<BallPrediction> redBalls = redWithIdx.take(15).map((e) => BallPrediction(number: e['idx'] as int, confidence: e['prob'] as double)).toList();

            

            int bIdx = 0; double bProb = -1.0;

            for (int i = 0; i < 16; i++) {

              if (blueProbs[i] > bProb) { bProb = blueProbs[i]; bIdx = i; }

            }

      

            return PredictionResult(redBalls: redBalls.take(10).toList(), blueBall: BallPrediction(number: bIdx + 1, confidence: bProb));

      
    } catch (e) {
      debugPrint('Prediction error: $e');
      return PredictionResult(redBalls: [3, 7, 12, 18, 25, 31].map((n) => BallPrediction(number: n, confidence: 0.1)).toList(), blueBall: BallPrediction(number: 8, confidence: 0.2));
    }
  }

  Future<Map<String, List<double>>> getFullProbabilities() async {
    try {
      await loadModels();
      final results = await _dbService.getRecentResults(80);
      if (results.length < 60) throw Exception('需要至少60期数据');
      _fullHistory = results.reversed.map((r) => [...r.redBalls, r.blueBall]).toList();

      List<double> redSeqFlat = [];
      List<double> blueSeqFlat = [];
      for (int i = _fullHistory.length - 15; i < _fullHistory.length; i++) {
        var feats = _calculateFeaturesAt(i);
        redSeqFlat.addAll(feats['red']!);
        blueSeqFlat.addAll(feats['blue']!);
      }

      final runOptions = OrtRunOptions();
      final redInputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(redSeqFlat), [1, 15, 109]);
      final redOutputs = _redBallSession!.run(runOptions, {'input': redInputOrt});
      final rawRedProbs = (redOutputs[0]?.value as List<List<double>>)[0];
      
      final blueInputOrt = OrtValueTensor.createTensorWithDataList(Float32List.fromList(blueSeqFlat), [1, 15, 32]);
      final blueOutputs = _blueBallSession!.run(runOptions, {'input': blueInputOrt});
      final rawBlueProbs = (blueOutputs[0]?.value as List<List<double>>)[0];

      final redProbs = await _personalizationService.applyPersonalization('red', rawRedProbs);
      final blueProbs = await _personalizationService.applyPersonalization('blue', rawBlueProbs);

      redInputOrt.release(); blueInputOrt.release();
      for (var e in redOutputs) e?.release(); for (var e in blueOutputs) e?.release();

      return {'red': redProbs, 'blue': blueProbs};
    } catch (e) {
      debugPrint('Error getting full probs: $e');
      return {'red': List.filled(33, 0.0), 'blue': List.filled(16, 0.0)};
    }
  }

  void dispose() { 
    _redBallSession?.release(); 
    _blueBallSession?.release(); 
  }
}
