import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/lottery_result.dart';
import 'database_service.dart';

class DataService {
  final Dio _dio = Dio();
  final DatabaseService _dbService = DatabaseService();

  static const String _cwlUrl =
      'https://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice';

  Future<List<LotteryResult>> fetchFromCwl({
    String? startIssue,
    int pageSize = 100,
  }) async {
    try {
      final response = await _dio.get(
        _cwlUrl,
        queryParameters: {
          'name': 'ssq',
          'pageNo': 1,
          'pageSize': pageSize,
          'systemType': 'PC',
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final List results = data['result'] ?? [];
        return results.map((item) {
          final redStr = item['red'] as String;
          final redBalls = redStr.split(',').map(int.parse).toList();
          return LotteryResult(
            id: 0,
            issue: item['code'] as String,
            drawDate: item['date'] as String,
            redBalls: redBalls,
            blueBall: int.parse(item['blue'] as String),
            createdAt: DateTime.now(),
          );
        }).toList();
      }
    } catch (e) {
      print('Fetch from CWL failed: $e');
    }
    return [];
  }

  Future<void> syncData() async {
    final latestIssue = await _dbService.getLatestIssue();
    final results = await fetchFromCwl();

    for (final result in results) {
      if (latestIssue != null && result.issue.compareTo(latestIssue) <= 0) {
        continue;
      }
      await _dbService.insertResult(result);
    }
  }

  Future<List<LotteryResult>> getRecentResults(int count) async {
    return await _dbService.getRecentResults(count);
  }
}
