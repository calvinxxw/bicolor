import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/lottery_result.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'lottery.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE lottery_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            issue TEXT UNIQUE,
            draw_date TEXT,
            red1 INTEGER,
            red2 INTEGER,
            red3 INTEGER,
            red4 INTEGER,
            red5 INTEGER,
            red6 INTEGER,
            blue INTEGER,
            created_at TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertResult(LotteryResult result) async {
    final db = await database;
    return await db.insert(
      'lottery_results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<LotteryResult>> getAllResults() async {
    final db = await database;
    final maps = await db.query('lottery_results', orderBy: 'issue DESC');
    return maps.map((map) => LotteryResult.fromMap(map)).toList();
  }

  Future<List<LotteryResult>> getRecentResults(int count) async {
    final db = await database;
    final maps = await db.query(
      'lottery_results',
      orderBy: 'issue DESC',
      limit: count,
    );
    return maps.map((map) => LotteryResult.fromMap(map)).toList();
  }

  Future<String?> getLatestIssue() async {
    final db = await database;
    final maps = await db.query(
      'lottery_results',
      orderBy: 'issue DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return maps.first['issue'] as String;
  }

  Future<void> insertSampleData() async {
    final db = await database;

    // Check if data already exists
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM lottery_results')
    );

    if (count != null && count > 0) {
      return; // Data already exists
    }

    // Insert 10 sample lottery results
    final sampleData = [
      LotteryResult(
        id: 0,
        issue: '2026010',
        drawDate: '2026-01-20',
        redBalls: [3, 7, 12, 18, 25, 31],
        blueBall: 8,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026009',
        drawDate: '2026-01-18',
        redBalls: [5, 9, 15, 22, 28, 33],
        blueBall: 12,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026008',
        drawDate: '2026-01-16',
        redBalls: [2, 8, 14, 19, 26, 30],
        blueBall: 5,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026007',
        drawDate: '2026-01-14',
        redBalls: [4, 11, 16, 23, 27, 32],
        blueBall: 10,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026006',
        drawDate: '2026-01-11',
        redBalls: [1, 6, 13, 20, 24, 29],
        blueBall: 3,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026005',
        drawDate: '2026-01-09',
        redBalls: [7, 10, 17, 21, 28, 33],
        blueBall: 15,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026004',
        drawDate: '2026-01-07',
        redBalls: [2, 9, 14, 18, 25, 31],
        blueBall: 6,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026003',
        drawDate: '2026-01-04',
        redBalls: [5, 11, 16, 22, 27, 32],
        blueBall: 11,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026002',
        drawDate: '2026-01-02',
        redBalls: [3, 8, 15, 19, 26, 30],
        blueBall: 9,
        createdAt: DateTime.now(),
      ),
      LotteryResult(
        id: 0,
        issue: '2026001',
        drawDate: '2025-12-31',
        redBalls: [1, 7, 12, 20, 24, 29],
        blueBall: 14,
        createdAt: DateTime.now(),
      ),
    ];

    for (final result in sampleData) {
      await insertResult(result);
    }
  }
}
