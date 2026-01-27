import 'package:flutter/material.dart';
import '../models/lottery_result.dart';
import '../models/prediction_result.dart';
import '../services/data_service.dart';
import '../services/prediction_service.dart';
import '../widgets/latest_draw_widget.dart';
import '../widgets/draw_countdown_widget.dart';
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
  bool _isLoading = false;
  bool _isPredicting = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadRecentResults();
    // Always attempt sync on startup, but silently if there's already data
    await _syncData(silent: _recentResults.isNotEmpty);
  }

  Future<void> _loadRecentResults() async {
    final results = await _dataService.getRecentResults(5);
    if (mounted) {
      setState(() {
        _recentResults = results;
      });
    }
  }

  Future<void> _runPrediction() async {
    setState(() { _isPredicting = true; });
    try {
      final result = await _predictionService.predict();
      setState(() { _prediction = result; });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI预测失败: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() { _isPredicting = false; });
    }
  }

  Future<void> _syncData({bool silent = false}) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final count = await _dataService.syncData();
      await _loadRecentResults();
      setState(() {
        _lastSyncTime = DateTime.now();
      });

      if (mounted && (!silent || count > 0)) {
        String msg = count > 0 ? '成功同步 $count 条新数据' : '已经是最新数据';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: count > 0 ? Colors.green : Colors.blueGrey,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('同步失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPredictionSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AI 智能推荐 (12码+1)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.psychology, color: Colors.indigo),
                onPressed: _runPrediction,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isPredicting)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_prediction == null)
            Card(
              child: InkWell(
                onTap: _runPrediction,
                child: const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('点击运行 AI 深度学习模型', style: TextStyle(color: Colors.indigo))),
                ),
              ),
            )
          else
            Column(
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            ..._prediction!.redBalls.map((p) => BallWidget(number: p.number, size: 36)),
                            BallWidget(number: _prediction!.blueBall.number, isBlue: true, size: 36),
                          ],
                        ),
                        const Divider(height: 32),
                        const Text('AI 预测置信度热力图', style: TextStyle(fontSize: 14, color: Colors.grey)),
                        const SizedBox(height: 12),
                        _buildHeatmapGrid(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    if (_prediction?.redProbabilities == null) return const SizedBox();
    
    // Normalize probabilities for visual representation
    double maxP = _prediction!.redProbabilities!.values.reduce((a, b) => a > b ? a : b);
    if (maxP == 0) maxP = 1.0;

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 11,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 33,
          itemBuilder: (context, index) {
            int num = index + 1;
            double p = _prediction!.redProbabilities![num] ?? 0;
            double alpha = (p / maxP).clamp(0.05, 1.0);
            bool isTop = _prediction!.redBalls.any((b) => b.number == num);

            return Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(alpha),
                borderRadius: BorderRadius.circular(4),
                border: isTop ? Border.all(color: Colors.black, width: 1.5) : null,
              ),
              child: Center(
                child: Text(
                  '$num',
                  style: TextStyle(
                    fontSize: 10,
                    color: alpha > 0.5 ? Colors.white : Colors.black87,
                    fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        // Blue ball heatmap
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 11,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemCount: 16,
          itemBuilder: (context, index) {
            int num = index + 1;
            double p = _prediction!.blueProbabilities?[num] ?? 0;
            double blueMax = _prediction!.blueProbabilities!.values.reduce((a, b) => a > b ? a : b);
            double alpha = (p / (blueMax == 0 ? 1 : blueMax)).clamp(0.05, 1.0);
            bool isTop = _prediction!.blueBall.number == num;

            return Container(
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(alpha),
                borderRadius: BorderRadius.circular(4),
                border: isTop ? Border.all(color: Colors.black, width: 1.5) : null,
              ),
              child: Center(
                child: Text(
                  '$num',
                  style: TextStyle(
                    fontSize: 10,
                    color: alpha > 0.5 ? Colors.white : Colors.black87,
                    fontWeight: isTop ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _syncModel() async {
    const String defaultUrl = "https://raw.githubusercontent.com/calvinxxw/bicolor/main/ml_training";
    final controller = TextEditingController(text: defaultUrl);
    
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('同步云端模型'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('将从 GitHub 获取最新的 AI 模型 (50/1000 双窗口版)', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '服务器地址',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            child: const Text('立即同步'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final success = await _predictionService.syncModels(controller.text);
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '模型同步成功' : '模型同步失败，请检查网络和服务器地址'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('双色球智能预测'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download),
            tooltip: '同步AI模型',
            onPressed: _syncModel,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _syncData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const DrawCountdownWidget(),
              LatestDrawWidget(
                results: _recentResults,
                isLoading: _isLoading,
                onRefresh: () => _syncData(),
                lastSyncTime: _lastSyncTime,
              ),
              const SizedBox(height: 24),
              _buildPredictionSection(),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.history),
                    title: const Text('历史开奖'),
                    subtitle: const Text('查看所有历史开奖记录'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.pushNamed(context, '/history');
                    },
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 32, bottom: 24),
                child: Text(
                  '© 2026 许迅文. All Rights Reserved.',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}