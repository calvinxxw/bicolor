import 'dart:convert';

class PurchaseRecord {
  final int? id;
  final String date;
  final String issue;
  final List<int> redBalls;
  final List<int> blueBalls;
  final int totalCost;
  final String winningStatus; // e.g., "Pending", "Won ¥3000", "No Win"

  PurchaseRecord({
    this.id,
    required this.date,
    required this.issue,
    required this.redBalls,
    required this.blueBalls,
    required this.totalCost,
    this.winningStatus = "待开奖",
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'issue': issue,
      'redBalls': jsonEncode(redBalls),
      'blueBalls': jsonEncode(blueBalls),
      'totalCost': totalCost,
      'winningStatus': winningStatus,
    };
  }

  factory PurchaseRecord.fromMap(Map<String, dynamic> map) {
    return PurchaseRecord(
      id: map['id'],
      date: map['date'],
      issue: map['issue'],
      redBalls: List<int>.from(jsonDecode(map['redBalls'])),
      blueBalls: List<int>.from(jsonDecode(map['blueBalls'])),
      totalCost: map['totalCost'],
      winningStatus: map['winningStatus'],
    );
  }
}