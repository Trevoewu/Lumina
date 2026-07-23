String formatPodcastDuration(int milliseconds) {
  if (milliseconds <= 0) return '';
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours > 0) return '$hours小时${minutes == 0 ? '' : '$minutes分钟'}';
  return '${duration.inMinutes.clamp(1, 9999)}分钟';
}

String formatPodcastDate(int milliseconds) {
  if (milliseconds <= 0) return '';
  final date = DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
  final now = DateTime.now();
  final difference = now.difference(date);
  if (!difference.isNegative && difference.inDays == 0) return '今天';
  if (!difference.isNegative && difference.inDays == 1) return '昨天';
  if (!difference.isNegative && difference.inDays < 7) {
    return '${difference.inDays}天前';
  }
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

String formatPlaybackTime(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}
