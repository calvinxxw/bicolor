import 'package:dio/dio.dart';
import 'package:xml/xml.dart';
import 'package:flutter/foundation.dart';
import '../models/lottery_result.dart';
import 'database_service.dart';
import 'bet_service.dart';

class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  final Dio _dio = Dio();
  final DatabaseService _dbService = DatabaseService();
  final BetService _betService = BetService();

  static const String _xmlUrl = 'https://kaijiang.500.com/static/info/kaijiang/xml/ssq/list.xml';

  // Heavy XML parsing offloaded to a background thread
  static List<LotteryResult> _parseXmlInBackground(String xmlData) {
    try {
      final document = XmlDocument.parse(xmlData);
      final rows = document.findAllElements('row').take(100);
      List<LotteryResult> results = [];

      for (var row in rows) {
        final expect = row.getAttribute('expect') ?? '';
        final opencode = row.getAttribute('opencode') ?? '';
        final opentime = row.getAttribute('opentime') ?? '';

        if (expect.isEmpty || opencode.isEmpty) continue;

        final parts = opencode.split('|');
        if (parts.length < 2) continue;

        final reds = parts[0].split(',').map(int.parse).toList();
        final blue = int.parse(parts[1]);

        results.add(LotteryResult(
          id: 0,
          issue: expect,
          drawDate: opentime,
          redBalls: reds,
          blueBall: blue,
          createdAt: DateTime.now(),
        ));
      }
      return results;
    } catch (e) {
      print('DataService Worker: Parse error: $e');
      return [];
    }
  }

  Future<List<LotteryResult>> fetchLatestResults() async {
    try {
      print("DataService: Fetching XML Feed...");
      _dio.options.connectTimeout = const Duration(seconds: 15);
      _dio.options.receiveTimeout = const Duration(seconds: 15);
      
      final response = await _dio.get(_xmlUrl);

      if (response.statusCode == 200 && response.data != null) {
        // Use compute to run parsing in another isolate
        return await compute(_parseXmlInBackground, response.data.toString());
      }
    } catch (e) {
      print('DataService: XML fetch failed: $e');
    }
    return [];
  }

  Future<String?> getLatestIssue() async {
    return await _dbService.getLatestIssue();
  }

  Future<int> syncData() async {
    try {
      print("DataService: Syncing High-Precision Data...");
      final results = await fetchLatestResults();
      if (results.isEmpty) return 0;

      int insertedCount = 0;
      for (var res in results) {
        final insertedId = await _dbService.insertResult(res);
        if (insertedId > 0) insertedCount++;
      }

      if (insertedCount > 0) {
        await _betService.verifyAllBets();
      }

      return insertedCount;
    } catch (e) {
      print("DataService: Sync Error: $e");
      return 0;
    }
  }

  Future<List<LotteryResult>> getRecentResults(int count) async {
    return await _dbService.getRecentResults(count);
  }
}