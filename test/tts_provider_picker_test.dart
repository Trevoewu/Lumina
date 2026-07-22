import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/database/app_database.dart';
import 'package:lumina/main.dart';
import 'package:lumina/presentation/screens/settings/tts_service_screen.dart';
import 'package:lumina/tts/provider_registry.dart';

void main() {
  testWidgets('provider picker separates switching from provider details', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRegistryProvider.overrideWithValue(ProviderRegistry()),
          ttsSettingsControllerProvider.overrideWith(_PickerTtsController.new),
          ttsProviderConfigurationStatusProvider.overrideWith(
            (ref) async => const {
              'fish_audio_api': true,
              'kokoro_local': false,
              'fish_audio_local': false,
              'edge': true,
              'minimax': false,
            },
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const TtsProviderPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Current'), findsOneWidget);
    expect(find.text('Other providers'), findsOneWidget);
    expect(find.text('Use'), findsOneWidget);
    expect(find.text('Set up'), findsNWidgets(3));
    expect(find.byTooltip('Provider details'), findsNWidgets(2));
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(find.byIcon(Icons.radio_button_off), findsNothing);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(TtsProviderPickerScreen),
      matchesGoldenFile('goldens/tts_provider_picker_430.png'),
    );
  });

  testWidgets('real settings flow opens the provider picker', (tester) async {
    tester.view.physicalSize = const Size(430, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tts-service-settings')));
    await tester.pumpAndSettle();

    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data)
        .whereType<String>()
        .join(' | ');
    expect(
      find.text('Provider'),
      findsOneWidget,
      reason: 'Visible text: $text; exception: ${tester.takeException()}',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

class _PickerTtsController extends TtsSettingsController {
  @override
  Future<TtsSettingsState> build() async => const TtsSettingsState(
    providerId: 'fish_audio_api',
    providerName: 'Fish Audio API',
    voiceId: 'fish_api_default',
    voiceName: 'Fish Audio Default',
    readiness: ServiceReadiness.ready,
    providers: [
      ProviderOptionViewData(
        id: 'fish_audio_api',
        name: 'Fish Audio API',
        subtitle: 'Cloud service',
        readiness: ServiceReadiness.ready,
        active: true,
        editable: true,
        removable: false,
      ),
      ProviderOptionViewData(
        id: 'kokoro_local',
        name: 'Kokoro 本地 TTS（MLX）',
        subtitle: 'On-device service',
        readiness: ServiceReadiness.setupRequired,
        active: false,
        editable: true,
        removable: false,
      ),
      ProviderOptionViewData(
        id: 'fish_audio_local',
        name: 'Fish Audio S2 Pro（MLX 8bit）',
        subtitle: 'On-device service',
        readiness: ServiceReadiness.setupRequired,
        active: false,
        editable: true,
        removable: false,
      ),
      ProviderOptionViewData(
        id: 'edge',
        name: 'Edge TTS（免费保底）',
        subtitle: 'Cloud service',
        readiness: ServiceReadiness.ready,
        active: false,
        editable: true,
        removable: false,
      ),
      ProviderOptionViewData(
        id: 'minimax',
        name: 'MiniMax 语音合成',
        subtitle: 'Cloud service',
        readiness: ServiceReadiness.setupRequired,
        active: false,
        editable: true,
        removable: false,
      ),
    ],
    voices: [],
  );
}
