import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class OnDeviceTrainingService {
  Database? _db;

  Future<void> init() async {
    _db = await openDatabase(
      join(await getDatabasesPath(), 'personalization.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE weights(type TEXT PRIMARY KEY, values TEXT)',
        );
      },
      version: 1,
    );
  }

  Future<List<double>> _getWeights(String type, int length) async {
    if (_db == null) await init();
    final List<Map<String, dynamic>> maps = await _db!.query(
      'weights',
      where: 'type = ?',
      whereArgs: [type],
    );

    if (maps.isEmpty) {
      return List.filled(length, 0.0);
    }

    try {
      final List<dynamic> decoded = jsonDecode(maps[0]['values'] as String);
      return decoded.map((e) => (e as num).toDouble()).toList();
    } catch (e) {
      return List.filled(length, 0.0);
    }
  }

  Future<void> _saveWeights(String type, List<double> weights) async {
    if (_db == null) await init();
    await _db!.insert(
      'weights',
      {'type': type, 'values': jsonEncode(weights)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Fine-tunes the output probabilities using a local frequency bias.
  /// This simulates a "Personalized Training API" by learning from recent device-synced data.
  Future<List<double>> applyPersonalization(String type, List<double> originalProbs) async {
    final weights = await _getWeights(type, originalProbs.length);
    return List.generate(originalProbs.length, (i) {
      return (originalProbs[i] + weights[i]).clamp(0.0, 1.0);
    });
  }

  /// Incremental "Training" step: Update local bias based on a new actual result.
  Future<void> trainOnNewResult(List<int> redBalls, int blueBall) async {
    // For simplicity, we just slightly boost the numbers that appeared recently.
    // This allows the model to "personalize" to local/recent trends.
    const double learningRate = 0.005;

    // Update Red Weights
    List<double> redWeights = await _getWeights('red', 33);
    for (int i = 1; i <= 33; i++) {
      if (redBalls.contains(i)) {
        redWeights[i - 1] += learningRate;
      } else {
        redWeights[i - 1] -= (learningRate / 10.0); // Slow decay
      }
      redWeights[i - 1] = redWeights[i - 1].clamp(-0.2, 0.2);
    }
    await _saveWeights('red', redWeights);

    // Update Blue Weights
    List<double> blueWeights = await _getWeights('blue', 16);
    for (int i = 1; i <= 16; i++) {
      if (i == blueBall) {
        blueWeights[i - 1] += learningRate;
      } else {
        blueWeights[i - 1] -= (learningRate / 10.0); // Slow decay
      }
      blueWeights[i - 1] = blueWeights[i - 1].clamp(-0.2, 0.2);
    }
    await _saveWeights('blue', blueWeights);
  }
}