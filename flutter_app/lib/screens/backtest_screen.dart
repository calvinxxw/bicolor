import 'package:flutter/material.dart';
import 'dart:convert';
import '../services/bet_service.dart';
import '../widgets/ball_widget.dart';

class BacktestScreen extends StatefulWidget {
  const BacktestScreen({super.key});

  @override
  State<BacktestScreen> createState() => _BacktestScreenState();
}

class _BacktestScreenState extends State<BacktestScreen> {
  final BetService _betService = BetService();
  List<Map<String, dynamic>> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() { _isLoading = true; });
    try {
      final history = await _betService.getPurchaseHistory();
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() { _isLoading = false; });
      print("Error loading history: $e");
    }
  }

  Future<void> _showDeleteDialog(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: const Text('确定要删除这条购买记录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteRecord(id);
    }
  }

  Future<void> _deleteRecord(int id) async {
    try {
      await _betService.deletePurchase(id);
      _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('记录已删除')));
      }
    } catch (e) {
      print("Delete error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('暂无购买记录', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('在“手动选号”页面购买后，此处将自动同步回测', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        final reds = List<int>.from(jsonDecode(item['red_balls']));
        final blues = List<int>.from(jsonDecode(item['blue_balls']));
        final status = item['winning_status'] ?? '待开奖';
        final isWon = status.contains('奖') && !status.contains('未');
        final hasDrawData = item['draw_reds'] != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          '期号: ${item['issue']}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _showDeleteDialog(item['id']),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isWon ? Colors.red[50] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                          color: isWon ? Colors.red : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                if (hasDrawData) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('实际开奖:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                      Text(item['draw_date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      ...(item['draw_reds'] as List).map((n) => BallWidget(number: n as int, size: 24, opacity: 0.6)),
                      BallWidget(number: item['draw_blue'] as int, size: 24, isBlue: true, opacity: 0.6),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('您的选号:', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                ] else ...[
                  const Text('投注号码:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ...reds.map((n) {
                      bool isHit = hasDrawData && (item['draw_reds'] as List).contains(n);
                      return BallWidget(
                        number: n, 
                        size: 28,
                        borderColor: isHit ? Colors.red : null,
                        borderWidth: isHit ? 2 : 0,
                      );
                    }),
                    ...blues.map((n) {
                      bool isHit = hasDrawData && item['draw_blue'] == n;
                      return BallWidget(
                        number: n, 
                        size: 28, 
                        isBlue: true,
                        borderColor: isHit ? Colors.blue[900] : null,
                        borderWidth: isHit ? 2 : 0,
                      );
                    }),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '总金额: ¥${item['total_cost']}',
                      style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '保存于: ${item['created_at'].toString().split('T')[0]}',
                      style: const TextStyle(color: Colors.grey, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}