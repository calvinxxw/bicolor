# 双色球彩票预测 AI 软件设计文档

> 创建日期：2026-01-14

## 1. 项目概述

开发一款跨平台（Windows、iOS、Android）的双色球彩票预测 AI 软件，自动获取 2024 年至今的开奖数据，使用 TensorFlow Lite 进行本地 ML 推理，输出单注和复式预测结果。

## 2. 技术选型

| 组件 | 技术方案 |
|------|----------|
| 跨平台框架 | Flutter |
| ML 框架 | TensorFlow / TensorFlow Lite |
| 本地存储 | SQLite |
| 数据获取 | HTTP 爬取（dio + html 解析） |
| 模型训练 | Python + TensorFlow (离线) |

## 3. 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter 跨平台应用                        │
│              (Windows / iOS / Android)                       │
├─────────────────────────────────────────────────────────────┤
│  UI 层                                                       │
│  ├── 首页：最新开奖 + 快速预测                               │
│  ├── 预测页：单注/复式结果展示                               │
│  ├── 历史页：开奖记录查询                                    │
│  └── 分析页：号码频率/走势图                                 │
├─────────────────────────────────────────────────────────────┤
│  业务逻辑层 (Dart)                                           │
│  ├── DataService：数据爬取与本地存储                         │
│  ├── PredictionService：调用 TF Lite 模型推理                │
│  └── AnalysisService：统计分析计算                           │
├─────────────────────────────────────────────────────────────┤
│  数据层                                                      │
│  ├── SQLite：本地存储开奖历史                                │
│  ├── TF Lite Model：预训练 LSTM 模型文件 (.tflite)           │
│  └── SharedPreferences：用户设置                             │
└─────────────────────────────────────────────────────────────┘
```

## 4. 数据获取与存储

### 4.1 数据源（按优先级）

1. 中国福彩网 (www.cwl.gov.cn) - 官方数据源
2. 500彩票网 (www.500.com) - 备用数据源
3. 新浪彩票 (lottery.sina.com.cn) - 第二备用

### 4.2 爬取流程

```
HTTP 请求 (dio) -> HTML 解析 (html库) -> 数据验证 -> SQLite 存储
```

### 4.3 数据表结构

```sql
CREATE TABLE lottery_results (
  id INTEGER PRIMARY KEY,
  issue TEXT UNIQUE,        -- 期号：2024001
  draw_date TEXT,           -- 开奖日期：2024-01-02
  red1 INTEGER, red2 INTEGER, red3 INTEGER,
  red4 INTEGER, red5 INTEGER, red6 INTEGER,
  blue INTEGER,
  created_at TEXT
);
```

### 4.4 更新机制

- 启动时检查本地最新期号，增量拉取缺失数据
- 开奖日（周二、四、日）21:30 后自动检查更新
- 失败时自动切换备用数据源

## 5. ML 模型设计

### 5.1 模型架构（LSTM）

**红球模型：**
- 输入：最近 5 期红球数据 (shape: 5x6)
- LSTM 层：64 units + Dropout(0.2)
- 输出：Dense(33) + Softmax，输出 1-33 号各自概率

**蓝球模型：**
- 输入：最近 5 期蓝球数据 (shape: 5x1)
- LSTM 层：32 units + Dropout(0.2)
- 输出：Dense(16) + Softmax，输出 1-16 号各自概率

### 5.2 训练策略

- 损失函数：Categorical Crossentropy
- 优化器：Adam (lr=0.001)
- 训练数据：2003-2023 年历史数据
- 验证数据：2024 年数据用于回测

### 5.3 置信度计算

```
置信度 = softmax 输出概率 × 100%
```

### 5.4 模型文件

- `red_ball_model.tflite` (~500KB)
- `blue_ball_model.tflite` (~200KB)

## 6. 预测结果展示

### 6.1 单注推荐

显示置信度最高的 6 个红球 + 1 个蓝球，附带各号码置信度百分比。

### 6.2 复式推荐

根据置信度排序，输出 8-12 个红球候选 + 2-3 个蓝球候选，显示投注金额计算。

### 6.3 附加功能

- 号码走势图：显示近 30 期各号码出现频率
- 冷热号分析：标记近期高频/低频号码
- 历史命中回测：显示模型在历史数据上的命中率

## 7. 项目结构

```
lottery/
├── flutter_app/                    # Flutter 跨平台应用
│   ├── lib/
│   │   ├── main.dart
│   │   ├── models/
│   │   │   └── lottery_result.dart
│   │   ├── services/
│   │   │   ├── data_service.dart
│   │   │   ├── prediction_service.dart
│   │   │   └── analysis_service.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── prediction_screen.dart
│   │   │   ├── history_screen.dart
│   │   │   └── analysis_screen.dart
│   │   └── widgets/
│   │       ├── ball_widget.dart
│   │       └── chart_widget.dart
│   ├── assets/
│   │   └── models/
│   │       ├── red_ball_model.tflite
│   │       └── blue_ball_model.tflite
│   └── pubspec.yaml
│
├── ml_training/                    # Python 模型训练
│   ├── train_model.py
│   ├── export_tflite.py
│   ├── data_crawler.py
│   └── requirements.txt
│
└── docs/
    └── plans/
        └── 2026-01-14-lottery-design.md
```

## 8. 实现步骤

| 阶段 | 任务 |
|------|------|
| 1 | 搭建 Flutter 项目框架，配置 Windows/iOS/Android 多平台支持 |
| 2 | 实现数据爬取模块（dio + html），完成 SQLite 存储 |
| 3 | Python 端训练 LSTM 模型，导出 TFLite 格式 |
| 4 | Flutter 集成 TF Lite 插件，实现推理服务 |
| 5 | 开发 UI 界面（首页、预测、历史、分析四个页面） |
| 6 | 测试与优化，打包发布三个平台 |

## 9. 风险提示

> ⚠️ 彩票开奖为随机事件，本软件仅供娱乐和学习用途，不构成任何投注建议。请理性购彩。

## 10. 依赖清单

### Flutter (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  dio: ^5.0.0
  html: ^0.15.0
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  tflite_flutter: ^0.10.0
  fl_chart: ^0.65.0
  provider: ^6.1.0
```

### Python (requirements.txt)

```
tensorflow>=2.15.0
pandas>=2.0.0
numpy>=1.24.0
requests>=2.31.0
beautifulsoup4>=4.12.0
scikit-learn>=1.3.0
```
