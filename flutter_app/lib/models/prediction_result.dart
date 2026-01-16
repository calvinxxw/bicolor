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
