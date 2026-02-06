import 'dart:io';
import 'dart:math';

import 'package:path_provider/path_provider.dart';

import '../models/debug_data.dart';
import '../models/lottery_result.dart';
import 'data_service.dart';
import 'database_service.dart';
import 'feature_utils.dart';
import 'prediction_service.dart';

typedef DebugDataLoader = Future<DebugData> Function();

class DebugService {
  final PredictionService _predictionService;
  final DatabaseService _dbService;
  final DataService _dataService;

  DebugService({
    PredictionService? predictionService,
    DatabaseService? dbService,
    DataService? dataService,
  })  : _predictionService = predictionService ?? PredictionService(),
        _dbService = dbService ?? DatabaseService(),
        _dataService = dataService ?? DataService();

  Future<DebugData> load() async {
    List<LotteryResult> history = await _dbService.getAllResults();
    if (history.isEmpty) {
      await _dataService.syncData();
      history = await _dbService.getAllResults();
    }
    if (history.isEmpty) {
      throw Exception('No history available');
    }

    final latest = history.first;
    final recentContext = FeatureUtils.selectContext(
      history.reversed.toList(),
      FeatureUtils.redWindow,
      FeatureUtils.seqLen,
    );
    final recentIssues = recentContext
        .skip(max(0, recentContext.length - 20))
        .map((draw) => '${draw.issue} (${draw.drawDate})')
        .toList();

    final probs = await _predictionService.getFullProbabilities();
    final redProbs = probs['red'] ?? <double>[];
    final blueProbs = probs['blue'] ?? <double>[];

    return DebugData(
      historyCount: history.length,
      latestIssue: latest.issue,
      latestDate: latest.drawDate,
      modelSource: await _resolveModelSource(),
      seqLen: FeatureUtils.seqLen,
      redWindow: FeatureUtils.redWindow,
      blueWindow: FeatureUtils.blueWindow,
      alphaR: FeatureUtils.alphaR,
      betaR: FeatureUtils.betaR,
      alphaB: FeatureUtils.alphaB,
      betaB: FeatureUtils.betaB,
      recentIssues: recentIssues,
      topRed: _topK(redProbs, 12),
      topBlue: _topK(blueProbs, 3),
      redStats: _buildStats(redProbs),
      blueStats: _buildStats(blueProbs),
    );
  }

  List<DebugProbability> _topK(List<double> probs, int k) {
    final indexed = List.generate(
      probs.length,
      (i) => DebugProbability(number: i + 1, probability: probs[i]),
    );
    indexed.sort((a, b) => b.probability.compareTo(a.probability));
    return indexed.take(min(k, indexed.length)).toList();
  }

  ProbabilityStats _buildStats(List<double> probs) {
    if (probs.isEmpty) {
      return const ProbabilityStats(min: 0, max: 0, sum: 0, nanCount: 0);
    }
    final valid = probs.where((value) => !value.isNaN).toList();
    if (valid.isEmpty) {
      return ProbabilityStats(
        min: 0,
        max: 0,
        sum: 0,
        nanCount: probs.length,
      );
    }
    double minValue = valid.first;
    double maxValue = valid.first;
    double sumValue = 0;
    for (final value in valid) {
      minValue = min(minValue, value);
      maxValue = max(maxValue, value);
      sumValue += value;
    }
    return ProbabilityStats(
      min: minValue,
      max: maxValue,
      sum: sumValue,
      nanCount: probs.length - valid.length,
    );
  }

  Future<String> _resolveModelSource() async {
    final docDir = await getApplicationDocumentsDirectory();
    final models = [
      'red_ball_xgb.onnx',
      'red_ball_lgbm.onnx',
      'blue_ball_xgb.onnx',
      'blue_ball_lgbm.onnx',
    ];

    int existsCount = 0;
    for (final model in models) {
      final file = File('${docDir.path}/$model');
      if (await file.exists()) {
        existsCount++;
      }
    }

    if (existsCount == 0) return 'Bundled';
    if (existsCount == models.length) return 'OTA';
    return 'Mixed';
  }
}
