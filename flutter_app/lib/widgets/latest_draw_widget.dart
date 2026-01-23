import 'package:flutter/material.dart';
import '../models/lottery_result.dart';
import 'ball_widget.dart';

class LatestDrawWidget extends StatelessWidget {
  final List<LotteryResult> results;
  final bool isLoading;
  final VoidCallback onRefresh;
  final DateTime? lastSyncTime;

  const LatestDrawWidget({
    super.key,
    required this.results,
    this.isLoading = false,
    required this.onRefresh,
    this.lastSyncTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '近期开奖',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: isLoading ? null : onRefresh,
                  tooltip: '同步数据',
                ),
              ],
            ),
            if (lastSyncTime != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '最后同步: ${_formatSyncTime(lastSyncTime!)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            const Divider(),
            if (results.isEmpty && !isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('暂无数据，请点击刷新按钮同步'),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: results.length,
                separatorBuilder: (context, index) => const Divider(height: 24),
                itemBuilder: (context, index) {
                  final result = results[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '期号: ${result.issue}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: index == 0 ? FontWeight.bold : FontWeight.w500,
                              color: index == 0 ? Colors.red[700] : Colors.black87,
                            ),
                          ),
                          Text(
                            result.drawDate,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: result.redBalls
                                  .map((ball) => BallWidget(number: ball, size: 28))
                                  .toList(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          BallWidget(number: result.blueBall, isBlue: true, size: 28),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }
}