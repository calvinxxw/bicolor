class DebugProbability {
  final int number;
  final double probability;

  const DebugProbability({
    required this.number,
    required this.probability,
  });
}

class ProbabilityStats {
  final double min;
  final double max;
  final double sum;
  final int nanCount;

  const ProbabilityStats({
    required this.min,
    required this.max,
    required this.sum,
    required this.nanCount,
  });
}

class DebugData {
  final int historyCount;
  final String latestIssue;
  final String latestDate;
  final String modelSource;
  final int seqLen;
  final int? redWindow;
  final int? blueWindow;
  final double alphaR;
  final double betaR;
  final double alphaB;
  final double betaB;
  final List<String> recentIssues;
  final List<DebugProbability> topRed;
  final List<DebugProbability> topBlue;
  final ProbabilityStats redStats;
  final ProbabilityStats blueStats;

  const DebugData({
    required this.historyCount,
    required this.latestIssue,
    required this.latestDate,
    required this.modelSource,
    required this.seqLen,
    required this.redWindow,
    required this.blueWindow,
    required this.alphaR,
    required this.betaR,
    required this.alphaB,
    required this.betaB,
    required this.recentIssues,
    required this.topRed,
    required this.topBlue,
    required this.redStats,
    required this.blueStats,
  });
}
