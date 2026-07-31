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
import 'package:lumina/presentation/screens/settings/tts_setup_wizard_screen.dart';
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
            (ref) async => const {'fish_audio_api': true, 'minimax': true},
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
    expect(find.byTooltip('Provider details'), findsNWidgets(2));
    expect(find.byTooltip('Add voice provider'), findsOneWidget);
    expect(find.byIcon(Icons.radio_button_checked), findsNothing);
    expect(find.byIcon(Icons.radio_button_off), findsNothing);
    expect(
      find.byKey(const ValueKey('provider-brand-fishAudio')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('provider-brand-minimax')),
      findsOneWidget,
    );
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
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ttsSettingsControllerProvider.overrideWith(_EmptyTtsController.new),
          ttsProviderConfigurationStatusProvider.overrideWith(
            (ref) async => const {'fish_audio_api': false, 'minimax': false},
          ),
        ],
        child: const LuminaApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -420));
    await tester.pumpAndSettle();
    final ttsSettings = find.byKey(const ValueKey('tts-service-settings'));
    await tester.tap(ttsSettings);
    await tester.pumpAndSettle();

    expect(find.byType(TtsSetupWizardScreen), findsOneWidget);
    expect(find.text('Configuration'), findsNothing);
    expect(find.text('Fish Audio'), findsOneWidget);
    expect(find.text('MiniMax'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('provider-brand-fishAudio')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('provider-brand-minimax')),
      findsOneWidget,
    );
    expect(find.byType(BottomSheet), findsNothing);
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

    Navigator.of(tester.element(find.byType(TtsSetupWizardScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('continue-tts-setup')), findsOneWidget);
    expect(find.text('Configuration'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });

  testWidgets('empty provider list opens the add cloud provider flow', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ttsSettingsControllerProvider.overrideWith(_EmptyTtsController.new),
          ttsProviderConfigurationStatusProvider.overrideWith(
            (ref) async => const {'fish_audio_api': false, 'minimax': false},
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const TtsProviderPickerScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No cloud voice providers yet'), findsOneWidget);
    await tester.tap(find.text('Add provider'));
    await tester.pumpAndSettle();
    expect(find.text('Fish Audio'), findsOneWidget);
    expect(find.text('MiniMax'), findsOneWidget);
    await tester.tap(find.text('Fish Audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();
    expect(find.text('Add Voice Provider'), findsOneWidget);
    expect(find.byKey(const ValueKey('save-tts-provider')), findsOneWidget);
    expect(find.text('API Key'), findsOneWidget);
    expect(find.text('Where do I get an API key?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('get-tts-api-key-fish_audio_api')),
      findsOneWidget,
    );
    expect(find.textContaining('Create API Key'), findsOneWidget);
    expect(find.textContaining('stays on this device'), findsOneWidget);
  });

  testWidgets('MiniMax setup explains where to create an API key', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRegistryProvider.overrideWithValue(ProviderRegistry()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const TtsProviderDetailsScreen(
            providerId: 'minimax',
            adding: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Where do I get an API key?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('get-tts-api-key-minimax')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Account management > API keys'),
      findsOneWidget,
    );
  });

  testWidgets('provider details confirms what is removed', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          providerRegistryProvider.overrideWithValue(ProviderRegistry()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const TtsProviderDetailsScreen(providerId: 'fish_audio_api'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('delete-tts-provider')));
    await tester.pumpAndSettle();

    expect(find.text('Delete voice provider?'), findsOneWidget);
    expect(find.textContaining('API key, synced voices'), findsOneWidget);
    expect(
      find.textContaining('does not delete your cloud account'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('confirm-delete-tts-provider')),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete voice provider?'), findsNothing);
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
        id: 'minimax',
        name: 'MiniMax 语音合成',
        subtitle: 'Cloud service',
        readiness: ServiceReadiness.ready,
        active: false,
        editable: true,
        removable: false,
      ),
    ],
    voices: [],
  );
}

class _EmptyTtsController extends TtsSettingsController {
  @override
  Future<TtsSettingsState> build() async => const TtsSettingsState(
    providerId: 'fish_audio_api',
    providerName: 'Fish Audio API',
    voiceId: null,
    voiceName: null,
    readiness: ServiceReadiness.setupRequired,
    providers: [
      ProviderOptionViewData(
        id: 'fish_audio_api',
        name: 'Fish Audio API',
        subtitle: 'Cloud service',
        readiness: ServiceReadiness.setupRequired,
        active: true,
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
