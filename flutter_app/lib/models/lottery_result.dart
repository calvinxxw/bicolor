class LotteryResult {
  final int id;
  final String issue;
  final String drawDate;
  final List<int> redBalls;
  final int blueBall;
  final DateTime createdAt;

  LotteryResult({
    required this.id,
    required this.issue,
    required this.drawDate,
    required this.redBalls,
    required this.blueBall,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'issue': issue,
      'draw_date': drawDate,
      'red1': redBalls[0],
      'red2': redBalls[1],
      'red3': redBalls[2],
      'red4': redBalls[3],
      'red5': redBalls[4],
      'red6': redBalls[5],
      'blue': blueBall,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LotteryResult.fromMap(Map<String, dynamic> map) {
    return LotteryResult(
      id: map['id'] as int,
      issue: map['issue'] as String,
      drawDate: map['draw_date'] as String,
      redBalls: [
        map['red1'] as int,
        map['red2'] as int,
        map['red3'] as int,
        map['red4'] as int,
        map['red5'] as int,
        map['red6'] as int,
      ],
      blueBall: map['blue'] as int,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
