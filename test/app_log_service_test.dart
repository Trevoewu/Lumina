import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/app_log_service.dart';

void main() {
  test('AppLogger only records warnings and errors', () async {
    final service = AppLogService.instance;
    await service.clear();

    AppLogger.info('Playback', 'chapter loaded');
    AppLogger.warning('Playback', 'chapter metadata missing');
    AppLogger.error(
      'Generation',
      'paragraph failed',
      error: StateError('network'),
      stackTrace: StackTrace.current,
    );

    expect(service.entries.value, hasLength(2));
    expect(service.entries.value.first.source, 'Playback');
    expect(service.entries.value.first.level, AppLogLevel.warning);
    expect(service.entries.value.last.source, 'Generation');
    expect(service.entries.value.last.level, AppLogLevel.error);
    expect(service.entries.value.last.error, contains('network'));
    expect(service.entries.value.last.stackTrace, isNotEmpty);
    expect(service.exportText(), contains('[Generation] paragraph failed'));
    expect(service.exportText(), isNot(contains('chapter loaded')));
  });

  test('AppLogEntry reads legacy info level as debug', () {
    final entry = AppLogEntry.fromJson({
      'timestamp': DateTime.now().toIso8601String(),
      'level': 'info',
      'source': 'App',
      'message': 'legacy line',
    });

    expect(entry.level, AppLogLevel.debug);
  });

  test('logs expire after one day and debug entries are never retained', () {
    final now = DateTime(2026, 8, 27, 12);
    AppLogEntry entry(AppLogLevel level, DateTime timestamp) => AppLogEntry(
      timestamp: timestamp,
      level: level,
      source: 'Test',
      message: 'message',
    );

    expect(
      AppLogService.shouldRetain(
        entry(AppLogLevel.warning, now.subtract(const Duration(hours: 23))),
        now,
      ),
      isTrue,
    );
    expect(
      AppLogService.shouldRetain(
        entry(AppLogLevel.error, now.subtract(const Duration(days: 1))),
        now,
      ),
      isFalse,
    );
    expect(
      AppLogService.shouldRetain(entry(AppLogLevel.debug, now), now),
      isFalse,
    );
  });
}
