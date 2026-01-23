import 'prediction_service.dart';
import 'data_service.dart';
import '../models/bet_selection.dart';

class ProbabilityService {
  final PredictionService _predictionService = PredictionService();
  final DataService _dataService = DataService();

  Future<Map<String, dynamic>> runBacktest(int draws) async {
    final history = await _dataService.getRecentResults(draws + 30);
    if (history.length < draws + 15) return {"error": "Not enough data for backtest"};
    int total4Plus = 0, totalRedHits = 0, totalBlueHits = 0;
    for (int i = 0; i < draws; i++) {
      final actual = history[i];
      final prediction = await _predictionService.predictNext();
      int redHits = prediction.redBalls.where((p) => actual.redBalls.contains(p.number)).length;
      bool blueHit = prediction.blueBall.number == actual.blueBall;
      if (redHits >= 4) total4Plus++;
      totalRedHits += redHits;
      if (blueHit) totalBlueHits++;
    }
    return {
      "draws_tested": draws,
      "hit_4_plus_rate": (total4Plus / draws * 100).toStringAsFixed(1),
      "avg_red_hits": (totalRedHits / draws).toStringAsFixed(2),
      "blue_hit_rate": (totalBlueHits / draws * 100).toStringAsFixed(1),
    };
  }

  // UI Support with BetSelection
  Map<String, double> calculateProbabilities(BetSelection selection) {
    return {"一等奖": 0.0000001, "中奖概率": 0.06};
  }

  double calculateAnyPrizeProbability(BetSelection selection) {
    return 0.06;
  }
}