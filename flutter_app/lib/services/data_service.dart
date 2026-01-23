import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/lottery_result.dart';
import 'database_service.dart';
import 'onnx_personalization_service.dart';

class DataService {
  final Dio _dio = Dio();
  final DatabaseService _dbService = DatabaseService();
  final OnDeviceTrainingService _trainingService = OnDeviceTrainingService();

  static const String _cwlUrl =
      'http://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice';

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
        options: Options(
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Referer': 'http://www.cwl.gov.cn/',
            'Accept': 'application/json, text/javascript, */*; q=0.01',
            'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
          },
        ),
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
      debugPrint('Fetch from CWL failed: $e');
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
      final inserted = await _dbService.insertResult(result);
      if (inserted > 0) {
        await _trainingService.trainOnNewResult(result.redBalls, result.blueBall);
      }
    }
  }

  Future<LotteryResult?> getLatestResult() async {
    final results = await _dbService.getRecentResults(1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<LotteryResult>> getRecentResults(int count) async {
    return await _dbService.getRecentResults(count);
  }

  Future<void> insertSampleData() async {
    await _dbService.insertSampleData();
  }
}
