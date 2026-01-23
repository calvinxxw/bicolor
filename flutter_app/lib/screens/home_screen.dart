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
    // Insert sample data if database is empty
    await _dataService.insertSampleData();
    await _loadRecentResults();
    await _autoSyncIfNeeded();
  }

  Future<void> _loadRecentResults() async {
    final results = await _dataService.getRecentResults(5);
    if (mounted) {
      setState(() {
        _recentResults = results;
      });
    }
  }

  Future<void> _autoSyncIfNeeded() async {
    // Auto-sync if no data or last sync was more than 1 hour ago
    if (_recentResults.isEmpty ||
        _lastSyncTime == null ||
        DateTime.now().difference(_lastSyncTime!).inHours >= 1) {
      await _syncData();
    }
  }

  Future<void> _syncData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _dataService.syncData();
      await _loadRecentResults();
      setState(() {
        _lastSyncTime = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('数据同步成功'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String message = '同步失败';
        if (e.toString().contains('Connection refused')) {
          message = '网络连接失败，请检查网络设置';
        } else if (e.toString().contains('404')) {
          message = '服务器接口地址已变更，请联系开发者';
        } else {
          message = '同步失败: $e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: '重试',
              textColor: Colors.white,
              onPressed: _syncData,
            ),
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
              padding: EdgeInsets.only(bottom: 24),
              child: Text(
                '© 2026 许迅文. All Rights Reserved.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}