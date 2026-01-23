enum BetType {
  single, // 单式: 6 red + 1 blue
  multipleRed, // 复式红球: n red (n>6) + 1 blue
  multipleBlue, // 复式蓝球: 6 red + m blue (m>1)
  fullMultiple, // 全复式: n red (n>6) + m blue (m>1)
}

class BetSelection {
  final Set<int> selectedRedBalls; // 1-33
  final Set<int> selectedBlueBalls; // 1-16
  final String? name;

  BetSelection({
    Set<int>? selectedRedBalls,
    Set<int>? selectedBlueBalls,
    this.name,
  })  : selectedRedBalls = selectedRedBalls ?? {},
        selectedBlueBalls = selectedBlueBalls ?? {};

  bool get isValid =>
      selectedRedBalls.isNotEmpty && selectedRedBalls.length >= 6 && selectedBlueBalls.isNotEmpty;

  BetType get betType {
    final redCount = selectedRedBalls.length;
    final blueCount = selectedBlueBalls.length;

    if (redCount == 6 && blueCount == 1) {
      return BetType.single;
    } else if (redCount > 6 && blueCount == 1) {
      return BetType.multipleRed;
    } else if (redCount == 6 && blueCount > 1) {
      return BetType.multipleBlue;
    } else {
      return BetType.fullMultiple;
    }
  }

  int get totalCombinations {
    if (!isValid) return 0;

    final redCount = selectedRedBalls.length;
    final blueCount = selectedBlueBalls.length;

    // Calculate C(n, 6) for red balls
    int redCombinations = _combination(redCount, 6);

    // Total combinations = C(n, 6) × m
    return redCombinations * blueCount;
  }

  double get totalCost => totalCombinations * 2.0;

  String get betTypeDescription {
    switch (betType) {
      case BetType.single:
        return '单式投注';
      case BetType.multipleRed:
        return '红球复式';
      case BetType.multipleBlue:
        return '蓝球复式';
      case BetType.fullMultiple:
        return '全复式';
    }
  }

  // Calculate combination C(n, r) = n! / (r! * (n-r)!)
  int _combination(int n, int r) {
    if (r > n) return 0;
    if (r == 0 || r == n) return 1;

    // Optimize by using smaller r
    if (r > n - r) {
      r = n - r;
    }

    int result = 1;
    for (int i = 0; i < r; i++) {
      result *= (n - i);
      result ~/= (i + 1);
    }
    return result;
  }

  BetSelection copyWith({
    Set<int>? selectedRedBalls,
    Set<int>? selectedBlueBalls,
    String? name,
  }) {
    return BetSelection(
      selectedRedBalls: selectedRedBalls ?? this.selectedRedBalls,
      selectedBlueBalls: selectedBlueBalls ?? this.selectedBlueBalls,
      name: name ?? this.name,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'selectedRedBalls': selectedRedBalls.toList(),
      'selectedBlueBalls': selectedBlueBalls.toList(),
      'name': name,
    };
  }

  factory BetSelection.fromMap(Map<String, dynamic> map) {
    return BetSelection(
      selectedRedBalls: Set<int>.from(map['selectedRedBalls'] ?? []),
      selectedBlueBalls: Set<int>.from(map['selectedBlueBalls'] ?? []),
      name: map['name'],
    );
  }
}
