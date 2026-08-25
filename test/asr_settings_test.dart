import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/asr_service_screen.dart';
import 'package:lumina/services/podcast_transcription_service.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

void main() {
  testWidgets('ASR settings manage Whisper weights and slice length', (
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

    // Every offered weight is listed, smallest first.
    for (final option in asrModelOptions) {
      expect(
        find.byKey(ValueKey('asr-model-${option.id}')),
        findsOneWidget,
        reason: option.name,
      );
    }

    // Nothing is installed yet, so each card offers a download.
    final baseDownload = find.byKey(const ValueKey('asr-download-base'));
    await tester.scrollUntilVisible(
      baseDownload,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(baseDownload);
    await tester.pumpAndSettle();
    expect(service.installedIds, contains('base'));
    expect(find.byKey(const ValueKey('asr-download-base')), findsNothing);

    // Downloading a second weight makes it the active one.
    final smallDownload = find.byKey(const ValueKey('asr-download-small'));
    await tester.scrollUntilVisible(
      smallDownload,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(smallDownload);
    await tester.pumpAndSettle();
    expect(service.installedIds, containsAll(<String>['base', 'small']));
    expect(await service.selectedModel(), WhisperModel.small);

    // Switching back to an installed weight is a plain tap on its card.
    final baseCard = find.byKey(const ValueKey('asr-model-base'));
    await tester.scrollUntilVisible(
      baseCard,
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(baseCard);
    await tester.pumpAndSettle();
    expect(await service.selectedModel(), WhisperModel.base);

    // Slice length is a chip row measured in seconds.
    final chunkChip = find.text('15s');
    await tester.scrollUntilVisible(
      chunkChip,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chunkChip);
    await tester.pumpAndSettle();
    expect(
      await database.getSetting(
        PodcastTranscriptionService.chunkSecondsSettingKey,
      ),
      '15',
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakePodcastTranscriptionService extends PodcastTranscriptionService {
  /// Ids of the weights that are present on disk.
  final Set<String> installedIds = {};

  _FakePodcastTranscriptionService(super.database);

  bool get installed => installedIds.contains(_selected.id);

  AsrModelOption _selectedOption = asrModelOptionFor(
    PodcastTranscriptionService.defaultModel,
  );

  AsrModelOption get _selected => _selectedOption;

  @override
  Future<WhisperModel> selectedModel() async => _selectedOption.model;

  @override
  Future<void> selectModel(WhisperModel model) async {
    _selectedOption = asrModelOptionFor(model);
  }

  @override
  Future<PodcastAsrModelInfo> getModelInfo({WhisperModel? model}) async {
    final option = asrModelOptionFor(model ?? _selectedOption.model);
    final present = installedIds.contains(option.id);
    return PodcastAsrModelInfo(
      model: option.model,
      installed: present,
      path: '/tmp/${option.name}.bin',
      installedBytes: present ? option.expectedBytes : 0,
      partialBytes: 0,
      expectedBytes: option.expectedBytes,
    );
  }

  @override
  Future<void> installModel({
    WhisperModel? model,
    void Function(double? progress, String message)? onProgress,
  }) async {
    final option = asrModelOptionFor(model ?? _selectedOption.model);
    onProgress?.call(0.5, 'Downloading ${option.name}');
    installedIds.add(option.id);
    onProgress?.call(1, '${option.name} is ready');
  }

  @override
  Future<void> deleteModel({WhisperModel? model}) async {
    installedIds.remove(asrModelOptionFor(model ?? _selectedOption.model).id);
  }
}
