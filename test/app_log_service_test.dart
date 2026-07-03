import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/services/app_log_service.dart';

void main() {
  test('AppLogger records source, level, errors, and stack traces', () async {
    final service = AppLogService.instance;
    await service.clear();

    AppLogger.info('Playback', 'chapter loaded');
    AppLogger.error(
      'Generation',
      'paragraph failed',
      error: StateError('network'),
      stackTrace: StackTrace.current,
    );

    expect(service.entries.value, hasLength(2));
    expect(service.entries.value.first.source, 'Playback');
    expect(service.entries.value.first.level, AppLogLevel.info);
    expect(service.entries.value.last.source, 'Generation');
    expect(service.entries.value.last.level, AppLogLevel.error);
    expect(service.entries.value.last.error, contains('network'));
    expect(service.entries.value.last.stackTrace, isNotEmpty);
    expect(service.exportText(), contains('[Generation] paragraph failed'));
  });
}
