# 双色球预测 AI 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 构建跨平台（Windows/iOS/Android）双色球彩票预测应用

**Architecture:** Flutter 单代码库覆盖三平台，TensorFlow Lite 本地推理，SQLite 存储历史数据，HTTP 爬取开奖数据

**Tech Stack:** Flutter, Dart, TensorFlow, TensorFlow Lite, Python, SQLite, dio, html

---

## Phase 1: 项目初始化

### Task 1.1: 创建 Flutter 项目

**Files:**
- Create: `flutter_app/` (Flutter 项目目录)

**Step 1: 创建 Flutter 项目**

```bash
cd D:\lottery
flutter create --org com.lottery --project-name lottery_predictor flutter_app
```

**Step 2: 验证项目创建成功**

```bash
cd D:\lottery\flutter_app
flutter doctor
```
Expected: Flutter 环境正常

**Step 3: Commit**

```bash
git init
git add .
git commit -m "init: create flutter project"
```

---

### Task 1.2: 配置多平台支持

**Files:**
- Modify: `flutter_app/pubspec.yaml`

**Step 1: 添加依赖**

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.4.0
  html: ^0.15.4
  sqflite: ^2.3.2
  path_provider: ^2.1.2
  tflite_flutter: ^0.10.4
  fl_chart: ^0.66.2
  provider: ^6.1.1
  intl: ^0.19.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1
```

**Step 2: 安装依赖**

```bash
cd D:\lottery\flutter_app
flutter pub get
```
Expected: 依赖安装成功

**Step 3: Commit**

```bash
git add pubspec.yaml pubspec.lock
git commit -m "deps: add core dependencies"
```

---

### Task 1.3: 创建 Python 训练环境

**Files:**
- Create: `ml_training/requirements.txt`
- Create: `ml_training/` 目录

**Step 1: 创建目录和依赖文件**

```bash
mkdir D:\lottery\ml_training
```

**Step 2: 创建 requirements.txt**

```
tensorflow>=2.15.0
pandas>=2.0.0
numpy>=1.24.0
requests>=2.31.0
beautifulsoup4>=4.12.0
scikit-learn>=1.3.0
```

**Step 3: 创建虚拟环境并安装**

```bash
cd D:\lottery\ml_training
python -m venv venv
venv\Scripts\activate
pip install -r requirements.txt
```

**Step 4: Commit**

```bash
git add ml_training/requirements.txt
git commit -m "init: add python ml training environment"
```

---

## Phase 2: 数据层实现

### Task 2.1: 创建数据模型

**Files:**
- Create: `flutter_app/lib/models/lottery_result.dart`

**Step 1: 创建模型类**

```dart
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
```

**Step 2: Commit**

```bash
git add flutter_app/lib/models/
git commit -m "feat: add lottery result model"
```

---

### Task 2.2: 实现数据库服务

**Files:**
- Create: `flutter_app/lib/services/database_service.dart`

**Step 1: 创建数据库服务**

```dart
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
```

**Step 2: Commit**

```bash
git add flutter_app/lib/services/database_service.dart
git commit -m "feat: add database service for lottery results"
```

---

### Task 2.3: 实现数据爬取服务

**Files:**
- Create: `flutter_app/lib/services/data_service.dart`

**Step 1: 创建爬取服务**

```dart
import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/lottery_result.dart';
import 'database_service.dart';

class DataService {
  final Dio _dio = Dio();
  final DatabaseService _dbService = DatabaseService();

  // 中国福彩网数据接口
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
```

**Step 2: Commit**

```bash
git add flutter_app/lib/services/data_service.dart
git commit -m "feat: add data crawling service"
```

---

## Phase 3: ML 模型训练

### Task 3.1: 实现数据爬取脚本 (Python)

**Files:**
- Create: `ml_training/data_crawler.py`

**Step 1: 创建爬取脚本**

```python
import requests
import pandas as pd
from datetime import datetime

def fetch_ssq_data(page_size=500):
    url = 'https://www.cwl.gov.cn/cwl_admin/front/cwlkj/search/kjxx/findDrawNotice'
    params = {
        'name': 'ssq',
        'pageNo': 1,
        'pageSize': page_size,
        'systemType': 'PC'
    }

