import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/presentation/screens/settings/logs_screen.dart';
import 'package:lumina/services/app_log_service.dart';

void main() {
  setUp(() => AppLogService.instance.entries.value = []);
  tearDown(() => AppLogService.instance.entries.value = []);
  testWidgets(
    'exports one log, selected logs and current filter with full details',
    (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      AppLogService.instance.entries.value = [
        AppLogEntry(
          timestamp: DateTime.now(),
          level: AppLogLevel.warning,
          source: 'AI',
          message: 'first log',
        ),
        AppLogEntry(
          timestamp: DateTime.now(),
          level: AppLogLevel.error,
          source: 'Generation',
          message: 'second log',
          error: 'error detail',
          stackTrace: 'stack detail',
        ),
        AppLogEntry(
          timestamp: DateTime.now(),
          level: AppLogLevel.warning,
          source: 'Podcast',
          message: 'third log',
        ),
      ];
      await tester.pumpWidget(const MaterialApp(home: LogsScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(IconButton).last);
      await tester.pumpAndSettle();
      expect(clipboard, contains('third log'));
      expect(clipboard, isNot(contains('first log')));
      await tester.tap(find.byType(Checkbox).at(0));
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pump();
      final export = find.byKey(const ValueKey('export-logs'));
      await tester.ensureVisible(export);
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(clipboard, contains('first log'));
      expect(clipboard, contains('second log'));
      expect(clipboard, contains('error detail'));
      expect(clipboard, contains('stack detail'));
      expect(clipboard, isNot(contains('third log')));
      await tester.tap(find.text('ASR').first);
      await tester.pumpAndSettle();
      expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);
      await tester.tap(export);
      await tester.pumpAndSettle();
      expect(clipboard, contains('third log'));
      expect(clipboard, isNot(contains('second log')));
      expect(tester.takeException(), isNull);
    },
  );
}
