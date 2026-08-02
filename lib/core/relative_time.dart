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
    if (difference.inMinutes < 1) return context.tr('刚刚', 'Just now');
    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return context.tr('$minutes 分钟前', '$minutes min ago');
    }
    if (difference.inDays == 0) return context.tr('今天', 'Today');
    if (difference.inDays == 1) return context.tr('昨天', 'Yesterday');
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return context.tr('$days 天前', '$days days ago');
    }
  }
  return '${moment.year}-${moment.month.toString().padLeft(2, '0')}-'
      '${moment.day.toString().padLeft(2, '0')}';
}
