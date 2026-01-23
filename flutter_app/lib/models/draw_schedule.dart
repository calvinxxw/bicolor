class DrawSchedule {
  static const List<int> drawDays = [2, 4, 7]; // Tuesday, Thursday, Sunday
  static const int drawHour = 21;
  static const int drawMinute = 15;

  static DateTime getNextDrawTime() {
    final now = DateTime.now();
    DateTime nextDraw = DateTime(
      now.year,
      now.month,
      now.day,
      drawHour,
      drawMinute,
    );

    // If today's draw time has passed, start from tomorrow
    if (now.isAfter(nextDraw)) {
      nextDraw = nextDraw.add(const Duration(days: 1));
    }

    // Find the next draw day
    while (!drawDays.contains(nextDraw.weekday)) {
      nextDraw = nextDraw.add(const Duration(days: 1));
    }

    return nextDraw;
  }

  static Duration getTimeUntilNextDraw() {
    final nextDraw = getNextDrawTime();
    return nextDraw.difference(DateTime.now());
  }

  static String formatCountdown(Duration duration) {
    if (duration.isNegative) {
      return 'Draw in progress';
    }

    final days = duration.inDays;
    final hours = duration.inHours % 24;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (days > 0) {
      return '$days天 $hours小时 $minutes分';
    } else if (hours > 0) {
      return '$hours小时 $minutes分 $seconds秒';
    } else if (minutes > 0) {
      return '$minutes分 $seconds秒';
    } else {
      return '$seconds秒';
    }
  }

  static String getDrawDayName(int weekday) {
    switch (weekday) {
      case 2:
        return '周二';
      case 4:
        return '周四';
      case 7:
        return '周日';
      default:
        return '';
    }
  }
}
