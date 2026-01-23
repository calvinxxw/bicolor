import 'dart:convert';
import 'database_service.dart';
import '../models/lottery_result.dart';
import '../models/bet_selection.dart';
import '../models/bet_combination.dart';
import '../utils/combination_math.dart';

class BetService {
  final DatabaseService _db = DatabaseService();

  Future<void> savePurchase({
    required String issue,
    required List<int> redBalls,
    required List<int> blueBalls,
    required int totalCost,
  }) async {
    final db = await _db.database;
    await db.insert('purchases', {
      'issue': issue,
      'red_balls': jsonEncode(redBalls),
      'blue_balls': jsonEncode(blueBalls),
      'total_cost': totalCost,
      'winning_status': '待开奖',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPurchaseHistory() async {
    final db = await _db.database;
    final purchases = await db.query('purchases', orderBy: 'created_at DESC');
    
    List<Map<String, dynamic>> results = [];
    for (var p in purchases) {
      var mutableP = Map<String, dynamic>.from(p);
      final drawData = await _db.getLotteryResultByIssue(mutableP['issue']);
      
      if (drawData != null) {
        final drawResult = LotteryResult.fromMap(drawData);
        // If it's still '待开奖', verify it now
        if (mutableP['winning_status'] == '待开奖') {
          final status = _verifyWin(
            purchasedReds: List<int>.from(jsonDecode(mutableP['red_balls'])),
            purchasedBlues: List<int>.from(jsonDecode(mutableP['blue_balls'])),
            drawResult: drawResult,
          );
          await db.update('purchases', {'winning_status': status}, where: 'id = ?', whereArgs: [mutableP['id']]);
          mutableP['winning_status'] = status;
        }
        // Include actual draw info for UI display
        mutableP['draw_reds'] = drawResult.redBalls;
        mutableP['draw_blue'] = drawResult.blueBall;
        mutableP['draw_date'] = drawResult.drawDate;
      }
      results.add(mutableP);
    }
    return results;
  }

  String _verifyWin({
    required List<int> purchasedReds,
    required List<int> purchasedBlues,
    required LotteryResult drawResult,
  }) {
    int redHits = 0;
    for (int r in purchasedReds) {
      if (drawResult.redBalls.contains(r)) redHits++;
    }
    bool blueHit = purchasedBlues.contains(drawResult.blueBall);
    
    if (redHits == 6 && blueHit) return "一等奖!";
    if (redHits == 6) return "二等奖!";
    if (redHits == 5 && blueHit) return "三等奖 (¥3000)";
    if (redHits == 5 || (redHits == 4 && blueHit)) return "四等奖 (¥200)";
    if (redHits == 4 || (redHits == 3 && blueHit)) return "五等奖 (¥10)";
    if (blueHit) return "六等奖 (¥5)";
    return "未中奖";
  }

  Future<void> verifyAllBets() async {
    await getPurchaseHistory(); // This method already triggers verification for all pending
  }

  // --- Calculator Methods ---

  List<BetCombination> generateCombinationsPage(BetSelection selection, int page, int pageSize) {
    final List<List<int>> redCombs = CombinationMath.getCombinations(
      selection.selectedRedBalls.toList()..sort(),
      6,
    );

    int start = page * pageSize;
    int end = (start + pageSize < redCombs.length) ? start + pageSize : redCombs.length;

    if (start >= redCombs.length) return [];

    List<BetCombination> pageCombs = [];
    for (int i = start; i < end; i++) {
      for (int blue in selection.selectedBlueBalls) {
        pageCombs.add(BetCombination(redBalls: redCombs[i], blueBall: blue));
      }
    }
    return pageCombs;
  }

  int getTotalPages(BetSelection selection, int pageSize) {
    int redCombsCount = CombinationMath.countCombinations(selection.selectedRedBalls.length, 6);
    int totalCombs = redCombsCount * selection.selectedBlueBalls.length;
    return (totalCombs / pageSize).ceil();
  }

  String exportToText(BetSelection selection) {
    final buffer = StringBuffer();
    buffer.writeln('双色球投注组合导出');
    buffer.writeln('日期: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('总注数: ${selection.totalCombinations}');
    buffer.writeln('总金额: ¥${selection.totalCost}');
    buffer.writeln('-------------------');

    final redCombs = CombinationMath.getCombinations(
      selection.selectedRedBalls.toList()..sort(),
      6,
    );

    for (var reds in redCombs) {
      for (var blue in selection.selectedBlueBalls) {
        buffer.writeln('${reds.map((n) => n.toString().padLeft(2, '0')).join(' ')} | ${blue.toString().padLeft(2, '0')}');
      }
    }
    return buffer.toString();
  }
}