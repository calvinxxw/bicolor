import 'package:flutter/services.dart';
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
      version: 2, // Incremented version to trigger update
      onCreate: (db, version) async {
        await _createTables(db);
        await _importLocalHistory(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add purchases table if upgrading from version 1
          await db.execute('''
            CREATE TABLE IF NOT EXISTS purchases (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              issue TEXT,
              red_balls TEXT,
              blue_balls TEXT,
              total_cost INTEGER,
              winning_status TEXT DEFAULT '待开奖',
              created_at TEXT
            )
          ''');
        }
      },
      onOpen: (db) async {
        final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM lottery_results'));
        print("DatabaseService: onOpen count = $count");
        if (count == null || count < 50) {
          await _importLocalHistory(db);
        }
      },
    );
  }

  Future<void> _createTables(Database db) async {
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
    await db.execute('''
      CREATE TABLE purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        issue TEXT,
        red_balls TEXT,
        blue_balls TEXT,
        total_cost INTEGER,
        winning_status TEXT DEFAULT '待开奖',
        created_at TEXT
      )
    ''');
  }

  Future<Map<String, dynamic>?> getLotteryResultByIssue(String issue) async {
    final db = await database;
    final results = await db.query(
      'lottery_results',
      where: 'issue = ?',
      whereArgs: [issue],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> _importLocalHistory(Database db) async {
    try {
      print("DatabaseService: Starting local history import...");
      final String csvData = await rootBundle.loadString('assets/data/history.csv');
      List<String> lines = csvData.split('\n');
      
      // The CSV has headers: issue,date,red1,red2,red3,red4,red5,red6,blue
      Batch batch = db.batch();
      int count = 0;
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final cols = line.split(',');
        if (cols.length < 9) continue;
        
        try {
          batch.insert('lottery_results', {
            'issue': cols[0].trim(),
            'draw_date': cols[1].trim(),
            'red1': int.parse(cols[2]),
            'red2': int.parse(cols[3]),
            'red3': int.parse(cols[4]),
            'red4': int.parse(cols[5]),
            'red5': int.parse(cols[6]),
            'red6': int.parse(cols[7]),
            'blue': int.parse(cols[8]),
            'created_at': DateTime.now().toIso8601String(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
          count++;
        } catch (e) {
          // Skip errors
        }
      }
      await batch.commit(noResult: true);
      print("DatabaseService: Successfully imported $count draws from local assets.");
    } catch (e) {
      print("DatabaseService: Local import CRITICAL failure: $e");
    }
  }

  Future<int> insertResult(LotteryResult result) async {
    final db = await database;
    final map = result.toMap();
    map.remove('id'); // Allow SQLite to auto-generate ID
    return await db.insert(
      'lottery_results',
      map,
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

  Future<int> insertPurchase(String issue, List<int> reds, List<int> blues, int cost) async {
    final db = await database;
    return await db.insert('purchases', {
      'issue': issue,
      'red_balls': reds.join(','),
      'blue_balls': blues.join(','),
      'total_cost': cost,
      'winning_status': '待开奖',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPurchases() async {
    final db = await database;
    return await db.query('purchases', orderBy: 'created_at DESC');
  }

  Future<void> updatePurchaseStatus(int id, String status) async {
    final db = await database;
    await db.update('purchases', {
      'winning_status': status,
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePurchase(int id) async {
    final db = await database;
    await db.delete('purchases', where: 'id = ?', whereArgs: [id]);
  }
}