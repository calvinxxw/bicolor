import 'dart:async';
import 'package:flutter/material.dart';
import '../models/draw_schedule.dart';

class DrawCountdownWidget extends StatefulWidget {
  const DrawCountdownWidget({super.key});

  @override
  State<DrawCountdownWidget> createState() => _DrawCountdownWidgetState();
}

class _DrawCountdownWidgetState extends State<DrawCountdownWidget> {
  Timer? _timer;
  Duration _timeUntilDraw = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateCountdown() {
    setState(() {
      _timeUntilDraw = DrawSchedule.getTimeUntilNextDraw();
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextDraw = DrawSchedule.getNextDrawTime();
    final dayName = DrawSchedule.getDrawDayName(nextDraw.weekday);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  '下期开奖倒计时',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DrawSchedule.formatCountdown(_timeUntilDraw),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$dayName ${nextDraw.month}月${nextDraw.day}日 ${DrawSchedule.drawHour}:${DrawSchedule.drawMinute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