    response = requests.get(url, params=params)
    data = response.json()

    results = []
    for item in data.get('result', []):
        red_balls = [int(x) for x in item['red'].split(',')]
        results.append({
            'issue': item['code'],
            'date': item['date'],
            'red1': red_balls[0],
            'red2': red_balls[1],
            'red3': red_balls[2],
            'red4': red_balls[3],
            'red5': red_balls[4],
            'red6': red_balls[5],
            'blue': int(item['blue'])
        })

    return pd.DataFrame(results)

if __name__ == '__main__':
    df = fetch_ssq_data()
    df.to_csv('ssq_data.csv', index=False)
    print(f'Saved {len(df)} records to ssq_data.csv')
```

**Step 2: 运行爬取**

```bash
cd D:\lottery\ml_training
python data_crawler.py
```
Expected: 生成 ssq_data.csv

**Step 3: Commit**

```bash
git add ml_training/data_crawler.py
git commit -m "feat: add python data crawler"
```

---

### Task 3.2: 实现模型训练脚本

**Files:**
- Create: `ml_training/train_model.py`

**Step 1: 创建训练脚本**

```python
import numpy as np
import pandas as pd
import tensorflow as tf
from tensorflow import keras
from sklearn.preprocessing import MinMaxScaler

def load_data(csv_path):
    df = pd.read_csv(csv_path)
    df = df.sort_values('issue').reset_index(drop=True)
    return df

def prepare_red_data(df, seq_len=5):
    red_cols = ['red1', 'red2', 'red3', 'red4', 'red5', 'red6']
    red_data = df[red_cols].values

    X, y = [], []
    for i in range(len(red_data) - seq_len):
        X.append(red_data[i:i+seq_len])
        # One-hot encode target (33 classes per ball)
        target = np.zeros((6, 33))
        for j, val in enumerate(red_data[i+seq_len]):
            target[j, val-1] = 1
        y.append(target.flatten())

    return np.array(X), np.array(y)

def prepare_blue_data(df, seq_len=5):
    blue_data = df['blue'].values.reshape(-1, 1)

    X, y = [], []
    for i in range(len(blue_data) - seq_len):
        X.append(blue_data[i:i+seq_len])
        target = np.zeros(16)
        target[blue_data[i+seq_len][0]-1] = 1
        y.append(target)

    return np.array(X), np.array(y)

def build_red_model(seq_len=5):
    model = keras.Sequential([
        keras.layers.LSTM(64, input_shape=(seq_len, 6), return_sequences=True),
        keras.layers.Dropout(0.2),
        keras.layers.LSTM(32),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(128, activation='relu'),
        keras.layers.Dense(6 * 33, activation='softmax')
    ])
    model.compile(optimizer='adam', loss='categorical_crossentropy')
    return model

def build_blue_model(seq_len=5):
    model = keras.Sequential([
        keras.layers.LSTM(32, input_shape=(seq_len, 1)),
        keras.layers.Dropout(0.2),
        keras.layers.Dense(32, activation='relu'),
        keras.layers.Dense(16, activation='softmax')
    ])
    model.compile(optimizer='adam', loss='categorical_crossentropy')
    return model

def train_and_save():
    df = load_data('ssq_data.csv')

    # Train red ball model
    X_red, y_red = prepare_red_data(df)
    red_model = build_red_model()
    red_model.fit(X_red, y_red, epochs=50, batch_size=32, validation_split=0.1)
    red_model.save('red_ball_model.keras')

    # Train blue ball model
    X_blue, y_blue = prepare_blue_data(df)
    blue_model = build_blue_model()
    blue_model.fit(X_blue, y_blue, epochs=50, batch_size=32, validation_split=0.1)
    blue_model.save('blue_ball_model.keras')

    print('Models saved!')

if __name__ == '__main__':
    train_and_save()
```

**Step 2: 运行训练**

```bash
cd D:\lottery\ml_training
python train_model.py
```
Expected: 生成 red_ball_model.keras 和 blue_ball_model.keras

**Step 3: Commit**

```bash
git add ml_training/train_model.py
git commit -m "feat: add model training script"
```

---

### Task 3.3: 导出 TFLite 模型

**Files:**
- Create: `ml_training/export_tflite.py`

**Step 1: 创建导出脚本**

```python
import tensorflow as tf

def convert_to_tflite(keras_path, tflite_path):
    model = tf.keras.models.load_model(keras_path)
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    tflite_model = converter.convert()

