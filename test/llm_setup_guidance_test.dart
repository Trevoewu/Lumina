import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/core/theme.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/presentation/screens/settings/dictionary_explanation_service_screen.dart';
import 'package:lumina/presentation/screens/settings/provider_editor_sheet.dart';

void main() {
  Widget wrap(Object override) => ProviderScope(
    overrides: [override as dynamic],
    child: MaterialApp(
      theme: AppTheme.lightTheme(),
      home: const DictionaryExplanationServiceScreen(),
    ),
  );

  testWidgets('an unconfigured pane offers only the add button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(
        llmSettingsControllerProvider.overrideWith(
          _EmptyLlmSettingsController.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configured providers'), findsOneWidget);
    expect(find.byKey(const ValueKey('add-llm-provider')), findsOneWidget);
    // Nothing is configured, so no provider card is drawn.
    expect(find.byType(SettingsRadioProbe), findsNothing);
  });

  testWidgets('the active provider expands to its cached model chips', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      wrap(
        llmSettingsControllerProvider.overrideWith(
          _ConfiguredLlmSettingsController.new,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('llm-provider-guided-openai')),
      findsOneWidget,
    );
    // The card is active, so the model section is visible and refreshable.
    expect(
      find.byKey(const ValueKey('llm-refresh-guided-openai')),
      findsOneWidget,
    );
    expect(find.text('gpt-guided'), findsOneWidget);
    expect(find.text('gpt-alternate'), findsOneWidget);
    // The preset shows as a tag next to the name.
    expect(find.text('OpenAI'), findsWidgets);
  });

  testWidgets('the editor sheet will not save until a model is chosen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          llmSettingsControllerProvider.overrideWith(
            _EmptyLlmSettingsController.new,
          ),
          openAiCompatibleExplanationProvider.overrideWithValue(
            _ModelCatalogService(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme(),
          home: const _SheetLauncher(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Add AI provider'), findsOneWidget);
    // No model yet, so saving is inert.
    await tester.tap(find.byKey(const ValueKey('save-provider')));
    await tester.pumpAndSettle();
    expect(find.text('Add AI provider'), findsOneWidget);

    // Fetching without a key reports the missing key rather than calling out.
    await tester.tap(find.byKey(const ValueKey('fetch-provider-models')));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('missing API key'),
      findsOneWidget,
    );
  });
}

/// Marker type used only to assert that no provider card was rendered.
class SettingsRadioProbe extends StatelessWidget {
  const SettingsRadioProbe({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _SheetLauncher extends StatelessWidget {
  const _SheetLauncher();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (inner) => TextButton(
            onPressed: () => LlmProviderEditorSheet.show(inner),
            child: const Text('open'),
          ),
        ),
      ),
    );
  }
}

class _EmptyLlmSettingsController extends LlmSettingsController {
  @override
  Future<LlmSettingsState> build() async => const LlmSettingsState(
    providerId: null,
    providerName: null,
    modelId: null,
    readiness: ServiceReadiness.setupRequired,
    providers: [],
    configurations: [],
    cards: [],
  );
}

class _ConfiguredLlmSettingsController extends LlmSettingsController {
  static const provider = LlmProviderConfiguration(
    id: 'guided-openai',
    kind: LlmProviderKind.openAi,
    displayName: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
  );

  @override
  Future<LlmSettingsState> build() async => LlmSettingsState(
    providerId: provider.id,
    providerName: provider.displayName,
    modelId: 'gpt-guided',
    readiness: ServiceReadiness.ready,
    providers: const [],
    configurations: const [provider],
    cards: [
      LlmProviderCardData(
        configuration: provider,
        active: true,
        selectedModelId: 'gpt-guided',
        models: const ['gpt-guided', 'gpt-alternate'],
        syncedAt: DateTime.now(),
      ),
    ],
  );
}

class _ModelCatalogService extends OpenAiCompatibleExplanationProvider {
  _ModelCatalogService()
    : super(settingReader: (_) async => null, settingWriter: (_, _) async {});

  @override
  Future<LlmProviderModels> fetchModels(
    LlmProviderConfiguration provider,
  ) async => LlmProviderModels(
    provider: provider,
    models: const [
      LlmModelOption(id: 'gpt-guided', ownedBy: 'OpenAI'),
      LlmModelOption(id: 'gpt-alternate', ownedBy: 'OpenAI'),
    ],
  );
}
