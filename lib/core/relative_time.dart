import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// Localized "how long ago" label for an epoch-millisecond timestamp.
///
/// Falls back to an ISO date once the moment is more than a week old, so lists
/// stay readable without turning into a wall of "42 days ago".
String relativeTimeLabel(BuildContext context, int milliseconds) {
  if (milliseconds <= 0) return '';
  final moment = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  final difference = DateTime.now().difference(moment);
  if (!difference.isNegative) {
    if (difference.inMinutes < 1) return context.tr('刚刚', 'Just now', 'たった今');
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return context.tr('$minutes 分钟前', '$minutes min ago', '$minutes分前');
    }
    if (difference.inDays == 0) return context.tr('今天', 'Today', '今日');
    if (difference.inDays == 1) return context.tr('昨天', 'Yesterday', '昨日');
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return context.tr('$days 天前', '$days days ago', '$days日前');
    }
  }
  return shortDateLabel(context, moment);
}

const _englishMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// "Sep 29" / "9月29日", with the year only when it is not this one, so an
/// older date reads like the relative ones beside it rather than an ISO
/// timestamp.
String shortDateLabel(BuildContext context, DateTime moment) {
  final thisYear = moment.year == DateTime.now().year;
  final month = moment.month;
  final day = moment.day;
  return context.tr(
    thisYear ? '$month月$day日' : '${moment.year}年$month月$day日',
    thisYear
        ? '${_englishMonths[month - 1]} $day'
        : '${_englishMonths[month - 1]} $day, ${moment.year}',
    thisYear ? '$month月$day日' : '${moment.year}年$month月$day日',
  );
}
