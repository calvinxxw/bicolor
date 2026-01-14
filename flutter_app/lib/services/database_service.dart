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
}
