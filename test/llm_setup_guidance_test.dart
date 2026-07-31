import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumina/core/providers.dart';
import 'package:lumina/core/service_settings_controllers.dart';
import 'package:lumina/data/dictionary/openai_compatible_explanation_provider.dart';
import 'package:lumina/presentation/screens/settings/dictionary_explanation_service_screen.dart';
import 'package:lumina/presentation/screens/settings/llm_setup_wizard_screen.dart';

void main() {
  testWidgets('unfinished LLM settings opens the wizard immediately', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          llmSettingsControllerProvider.overrideWith(
            _EmptyLlmSettingsController.new,
          ),
        ],
        child: const MaterialApp(home: DictionaryExplanationServiceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LlmSetupWizardScreen), findsOneWidget);
    expect(find.text('Configuration'), findsNothing);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.text('DeepSeek'), findsOneWidget);
    expect(find.byKey(const ValueKey('provider-brand-openAi')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('provider-brand-deepSeek')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('provider-brand-zai')), findsOneWidget);

    final wizardElement = tester.element(find.byType(LlmSetupWizardScreen));
    await tester.tap(find.text('OpenAI'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(SlideTransition), findsWidgets);
    await tester.pumpAndSettle();

    expect(
      tester.element(find.byType(LlmSetupWizardScreen)),
      same(wizardElement),
    );
    expect(find.byKey(const ValueKey('wizard-llm-api-key')), findsOneWidget);

    Navigator.of(tester.element(find.byType(LlmSetupWizardScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('continue-llm-setup')), findsOneWidget);
    expect(find.text('Configuration'), findsNothing);
  });

  testWidgets('guided LLM setup leads from provider to API key', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          llmSettingsControllerProvider.overrideWith(
            _EmptyLlmSettingsController.new,
          ),
        ],
        child: const MaterialApp(
          home: LlmProviderPickerScreen(guidedSetup: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI setup progress'), findsOneWidget);
    expect(find.text('Provider'), findsOneWidget);
    expect(find.text('Key'), findsOneWidget);
    expect(find.text('Model'), findsOneWidget);
    expect(find.text('OpenAI'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);

    await tester.tap(find.text('OpenAI'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();

    expect(find.text('Add Provider'), findsOneWidget);
    expect(find.byKey(const ValueKey('llm-api-key-field')), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.text('Where do I get an API key?'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('get-llm-api-key-openai')),
      findsOneWidget,
    );
    expect(find.textContaining('Models will sync next'), findsOneWidget);

    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('guided LLM model step requires an explicit model selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          llmSettingsControllerProvider.overrideWith(
            _ModelLlmSettingsController.new,
          ),
          openAiCompatibleExplanationProvider.overrideWithValue(
            _ModelCatalogService(),
          ),
        ],
        child: const MaterialApp(home: _ModelSetupLauncher()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-llm-model-setup')));
    await tester.pumpAndSettle();

    expect(find.text('AI setup progress'), findsOneWidget);
    expect(find.text('gpt-guided'), findsOneWidget);
    expect(
      find.textContaining('Choose the model to use for AI features'),
      findsOneWidget,
    );

    await tester.tap(find.text('gpt-guided'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();

    expect(find.text('Model selected'), findsOneWidget);
  });

  testWidgets('single-page LLM wizard completes without pushing another page', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          llmSettingsControllerProvider.overrideWith(
            _ModelLlmSettingsController.new,
          ),
          openAiCompatibleExplanationProvider.overrideWithValue(
            _ModelCatalogService(),
          ),
        ],
        child: const MaterialApp(home: _SinglePageModelSetupLauncher()),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('start-single-page-llm')));
    await tester.pumpAndSettle();
    final wizardElement = tester.element(find.byType(LlmSetupWizardScreen));

    await tester.tap(find.text('gpt-guided'));
    await tester.pump();
    expect(
      tester.element(find.byType(LlmSetupWizardScreen)),
      same(wizardElement),
    );
    await tester.tap(find.byKey(const ValueKey('setup-next')));
    await tester.pumpAndSettle();

    expect(find.text('Model selected'), findsOneWidget);
  });
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
  );
}

class _ModelLlmSettingsController extends LlmSettingsController {
  static const provider = LlmProviderConfiguration(
    id: 'guided-openai',
    kind: LlmProviderKind.openAi,
    displayName: 'OpenAI',
    baseUrl: 'https://api.openai.com/v1',
  );

  @override
  Future<LlmSettingsState> build() async => const LlmSettingsState(
    providerId: 'guided-openai',
    providerName: 'OpenAI',
    modelId: null,
    readiness: ServiceReadiness.setupRequired,
    providers: [],
    configurations: [provider],
  );

  @override
  Future<void> selectModel(String modelId) async {
    state = AsyncData(
      LlmSettingsState(
        providerId: provider.id,
        providerName: provider.displayName,
        modelId: modelId,
        readiness: ServiceReadiness.ready,
        providers: const [],
        configurations: const [provider],
      ),
    );
  }
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

class _ModelSetupLauncher extends StatefulWidget {
  const _ModelSetupLauncher();

  @override
  State<_ModelSetupLauncher> createState() => _ModelSetupLauncherState();
}

class _ModelSetupLauncherState extends State<_ModelSetupLauncher> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _selected
          ? const Text('Model selected')
          : FilledButton(
              key: const ValueKey('start-llm-model-setup'),
              onPressed: () async {
                final selected = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const LlmModelPickerScreen(guidedSelection: true),
                  ),
                );
                if (mounted && selected == true) {
                  setState(() => _selected = true);
                }
              },
              child: const Text('Start'),
            ),
    ),
  );
}

class _SinglePageModelSetupLauncher extends StatefulWidget {
  const _SinglePageModelSetupLauncher();

  @override
  State<_SinglePageModelSetupLauncher> createState() =>
      _SinglePageModelSetupLauncherState();
}

class _SinglePageModelSetupLauncherState
    extends State<_SinglePageModelSetupLauncher> {
  bool _selected = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: _selected
          ? const Text('Model selected')
          : FilledButton(
              key: const ValueKey('start-single-page-llm'),
              onPressed: () async {
                final selected = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => const LlmSetupWizardScreen(),
                  ),
                );
                if (mounted && selected == true) {
                  setState(() => _selected = true);
                }
              },
              child: const Text('Start'),
            ),
    ),
  );
}
