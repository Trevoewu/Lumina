import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/asr_service_screen.dart';
import 'package:lumina/services/podcast_transcription_service.dart';

void main() {
  testWidgets('ASR settings manage the model and transcript preferences', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final service = _FakePodcastTranscriptionService(database);
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          podcastTranscriptionServiceProvider.overrideWithValue(service),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const AsrServiceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('asr-status-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('asr-model-status')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('asr-chunk-settings')));
    await tester.pumpAndSettle();
    final chunkChoices = find.byType(RadioListTile<int>);
    expect(chunkChoices, findsNWidgets(3));
    await tester.tap(chunkChoices.first);
    await tester.pumpAndSettle();
    expect(
      await database.getSetting(
        PodcastTranscriptionService.chunkMinutesSettingKey,
      ),
      '1',
    );

    await tester.tap(find.byKey(const ValueKey('asr-language-settings')));
    await tester.pumpAndSettle();
    final languageChoices = find.byType(RadioListTile<String>);
    expect(languageChoices, findsNWidgets(2));
    await tester.tap(languageChoices.last);
    await tester.pumpAndSettle();
    expect(
      await database.getSetting(
        PodcastTranscriptionService.languagePreferenceSettingKey,
      ),
      PodcastTranscriptionService.automaticLanguagePreference,
    );

    final downloadButton = find.byKey(const ValueKey('download-asr-model'));
    await tester.ensureVisible(downloadButton);
    await tester.pumpAndSettle();
    expect(downloadButton, findsOneWidget);
    await tester.tap(downloadButton);
    await tester.pumpAndSettle();
    expect(service.installed, isTrue);
    expect(find.byKey(const ValueKey('delete-asr-model')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('delete-asr-model')));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    await tester.tap(
      find.descendant(of: dialog, matching: find.byType(FilledButton)),
    );
    await tester.pumpAndSettle();
    expect(service.installed, isFalse);
    expect(find.byKey(const ValueKey('download-asr-model')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakePodcastTranscriptionService extends PodcastTranscriptionService {
  bool installed = false;

  _FakePodcastTranscriptionService(super.database);

  @override
  Future<PodcastAsrModelInfo> getModelInfo() async => PodcastAsrModelInfo(
    installed: installed,
    path: '/tmp/whisper-base.bin',
    installedBytes: installed
        ? PodcastTranscriptionService.baseModelExpectedBytes
        : 0,
    partialBytes: 0,
    expectedBytes: PodcastTranscriptionService.baseModelExpectedBytes,
  );

  @override
  Future<void> installModel({
    void Function(double? progress, String message)? onProgress,
  }) async {
    onProgress?.call(0.5, 'Downloading Whisper Base');
    installed = true;
    onProgress?.call(1, 'Whisper Base is ready');
  }

  @override
  Future<void> deleteModel() async {
    installed = false;
  }
}