    with open(tflite_path, 'wb') as f:
        f.write(tflite_model)
    print(f'Saved {tflite_path}')

if __name__ == '__main__':
    convert_to_tflite('red_ball_model.keras', 'red_ball_model.tflite')
    convert_to_tflite('blue_ball_model.keras', 'blue_ball_model.tflite')
```

**Step 2: 运行导出**

```bash
cd D:\lottery\ml_training
python export_tflite.py
```

**Step 3: 复制到 Flutter assets**

```bash
mkdir -p D:\lottery\flutter_app\assets\models
cp red_ball_model.tflite D:\lottery\flutter_app\assets\models\
cp blue_ball_model.tflite D:\lottery\flutter_app\assets\models\
```

**Step 4: 更新 pubspec.yaml 添加 assets**

在 flutter_app/pubspec.yaml 中添加:
```yaml
flutter:
  assets:
    - assets/models/
```

**Step 5: Commit**

```bash
git add ml_training/export_tflite.py flutter_app/assets/ flutter_app/pubspec.yaml
git commit -m "feat: add tflite export and model assets"
```

---

## Phase 4: 预测服务实现

### Task 4.1: 实现 TFLite 预测服务

**Files:**
- Create: `flutter_app/lib/services/prediction_service.dart`

**Step 1: 创建预测服务**

```dart
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/lottery_result.dart';

class PredictionResult {
  final List<MapEntry<int, double>> redBalls;
  final List<MapEntry<int, double>> blueBalls;

  PredictionResult({required this.redBalls, required this.blueBalls});
}

class PredictionService {
  Interpreter? _redInterpreter;
  Interpreter? _blueInterpreter;

  Future<void> loadModels() async {
    _redInterpreter = await Interpreter.fromAsset('assets/models/red_ball_model.tflite');
    _blueInterpreter = await Interpreter.fromAsset('assets/models/blue_ball_model.tflite');
  }

  PredictionResult predict(List<LotteryResult> recentResults) {
    if (_redInterpreter == null || _blueInterpreter == null) {
      throw Exception('Models not loaded');
    }

    // Prepare red ball input (5 x 6)
    final redInput = List.generate(5, (i) {
      if (i < recentResults.length) {
        return recentResults[recentResults.length - 5 + i].redBalls.map((e) => e.toDouble()).toList();
      }
      return List.filled(6, 0.0);
    });

    // Prepare blue ball input (5 x 1)
    final blueInput = List.generate(5, (i) {
      if (i < recentResults.length) {
        return [recentResults[recentResults.length - 5 + i].blueBall.toDouble()];
      }
      return [0.0];
    });

    // Run red prediction
    final redOutput = List.filled(6 * 33, 0.0).reshape([1, 198]);
    _redInterpreter!.run([redInput], redOutput);

    // Run blue prediction
    final blueOutput = List.filled(16, 0.0).reshape([1, 16]);
    _blueInterpreter!.run([blueInput], blueOutput);

    // Parse red ball probabilities
    final redProbs = <MapEntry<int, double>>[];
    for (int ball = 1; ball <= 33; ball++) {
      double maxProb = 0;
      for (int pos = 0; pos < 6; pos++) {
        final prob = redOutput[0][pos * 33 + ball - 1];
        if (prob > maxProb) maxProb = prob;
      }
      redProbs.add(MapEntry(ball, maxProb));
    }
    redProbs.sort((a, b) => b.value.compareTo(a.value));

    // Parse blue ball probabilities
    final blueProbs = <MapEntry<int, double>>[];
    for (int ball = 1; ball <= 16; ball++) {
      blueProbs.add(MapEntry(ball, blueOutput[0][ball - 1]));
    }
    blueProbs.sort((a, b) => b.value.compareTo(a.value));

    return PredictionResult(redBalls: redProbs, blueBalls: blueProbs);
  }

