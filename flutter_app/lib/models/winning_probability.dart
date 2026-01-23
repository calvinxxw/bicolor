enum PrizeTier {
  first, // 6 red + 1 blue
  second, // 6 red
  third, // 5 red + 1 blue
  fourth, // 5 red OR 4 red + 1 blue
  fifth, // 4 red OR 3 red + 1 blue
  sixth, // 2 red + 1 blue OR 1 red + 1 blue OR 0 red + 1 blue
}

class WinningProbability {
  final PrizeTier tier;
  final double probability;
  final int combinations;

  WinningProbability({
    required this.tier,
    required this.probability,
    required this.combinations,
  });

  String get tierName {
    switch (tier) {
      case PrizeTier.first:
        return '一等奖';
      case PrizeTier.second:
        return '二等奖';
      case PrizeTier.third:
        return '三等奖';
      case PrizeTier.fourth:
        return '四等奖';
      case PrizeTier.fifth:
        return '五等奖';
      case PrizeTier.sixth:
        return '六等奖';
    }
  }

  String get tierDescription {
    switch (tier) {
      case PrizeTier.first:
        return '6红+1蓝';
      case PrizeTier.second:
        return '6红';
      case PrizeTier.third:
        return '5红+1蓝';
      case PrizeTier.fourth:
        return '5红 或 4红+1蓝';
      case PrizeTier.fifth:
        return '4红 或 3红+1蓝';
      case PrizeTier.sixth:
        return '2红+1蓝 或 1红+1蓝 或 0红+1蓝';
    }
  }

  String get probabilityPercentage {
    return '${(probability * 100).toStringAsFixed(6)}%';
  }

  String get oneInX {
    if (probability == 0) return '0';
    final x = (1 / probability).round();
    return '1 / ${_formatNumber(x)}';
  }

  String _formatNumber(int number) {
    final str = number.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
