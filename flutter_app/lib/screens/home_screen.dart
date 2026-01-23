import 'package:flutter/material.dart';
import '../models/lottery_result.dart';
import '../services/data_service.dart';
import '../widgets/latest_draw_widget.dart';
import '../widgets/draw_countdown_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DataService _dataService = DataService();
  List<LotteryResult> _recentResults = [];
  bool _isLoading = false;
  DateTime? _lastSyncTime;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _loadRecentResults();
    if (_recentResults.isEmpty) {
      await _syncData();
    }
  }

  Future<void> _loadRecentResults() async {
    final results = await _dataService.getRecentResults(5);
    if (mounted) {
      setState(() {
        _recentResults = results;
      });
    }
  }

  Future<void> _syncData() async {
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

      if (mounted) {
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
      if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _syncData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            const DrawCountdownWidget(),
            LatestDrawWidget(
              results: _recentResults,
              isLoading: _isLoading,
              onRefresh: _syncData,
              lastSyncTime: _lastSyncTime,
            ),
            const SizedBox(height: 16),
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
                '漏 2026 许迅文. All Rights Reserved.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}