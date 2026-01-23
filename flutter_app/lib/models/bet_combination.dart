class BetCombination {
  final List<int> redBalls; // 6 red balls
  final int blueBall; // 1 blue ball

  BetCombination({
    required this.redBalls,
    required this.blueBall,
  }) : assert(redBalls.length == 6, 'Must have exactly 6 red balls');

  double get cost => 2.0;

  @override
  String toString() {
    final redStr = redBalls.map((n) => n.toString().padLeft(2, '0')).join(' ');
    final blueStr = blueBall.toString().padLeft(2, '0');
    return '$redStr + $blueStr';
  }

  Map<String, dynamic> toMap() {
    return {
      'redBalls': redBalls,
      'blueBall': blueBall,
    };
  }

  factory BetCombination.fromMap(Map<String, dynamic> map) {
    return BetCombination(
      redBalls: List<int>.from(map['redBalls']),
      blueBall: map['blueBall'],
    );
  }
}