  void dispose() {
    _redInterpreter?.close();
    _blueInterpreter?.close();
  }
}
```

**Step 2: Commit**

```bash
git add flutter_app/lib/services/prediction_service.dart
git commit -m "feat: add tflite prediction service"
```

---

## Phase 5: UI 实现

### Task 5.1: 创建球号组件

**Files:**
- Create: `flutter_app/lib/widgets/ball_widget.dart`

**Step 1: 创建组件**

```dart
import 'package:flutter/material.dart';

class BallWidget extends StatelessWidget {
  final int number;
  final bool isRed;
  final double? confidence;
  final double size;

  const BallWidget({
    super.key,
    required this.number,
    required this.isRed,
    this.confidence,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRed ? Colors.red : Colors.blue,
            boxShadow: [
              BoxShadow(
                color: (isRed ? Colors.red : Colors.blue).withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              number.toString().padLeft(2, '0'),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: size * 0.4,
              ),
            ),
          ),
        ),
        if (confidence != null) ...[
          const SizedBox(height: 4),
          Text(
            '${(confidence! * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }
}
```

**Step 2: Commit**

```bash
git add flutter_app/lib/widgets/ball_widget.dart
git commit -m "feat: add ball widget component"
```

---

### Task 5.2: 创建首页

**Files:**
- Create: `flutter_app/lib/screens/home_screen.dart`

**Step 1: 创建首页**

```dart
import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../services/prediction_service.dart';
import '../models/lottery_result.dart';
import '../widgets/ball_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  final PredictionService _predictionService = PredictionService();

  List<LotteryResult> _recentResults = [];
  PredictionResult? _prediction;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _predictionService.loadModels();
    await _dataService.syncData();
    _recentResults = await _dataService.getRecentResults(10);

    if (_recentResults.length >= 5) {
      _prediction = _predictionService.predict(_recentResults);
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('双色球预测')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLatestResult(),
            const SizedBox(height: 24),
            _buildPrediction(),
          ],
        ),
      ),
    );
  }

  Widget _buildLatestResult() {
    if (_recentResults.isEmpty) return const SizedBox();
    final latest = _recentResults.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('最新开奖 第${latest.issue}期', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(latest.drawDate, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            Row(
              children: [
                ...latest.redBalls.map((n) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: BallWidget(number: n, isRed: true),
                )),
                BallWidget(number: latest.blueBall, isRed: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrediction() {
    if (_prediction == null) return const SizedBox();

    final topRed = _prediction!.redBalls.take(6).toList();
    final topBlue = _prediction!.blueBalls.first;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('单注推荐', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                ...topRed.map((e) => BallWidget(
                  number: e.key,
                  isRed: true,
                  confidence: e.value,
                )),
                BallWidget(
                  number: topBlue.key,
                  isRed: false,
                  confidence: topBlue.value,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _predictionService.dispose();
    super.dispose();
  }
}
```

**Step 2: Commit**

```bash
git add flutter_app/lib/screens/home_screen.dart
git commit -m "feat: add home screen with prediction display"
```

---

### Task 5.3: 更新 main.dart

**Files:**
- Modify: `flutter_app/lib/main.dart`

**Step 1: 更新入口文件**

```dart
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const LotteryApp());
}

class LotteryApp extends StatelessWidget {
  const LotteryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '双色球预测',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

**Step 2: Commit**

```bash
git add flutter_app/lib/main.dart
git commit -m "feat: update main.dart with app entry"
```

---

## Phase 6: 测试与发布

### Task 6.1: 运行测试

**Step 1: 运行 Flutter 测试**

```bash
cd D:\lottery\flutter_app
flutter test
```

**Step 2: 运行应用**

```bash
flutter run -d windows
```

---

### Task 6.2: 构建发布版本

**Step 1: 构建 Windows**

```bash
flutter build windows --release
```

**Step 2: 构建 Android**

```bash
flutter build apk --release
```

**Step 3: 构建 iOS (需要 macOS)**

```bash
flutter build ios --release
```

---

## 风险提示

应用中必须显示以下免责声明：

> ⚠️ 彩票开奖为随机事件，本软件仅供娱乐和学习用途，不构成任何投注建议。请理性购彩。
