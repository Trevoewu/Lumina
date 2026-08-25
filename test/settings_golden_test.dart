import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/presentation/screens/settings/settings_screen.dart';
import 'package:lumina/services/podcast_transcription_service.dart';

void main() {
  testWidgets('settings root dark visual regression', (tester) async {
    await _pumpSettings(
      tester,
      size: const Size(390, 844),
      themeMode: ThemeMode.dark,
      textScale: 1,
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_dark_390.png'),
    );
  });

  testWidgets('settings root light large-text visual regression', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      size: const Size(430, 932),
      themeMode: ThemeMode.light,
      textScale: 1.3,
    );
    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings_light_430_130.png'),
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required Size size,
  required ThemeMode themeMode,
  required double textScale,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final database = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(database.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        ttsSettingsControllerProvider.overrideWith(_GoldenTtsController.new),
        asrSettingsControllerProvider.overrideWith(_GoldenAsrController.new),
        llmSettingsControllerProvider.overrideWith(_GoldenLlmController.new),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme(),
        darkTheme: AppTheme.darkTheme(),
        themeMode: themeMode,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _GoldenTtsController extends TtsSettingsController {
  @override
  Future<TtsSettingsState> build() async => const TtsSettingsState(
    providerId: 'fish_audio_api',
    providerName: 'Fish Audio API',
    voiceId: 'fish_api_default',
    voiceName: 'Fish Audio Default',
    readiness: ServiceReadiness.ready,
    providers: [],
    voices: [],
  );
}

class _GoldenLlmController extends LlmSettingsController {
  @override
  Future<LlmSettingsState> build() async => const LlmSettingsState(
    providerId: 'deepseek',
    providerName: 'DeepSeek',
    modelId: 'deepseek-chat',
    readiness: ServiceReadiness.ready,
    providers: [],
    configurations: [],
  );
}

class _GoldenAsrController extends AsrSettingsController {
  @override
  Future<AsrSettingsState> build() async => const AsrSettingsState(
    readiness: ServiceReadiness.ready,
    modelInstalled: true,
    modelPath: '/models/ggml-base.bin',
    installedBytes: PodcastTranscriptionService.baseModelExpectedBytes,
    partialBytes: 0,
    expectedBytes: PodcastTranscriptionService.baseModelExpectedBytes,
    chunkSeconds: PodcastTranscriptionService.defaultChunkSeconds,
  );
}
