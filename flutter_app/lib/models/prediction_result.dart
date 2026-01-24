class PredictionResult {
  final List<BallPrediction> redBalls;
  final BallPrediction blueBall;
  final Map<int, double>? redProbabilities;
  final Map<int, double>? blueProbabilities;
  final DateTime createdAt;

  PredictionResult({
    required this.redBalls,
    required this.blueBall,
    this.redProbabilities,
    this.blueProbabilities,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class BallPrediction {
  final int number;
  final double confidence;

  BallPrediction({
    required this.number,
    required this.confidence,
  });
}
